import pool from "../../db/db.js";
import { likePattern, pageResult, setClause } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { audit } from "../../services/audit.js";
import { assertCanChange, workerBalance, workerBalances } from "../../services/ledger.js";
import { periodFor } from "../../services/periods.js";
import { accrueSalaries } from "../../services/salaries.js";
import { newShareToken } from "../../services/tokens.js";
import { ApiError } from "../../utils/ApiError.js";
import { dec, money } from "../../utils/money.js";
import { ownPayProblem } from "./workers.schemas.js";

export const WORKER_COLUMNS = `id, name, nickname, village, phone, note, main_work, rate, rate_unit,
  monthly_salary, salary_from, is_active, left_on, share_enabled, created_at, updated_at`;

// What a supervisor may see of other workers: enough to pick the right one
// (rate_unit, so a worker paid by the day is not picked for group work), but
// never their rate.
const SUPERVISOR_COLUMNS = "id, name, nickname, village, main_work, rate_unit, is_active";

const TXN_COLUMNS = `id, worker_id, period_id, kind, txn_date, amount, cash_holder_id, note,
  created_by, cancelled_at, cancel_reason, created_at, updated_at`;

const notFound = () => new ApiError(404, "Not found");
const isSupervisor = (ctx) => ctx.role === "supervisor";

async function loadWorker(db, factoryId, workerId, { lock = false } = {}) {
  const {
    rows: [worker],
  } = await db.query(
    `SELECT ${WORKER_COLUMNS}, share_token FROM workers WHERE factory_id = $1 AND id = $2${lock ? " FOR UPDATE" : ""}`,
    [factoryId, workerId],
  );
  if (!worker) throw notFound();
  return worker;
}

const withoutToken = ({ share_token, ...worker }) => worker;

/** A supervisor sees their own account, never another worker's. */
function assertMayRead(ctx, workerId) {
  if (isSupervisor(ctx) && ctx.member.worker_id !== workerId) throw notFound();
}

export async function listWorkers(ctx, { active, main_work, search }) {
  const supervisor = isSupervisor(ctx);
  const { rows } = await pool.query(
    `SELECT ${supervisor ? SUPERVISOR_COLUMNS : WORKER_COLUMNS}
     FROM workers
     WHERE factory_id = $1
       AND ($2::boolean IS NULL OR is_active = $2)
       AND ($3::text IS NULL OR name ILIKE $3 OR nickname ILIKE $3 OR village ILIKE $3)
       AND ($4::text IS NULL OR main_work = $4)
     ORDER BY is_active DESC, lower(name), lower(coalesce(nickname, ''))`,
    [ctx.factory.id, active ?? null, search ? likePattern(search) : null, main_work ?? null],
  );
  if (supervisor) return rows;

  await accrueSalaries(ctx.factory.id);
  const balances = await workerBalances(pool, ctx.factory.id);
  return rows.map((worker) => ({ ...worker, balance: balances.get(worker.id) ?? "0.00" }));
}

export async function getWorker(ctx, workerId) {
  assertMayRead(ctx, workerId);
  const worker = withoutToken(await loadWorker(pool, ctx.factory.id, workerId));
  await accrueSalaries(ctx.factory.id);
  return { ...worker, balance: await workerBalance(pool, ctx.factory.id, workerId) };
}

/** Just the balance: what a supervisor needs to see before giving an advance. */
export async function getBalance(ctx, workerId) {
  const worker = await loadWorker(pool, ctx.factory.id, workerId);
  await accrueSalaries(ctx.factory.id);
  return {
    worker_id: worker.id,
    name: worker.name,
    nickname: worker.nickname,
    balance: await workerBalance(pool, ctx.factory.id, workerId),
  };
}

export async function createWorker(ctx, data) {
  return withTransaction(async (client) => {
    const {
      rows: [worker],
    } = await client.query(
      `INSERT INTO workers (factory_id, name, main_work, rate, rate_unit, nickname, village, phone, note,
                            monthly_salary, salary_from, share_token, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING ${WORKER_COLUMNS}`,
      [
        ctx.factory.id,
        data.name,
        data.main_work,
        data.rate ?? null,
        data.rate == null ? null : data.rate_unit,
        data.nickname ?? null,
        data.village ?? null,
        data.phone ?? null,
        data.note ?? null,
        data.monthly_salary ?? null,
        data.salary_from ?? null,
        newShareToken(),
        ctx.user.id,
      ],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "worker", entityId: worker.id });
    return { ...worker, balance: "0.00" };
  });
}

