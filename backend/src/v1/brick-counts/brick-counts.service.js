import pool from "../../db/db.js";
import { Filters, pageResult } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { audit } from "../../services/audit.js";
import { assertCanChange, stockWarnings } from "../../services/ledger.js";
import { hasRate, payFor, workerRateMissing } from "../../services/pay.js";
import { periodFor } from "../../services/periods.js";
import { postBrickCount } from "../../services/posting.js";
import {
  assertNotPaidByDay,
  groupRows,
  groupWorkerIds,
  loadWorkers,
  loadWorkTypes,
  noSavedRates,
  readWork,
  savedRates,
  workerRateLookup,
} from "../../services/work-groups.js";
import { ApiError } from "../../utils/ApiError.js";
import { paidOnlyByDay } from "../workers/workers.schemas.js";
import { money } from "../../utils/money.js";

const COUNT_COLUMNS = `c.id, c.period_id, c.counted_on, c.reason, c.quantity, c.molder_id,
  c.already_counted, c.kiln_id, c.truck_id, c.trips, c.note, c.created_by, c.cancelled_at, c.cancel_reason,
  c.created_at, c.updated_at`;

const notFound = () => new ApiError(404, "Not found");
const mayChangePay = (ctx) => ctx.role !== "supervisor";

export async function getBrickCount(db, ctx, countId) {
  const {
    rows: [count],
  } = await db.query(
    `SELECT ${COUNT_COLUMNS}, m.name AS molder_name, m.nickname AS molder_nickname,
            t.number AS truck_number, k.name AS kiln_name, u.name AS created_by_name
     FROM brick_counts c
     LEFT JOIN workers m ON m.id = c.molder_id
     LEFT JOIN trucks t ON t.id = c.truck_id
     LEFT JOIN kilns k ON k.id = c.kiln_id
     LEFT JOIN users u ON u.id = c.created_by
     WHERE c.factory_id = $1 AND c.id = $2`,
    [ctx.factory.id, countId],
  );
  if (!count) throw notFound();
  if (ctx.role === "supervisor" && count.created_by !== ctx.user.id) throw notFound();

  const { individual, groups } = await readWork(db, "brick_count_id", countId);
  return { ...count, molder_pay: individual[0] ?? null, groups };
}

export async function listBrickCounts(ctx, query) {
  const filters = new Filters()
    .add("c.factory_id = ?", ctx.factory.id)
    .addIf(query.from, "c.counted_on >= ?", query.from)
    .addIf(query.to, "c.counted_on <= ?", query.to)
    .addIf(query.period_id, "c.period_id = ?", query.period_id)
    .addIf(query.reason, "c.reason = ?", query.reason)
    .addIf(query.molder_id, "c.molder_id = ?", query.molder_id)
    .addIf(query.kiln_id, "c.kiln_id = ?", query.kiln_id)
    .addIf(!query.include_cancelled, "c.cancelled_at IS NULL")
    // A supervisor sees only the counts they entered.
    .addIf(ctx.role === "supervisor", "c.created_by = ?", ctx.user.id);

  const { rows } = await pool.query(
    `SELECT ${COUNT_COLUMNS}, m.name AS molder_name, m.nickname AS molder_nickname,
            k.name AS kiln_name, u.name AS created_by_name,
            (SELECT COALESCE(sum(e.amount), 0) FROM work_entries e WHERE e.brick_count_id = c.id) AS total_pay,
            COUNT(*) OVER () AS total_count
     FROM brick_counts c
     LEFT JOIN workers m ON m.id = c.molder_id
     LEFT JOIN kilns k ON k.id = c.kiln_id
     LEFT JOIN users u ON u.id = c.created_by
     ${filters.where}
     ORDER BY c.counted_on DESC, c.created_at DESC
     LIMIT ${filters.param(query.limit)} OFFSET ${filters.param(query.offset)}`,
    filters.values,
  );
  return pageResult(rows, query);
}

/**
 * The molder's pay and every group's shares for one count. `saved` holds the
 * rates the count was first made with (none for a new count).
 */
