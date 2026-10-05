import pool from "../../db/db.js";
import { insertRows, setClause } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { audit } from "../../services/audit.js";
import { openPeriod } from "../../services/periods.js";
import { currentSubscription, startTrial } from "../../services/subscriptions.js";
import { ApiError } from "../../utils/ApiError.js";
import { todayIst } from "../../utils/dates.js";

const FACTORY_COLUMNS = "id, name, owner_name, phone, city, state, language, created_at, updated_at";

// Every factory starts with these. Rates start at 0 and the app asks the
// owner to set them; the app shows its own translated name for each code.
const DEFAULT_WORK_TYPES = [
  { code: "molding", name: "Brick making", pay_unit: "per_1000", rate: "0", is_group: false },
  { code: "kiln_loading", name: "Kiln loading", pay_unit: "per_1000", rate: "0", is_group: true },
  { code: "stacking", name: "Kiln stacking and firing", pay_unit: "per_lakh", rate: "0", is_group: true },
  { code: "unloading", name: "Kiln unloading", pay_unit: "per_1000", rate: "0", is_group: true },
  { code: "truck_loading", name: "Truck loading", pay_unit: "per_trip", rate: "0", is_group: true },
  { code: "daily", name: "Day work", pay_unit: "per_day", rate: "0", is_group: false },
  { code: "salary", name: "Monthly salary", pay_unit: "per_month", rate: null, is_group: false },
  { code: "lumpsum", name: "Lump sum", pay_unit: "lumpsum", rate: null, is_group: false },
];

const notFound = () => new ApiError(404, "Not found");

/** The factory as the app needs it after login: role, open period, subscription. */
export async function factoryView(db, factoryId, { role, workerId }) {
  const {
    rows: [factory],
  } = await db.query(`SELECT ${FACTORY_COLUMNS} FROM factories WHERE id = $1`, [factoryId]);
  return {
    ...factory,
    role,
    worker_id: workerId ?? null,
    period: await openPeriod(db, factoryId),
    subscription: await currentSubscription(db, factoryId),
  };
}

export async function createFactory(user, data) {
  const { season_started_on, ...fields } = data;
  if (season_started_on && season_started_on > todayIst()) {
    throw new ApiError(400, "season_started_on cannot be in the future");
  }

  return withTransaction(async (client) => {
    const set = setClause(fields, ["name", "owner_name", "phone", "city", "state", "language"]);
    const {
      rows: [factory],
    } = await client.query(
      `INSERT INTO factories (${[...set.keys, "created_by"].join(", ")})
       VALUES (${set.keys.map((_, i) => `$${i + 1}`).concat(`$${set.keys.length + 1}`).join(", ")})
       RETURNING id`,
      [...set.values, user.id],
    );

    await client.query(
      "INSERT INTO factory_members (factory_id, user_id, role, added_by) VALUES ($1, $2, 'owner', $2)",
      [factory.id, user.id],
    );
    await client.query("INSERT INTO kilns (factory_id, name) VALUES ($1, 'Bhatho 1')", [factory.id]);
    await insertRows(
      client,
      "work_types",
      ["factory_id", "code", "name", "pay_unit", "rate", "is_group", "sort_order"],
      DEFAULT_WORK_TYPES.map((type, i) => ({ ...type, factory_id: factory.id, sort_order: i + 1 })),
    );
    await client.query(
      `INSERT INTO periods (factory_id, kind, started_on, started_by) VALUES ($1, $2, $3, $4)`,
      [factory.id, season_started_on ? "season" : "off_season", season_started_on ?? todayIst(), user.id],
    );
    await startTrial(client, factory.id);

    await audit(client, { factoryId: factory.id, userId: user.id, action: "create", entityType: "factory", entityId: factory.id });
    return factoryView(client, factory.id, { role: "owner" });
  });
}

export async function listFactories(userId) {
  const { rows } = await pool.query(
    `SELECT f.id, f.name, f.city, f.language, m.role, m.worker_id
     FROM factories f
     JOIN factory_members m ON m.factory_id = f.id AND m.user_id = $1 AND m.status = 'active'
     WHERE f.archived_at IS NULL
     ORDER BY f.created_at`,
    [userId],
  );
  return rows;
}

export async function updateFactory(ctx, data) {
  return withTransaction(async (client) => {
    const set = setClause(data, ["name", "owner_name", "phone", "city", "state", "language"]);
    if (set.keys.length > 0) {
      const {
        rows: [before],
      } = await client.query(`SELECT ${FACTORY_COLUMNS} FROM factories WHERE id = $1 FOR UPDATE`, [ctx.factory.id]);
      const {
        rows: [after],
      } = await client.query(
        `UPDATE factories SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${FACTORY_COLUMNS}`,
        [...set.values, ctx.factory.id],
      );
      await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "factory", entityId: ctx.factory.id, before, after });
    }
    return factoryView(client, ctx.factory.id, { role: ctx.role, workerId: ctx.member.worker_id });
  });
}

