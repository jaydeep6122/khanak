import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { Filters, pageResult } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { workerBalance } from "../../services/ledger.js";
import { hasRate, paidAtOwnRate, payFor, rateMissing } from "../../services/pay.js";
import { periodFor } from "../../services/periods.js";
import { ApiError } from "../../utils/ApiError.js";
import { context, created, ok, paged } from "../../utils/http.js";
import { money as toMoney } from "../../utils/money.js";
import { cancelSchema, date, decimal, id, listQuery, money, optionalText, queryBoolean } from "../../utils/schemas.js";

// Work typed in by hand: day work ("6 days"), a lump sum ("₹150, he was
// worn out") or any kind of work done outside a count. Owner and munim only.
const router = Router({ mergeParams: true });
router.use(requireRole("munim"));

const entrySchema = z.object({
  worker_id: id,
  work_type_id: id,
  entry_date: date,
  // Days, bricks or trips, by the kind of work. Not used for a lump sum.
  quantity: decimal({ dp: 3, gt: 0, max: 1e9 }).optional(),
  // Overrides what the rate gives, e.g. ₹150 for a ₹100 day.
  amount: money().optional(),
  note: optionalText(1000),
});

const listQuerySchema = listQuery({
  worker_id: id.optional(),
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  source: z.enum(["manual", "brick_count", "kiln_unloading", "salary"]).optional(),
  include_cancelled: queryBoolean.optional(),
});

const COLUMNS = `e.id, e.period_id, e.worker_id, e.work_type_id, e.entry_date, e.quantity, e.rate,
  e.amount, e.group_total, e.group_size, e.source, e.brick_count_id, e.kiln_unloading_id,
  e.salary_month, e.note, e.created_by, e.cancelled_at, e.cancel_reason, e.created_at, e.updated_at`;

const notFound = () => new ApiError(404, "Not found");

async function getEntry(db, factoryId, entryId) {
  const {
    rows: [entry],
  } = await db.query(
    `SELECT ${COLUMNS}, w.name AS worker_name, t.code AS work_type_code, t.name AS work_type_name, t.pay_unit
     FROM work_entries e
     JOIN workers w ON w.id = e.worker_id
     JOIN work_types t ON t.id = e.work_type_id
     WHERE e.factory_id = $1 AND e.id = $2`,
    [factoryId, entryId],
  );
  if (!entry) throw notFound();
  return entry;
}

/**
 * quantity, rate and amount for a hand-typed entry. `keptRate` is the rate an
 * edited entry was made with, kept while its worker and kind stay the same.
 */
async function priced(db, factoryId, data, keptRate) {
  const {
    rows: [type],
  } = await db.query("SELECT * FROM work_types WHERE factory_id = $1 AND id = $2", [factoryId, data.work_type_id]);
  if (!type) throw new ApiError(400, "Unknown work_type_id");
  if (type.code === "salary") throw new ApiError(400, "Monthly salary is added by itself at the end of each month");
  if (type.code === "stacking") {
    throw new ApiError(400, "Khadkaniya are paid from the counts of bricks going into the kiln");
  }

  const {
    rows: [worker],
  } = await db.query("SELECT rate, rate_unit FROM workers WHERE factory_id = $1 AND id = $2", [
    factoryId,
    data.worker_id,
  ]);
  if (!worker) throw new ApiError(400, "Unknown worker_id");

  if (type.pay_unit === "lumpsum") {
    if (data.amount === undefined) throw new ApiError(400, `"${type.name}" is a lump sum: give the amount`);
    return { quantity: null, rate: null, amount: toMoney(data.amount) };
  }
  if (data.quantity === undefined) throw new ApiError(400, `"${type.name}" needs a quantity`);
  // The worker's own rate: their rate per day for day work, their rate per
  // 1000 bricks for brick work paid at each worker's own rate.
  const atOwnRate = paidAtOwnRate(type);
  const ownRate =
    (type.pay_unit === "per_day" && worker.rate_unit === "per_day") || (atOwnRate && worker.rate_unit === "per_1000")
      ? worker.rate
      : null;
  const rate = [keptRate, ownRate, type.rate].find(hasRate) ?? null;
  if (data.amount === undefined && !hasRate(rate)) {
    throw atOwnRate ? new ApiError(400, "No rate per 1000 bricks is set for this worker yet") : rateMissing(type);
  }
  return {
    quantity: data.quantity,
    rate,
    amount: data.amount !== undefined ? toMoney(data.amount) : payFor(type.pay_unit, rate, data.quantity),
  };
}

