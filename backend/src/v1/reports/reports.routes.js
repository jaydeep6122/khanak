import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { brickStock } from "../../services/ledger.js";
import { openPeriod } from "../../services/periods.js";
import { accrueSalaries } from "../../services/salaries.js";
import { todayIst } from "../../utils/dates.js";
import { ok } from "../../utils/http.js";
import { date, id } from "../../utils/schemas.js";

// Owner and munim only: a supervisor never sees totals, pay or stock.
const router = Router({ mergeParams: true });
router.use(requireRole("munim"));

router.get("/stock", async (req, res) => {
  ok(res, await brickStock(pool, req.factory.id));
});

/** The home screen: today, the running period, what is owed and the stock. */
router.get("/summary", validate(z.object({ period_id: id.optional() }), "query"), async (req, res) => {
  const factoryId = req.factory.id;
  await accrueSalaries(factoryId);
  const period = req.query.period_id
    ? (await pool.query("SELECT * FROM periods WHERE factory_id = $1 AND id = $2", [factoryId, req.query.period_id])).rows[0]
    : await openPeriod(pool, factoryId);
  const periodId = period?.id ?? null;
  const today = todayIst();

  const {
    rows: [workers],
  } = await pool.query(
    `SELECT COALESCE(sum(balance) FILTER (WHERE balance > 0), 0) AS payable,
            COALESCE(-sum(balance) FILTER (WHERE balance < 0), 0) AS receivable,
            count(*) FILTER (WHERE balance > 0) AS workers_owed,
            count(*) FILTER (WHERE balance < 0) AS workers_owing
     FROM (SELECT worker_id, sum(credit - debit) AS balance
           FROM worker_ledger WHERE factory_id = $1 GROUP BY worker_id) b`,
    [factoryId],
  );

  const {
    rows: [bricks],
  } = await pool.query(
    `SELECT COALESCE(sum(quantity) FILTER (WHERE NOT already_counted AND period_id = $2), 0)::bigint AS made_in_period,
            COALESCE(sum(quantity) FILTER (WHERE NOT already_counted AND counted_on = $3), 0)::bigint AS made_today,
            COALESCE((SELECT sum(quantity) FROM kiln_unloadings
                      WHERE factory_id = $1 AND cancelled_at IS NULL AND period_id = $2), 0)::bigint AS unloaded_in_period
     FROM brick_counts
     WHERE factory_id = $1 AND cancelled_at IS NULL`,
    [factoryId, periodId, today],
  );

  const {
    rows: [money],
  } = await pool.query(
    `SELECT COALESCE(sum(credit) FILTER (WHERE entry_kind = 'work' AND period_id = $2), 0) AS wages_in_period,
            COALESCE(sum(debit) FILTER (WHERE entry_kind = 'advance' AND period_id = $2), 0) AS advances_in_period,
            COALESCE(sum(debit) FILTER (WHERE entry_kind = 'advance' AND entry_date = $3), 0) AS advances_today,
            COALESCE(sum(credit) FILTER (WHERE entry_kind = 'writeoff' AND period_id = $2), 0) AS written_off_in_period
     FROM worker_ledger WHERE factory_id = $1`,
    [factoryId, periodId, today],
  );

  const {
    rows: [{ active_workers }],
  } = await pool.query("SELECT count(*) AS active_workers FROM workers WHERE factory_id = $1 AND is_active", [
    factoryId,
  ]);

  ok(res, {
    today,
    period,
    stock: await brickStock(pool, factoryId),
    workers: { active: active_workers, ...workers },
    bricks: {
      made_today: Number(bricks.made_today),
      made_in_period: Number(bricks.made_in_period),
      unloaded_in_period: Number(bricks.unloaded_in_period),
    },
    money,
  });
});

// "What did the supervisor enter today?": everything anyone created, changed
// or cancelled, newest first.
router.get(
  "/activity",
  validate(z.object({ date: date.optional(), user_id: id.optional() }), "query"),
  async (req, res) => {
    const { rows } = await pool.query(
      `SELECT a.id, a.action, a.entity_type, a.entity_id, a.user_id, u.name AS user_name,
              a.before, a.after, a.created_at
       FROM audit_log a
       LEFT JOIN users u ON u.id = a.user_id
       WHERE a.factory_id = $1
         AND (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = $2
         AND ($3::uuid IS NULL OR a.user_id = $3)
       ORDER BY a.created_at DESC
       LIMIT 500`,
      [req.factory.id, req.query.date ?? todayIst(), req.query.user_id ?? null],
    );
    ok(res, rows);
  },
);

export default router;
