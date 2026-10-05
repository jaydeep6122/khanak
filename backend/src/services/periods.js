import { ApiError } from "../utils/ApiError.js";
import { todayIst } from "../utils/dates.js";

/**
 * The season or off-season an entry dated `date` belongs to: the latest one
 * that had started by then. When a season ends, the off-season starts the
 * same day, so anything entered after "End season" lands in the off-season.
 */
export async function periodFor(db, factoryId, date) {
  if (date > todayIst()) throw new ApiError(400, "The date cannot be in the future");

  const {
    rows: [period],
  } = await db.query(
    `SELECT id, kind, started_on, ended_on
     FROM periods
     WHERE factory_id = $1 AND started_on <= $2
     ORDER BY started_on DESC, created_at DESC
     LIMIT 1`,
    [factoryId, date],
  );
  if (!period) {
    throw new ApiError(400, `${date} is before this factory's first season or off-season`);
  }
  return period;
}

/** The one open period; every factory always has one. */
export async function openPeriod(db, factoryId, { lock = false } = {}) {
  const {
    rows: [period],
  } = await db.query(
    `SELECT * FROM periods WHERE factory_id = $1 AND ended_on IS NULL${lock ? " FOR UPDATE" : ""}`,
    [factoryId],
  );
  return period;
}

/** Closes the open period on `on` and opens a `kind` period the same day. */
export async function switchPeriod(client, { factoryId, userId, kind, on, name }) {
  const current = await openPeriod(client, factoryId, { lock: true });
  if (current?.kind === kind) {
    throw new ApiError(409, kind === "season" ? "A season is already running" : "No season is running");
  }
  if (on > todayIst()) throw new ApiError(400, "The date cannot be in the future");
  if (current && on < current.started_on) {
    throw new ApiError(400, `The date cannot be before ${current.started_on}, when the current period started`);
  }

  let closed = null;
  if (current) {
    ({
      rows: [closed],
    } = await client.query("UPDATE periods SET ended_on = $2, ended_by = $3 WHERE id = $1 RETURNING *", [
      current.id,
      on,
      userId,
    ]));
  }
  const {
    rows: [opened],
  } = await client.query(
    `INSERT INTO periods (factory_id, kind, name, started_on, started_by)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [factoryId, kind, name ?? null, on, userId],
  );
  return { closed, opened };
}