async function workRowsFor(client, ctx, data, saved) {
  if (data.molder_amount !== undefined && !mayChangePay(ctx)) {
    throw new ApiError(403, "Only the owner or munim can change how much is paid");
  }
  const types = await loadWorkTypes(client, ctx.factory.id);
  const workers = await loadWorkers(client, ctx.factory.id, [data.molder_id, ...groupWorkerIds(data.groups)]);
  assertNotPaidByDay(data.groups, workers);
  if (data.truck_id) {
    const { rowCount } = await client.query("SELECT 1 FROM trucks WHERE factory_id = $1 AND id = $2", [
      ctx.factory.id,
      data.truck_id,
    ]);
    if (!rowCount) throw new ApiError(400, "Unknown truck_id");
  }
  if (data.kiln_id) {
    const { rowCount } = await client.query("SELECT 1 FROM kilns WHERE factory_id = $1 AND id = $2", [
      ctx.factory.id,
      data.kiln_id,
    ]);
    if (!rowCount) throw new ApiError(400, "Unknown kiln_id");
  }
  // A count pays the molder, whoever carried the bricks and, for bricks going
  // into a kiln, the khadkaniya who stacked them there (per lakh). Nikasi
  // is paid from its own entry.
  const intoKiln = data.reason === "kiln_by_workers" || data.reason === "kiln_by_truck";
  let carriers = false;
  let stackers = false;
  for (const group of data.groups ?? []) {
    const code = types.byId.get(group.work_type_id)?.code;
    if (code === "unloading") throw new ApiError(400, "Nikasi is paid from the nikasi entry, not a count");
    if (code === "stacking") {
      if (!intoKiln) throw new ApiError(400, "Khadkaniya are paid only for bricks going into a kiln");
      stackers = true;
    } else {
      carriers = true;
    }
  }
  if (data.reason !== "final" && !carriers) {
    throw new ApiError(400, intoKiln ? "Who put the bricks into the kiln?" : "Who carried the bricks to dry?");
  }
  if (intoKiln && !stackers) throw new ApiError(400, "Who stacked the bricks in the kiln (khadkaniya)?");

  const rows = [];
  // Each molder is paid at their own rate per 1000 bricks; an edited count
  // keeps the rate it was made with while the molder stays the same. A
  // molder paid only by the day earns nothing from counts: their days are
  // typed in as day work.
  const molder = workers.get(data.molder_id);
  if (!data.already_counted && (!paidOnlyByDay(molder) || data.molder_amount !== undefined)) {
    const molding = types.byCode.get("molding");
    const { rate } = workerRateLookup(saved, workers)(molding, data.molder_id);
    if (data.molder_amount === undefined && !hasRate(rate)) throw workerRateMissing(molder);
    rows.push({
      worker_id: data.molder_id,
      work_type_id: molding.id,
      quantity: data.quantity,
      rate: hasRate(rate) ? rate : null,
      amount: data.molder_amount !== undefined ? money(data.molder_amount) : payFor(molding.pay_unit, rate, data.quantity),
    });
  }
  rows.push(
    ...groupRows(data.groups, types, {
      bricks: data.quantity,
      trips: data.trips,
      saved,
      workers,
      allowAmounts: mayChangePay(ctx),
    }),
  );
  return rows;
}

const auditView = (count) => ({
  counted_on: count.counted_on,
  reason: count.reason,
  quantity: count.quantity,
  molder_id: count.molder_id,
  already_counted: count.already_counted,
  kiln_id: count.kiln_id,
  truck_id: count.truck_id,
  trips: count.trips,
  note: count.note,
  molder_pay: count.molder_pay?.amount ?? null,
  groups: count.groups.map((group) => ({
    work_type_id: group.work_type_id,
    total: group.total,
    workers: group.workers.map((worker) => ({ worker_id: worker.worker_id, amount: worker.amount })),
  })),
});

const fields = (data) => [
  data.counted_on,
  data.reason,
  data.quantity,
  data.already_counted ? null : data.molder_id,
  data.already_counted ?? false,
  data.kiln_id ?? null,
  data.truck_id ?? null,
  data.trips ?? null,
  data.note ?? null,
];

export async function createBrickCount(ctx, data) {
  return withTransaction(async (client) => {
    const period = await periodFor(client, ctx.factory.id, data.counted_on);
    const workRows = await workRowsFor(client, ctx, data, noSavedRates());

    const {
      rows: [count],
    } = await client.query(
      `INSERT INTO brick_counts
         (counted_on, reason, quantity, molder_id, already_counted, kiln_id, truck_id, trips, note,
          factory_id, period_id, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING *`,
      [...fields(data), ctx.factory.id, period.id, ctx.user.id],
    );
    await postBrickCount(client, count, workRows);

    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "brick_count", entityId: count.id });
    return {
      ...(await getBrickCount(client, ctx, count.id)),
      warnings: await stockWarnings(client, ctx.factory.id),
    };
  });
}

async function lockCount(client, ctx, countId) {
  const {
    rows: [row],
  } = await client.query("SELECT * FROM brick_counts WHERE factory_id = $1 AND id = $2 FOR UPDATE", [
    ctx.factory.id,
    countId,
  ]);
  if (!row) throw notFound();
  if (row.cancelled_at) throw new ApiError(409, "This count is cancelled");
  assertCanChange(ctx, row);
  return row;
}

/** Replaces the whole count; the pay and stock it made are written again. */
export async function updateBrickCount(ctx, countId, data) {
  return withTransaction(async (client) => {
    await lockCount(client, ctx, countId);
    const before = await getBrickCount(client, ctx, countId);
    const period = await periodFor(client, ctx.factory.id, data.counted_on);
    const workRows = await workRowsFor(client, ctx, data, await savedRates(client, "brick_count_id", countId));

    const {
      rows: [count],
    } = await client.query(
      `UPDATE brick_counts
       SET counted_on = $1, reason = $2, quantity = $3, molder_id = $4, already_counted = $5,
           kiln_id = $6, truck_id = $7, trips = $8, note = $9, period_id = $10
       WHERE id = $11
       RETURNING *`,
      [...fields(data), period.id, countId],
    );
    await postBrickCount(client, count, workRows);

    const after = await getBrickCount(client, ctx, countId);
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "update",
      entityType: "brick_count",
      entityId: countId,
      before: auditView(before),
      after: auditView(after),
    });
    return { ...after, warnings: await stockWarnings(client, ctx.factory.id) };
  });
}

/** The count stays on record; the pay and stock it made are removed. */
export async function cancelBrickCount(ctx, countId, reason) {
  return withTransaction(async (client) => {
    await lockCount(client, ctx, countId);
    const before = await getBrickCount(client, ctx, countId);
    const {
      rows: [count],
    } = await client.query(
      `UPDATE brick_counts SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3
       WHERE id = $1 RETURNING *`,
      [countId, ctx.user.id, reason ?? null],
    );
    await postBrickCount(client, count, []);

    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "cancel",
      entityType: "brick_count",
      entityId: countId,
      before: { ...auditView(before), reason: reason ?? null },
    });
    return {
      ...(await getBrickCount(client, ctx, countId)),
      warnings: await stockWarnings(client, ctx.factory.id),
    };
  });
}
