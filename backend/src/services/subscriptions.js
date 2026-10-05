import { ApiError } from "../utils/ApiError.js";

/** The subscription covering now(), if any; the one that runs longest wins. */
export async function currentSubscription(db, factoryId) {
  const {
    rows: [row],
  } = await db.query(
    `SELECT s.id, s.plan_code, p.name AS plan_name, p.is_trial, s.starts_at, s.ends_at
     FROM subscriptions s
     JOIN plans p ON p.code = s.plan_code
     WHERE s.factory_id = $1 AND s.status = 'active'
       AND s.starts_at <= now() AND s.ends_at > now()
     ORDER BY s.ends_at DESC
     LIMIT 1`,
    [factoryId],
  );
  return row ?? null;
}

/** Starts the free trial for a new factory, inside its creating transaction. */
export async function startTrial(client, factoryId) {
  const {
    rows: [subscription],
  } = await client.query(
    `INSERT INTO subscriptions (factory_id, plan_code, ends_at)
     SELECT $1, code, now() + make_interval(days => duration_days)
     FROM plans WHERE code = 'trial'
     RETURNING id, plan_code, starts_at, ends_at`,
    [factoryId],
  );
  return subscription;
}

/**
 * Without a subscription a factory keeps reading everything (its data is
 * never held back) but cannot add or change entries. The app recognises the
 * `code` and shows its renew screen.
 */
export async function assertWritable(db, factoryId) {
  if (!(await currentSubscription(db, factoryId))) {
    const error = new ApiError(402, "The subscription has ended. Renew it to add or change entries.");
    error.code = "subscription_inactive";
    throw error;
  }
}