export async function updateWorker(ctx, workerId, data) {
  const updated = await withTransaction(async (client) => {
    const before = withoutToken(await loadWorker(client, ctx.factory.id, workerId, { lock: true }));
    // A driver has no rate of their own.
    if (data.main_work === "driver" && data.rate === undefined) data = { ...data, rate: null };
    if (data.rate === null) data = { ...data, rate_unit: null };
    const merged = { ...before, ...data };
    if ((merged.monthly_salary == null) !== (merged.salary_from == null)) {
      throw new ApiError(400, "Give both monthly_salary and salary_from, or neither");
    }
    const problem = ownPayProblem(merged);
    if (problem) throw new ApiError(400, `${problem.path}: ${problem.message}`);

    const set = setClause(data, [
      "name",
      "main_work",
      "rate",
      "rate_unit",
      "nickname",
      "village",
      "phone",
      "note",
      "monthly_salary",
      "salary_from",
    ]);
    if (set.keys.length === 0) return before;
    const {
      rows: [after],
    } = await client.query(
      `UPDATE workers SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${WORKER_COLUMNS}`,
      [...set.values, workerId],
    );

    // A corrected start date (or salary removed) means the months written so
    // far were wrong: they are written again from the corrected details. A
    // new amount alone only applies to months still to come.
    if (data.salary_from !== undefined && data.salary_from !== before.salary_from) {
      await client.query("DELETE FROM work_entries WHERE worker_id = $1 AND source = 'salary'", [workerId]);
    }
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "worker", entityId: workerId, before, after });
    return after;
  });
  await accrueSalaries(ctx.factory.id);
  return { ...updated, balance: await workerBalance(pool, ctx.factory.id, workerId) };
}

/**
 * The worker left: they drop out of pick lists, their link stops working and
 * a salary is paid up to `left_on`. Their account stays, balance and all.
 */
export async function markLeft(ctx, workerId, leftOn) {
  return withTransaction(async (client) => {
    const before = withoutToken(await loadWorker(client, ctx.factory.id, workerId, { lock: true }));
    if (before.salary_from && leftOn < before.salary_from) {
      throw new ApiError(400, "left_on cannot be before salary_from");
    }
    const {
      rows: [after],
    } = await client.query(
      `UPDATE workers SET is_active = false, left_on = $2, share_enabled = false
       WHERE id = $1 RETURNING ${WORKER_COLUMNS}`,
      [workerId, leftOn],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "mark_left", entityType: "worker", entityId: workerId, before, after });
    return after;
  });
}

/** Back for another season: same account, same link, old balance carried. */
export async function markReturned(ctx, workerId) {
  return withTransaction(async (client) => {
    const before = withoutToken(await loadWorker(client, ctx.factory.id, workerId, { lock: true }));
    const {
      rows: [after],
    } = await client.query(
      `UPDATE workers SET is_active = true, left_on = NULL, share_enabled = true
       WHERE id = $1 RETURNING ${WORKER_COLUMNS}`,
      [workerId],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "mark_returned", entityType: "worker", entityId: workerId, before, after });
    return after;
  });
}

// ---- The worker's own link ---------------------------------------------------

export async function getShare(ctx, workerId) {
  const worker = await loadWorker(pool, ctx.factory.id, workerId);
  return { token: worker.share_token, enabled: worker.share_enabled, phone: worker.phone };
}

/** A new link; the old one stops working at once. */
export async function regenerateShare(ctx, workerId) {
  return withTransaction(async (client) => {
    await loadWorker(client, ctx.factory.id, workerId, { lock: true });
    const {
      rows: [worker],
    } = await client.query(
      "UPDATE workers SET share_token = $2, share_enabled = true WHERE id = $1 RETURNING share_token, share_enabled, phone",
      [workerId, newShareToken()],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "regenerate_link", entityType: "worker", entityId: workerId });
    return { token: worker.share_token, enabled: worker.share_enabled, phone: worker.phone };
  });
}

