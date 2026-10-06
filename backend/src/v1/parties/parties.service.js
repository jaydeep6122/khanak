import pool from "../../db/db.js";
import { likePattern, pageResult, setClause } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { audit } from "../../services/audit.js";
import { partyBalance, partyBalances } from "../../services/parties.js";
import { periodFor } from "../../services/periods.js";
import { ApiError } from "../../utils/ApiError.js";
import { dec, money } from "../../utils/money.js";

const PARTY_COLUMNS = "id, kind, name, phone, village, note, is_active, created_at, updated_at";
const PAYMENT_COLUMNS = `id, party_id, period_id, kind, paid_on, amount, mode, note, created_by,
  cancelled_at, cancel_reason, created_at, updated_at`;

const notFound = () => new ApiError(404, "Not found");

async function loadParty(db, factoryId, partyId, { lock = false } = {}) {
  const {
    rows: [party],
  } = await db.query(
    `SELECT ${PARTY_COLUMNS} FROM parties WHERE factory_id = $1 AND id = $2${lock ? " FOR UPDATE" : ""}`,
    [factoryId, partyId],
  );
  if (!party) throw notFound();
  return party;
}

/**
 * Customers or suppliers, with what each owes or is owed. With
 * `with_balance`, only those with something outstanding: the "udhar baki" list.
 */
export async function listParties(ctx, { kind, search, with_balance }) {
  const { rows } = await pool.query(
    `SELECT ${PARTY_COLUMNS}
     FROM parties
     WHERE factory_id = $1
       AND ($2::text IS NULL OR kind = $2)
       AND ($3::text IS NULL OR name ILIKE $3 OR phone ILIKE $3 OR village ILIKE $3)
     ORDER BY is_active DESC, lower(name)`,
    [ctx.factory.id, kind ?? null, search ? likePattern(search) : null],
  );
  const balances = await partyBalances(pool, ctx.factory.id);
  const withBalances = rows.map((party) => ({ ...party, balance: balances.get(party.id) ?? "0.00" }));
  return with_balance ? withBalances.filter((party) => !dec(party.balance).isZero()) : withBalances;
}

export async function getParty(ctx, partyId) {
  const party = await loadParty(pool, ctx.factory.id, partyId);
  return { ...party, balance: await partyBalance(pool, ctx.factory.id, partyId) };
}

export async function createParty(ctx, data) {
  return withTransaction(async (client) => {
    const {
      rows: [party],
    } = await client.query(
      `INSERT INTO parties (factory_id, kind, name, phone, village, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING ${PARTY_COLUMNS}`,
      [ctx.factory.id, data.kind, data.name, data.phone ?? null, data.village ?? null, data.note ?? null, ctx.user.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "party", entityId: party.id });
    return { ...party, balance: "0.00" };
  });
}

export async function updateParty(ctx, partyId, data) {
  return withTransaction(async (client) => {
    const before = await loadParty(client, ctx.factory.id, partyId, { lock: true });
    const set = setClause(data, ["name", "phone", "village", "note", "is_active"]);
    let after = before;
    if (set.keys.length > 0) {
      ({
        rows: [after],
      } = await client.query(`UPDATE parties SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${PARTY_COLUMNS}`, [
        ...set.values,
        partyId,
      ]));
      await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "party", entityId: partyId, before, after });
    }
    return { ...after, balance: await partyBalance(client, ctx.factory.id, partyId) };
  });
}

/** Every line of one party's account, newest first. */
export async function partyLedger(ctx, partyId, { from, to, limit, offset }) {
  await loadParty(pool, ctx.factory.id, partyId);
  const { rows } = await pool.query(
    `SELECT entry_kind, entry_id, entry_date, period_id, owed, amount, paid_amount, quantity, rate, note, created_at,
            COUNT(*) OVER () AS total_count
     FROM party_ledger
     WHERE factory_id = $1 AND party_id = $2
       AND ($3::date IS NULL OR entry_date >= $3)
       AND ($4::date IS NULL OR entry_date <= $4)
     ORDER BY entry_date DESC, created_at DESC
     LIMIT $5 OFFSET $6`,
    [ctx.factory.id, partyId, from ?? null, to ?? null, limit, offset],
  );
  return { ...pageResult(rows, { limit, offset }), balance: await partyBalance(pool, ctx.factory.id, partyId) };
}

// ---- Money received, paid or written off ---------------------------------------

/** A write-off can forgive at most what the customer owes now. */
async function assertWriteOffFits(db, factoryId, partyId) {
  if (dec(await partyBalance(db, factoryId, partyId)).isNegative()) {
    throw new ApiError(400, "Only what the customer owes can be written off");
  }
}

export async function addPayment(ctx, partyId, data) {
  if (data.kind === "writeoff" && ctx.role !== "owner") {
    throw new ApiError(403, "Only the owner can write off what a customer owes");
  }
  return withTransaction(async (client) => {
    await loadParty(client, ctx.factory.id, partyId, { lock: true });
    const period = await periodFor(client, ctx.factory.id, data.paid_on);
    const {
      rows: [payment],
    } = await client.query(
      `INSERT INTO party_payments (factory_id, period_id, party_id, kind, paid_on, amount, mode, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING ${PAYMENT_COLUMNS}`,
      [ctx.factory.id, period.id, partyId, data.kind, data.paid_on, data.amount, data.mode ?? "cash", data.note ?? null, ctx.user.id],
    );
    if (data.kind === "writeoff") await assertWriteOffFits(client, ctx.factory.id, partyId);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "party_payment", entityId: payment.id });
    return { ...payment, balance: await partyBalance(client, ctx.factory.id, partyId) };
  });
}

async function lockPayment(client, ctx, paymentId) {
  const {
    rows: [payment],
  } = await client.query(`SELECT ${PAYMENT_COLUMNS} FROM party_payments WHERE factory_id = $1 AND id = $2 FOR UPDATE`, [
    ctx.factory.id,
    paymentId,
  ]);
  if (!payment) throw notFound();
  if (payment.cancelled_at) throw new ApiError(409, "This entry is cancelled");
  if (payment.kind === "writeoff" && ctx.role !== "owner") throw new ApiError(403, "Only the owner can change a write-off");
  return payment;
}

export async function updatePayment(ctx, paymentId, data) {
  return withTransaction(async (client) => {
    const before = await lockPayment(client, ctx, paymentId);
    const next = { ...before, ...data };
    const period = await periodFor(client, ctx.factory.id, next.paid_on);
    const {
      rows: [after],
    } = await client.query(
      `UPDATE party_payments SET paid_on = $2, amount = $3, mode = $4, note = $5, period_id = $6
       WHERE id = $1 RETURNING ${PAYMENT_COLUMNS}`,
      [paymentId, next.paid_on, money(next.amount), next.mode, next.note, period.id],
    );
    if (after.kind === "writeoff") await assertWriteOffFits(client, ctx.factory.id, after.party_id);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "party_payment", entityId: paymentId, before, after });
    return { ...after, balance: await partyBalance(client, ctx.factory.id, after.party_id) };
  });
}

export async function cancelPayment(ctx, paymentId, reason) {
  return withTransaction(async (client) => {
    const before = await lockPayment(client, ctx, paymentId);
    const {
      rows: [after],
    } = await client.query(
      `UPDATE party_payments SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3
       WHERE id = $1 RETURNING ${PAYMENT_COLUMNS}`,
      [paymentId, ctx.user.id, reason ?? null],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "cancel", entityType: "party_payment", entityId: paymentId, before: { reason: reason ?? null } });
    return { ...after, balance: await partyBalance(client, ctx.factory.id, before.party_id) };
  });
}
