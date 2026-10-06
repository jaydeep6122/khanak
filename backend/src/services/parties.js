import { ApiError } from "../utils/ApiError.js";
import { audit } from "./audit.js";

/**
 * What each party owes the factory: positive = they owe (lena), negative =
 * the factory owes them (dena: a supplier's credit or a customer's advance).
 */
export async function partyBalances(db, factoryId, partyIds = null) {
  const { rows } = await db.query(
    `SELECT party_id, COALESCE(sum(owed), 0) AS balance
     FROM party_ledger
     WHERE factory_id = $1 AND ($2::uuid[] IS NULL OR party_id = ANY($2::uuid[]))
     GROUP BY party_id`,
    [factoryId, partyIds],
  );
  return new Map(rows.map((row) => [row.party_id, row.balance]));
}

export async function partyBalance(db, factoryId, partyId) {
  return (await partyBalances(db, factoryId, [partyId])).get(partyId) ?? "0.00";
}

/**
 * The party a sale or expense is with: an existing one by id, or a new one
 * from the name typed (customers and suppliers are mostly one-off, so they
 * are added on the spot rather than set up first). Null when neither is given.
 */
export async function resolveParty(client, ctx, { id, details }, kind) {
  if (id) {
    const { rowCount } = await client.query("SELECT 1 FROM parties WHERE factory_id = $1 AND id = $2", [
      ctx.factory.id,
      id,
    ]);
    if (!rowCount) throw new ApiError(400, "Unknown party");
    return id;
  }
  if (!details) return null;

  const {
    rows: [party],
  } = await client.query(
    `INSERT INTO parties (factory_id, kind, name, phone, village, created_by)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [ctx.factory.id, kind, details.name, details.phone ?? null, details.village ?? null, ctx.user.id],
  );
  await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "party", entityId: party.id });
  return party.id;
}
