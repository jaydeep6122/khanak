import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { Filters, pageResult } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { assertCanChange, stockWarnings } from "../../services/ledger.js";
import { periodFor } from "../../services/periods.js";
import { postKilnUnloading } from "../../services/posting.js";
import {
  assertWorkersExist,
  groupRows,
  loadWorkTypes,
  rateLookup,
  readWork,
  savedRates,
} from "../../services/work-groups.js";
import { ApiError } from "../../utils/ApiError.js";
import { context, created, ok, paged } from "../../utils/http.js";
import { bricks, cancelSchema, date, id, listQuery, optionalText, queryBoolean } from "../../utils/schemas.js";
import { groupSchema } from "../brick-counts/brick-counts.schemas.js";

// Taking fired bricks out of a kiln ("nikasi"): that kiln's stock down,
// fired stock up, and the unloading group paid. Open to every role; a supervisor
// sees and changes only their own.
const router = Router({ mergeParams: true });

const unloadingSchema = z.object({
  unloaded_on: date,
  // Which kiln the fired bricks came out of.
  kiln_id: id,
  quantity: bricks,
  groups: z.array(groupSchema).max(10).optional(),
  note: optionalText(1000),
});

const listQuerySchema = listQuery({
  kiln_id: id.optional(),
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  include_cancelled: queryBoolean.optional(),
});

const COLUMNS = `k.id, k.period_id, k.unloaded_on, k.kiln_id, k.quantity, k.note, k.created_by,
  k.cancelled_at, k.cancel_reason, k.created_at, k.updated_at`;

const notFound = () => new ApiError(404, "Not found");

async function getUnloading(db, ctx, unloadingId) {
  const {
    rows: [unloading],
  } = await db.query(
    `SELECT ${COLUMNS}, b.name AS kiln_name, u.name AS created_by_name
     FROM kiln_unloadings k
     JOIN kilns b ON b.id = k.kiln_id
     LEFT JOIN users u ON u.id = k.created_by
     WHERE k.factory_id = $1 AND k.id = $2`,
    [ctx.factory.id, unloadingId],
  );
  if (!unloading) throw notFound();
  if (ctx.role === "supervisor" && unloading.created_by !== ctx.user.id) throw notFound();
  return { ...unloading, groups: (await readWork(db, "kiln_unloading_id", unloadingId)).groups };
}

async function workRowsFor(client, ctx, data, saved) {
  const { rowCount } = await client.query("SELECT 1 FROM kilns WHERE factory_id = $1 AND id = $2", [
    ctx.factory.id,
    data.kiln_id,
  ]);
  if (!rowCount) throw new ApiError(400, "Unknown kiln_id");
  const types = await loadWorkTypes(client, ctx.factory.id);
  await assertWorkersExist(
    client,
    ctx.factory.id,
    (data.groups ?? []).flatMap((group) => group.workers.map((worker) => worker.worker_id)),
  );
  return groupRows(data.groups, types, {
    bricks: data.quantity,
    rateFor: rateLookup(saved),
    allowAmounts: ctx.role !== "supervisor",
  });
}

async function lockUnloading(client, ctx, unloadingId) {
  const {
    rows: [row],
  } = await client.query("SELECT * FROM kiln_unloadings WHERE factory_id = $1 AND id = $2 FOR UPDATE", [
    ctx.factory.id,
    unloadingId,
  ]);
  if (!row) throw notFound();
  if (row.cancelled_at) throw new ApiError(409, "This unloading is cancelled");
  assertCanChange(ctx, row);
  return row;
}

const auditView = (unloading) => ({
  unloaded_on: unloading.unloaded_on,
  kiln_id: unloading.kiln_id,
  quantity: unloading.quantity,
  note: unloading.note,
  groups: unloading.groups.map((group) => ({
    work_type_id: group.work_type_id,
    total: group.total,
    workers: group.workers.map((worker) => ({ worker_id: worker.worker_id, amount: worker.amount })),
  })),
});

