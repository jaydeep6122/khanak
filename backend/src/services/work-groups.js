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

export async function assertWorkersExist(db, factoryId, workerIds) {
  const unique = [...new Set(workerIds.filter(Boolean))];
  if (unique.length === 0) return;
  const { rows } = await db.query("SELECT id FROM workers WHERE factory_id = $1 AND id = ANY($2::uuid[])", [
    factoryId,
    unique,
  ]);
  if (rows.length !== unique.length) throw new ApiError(400, "Unknown worker_id");
}

/**
 * A bharai or nikasi worker paid by the day is never paid a group's share:
 * their days are typed in as day work instead.
 */
export async function assertNotPaidByDay(db, factoryId, groups = []) {
  const ids = [...new Set(groups.flatMap((group) => group.workers.map((worker) => worker.worker_id)))];
  if (ids.length === 0) return;
  const {
    rows: [worker],
  } = await db.query(
    `SELECT name FROM workers
     WHERE factory_id = $1 AND id = ANY($2::uuid[]) AND main_work IN ('loader', 'unloader') AND rate IS NOT NULL
     LIMIT 1`,
    [factoryId, ids],
  );
  if (worker) throw new ApiError(400, `"${worker.name}" is paid by the day: type their days in as day work`);
}

/**
 * The rate each kind of work was paid at when this document was first saved.
 * Editing the document later keeps those rates, so a rate change made since
 * never alters pay that was already earned.
 */
export async function savedRates(db, column, sourceId) {
  if (!sourceId) return new Map();
  const { rows } = await db.query(
    `SELECT DISTINCT ON (work_type_id) work_type_id, rate
     FROM work_entries WHERE ${column} = $1 AND rate IS NOT NULL`,
    [sourceId],
  );
  return new Map(rows.map((row) => [row.work_type_id, row.rate]));
}

/** An edited document keeps the rate it was made with, unless it was made with none. */
export const rateLookup = (saved) => (workType) => {
  const kept = saved.get(workType.id);
  return hasRate(kept) ? kept : workType.rate;
};

/** One work entry per worker for every group. A kind of work may appear once. */
export function groupRows(groups = [], types, options) {
  const seen = new Set();
  return groups.flatMap((group) => {
    if (seen.has(group.work_type_id)) throw new ApiError(400, "Each kind of work may be listed once");
    seen.add(group.work_type_id);
    return resolveGroup(group, types.byId.get(group.work_type_id), options);
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
      amount: row.amount,
    });
  }
  return { individual, groups };
}
