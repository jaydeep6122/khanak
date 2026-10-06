import { ApiError } from "../utils/ApiError.js";
import { hasRate, resolveGroup } from "./pay.js";

/**
 * Shared by brick counts and kiln unloadings: both pay one or more groups of
 * workers from the same number of bricks.
 */

export async function loadWorkTypes(db, factoryId) {
  const { rows } = await db.query(
    "SELECT id, code, name, pay_unit, rate, is_group, is_active, sort_order FROM work_types WHERE factory_id = $1",
    [factoryId],
  );
  return {
    byId: new Map(rows.map((type) => [type.id, type])),
    byCode: new Map(rows.filter((type) => type.code).map((type) => [type.code, type])),
  };
}

/**
 * The workers named in a document, by id, with what they are paid: their
 * name, rate and rate_unit. Every id must be one of this factory's workers.
 */
export async function loadWorkers(db, factoryId, workerIds) {
  const unique = [...new Set(workerIds.filter(Boolean))];
  if (unique.length === 0) return new Map();
  const { rows } = await db.query(
    "SELECT id, name, rate, rate_unit FROM workers WHERE factory_id = $1 AND id = ANY($2::uuid[])",
    [factoryId, unique],
  );
  if (rows.length !== unique.length) throw new ApiError(400, "Unknown worker_id");
  return new Map(rows.map((worker) => [worker.id, worker]));
}

export const groupWorkerIds = (groups = []) => groups.flatMap((group) => group.workers.map((worker) => worker.worker_id));

/**
 * A worker paid by the day is never paid a group's share: their days are
 * typed in as day work instead.
 */
export function assertNotPaidByDay(groups = [], workers) {
  for (const workerId of groupWorkerIds(groups)) {
    const worker = workers.get(workerId);
    if (worker?.rate_unit === "per_day") {
      throw new ApiError(400, `"${worker.name}" is paid by the day: type their days in as day work`);
    }
  }
}

/**
 * The rates this document was paid at when it was first saved: each kind of
 * work's (`byType`), and each worker's for work paid at their own rate
 * (`byWorker`, keyed "work_type_id:worker_id"). Editing the document later
 * keeps those rates, so a rate change made since never alters pay that was
 * already earned.
 */
export async function savedRates(db, column, sourceId) {
  const saved = { byType: new Map(), byWorker: new Map() };
  if (!sourceId) return saved;
  const { rows } = await db.query(
    `SELECT work_type_id, worker_id, rate FROM work_entries WHERE ${column} = $1 AND rate IS NOT NULL`,
    [sourceId],
  );
  for (const row of rows) {
    if (!saved.byType.has(row.work_type_id)) saved.byType.set(row.work_type_id, row.rate);
    saved.byWorker.set(`${row.work_type_id}:${row.worker_id}`, row.rate);
  }
  return saved;
}

export const noSavedRates = () => ({ byType: new Map(), byWorker: new Map() });

/** An edited document keeps the rate it was made with, unless it was made with none. */
export const rateLookup = (saved) => (workType) => {
  const kept = saved.byType.get(workType.id);
  return hasRate(kept) ? kept : workType.rate;
};

/**
 * `{ name, rate }` for a worker paid at their own rate per 1000 bricks: the
 * rate this document already paid them for this work, or their rate today.
 */
export const workerRateLookup = (saved, workers) => (workType, workerId) => {
  const worker = workers.get(workerId);
  const kept = saved.byWorker.get(`${workType.id}:${workerId}`);
  if (hasRate(kept)) return { name: worker?.name, rate: kept };
  return { name: worker?.name, rate: worker?.rate_unit === "per_1000" ? worker.rate : null };
};

/**
 * One work entry per worker for every group. A kind of work may appear once.
 * `options` are resolveGroup's, with `saved` and `workers` in place of the
 * rate lookups.
 */
export function groupRows(groups = [], types, { saved, workers, ...options }) {
  const seen = new Set();
  return groups.flatMap((group) => {
    if (seen.has(group.work_type_id)) throw new ApiError(400, "Each kind of work may be listed once");
    seen.add(group.work_type_id);
    return resolveGroup(group, types.byId.get(group.work_type_id), {
      ...options,
      rateFor: rateLookup(saved),
      workerRate: workerRateLookup(saved, workers),
    });
  });
}

/** A document's pay as the app shows it: individual lines, then each group with its workers. */
export async function readWork(db, column, sourceId) {
  const { rows } = await db.query(
    `SELECT e.worker_id, w.name AS worker_name, w.nickname AS worker_nickname,
            e.work_type_id, t.code AS work_type_code, t.name AS work_type_name, t.pay_unit,
            e.quantity, e.rate, e.amount, e.group_total, e.group_size
     FROM work_entries e
     JOIN workers w ON w.id = e.worker_id
     JOIN work_types t ON t.id = e.work_type_id
     WHERE e.${column} = $1
     ORDER BY t.sort_order, e.amount DESC, w.name`,
    [sourceId],
  );

  const individual = rows.filter((row) => row.group_size === null);
  const groups = [];
  for (const row of rows.filter((row) => row.group_size !== null)) {
    let group = groups.find((existing) => existing.work_type_id === row.work_type_id);
    if (!group) {
      group = {
        work_type_id: row.work_type_id,
        work_type_code: row.work_type_code,
        work_type_name: row.work_type_name,
        pay_unit: row.pay_unit,
        quantity: row.quantity,
        rate: row.rate,
        total: row.group_total,
        workers: [],
      };
      groups.push(group);
    }
    group.workers.push({
      worker_id: row.worker_id,
      name: row.worker_name,
      nickname: row.worker_nickname,
      // Work paid at each worker's own rate: their share of the bricks and
      // their rate.
      quantity: row.quantity,
      rate: row.rate,
      amount: row.amount,
    });
  }
  return { individual, groups };
}
