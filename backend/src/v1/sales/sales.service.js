import pool from "../../db/db.js";
import { Filters, pageResult } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { audit } from "../../services/audit.js";
import { stockWarnings } from "../../services/ledger.js";
import { partyBalance, resolveParty } from "../../services/parties.js";
import { periodFor } from "../../services/periods.js";
import { postSale } from "../../services/posting.js";
import { assertNotPaidByDay, assertWorkersExist, groupRows, loadWorkTypes, rateLookup, readWork, savedRates } from "../../services/work-groups.js";
import { ApiError } from "../../utils/ApiError.js";
import { dec, money } from "../../utils/money.js";

const SALE_COLUMNS = `s.id, s.period_id, s.sold_on, s.party_id, s.customer_name, s.quantity, s.rate,
  s.bricks_amount, s.bhadu, s.total, s.paid_amount, s.delivery, s.truck_id, s.driver_id, s.trips,
  s.destination, s.hire_party_id, s.hire_amount, s.note, s.created_by, s.cancelled_at, s.cancel_reason,
  s.created_at, s.updated_at`;

const SALE_JOINS = `
  LEFT JOIN parties p ON p.id = s.party_id
  LEFT JOIN parties h ON h.id = s.hire_party_id
  LEFT JOIN trucks t ON t.id = s.truck_id
  LEFT JOIN workers d ON d.id = s.driver_id`;

const SALE_NAMES = `p.name AS party_name, p.phone AS party_phone, h.name AS hire_party_name,
  t.number AS truck_number, d.name AS driver_name`;

const notFound = () => new ApiError(404, "Not found");

export async function getSale(db, ctx, saleId) {
  const {
    rows: [sale],
  } = await db.query(`SELECT ${SALE_COLUMNS}, ${SALE_NAMES} FROM sales s ${SALE_JOINS} WHERE s.factory_id = $1 AND s.id = $2`, [
    ctx.factory.id,
    saleId,
  ]);
  if (!sale) throw notFound();
  const { groups } = await readWork(db, "sale_id", saleId);
  return {
    ...sale,
    due: money(dec(sale.total).minus(sale.paid_amount)),
    groups,
    party_balance: sale.party_id ? await partyBalance(db, ctx.factory.id, sale.party_id) : null,
  };
}

export async function listSales(ctx, query) {
  const filters = new Filters()
    .add("s.factory_id = ?", ctx.factory.id)
    .addIf(query.from, "s.sold_on >= ?", query.from)
    .addIf(query.to, "s.sold_on <= ?", query.to)
    .addIf(query.period_id, "s.period_id = ?", query.period_id)
    .addIf(query.party_id, "s.party_id = ?", query.party_id)
    .addIf(query.truck_id, "s.truck_id = ?", query.truck_id)
    .addIf(!query.include_cancelled, "s.cancelled_at IS NULL");
  const { rows } = await pool.query(
    `SELECT ${SALE_COLUMNS}, ${SALE_NAMES}, COUNT(*) OVER () AS total_count
     FROM sales s ${SALE_JOINS}
     ${filters.where}
     ORDER BY s.sold_on DESC, s.created_at DESC
     LIMIT ${filters.param(query.limit)} OFFSET ${filters.param(query.offset)}`,
    filters.values,
  );
  return pageResult(rows, query);
}

/**
 * The rate to start a new sale with: this customer's last, or the factory's
 * last sale. The price changes from load to load, so it is only a suggestion.
 */
export async function lastRate(ctx, partyId) {
  const {
    rows: [row],
  } = await pool.query(
    `SELECT rate, sold_on FROM sales
     WHERE factory_id = $1 AND cancelled_at IS NULL AND ($2::uuid IS NULL OR party_id = $2)
     ORDER BY sold_on DESC, created_at DESC LIMIT 1`,
    [ctx.factory.id, partyId ?? null],
  );
  if (row || !partyId) return row ?? null;
  return lastRate(ctx, null);
}

async function assertBelongs(client, ctx, table, id, label) {
  if (!id) return;
  const { rowCount } = await client.query(`SELECT 1 FROM ${table} WHERE factory_id = $1 AND id = $2`, [ctx.factory.id, id]);
  if (!rowCount) throw new ApiError(400, `Unknown ${label}`);
}

/** The loading groups' pay. Truck loaders are paid per trip or per 1000 bricks. */
async function workRowsFor(client, ctx, data, saved) {
  const types = await loadWorkTypes(client, ctx.factory.id);
  for (const group of data.groups ?? []) {
    const code = types.byId.get(group.work_type_id)?.code;
    if (code === "stacking" || code === "unloading") {
      throw new ApiError(400, "A sale pays only the workers who loaded the bricks");
    }
  }
  await assertWorkersExist(
    client,
    ctx.factory.id,
    (data.groups ?? []).flatMap((group) => group.workers.map((worker) => worker.worker_id)),
  );
  await assertNotPaidByDay(client, ctx.factory.id, data.groups);
  return groupRows(data.groups, types, {
    bricks: data.quantity,
    // One trip unless more are given; a customer's own vehicle is one trip
    // as far as pay goes.
    trips: data.delivery === "own_truck" ? (data.trips ?? 1) : 1,
    rateFor: rateLookup(saved),
    allowAmounts: true,
  });
}