export async function setShareEnabled(ctx, workerId, enabled) {
  return withTransaction(async (client) => {
    await loadWorker(client, ctx.factory.id, workerId, { lock: true });
    const {
      rows: [worker],
    } = await client.query(
      "UPDATE workers SET share_enabled = $2 WHERE id = $1 RETURNING share_token, share_enabled, phone",
      [workerId, enabled],
    );
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: enabled ? "enable_link" : "disable_link",
      entityType: "worker",
      entityId: workerId,
    });
    return { token: worker.share_token, enabled: worker.share_enabled, phone: worker.phone };
  });
}

// ---- Ledger --------------------------------------------------------------------

const LEDGER_SELECT = `
  SELECT l.entry_kind, l.entry_id, l.entry_date, l.period_id,
         l.work_type_id, t.code AS work_type_code, t.name AS work_type_name, t.pay_unit,
         l.quantity, l.rate, l.group_total, l.group_size, l.credit, l.debit,
         l.source, l.brick_count_id, l.kiln_unloading_id, l.salary_month, l.note, l.created_at`;

/** Every line of one worker's account, newest first, with what they add up to. */
export async function workerLedger(db, factoryId, workerId, { period_id, from, to, limit, offset }) {
  const filters = [period_id ?? null, from ?? null, to ?? null];
  const { rows } = await db.query(
    `${LEDGER_SELECT}, COUNT(*) OVER () AS total_count
     FROM worker_ledger l
     LEFT JOIN work_types t ON t.id = l.work_type_id
     WHERE l.factory_id = $1 AND l.worker_id = $2
       AND ($3::uuid IS NULL OR l.period_id = $3)
       AND ($4::date IS NULL OR l.entry_date >= $4)
       AND ($5::date IS NULL OR l.entry_date <= $5)
     ORDER BY l.entry_date DESC, l.created_at DESC
     LIMIT $6 OFFSET $7`,
    [factoryId, workerId, ...filters, limit, offset],
  );
  const {
    rows: [totals],
  } = await db.query(
    `SELECT COALESCE(sum(credit) FILTER (WHERE entry_kind = 'work'), 0) AS earned,
            COALESCE(sum(debit) FILTER (WHERE entry_kind = 'advance'), 0) AS advances,
            COALESCE(sum(debit) FILTER (WHERE entry_kind = 'settlement'), 0) AS settled,
            COALESCE(sum(credit) FILTER (WHERE entry_kind IN ('recovery', 'writeoff')), 0) AS recovered,
            COALESCE(sum(credit - debit), 0) AS net
     FROM worker_ledger
     WHERE factory_id = $1 AND worker_id = $2
       AND ($3::uuid IS NULL OR period_id = $3)
       AND ($4::date IS NULL OR entry_date >= $4)
       AND ($5::date IS NULL OR entry_date <= $5)`,
    [factoryId, workerId, ...filters],
  );
  return {
    ...pageResult(rows, { limit, offset }),
    totals,
    balance: await workerBalance(db, factoryId, workerId),
  };
}

export async function getLedger(ctx, workerId, query) {
  assertMayRead(ctx, workerId);
  await loadWorker(pool, ctx.factory.id, workerId);
  await accrueSalaries(ctx.factory.id);
  return workerLedger(pool, ctx.factory.id, workerId, query);
}

// ---- Advances, settlements, recoveries and write-offs ----------------------------

async function assertCashHolder(db, factoryId, userId) {
  const { rowCount } = await db.query(
    "SELECT 1 FROM factory_members WHERE factory_id = $1 AND user_id = $2 AND status = 'active'",
    [factoryId, userId],
  );
  if (!rowCount) throw new ApiError(400, "cash_holder_id is not a member of this factory");
}

/** A write-off can forgive at most what the worker owes now. */
async function assertWriteOffFits(db, factoryId, workerId, amount) {
  const owed = dec(await workerBalance(db, factoryId, workerId)).negated();
  if (dec(amount).gt(owed)) {
    throw new ApiError(400, `Only what the worker owes can be written off (${money(owed.isNegative() ? 0 : owed)})`);
  }
}

