import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { withTransaction } from "../../db/transaction.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { ApiError } from "../../utils/ApiError.js";
import { todayIst } from "../../utils/dates.js";
import { context, created, ok } from "../../utils/http.js";
import { dec, money as toMoney } from "../../utils/money.js";
import { cancelSchema, date, id, money, optionalText } from "../../utils/schemas.js";

// Cash the owner leaves with a supervisor to pay advances from.
// In hand = given - returned - advances the supervisor paid.
const router = Router({ mergeParams: true });

const handoverSchema = z.object({
  holder_id: id,
  kind: z.enum(["given", "returned"]),
  handover_date: date,
  amount: money({ gt: 0 }),
  note: optionalText(1000),
});

const settleSchema = z.object({ handover_date: date.optional(), note: optionalText(1000) });

const SUMMARY = `
  WITH handed AS (
    SELECT holder_id,
           sum(amount) FILTER (WHERE kind = 'given') AS given,
           sum(amount) FILTER (WHERE kind = 'returned') AS returned
    FROM cash_handovers
    WHERE factory_id = $1 AND cancelled_at IS NULL
    GROUP BY holder_id
  ), paid AS (
    SELECT cash_holder_id AS holder_id, sum(amount) AS advances
    FROM worker_transactions
    WHERE factory_id = $1 AND cancelled_at IS NULL AND cash_holder_id IS NOT NULL
    GROUP BY cash_holder_id
  )
  SELECT holder_id, u.name,
         COALESCE(given, 0)::numeric(14, 2) AS given,
         COALESCE(returned, 0)::numeric(14, 2) AS returned,
         COALESCE(advances, 0)::numeric(14, 2) AS advances_paid,
         (COALESCE(given, 0) - COALESCE(returned, 0) - COALESCE(advances, 0))::numeric(14, 2) AS in_hand
  FROM handed FULL JOIN paid USING (holder_id)
  JOIN users u ON u.id = holder_id`;

async function holderSummary(db, factoryId, holderId) {
  const {
    rows: [row],
  } = await db.query(`${SUMMARY} WHERE holder_id = $2`, [factoryId, holderId]);
  return row ?? { holder_id: holderId, given: "0.00", returned: "0.00", advances_paid: "0.00", in_hand: "0.00" };
}

/** A supervisor sees only their own cash. */
function assertMayRead(ctx, holderId) {
  if (ctx.role === "supervisor" && holderId !== ctx.user.id) throw new ApiError(404, "Not found");
}

async function assertMember(db, factoryId, userId) {
  const { rowCount } = await db.query(
    "SELECT 1 FROM factory_members WHERE factory_id = $1 AND user_id = $2 AND status = 'active'",
    [factoryId, userId],
  );
  if (!rowCount) throw new ApiError(400, "holder_id is not a member of this factory");
}

router.get("/", async (req, res) => {
  const ctx = context(req);
  if (ctx.role === "supervisor") return ok(res, [await holderSummary(pool, ctx.factory.id, ctx.user.id)]);
  const { rows } = await pool.query(`${SUMMARY} ORDER BY u.name`, [ctx.factory.id]);
  ok(res, rows);
});

router.get("/:holderId", idParams("holderId"), async (req, res) => {
  const ctx = context(req);
  const { holderId } = req.params;
  assertMayRead(ctx, holderId);
  const { rows: lines } = await pool.query(
    `SELECT 'handover' AS line_kind, h.id, h.kind, h.handover_date AS line_date, h.amount, h.note,
            NULL::uuid AS worker_id, NULL AS worker_name, h.created_at
     FROM cash_handovers h
     WHERE h.factory_id = $1 AND h.holder_id = $2 AND h.cancelled_at IS NULL
     UNION ALL
     SELECT 'advance', t.id, t.kind, t.txn_date, t.amount, t.note, t.worker_id, w.name, t.created_at
     FROM worker_transactions t JOIN workers w ON w.id = t.worker_id
     WHERE t.factory_id = $1 AND t.cash_holder_id = $2 AND t.cancelled_at IS NULL
     ORDER BY line_date DESC, created_at DESC
     LIMIT 500`,
    [ctx.factory.id, holderId],
  );
  ok(res, { ...(await holderSummary(pool, ctx.factory.id, holderId)), lines });
});

router.post("/handovers", requireRole("munim"), validate(handoverSchema), async (req, res) => {
  const ctx = context(req);
  const data = req.body;
  if (data.handover_date > todayIst()) throw new ApiError(400, "The date cannot be in the future");
  const summary = await withTransaction(async (client) => {
    await assertMember(client, ctx.factory.id, data.holder_id);
    const {
      rows: [row],
    } = await client.query(
      `INSERT INTO cash_handovers (factory_id, holder_id, kind, handover_date, amount, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [ctx.factory.id, data.holder_id, data.kind, data.handover_date, data.amount, data.note ?? null, ctx.user.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "cash_handover", entityId: row.id });
    return holderSummary(client, ctx.factory.id, data.holder_id);
  });
  created(res, summary);
});

router.post(
  "/handovers/:handoverId/cancel",
  requireRole("munim"),
  idParams("handoverId"),
  validate(cancelSchema),
  async (req, res) => {
    const ctx = context(req);
    const summary = await withTransaction(async (client) => {
      const {
        rows: [row],
      } = await client.query(
        `UPDATE cash_handovers SET cancelled_at = now(), cancelled_by = $3, cancel_reason = $4
         WHERE factory_id = $1 AND id = $2 AND cancelled_at IS NULL
         RETURNING holder_id`,
        [ctx.factory.id, req.params.handoverId, ctx.user.id, req.body.reason ?? null],
      );
      if (!row) throw new ApiError(404, "Not found");
      await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "cancel", entityType: "cash_handover", entityId: req.params.handoverId, before: { reason: req.body.reason ?? null } });
      return holderSummary(client, ctx.factory.id, row.holder_id);
    });
    ok(res, summary);
  },
);

// "Settle the cash": the supervisor hands back what is left, or is paid back
// what they spent from their own pocket. Leaves them at zero.
router.post("/:holderId/settle", requireRole("munim"), idParams("holderId"), validate(settleSchema), async (req, res) => {
  const ctx = context(req);
  const { holderId } = req.params;
  const settleOn = req.body.handover_date ?? todayIst();
  if (settleOn > todayIst()) throw new ApiError(400, "The date cannot be in the future");

  const summary = await withTransaction(async (client) => {
    // One settle at a time per holder, so two taps cannot both record it.
    await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [`cash:${ctx.factory.id}:${holderId}`]);
    const inHand = dec((await holderSummary(client, ctx.factory.id, holderId)).in_hand);
    if (inHand.isZero()) throw new ApiError(409, "Nothing to settle: the cash in hand is already zero");

    const {
      rows: [row],
    } = await client.query(
      `INSERT INTO cash_handovers (factory_id, holder_id, kind, handover_date, amount, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [
        ctx.factory.id,
        holderId,
        inHand.isPositive() ? "returned" : "given",
        settleOn,
        toMoney(inHand.abs()),
        req.body.note ?? null,
        ctx.user.id,
      ],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "settle_cash", entityType: "cash_handover", entityId: row.id });
    return holderSummary(client, ctx.factory.id, holderId);
  });
  ok(res, summary);
});

export default router;
