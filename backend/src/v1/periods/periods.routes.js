import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { withTransaction } from "../../db/transaction.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { openPeriod, switchPeriod } from "../../services/periods.js";
import { ApiError } from "../../utils/ApiError.js";
import { todayIst } from "../../utils/dates.js";
import { context, created, ok } from "../../utils/http.js";
import { date, optionalText } from "../../utils/schemas.js";

const router = Router({ mergeParams: true });

const startSeasonSchema = z.object({ started_on: date.optional(), name: optionalText(100) });
const endSeasonSchema = z.object({ ended_on: date.optional() });
const renameSchema = z.object({ name: optionalText(100) });

router.get("/", async (req, res) => {
  const { rows } = await pool.query(
    "SELECT * FROM periods WHERE factory_id = $1 ORDER BY started_on DESC, created_at DESC",
    [req.factory.id],
  );
  ok(res, rows);
});

router.get("/current", async (req, res) => {
  ok(res, await openPeriod(pool, req.factory.id));
});

async function change(req, kind, on, name) {
  const ctx = context(req);
  return withTransaction(async (client) => {
    const result = await switchPeriod(client, { factoryId: ctx.factory.id, userId: ctx.user.id, kind, on, name });
    await audit(client, {
      factoryId: ctx.factory.id,
      userId: ctx.user.id,
      action: kind === "season" ? "start_season" : "end_season",
      entityType: "period",
      entityId: result.opened.id,
      after: { closed: result.closed?.id ?? null, on },
    });
    return result;
  });
}

// "Start season": closes the off-season and opens a season.
router.post("/start-season", requireRole("munim"), validate(startSeasonSchema), async (req, res) => {
  created(res, await change(req, "season", req.body.started_on ?? todayIst(), req.body.name));
});

// "End season": closes the season and opens the off-season the same day.
// Balances, credit and stock carry on as they are into the off-season.
router.post("/end-season", requireRole("munim"), validate(endSeasonSchema), async (req, res) => {
  created(res, await change(req, "off_season", req.body.ended_on ?? todayIst()));
});

router.patch("/:periodId", requireRole("munim"), idParams("periodId"), validate(renameSchema), async (req, res) => {
  const {
    rows: [period],
  } = await pool.query("UPDATE periods SET name = $3 WHERE factory_id = $1 AND id = $2 RETURNING *", [
    req.factory.id,
    req.params.periodId,
    req.body.name ?? null,
  ]);
  if (!period) throw new ApiError(404, "Not found");
  ok(res, period);
});

export default router;