router.get("/", validate(listQuerySchema, "query"), async (req, res) => {
  const ctx = context(req);
  const query = req.query;
  const filters = new Filters()
    .add("k.factory_id = ?", ctx.factory.id)
    .addIf(query.from, "k.unloaded_on >= ?", query.from)
    .addIf(query.to, "k.unloaded_on <= ?", query.to)
    .addIf(query.period_id, "k.period_id = ?", query.period_id)
    .addIf(query.kiln_id, "k.kiln_id = ?", query.kiln_id)
    .addIf(!query.include_cancelled, "k.cancelled_at IS NULL")
    .addIf(ctx.role === "supervisor", "k.created_by = ?", ctx.user.id);
  const { rows } = await pool.query(
    `SELECT ${COLUMNS}, b.name AS kiln_name, u.name AS created_by_name,
            (SELECT COALESCE(sum(e.amount), 0) FROM work_entries e WHERE e.kiln_unloading_id = k.id) AS total_pay,
            COUNT(*) OVER () AS total_count
     FROM kiln_unloadings k
     JOIN kilns b ON b.id = k.kiln_id
     LEFT JOIN users u ON u.id = k.created_by
     ${filters.where}
     ORDER BY k.unloaded_on DESC, k.created_at DESC
     LIMIT ${filters.param(query.limit)} OFFSET ${filters.param(query.offset)}`,
    filters.values,
  );
  paged(res, pageResult(rows, query));
});

router.post("/", validate(unloadingSchema), async (req, res) => {
  const ctx = context(req);
  const data = req.body;
  const result = await withTransaction(async (client) => {
    const period = await periodFor(client, ctx.factory.id, data.unloaded_on);
    const workRows = await workRowsFor(client, ctx, data, new Map());
    const {
      rows: [unloading],
    } = await client.query(
      `INSERT INTO kiln_unloadings (factory_id, period_id, unloaded_on, kiln_id, quantity, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [ctx.factory.id, period.id, data.unloaded_on, data.kiln_id, data.quantity, data.note ?? null, ctx.user.id],
    );
    await postKilnUnloading(client, unloading, workRows);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "kiln_unloading", entityId: unloading.id });
    return { ...(await getUnloading(client, ctx, unloading.id)), warnings: await stockWarnings(client, ctx.factory.id) };
  });
  created(res, result);
});

router.get("/:unloadingId", idParams("unloadingId"), async (req, res) => {
  ok(res, await getUnloading(pool, context(req), req.params.unloadingId));
});

router.put("/:unloadingId", idParams("unloadingId"), validate(unloadingSchema), async (req, res) => {
  const ctx = context(req);
  const data = req.body;
  const { unloadingId } = req.params;
  const result = await withTransaction(async (client) => {
    await lockUnloading(client, ctx, unloadingId);
    const before = await getUnloading(client, ctx, unloadingId);
    const period = await periodFor(client, ctx.factory.id, data.unloaded_on);
    const workRows = await workRowsFor(client, ctx, data, await savedRates(client, "kiln_unloading_id", unloadingId));
    const {
      rows: [unloading],
    } = await client.query(
      `UPDATE kiln_unloadings SET unloaded_on = $2, kiln_id = $3, quantity = $4, note = $5, period_id = $6
       WHERE id = $1 RETURNING *`,
      [unloadingId, data.unloaded_on, data.kiln_id, data.quantity, data.note ?? null, period.id],
    );
    await postKilnUnloading(client, unloading, workRows);
    const after = await getUnloading(client, ctx, unloadingId);
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "update",
      entityType: "kiln_unloading",
      entityId: unloadingId,
      before: auditView(before),
      after: auditView(after),
    });
    return { ...after, warnings: await stockWarnings(client, ctx.factory.id) };
  });
  ok(res, result);
});

router.post("/:unloadingId/cancel", idParams("unloadingId"), validate(cancelSchema), async (req, res) => {
  const ctx = context(req);
  const { unloadingId } = req.params;
  const result = await withTransaction(async (client) => {
    await lockUnloading(client, ctx, unloadingId);
    const before = await getUnloading(client, ctx, unloadingId);
    const {
      rows: [unloading],
    } = await client.query(
      `UPDATE kiln_unloadings SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3
       WHERE id = $1 RETURNING *`,
      [unloadingId, ctx.user.id, req.body.reason ?? null],
    );
    await postKilnUnloading(client, unloading, []);
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "cancel",
      entityType: "kiln_unloading",
      entityId: unloadingId,
      before: { ...auditView(before), reason: req.body.reason ?? null },
    });
    return { ...(await getUnloading(client, ctx, unloadingId)), warnings: await stockWarnings(client, ctx.factory.id) };
  });
  ok(res, result);
});

export default router;
