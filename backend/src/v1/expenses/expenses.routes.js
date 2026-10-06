import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { Filters, pageResult } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { partyBalance, resolveParty } from "../../services/parties.js";
import { periodFor } from "../../services/periods.js";
import { ApiError } from "../../utils/ApiError.js";
import { context, created, ok, paged } from "../../utils/http.js";
import { dec, money as toMoney } from "../../utils/money.js";
import { cancelSchema, date, decimal, id, listQuery, money, optionalText, queryBoolean } from "../../utils/schemas.js";
import { newParty } from "../parties/parties.schemas.js";

// What the factory spends: soil, coal, husk, diesel, truck upkeep and the
// rest. A supplier is needed only when part is left unpaid. Owner and munim.
const router = Router({ mergeParams: true });
router.use(requireRole("munim"));

const CATEGORIES = ["soil", "coal", "husk", "diesel", "truck_upkeep", "other"];

const expenseSchema = z
  .object({
    spent_on: date,
    category: z.enum(CATEGORIES),
    quantity: decimal({ dp: 3, gt: 0, max: 1e9 }).nullable().optional(),
    unit: optionalText(20),
    amount: money({ gt: 0 }),
    // Left out: paid in full.
    paid_amount: money().optional(),
    party_id: id.nullable().optional(),
    party: newParty.optional(),
    // Diesel and truck upkeep: which truck. Diesel: litres and the odometer
    // when the tank was filled up, for the truck's average.
    truck_id: id.nullable().optional(),
    litres: decimal({ dp: 2, gt: 0, max: 100000 }).nullable().optional(),
    odometer: z.number().int().min(0).max(10_000_000).nullable().optional(),
    note: optionalText(1000),
  })
  .superRefine((expense, ctx) => {
    const fail = (path, message) => ctx.addIssue({ code: "custom", path: [path], message });
    const paid = dec(expense.paid_amount ?? expense.amount);
    if (paid.gt(expense.amount)) fail("paid_amount", "Cannot pay more than the amount");
    if (expense.party_id && expense.party) fail("party", "Give party_id or a new party, not both");
    if (paid.lt(expense.amount) && !expense.party_id && !expense.party) {
      fail("party", "Something is left owing: give the supplier's name");
    }
    if (!["diesel", "truck_upkeep"].includes(expense.category) && expense.truck_id) {
      fail("truck_id", "Only diesel and truck upkeep are for a truck");
    }
    if (expense.category !== "diesel" && (expense.litres != null || expense.odometer != null)) {
      fail("litres", "Litres and the odometer are only for diesel");
    }
  });

const listQuerySchema = listQuery({
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  category: z.enum(CATEGORIES).optional(),
  truck_id: id.optional(),
  party_id: id.optional(),
  include_cancelled: queryBoolean.optional(),
});

const COLUMNS = `e.id, e.period_id, e.spent_on, e.category, e.quantity, e.unit, e.amount, e.paid_amount,
  e.party_id, e.truck_id, e.litres, e.odometer, e.note, e.created_by, e.cancelled_at, e.cancel_reason,
  e.created_at, e.updated_at`;

const FIELDS = ["spent_on", "category", "quantity", "unit", "amount", "paid_amount", "party_id", "truck_id", "litres", "odometer", "note"];

const notFound = () => new ApiError(404, "Not found");

async function getExpense(db, ctx, expenseId) {
  const {
    rows: [expense],
  } = await db.query(
    `SELECT ${COLUMNS}, p.name AS party_name, t.number AS truck_number
     FROM expenses e
     LEFT JOIN parties p ON p.id = e.party_id
     LEFT JOIN trucks t ON t.id = e.truck_id
     WHERE e.factory_id = $1 AND e.id = $2`,
    [ctx.factory.id, expenseId],
  );
  if (!expense) throw notFound();
  return {
    ...expense,
    due: toMoney(dec(expense.amount).minus(expense.paid_amount)),
    party_balance: expense.party_id ? await partyBalance(db, ctx.factory.id, expense.party_id) : null,
  };
}

async function fieldsOf(client, ctx, data) {
  if (data.truck_id) {
    const { rowCount } = await client.query("SELECT 1 FROM trucks WHERE factory_id = $1 AND id = $2", [
      ctx.factory.id,
      data.truck_id,
    ]);
    if (!rowCount) throw new ApiError(400, "Unknown truck_id");
  }
  const partyId = await resolveParty(client, ctx, { id: data.party_id, details: data.party }, "supplier");
  return {
    spent_on: data.spent_on,
    category: data.category,
    quantity: data.quantity ?? null,
    unit: data.unit ?? null,
    amount: data.amount,
    paid_amount: data.paid_amount ?? data.amount,
    party_id: partyId,
    truck_id: data.truck_id ?? null,
    litres: data.litres ?? null,
    odometer: data.odometer ?? null,
    note: data.note ?? null,
  };
}