/** The row's values, with the customer and hired truck's owner settled. */
async function saleFields(client, ctx, data) {
  await assertBelongs(client, ctx, "trucks", data.truck_id, "truck_id");
  await assertBelongs(client, ctx, "workers", data.driver_id, "driver_id");
  const partyId = await resolveParty(client, ctx, { id: data.party_id, details: data.party }, "customer");
  const hirePartyId =
    data.delivery === "hired"
      ? await resolveParty(client, ctx, { id: data.hire_party_id, details: data.hire_party }, "supplier")
      : null;
  const bricksAmount = money(dec(data.quantity).times(data.rate).dividedBy(1000));
  const total = money(dec(bricksAmount).plus(data.bhadu ?? 0));
  return {
    sold_on: data.sold_on,
    party_id: partyId,
    customer_name: partyId ? null : (data.customer_name ?? null),
    quantity: data.quantity,
    rate: data.rate,
    bricks_amount: bricksAmount,
    bhadu: data.bhadu ?? null,
    total,
    paid_amount: data.paid_amount,
    delivery: data.delivery,
    truck_id: data.delivery === "own_truck" ? data.truck_id : null,
    driver_id: data.delivery === "own_truck" ? (data.driver_id ?? null) : null,
    trips: data.delivery === "own_truck" ? (data.trips ?? 1) : null,
    destination: data.destination ?? null,
    hire_party_id: hirePartyId,
    hire_amount: data.delivery === "hired" ? data.hire_amount : null,
    note: data.note ?? null,
  };
}

const COLUMNS = [
  "sold_on",
  "party_id",
  "customer_name",
  "quantity",
  "rate",
  "bricks_amount",
  "bhadu",
  "total",
  "paid_amount",
  "delivery",
  "truck_id",
  "driver_id",
  "trips",
  "destination",
  "hire_party_id",
  "hire_amount",
  "note",
];

const auditView = (sale) => ({
  ...Object.fromEntries(COLUMNS.map((column) => [column, sale[column] ?? null])),
  groups: sale.groups.map((group) => ({
    work_type_id: group.work_type_id,
    total: group.total,
    workers: group.workers.map((worker) => ({ worker_id: worker.worker_id, amount: worker.amount })),
  })),
});

export async function createSale(ctx, data) {
  return withTransaction(async (client) => {
    const period = await periodFor(client, ctx.factory.id, data.sold_on);
    const fields = await saleFields(client, ctx, data);
    const workRows = await workRowsFor(client, ctx, data, new Map());
    const values = COLUMNS.map((column) => fields[column]);
    const {
      rows: [sale],
    } = await client.query(
      `INSERT INTO sales (${COLUMNS.join(", ")}, factory_id, period_id, created_by)
       VALUES (${COLUMNS.map((_, i) => `$${i + 1}`).join(", ")}, $${COLUMNS.length + 1}, $${COLUMNS.length + 2}, $${COLUMNS.length + 3})
       RETURNING *`,
      [...values, ctx.factory.id, period.id, ctx.user.id],
    );
    await postSale(client, sale, workRows);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "sale", entityId: sale.id });
    return { ...(await getSale(client, ctx, sale.id)), warnings: await stockWarnings(client, ctx.factory.id) };
  });
}

async function lockSale(client, ctx, saleId) {
  const {
    rows: [sale],
  } = await client.query("SELECT * FROM sales WHERE factory_id = $1 AND id = $2 FOR UPDATE", [ctx.factory.id, saleId]);
  if (!sale) throw notFound();
  if (sale.cancelled_at) throw new ApiError(409, "This sale is cancelled");
  return sale;
}

/** Replaces the whole sale; its stock and loaders' pay are written again. */
export async function updateSale(ctx, saleId, data) {
  return withTransaction(async (client) => {
    await lockSale(client, ctx, saleId);
    const before = await getSale(client, ctx, saleId);
    const period = await periodFor(client, ctx.factory.id, data.sold_on);
    const fields = await saleFields(client, ctx, data);
    const workRows = await workRowsFor(client, ctx, data, await savedRates(client, "sale_id", saleId));
    const {
      rows: [sale],
    } = await client.query(
      `UPDATE sales SET ${COLUMNS.map((column, i) => `${column} = $${i + 1}`).join(", ")}, period_id = $${COLUMNS.length + 1}
       WHERE id = $${COLUMNS.length + 2} RETURNING *`,
      [...COLUMNS.map((column) => fields[column]), period.id, saleId],
    );
    await postSale(client, sale, workRows);
    const after = await getSale(client, ctx, saleId);
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "update",
      entityType: "sale",
      entityId: saleId,
      before: auditView(before),
      after: auditView(after),
    });
    return { ...after, warnings: await stockWarnings(client, ctx.factory.id) };
  });
}

/** The sale stays on record; its stock, pay and what it put on accounts go. */
export async function cancelSale(ctx, saleId, reason) {
  return withTransaction(async (client) => {
    await lockSale(client, ctx, saleId);
    const before = await getSale(client, ctx, saleId);
    const {
      rows: [sale],
    } = await client.query(
      "UPDATE sales SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3 WHERE id = $1 RETURNING *",
      [saleId, ctx.user.id, reason ?? null],
    );
    await postSale(client, sale, []);
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: "cancel",
      entityType: "sale",
      entityId: saleId,
      before: { ...auditView(before), reason: reason ?? null },
    });
    return { ...(await getSale(client, ctx, saleId)), warnings: await stockWarnings(client, ctx.factory.id) };
  });
}