/** Archived factories disappear from the app; nothing is deleted. */
export async function archiveFactory(ctx) {
  await withTransaction(async (client) => {
    await client.query("UPDATE factories SET archived_at = now() WHERE id = $1", [ctx.factory.id]);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "archive", entityType: "factory", entityId: ctx.factory.id });
  });
}

// ---- Members -----------------------------------------------------------------

const MEMBER_SELECT = `
  SELECT m.user_id, u.name, u.email, m.role, m.worker_id, w.name AS worker_name, m.created_at
  FROM factory_members m
  JOIN users u ON u.id = m.user_id
  LEFT JOIN workers w ON w.id = m.worker_id`;

async function getMember(db, factoryId, userId) {
  const {
    rows: [member],
  } = await db.query(`${MEMBER_SELECT} WHERE m.factory_id = $1 AND m.user_id = $2 AND m.status = 'active'`, [
    factoryId,
    userId,
  ]);
  return member;
}

export async function listMembers(ctx) {
  const { rows } = await pool.query(
    `${MEMBER_SELECT} WHERE m.factory_id = $1 AND m.status = 'active'
     ORDER BY CASE m.role WHEN 'owner' THEN 1 WHEN 'munim' THEN 2 ELSE 3 END, u.name`,
    [ctx.factory.id],
  );
  return rows;
}

async function assertWorker(db, factoryId, workerId) {
  if (!workerId) return;
  const { rowCount } = await db.query("SELECT 1 FROM workers WHERE factory_id = $1 AND id = $2", [factoryId, workerId]);
  if (!rowCount) throw new ApiError(400, "Unknown worker_id");
}

/**
 * Gives someone with a Khanak account access to this factory. They sign up
 * on their own first; the owner adds them by the email they used.
 */
export async function addMember(ctx, { email, role, worker_id }) {
  return withTransaction(async (client) => {
    const {
      rows: [user],
    } = await client.query("SELECT id FROM users WHERE email = $1 AND is_active", [email]);
    if (!user) throw new ApiError(404, "No Khanak account uses this email. Ask them to sign up first.");
    await assertWorker(client, ctx.factory.id, worker_id);

    const {
      rows: [existing],
    } = await client.query("SELECT status FROM factory_members WHERE factory_id = $1 AND user_id = $2", [
      ctx.factory.id,
      user.id,
    ]);
    if (existing?.status === "active") throw new ApiError(409, "This person is already a member");

    await client.query(
      `INSERT INTO factory_members (factory_id, user_id, role, worker_id, added_by)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (factory_id, user_id)
       DO UPDATE SET role = EXCLUDED.role, worker_id = EXCLUDED.worker_id,
                     added_by = EXCLUDED.added_by, status = 'active'`,
      [ctx.factory.id, user.id, role, worker_id ?? null, ctx.user.id],
    );
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "add_member",
      entityType: "member",
      entityId: user.id,
      after: { role, worker_id: worker_id ?? null },
    });
    return getMember(client, ctx.factory.id, user.id);
  });
}

export async function updateMember(ctx, userId, data) {
  return withTransaction(async (client) => {
    const before = await getMember(client, ctx.factory.id, userId);
    if (!before) throw notFound();
    if (before.role === "owner") throw new ApiError(400, "The owner's access cannot be changed");
    await assertWorker(client, ctx.factory.id, data.worker_id);

    const set = setClause(data, ["role", "worker_id"]);
    if (set.keys.length > 0) {
      await client.query(
        `UPDATE factory_members SET ${set.sql}
         WHERE factory_id = $${set.keys.length + 1} AND user_id = $${set.keys.length + 2}`,
        [...set.values, ctx.factory.id, userId],
      );
    }
    const after = await getMember(client, ctx.factory.id, userId);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update_member", entityType: "member", entityId: userId, before, after });
    return after;
  });
}

export async function removeMember(ctx, userId) {
  await withTransaction(async (client) => {
    const member = await getMember(client, ctx.factory.id, userId);
    if (!member) throw notFound();
    if (member.role === "owner") throw new ApiError(400, "The owner cannot be removed");

    await client.query(
      "UPDATE factory_members SET status = 'removed', worker_id = NULL WHERE factory_id = $1 AND user_id = $2",
      [ctx.factory.id, userId],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "remove_member", entityType: "member", entityId: userId, before: member });
  });
}

// ---- Subscription ------------------------------------------------------------

export async function subscriptionHistory(ctx) {
  const { rows } = await pool.query(
    `SELECT s.id, s.plan_code, p.name AS plan_name, p.is_trial, s.starts_at, s.ends_at,
            s.status, s.amount_paid, s.payment_ref, s.created_at
     FROM subscriptions s JOIN plans p ON p.code = s.plan_code
     WHERE s.factory_id = $1
     ORDER BY s.starts_at DESC`,
    [ctx.factory.id],
  );
  return { current: await currentSubscription(pool, ctx.factory.id), history: rows };
}