router.get("/", validate(listQuerySchema, "query"), async (req, res) => {
  const query = req.query;
  const filters = new Filters()
    .add("e.factory_id = ?", req.factory.id)
    .addIf(query.worker_id, "e.worker_id = ?", query.worker_id)
    .addIf(query.from, "e.entry_date >= ?", query.from)
    .addIf(query.to, "e.entry_date <= ?", query.to)
    .addIf(query.period_id, "e.period_id = ?", query.period_id)
    .addIf(query.source, "e.source = ?", query.source)
    .addIf(!query.include_cancelled, "e.cancelled_at IS NULL");
  const { rows } = await pool.query(
    `SELECT ${COLUMNS}, w.name AS worker_name, t.code AS work_type_code, t.name AS work_type_name, t.pay_unit,
            COUNT(*) OVER () AS total_count
     FROM work_entries e
     JOIN workers w ON w.id = e.worker_id
     JOIN work_types t ON t.id = e.work_type_id
     ${filters.where}
     ORDER BY e.entry_date DESC, e.created_at DESC
     LIMIT ${filters.param(query.limit)} OFFSET ${filters.param(query.offset)}`,
    filters.values,
  );
  paged(res, pageResult(rows, query));
});

router.post("/", validate(entrySchema), async (req, res) => {
  const ctx = context(req);
  const data = req.body;
  const entry = await withTransaction(async (client) => {
    const period = await periodFor(client, ctx.factory.id, data.entry_date);
    const pay = await priced(client, ctx.factory.id, data);
    const {
      rows: [row],
    } = await client.query(
      `INSERT INTO work_entries
         (factory_id, period_id, worker_id, work_type_id, entry_date, quantity, rate, amount, source, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'manual', $9, $10)
       RETURNING id`,
      [ctx.factory.id, period.id, data.worker_id, data.work_type_id, data.entry_date, pay.quantity, pay.rate, pay.amount, data.note ?? null, ctx.user.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "work_entry", entityId: row.id });
    const entry = await getEntry(client, ctx.factory.id, row.id);
    return { ...entry, balance: await workerBalance(client, ctx.factory.id, entry.worker_id) };
  });
  created(res, entry);
});

router.get("/:entryId", idParams("entryId"), async (req, res) => {
  ok(res, await getEntry(pool, req.factory.id, req.params.entryId));
});

async function lockManual(client, factoryId, entryId) {
  const {
    rows: [row],
  } = await client.query("SELECT * FROM work_entries WHERE factory_id = $1 AND id = $2 FOR UPDATE", [factoryId, entryId]);
  if (!row) throw notFound();
  if (row.source !== "manual") {
    throw new ApiError(409, "This pay comes from a brick count, an unloading or a salary; change it there");
  }
  if (row.cancelled_at) throw new ApiError(409, "This entry is cancelled");
  return row;
}

router.put("/:entryId", idParams("entryId"), validate(entrySchema), async (req, res) => {
  const ctx = context(req);
  const data = req.body;
  const { entryId } = req.params;
  const entry = await withTransaction(async (client) => {
    const current = await lockManual(client, ctx.factory.id, entryId);
    const before = await getEntry(client, ctx.factory.id, entryId);
    const period = await periodFor(client, ctx.factory.id, data.entry_date);
    const keptRate =
      current.work_type_id === data.work_type_id && current.worker_id === data.worker_id ? current.rate : undefined;
    const pay = await priced(client, ctx.factory.id, data, keptRate ?? undefined);
    await client.query(
      `UPDATE work_entries
       SET worker_id = $2, work_type_id = $3, entry_date = $4, quantity = $5, rate = $6, amount = $7,
           note = $8, period_id = $9
       WHERE id = $1`,
      [entryId, data.worker_id, data.work_type_id, data.entry_date, pay.quantity, pay.rate, pay.amount, data.note ?? null, period.id],
    );
    const after = await getEntry(client, ctx.factory.id, entryId);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "work_entry", entityId: entryId, before, after });
    return { ...after, balance: await workerBalance(client, ctx.factory.id, after.worker_id) };
  });
  ok(res, entry);
});

router.post("/:entryId/cancel", idParams("entryId"), validate(cancelSchema), async (req, res) => {
  const ctx = context(req);
  const { entryId } = req.params;
  const entry = await withTransaction(async (client) => {
    await lockManual(client, ctx.factory.id, entryId);
    await client.query(
      "UPDATE work_entries SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3 WHERE id = $1",
      [entryId, ctx.user.id, req.body.reason ?? null],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "cancel", entityType: "work_entry", entityId: entryId, before: { reason: req.body.reason ?? null } });
    const after = await getEntry(client, ctx.factory.id, entryId);
    return { ...after, balance: await workerBalance(client, ctx.factory.id, after.worker_id) };
  });
  ok(res, entry);
});

export default router;