export async function addTransaction(ctx, workerId, data) {
  let cashHolderId = data.cash_holder_id ?? null;
  if (isSupervisor(ctx)) {
    if (data.kind !== "advance") throw new ApiError(403, "A supervisor can only give advances");
    if (ctx.member.worker_id === workerId) {
      throw new ApiError(403, "A supervisor cannot give an advance to themselves");
    }
    if (cashHolderId && cashHolderId !== ctx.user.id) {
      throw new ApiError(403, "A supervisor's advances come from their own cash");
    }
    cashHolderId = ctx.user.id;
  }
  if (data.kind === "writeoff" && ctx.role !== "owner") {
    throw new ApiError(403, "Only the owner can write off what a worker owes");
  }
  if (cashHolderId && data.kind !== "advance") {
    throw new ApiError(400, "cash_holder_id is only for advances");
  }

  await accrueSalaries(ctx.factory.id);
  return withTransaction(async (client) => {
    await loadWorker(client, ctx.factory.id, workerId, { lock: true });
    if (cashHolderId) await assertCashHolder(client, ctx.factory.id, cashHolderId);
    if (data.kind === "writeoff") await assertWriteOffFits(client, ctx.factory.id, workerId, data.amount);
    const period = await periodFor(client, ctx.factory.id, data.txn_date);

    const {
      rows: [txn],
    } = await client.query(
      `INSERT INTO worker_transactions
         (factory_id, period_id, worker_id, kind, txn_date, amount, cash_holder_id, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING ${TXN_COLUMNS}`,
      [ctx.factory.id, period.id, workerId, data.kind, data.txn_date, data.amount, cashHolderId, data.note ?? null, ctx.user.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "worker_transaction", entityId: txn.id });
    return { ...txn, balance: await workerBalance(client, ctx.factory.id, workerId) };
  });
}

async function loadTransaction(client, ctx, txnId) {
  const {
    rows: [txn],
  } = await client.query(`SELECT ${TXN_COLUMNS} FROM worker_transactions WHERE factory_id = $1 AND id = $2 FOR UPDATE`, [
    ctx.factory.id,
    txnId,
  ]);
  if (!txn) throw notFound();
  if (txn.cancelled_at) throw new ApiError(409, "This entry is cancelled");
  assertCanChange(ctx, txn);
  if (txn.kind === "writeoff" && ctx.role !== "owner") throw new ApiError(403, "Only the owner can change a write-off");
  return txn;
}

export async function updateTransaction(ctx, txnId, data) {
  return withTransaction(async (client) => {
    const before = await loadTransaction(client, ctx, txnId);
    const next = { ...before, ...data };
    const period = await periodFor(client, ctx.factory.id, next.txn_date);

    const {
      rows: [after],
    } = await client.query(
      `UPDATE worker_transactions SET txn_date = $2, amount = $3, note = $4, period_id = $5
       WHERE id = $1 RETURNING ${TXN_COLUMNS}`,
      [txnId, next.txn_date, next.amount, next.note, period.id],
    );
    if (after.kind === "writeoff") {
      // The new amount must still fit what the worker owed without it.
      await assertWriteOffFits(client, ctx.factory.id, after.worker_id, "0");
    }
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "worker_transaction", entityId: txnId, before, after });
    return { ...after, balance: await workerBalance(client, ctx.factory.id, after.worker_id) };
  });
}

export async function cancelTransaction(ctx, txnId, reason) {
  return withTransaction(async (client) => {
    const before = await loadTransaction(client, ctx, txnId);
    const {
      rows: [after],
    } = await client.query(
      `UPDATE worker_transactions SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3
       WHERE id = $1 RETURNING ${TXN_COLUMNS}`,
      [txnId, ctx.user.id, reason ?? null],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "cancel", entityType: "worker_transaction", entityId: txnId, before: { reason: reason ?? null } });
    return { ...after, balance: await workerBalance(client, ctx.factory.id, before.worker_id) };
  });
}
