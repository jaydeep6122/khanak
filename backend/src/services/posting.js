import { insertRows } from "../db/sql.js";

/**
 * The only code that writes posted work entries and brick stock. Each post*
 * function deletes what its source produced and writes it again from the
 * source's current state, so create, edit and cancel all go through the same
 * path and pay or stock can never disagree with the counts behind them. Call
 * inside the source's transaction.
 */

const WORK_COLUMNS = [
  "factory_id",
  "period_id",
  "worker_id",
  "work_type_id",
  "entry_date",
  "quantity",
  "rate",
  "amount",
  "group_total",
  "group_size",
  "source",
  "brick_count_id",
  "kiln_unloading_id",
  "created_by",
];

const MOVEMENT_COLUMNS = [
  "factory_id",
  "period_id",
  "moved_on",
  "stage",
  "kiln_id",
  "quantity",
  "brick_count_id",
  "kiln_unloading_id",
];

/**
 * Where a count's bricks go. Counted on the drying ground (or the last count
 * of the season) they are raw stock; counted going into a kiln they are that
 * kiln's stock, and if an earlier count already had them, they leave raw stock.
 */
export function countMovements(count) {
  if (count.reason === "drying" || count.reason === "final") {
    return [{ stage: "raw", quantity: count.quantity }];
  }
  const intoKiln = { stage: "kiln", kiln_id: count.kiln_id, quantity: count.quantity };
  return count.already_counted ? [{ stage: "raw", quantity: -count.quantity }, intoKiln] : [intoKiln];
}

async function clearSource(client, column, sourceId) {
  await client.query(`DELETE FROM work_entries WHERE ${column} = $1`, [sourceId]);
  await client.query(`DELETE FROM brick_movements WHERE ${column} = $1`, [sourceId]);
}

async function writeWork(client, source, column, document, rows) {
  await insertRows(
    client,
    "work_entries",
    WORK_COLUMNS,
    rows.map((row) => ({
      ...row,
      factory_id: document.factory_id,
      period_id: document.period_id,
      entry_date: document.date,
      source,
      [column]: document.id,
      created_by: document.created_by,
    })),
  );
}

async function writeMovements(client, column, document, movements) {
  await insertRows(
    client,
    "brick_movements",
    MOVEMENT_COLUMNS,
    movements.map((movement) => ({
      ...movement,
      factory_id: document.factory_id,
      period_id: document.period_id,
      moved_on: document.date,
      [column]: document.id,
    })),
  );
}

/** `workRows`: the molder's pay and every group's shares. A cancelled count posts nothing. */
export async function postBrickCount(client, count, workRows) {
  await clearSource(client, "brick_count_id", count.id);
  if (count.cancelled_at) return;

  const document = { ...count, date: count.counted_on };
  await writeWork(client, "brick_count", "brick_count_id", document, workRows);
  await writeMovements(client, "brick_count_id", document, countMovements(count));
}

export async function postKilnUnloading(client, unloading, workRows) {
  await clearSource(client, "kiln_unloading_id", unloading.id);
  if (unloading.cancelled_at) return;

  const document = { ...unloading, date: unloading.unloaded_on };
  await writeWork(client, "kiln_unloading", "kiln_unloading_id", document, workRows);
  await writeMovements(client, "kiln_unloading_id", document, [
    { stage: "kiln", kiln_id: unloading.kiln_id, quantity: -unloading.quantity },
    { stage: "fired", quantity: unloading.quantity },
  ]);
}