router.get("/", validate(listQuerySchema, "query"), async (req, res) => {
  const query = req.query;
  const filters = new Filters()
    .add("e.factory_id = ?", req.factory.id)
    .addIf(query.from, "e.spent_on >= ?", query.from)
    .addIf(query.to, "e.spent_on <= ?", query.to)
    .addIf(query.period_id, "e.period_id = ?", query.period_id)
    .addIf(query.category, "e.category = ?", query.category)
    .addIf(query.truck_id, "e.truck_id = ?", query.truck_id)
    .addIf(query.party_id, "e.party_id = ?", query.party_id)
    .addIf(!query.include_cancelled, "e.cancelled_at IS NULL");
  const { rows } = await pool.query(
    `SELECT ${COLUMNS}, p.name AS party_name, t.number AS truck_number, COUNT(*) OVER () AS total_count
     FROM expenses e
     LEFT JOIN parties p ON p.id = e.party_id
     LEFT JOIN trucks t ON t.id = e.truck_id
     ${filters.where}
     ORDER BY e.spent_on DESC, e.created_at DESC
     LIMIT ${filters.param(query.limit)} OFFSET ${filters.param(query.offset)}`,
    filters.values,
  );
  paged(res, pageResult(rows, query));
});

router.post("/", validate(expenseSchema), async (req, res) => {
  const ctx = context(req);
  const expense = await withTransaction(async (client) => {
    const period = await periodFor(client, ctx.factory.id, req.body.spent_on);
    const fields = await fieldsOf(client, ctx, req.body);
    const {
      rows: [row],
    } = await client.query(
      `INSERT INTO expenses (${FIELDS.join(", ")}, factory_id, period_id, created_by)
       VALUES (${FIELDS.map((_, i) => `$${i + 1}`).join(", ")}, $${FIELDS.length + 1}, $${FIELDS.length + 2}, $${FIELDS.length + 3})
       RETURNING id`,
      [...FIELDS.map((field) => fields[field]), ctx.factory.id, period.id, ctx.user.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "expense", entityId: row.id });
    return getExpense(client, ctx, row.id);
  });
  created(res, expense);
});

router.get("/:expenseId", idParams("expenseId"), async (req, res) => {
  ok(res, await getExpense(pool, context(req), req.params.expenseId));
});

async function lockExpense(client, ctx, expenseId) {
  const {
    rows: [row],
  } = await client.query("SELECT * FROM expenses WHERE factory_id = $1 AND id = $2 FOR UPDATE", [ctx.factory.id, expenseId]);
  if (!row) throw notFound();
  if (row.cancelled_at) throw new ApiError(409, "This expense is cancelled");
  return row;
}

router.put("/:expenseId", idParams("expenseId"), validate(expenseSchema), async (req, res) => {
  const ctx = context(req);
  const { expenseId } = req.params;
  const expense = await withTransaction(async (client) => {
    await lockExpense(client, ctx, expenseId);
    const before = await getExpense(client, ctx, expenseId);
    const period = await periodFor(client, ctx.factory.id, req.body.spent_on);
    const fields = await fieldsOf(client, ctx, req.body);
    await client.query(
      `UPDATE expenses SET ${FIELDS.map((field, i) => `${field} = $${i + 1}`).join(", ")}, period_id = $${FIELDS.length + 1}
       WHERE id = $${FIELDS.length + 2}`,
      [...FIELDS.map((field) => fields[field]), period.id, expenseId],
    );
    const after = await getExpense(client, ctx, expenseId);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "expense", entityId: expenseId, before, after });
    return after;
  });
  ok(res, expense);
});

router.post("/:expenseId/cancel", idParams("expenseId"), validate(cancelSchema), async (req, res) => {
  const ctx = context(req);
  const { expenseId } = req.params;
  const expense = await withTransaction(async (client) => {
    await lockExpense(client, ctx, expenseId);
    await client.query("UPDATE expenses SET cancelled_at = now(), cancelled_by = $2, cancel_reason = $3 WHERE id = $1", [
      expenseId,
      ctx.user.id,
      req.body.reason ?? null,
    ]);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "cancel", entityType: "expense", entityId: expenseId, before: { reason: req.body.reason ?? null } });
    return getExpense(client, ctx, expenseId);
  });
  ok(res, expense);
});

export default router;
