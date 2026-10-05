import { ApiError } from "../utils/ApiError.js";
import { istDate, todayIst } from "../utils/dates.js";

/**
 * Balance per worker: positive = the factory owes the worker (devana),
 * negative = the worker owes the factory (levana).
 */
export async function workerBalances(db, factoryId, workerIds = null) {
  const { rows } = await db.query(
    `SELECT worker_id, COALESCE(sum(credit - debit), 0) AS balance
     FROM worker_ledger
     WHERE factory_id = $1 AND ($2::uuid[] IS NULL OR worker_id = ANY($2::uuid[]))
     GROUP BY worker_id`,
    [factoryId, workerIds],
  );
  return new Map(rows.map((row) => [row.worker_id, row.balance]));
}

export async function workerBalance(db, factoryId, workerId) {
  return (await workerBalances(db, factoryId, [workerId])).get(workerId) ?? "0.00";
}

/** Bricks in each stage: raw (kachi), kiln (bhatha) and fired (pakki). */
export async function brickStock(db, factoryId) {
  const { rows } = await db.query(
    `SELECT stage, COALESCE(sum(quantity), 0)::bigint AS quantity
     FROM brick_movements WHERE factory_id = $1 GROUP BY stage`,
    [factoryId],
  );
  const stock = { raw: 0, kiln: 0, fired: 0 };
  for (const row of rows) stock[row.stage] = Number(row.quantity);
  return stock;
}

/**
 * Stock never stops an entry: counts are sometimes off. A stage that went
 * below zero comes back as a warning the app shows, so the count can be fixed.
 */
export async function stockWarnings(db, factoryId) {
  const stock = await brickStock(db, factoryId);
  return Object.entries(stock)
    .filter(([, quantity]) => quantity < 0)
    .map(([stage, quantity]) => ({ code: "negative_stock", stage, quantity }));
}

/**
 * Owner and munim may change anything. A supervisor may change only what they
 * entered themselves, and only on the same day.
 */
export function assertCanChange(ctx, row) {
  if (ctx.role !== "supervisor") return;
  if (row.created_by !== ctx.user.id || istDate(new Date(row.created_at)) !== todayIst()) {
    throw new ApiError(403, "A supervisor can change only their own entries, on the day they made them");
  }
}
