import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { accrueSalaries } from "../../services/salaries.js";
import { ApiError } from "../../utils/ApiError.js";
import { ok } from "../../utils/http.js";
import { listQuery } from "../../utils/schemas.js";
import { workerLedger } from "../workers/workers.service.js";

const router = Router();

/**
 * A worker's own account, opened from the link sent on WhatsApp. No login:
 * the token in the URL is the only key, it shows that one worker and nothing
 * else of the factory, and the owner can replace or switch it off.
 */
router.get(
  "/workers/:token",
  validate(listQuery({ period: z.enum(["current", "all"]).default("all") }), "query"),
  async (req, res) => {
    res.set("X-Robots-Tag", "noindex, nofollow");
    res.set("Cache-Control", "private, no-store");

    const { token } = req.params;
    if (!/^[A-Za-z0-9_-]{20,64}$/.test(token)) throw new ApiError(404, "This link is not valid");

    const {
      rows: [worker],
    } = await pool.query(
      `SELECT w.id, w.factory_id, w.name, w.nickname, w.village, f.name AS factory_name, f.language
       FROM workers w JOIN factories f ON f.id = w.factory_id
       WHERE w.share_token = $1 AND w.share_enabled AND f.archived_at IS NULL`,
      [token],
    );
    if (!worker) throw new ApiError(404, "This link is not valid");

    await accrueSalaries(worker.factory_id);
    const {
      rows: [period],
    } = await pool.query("SELECT id, kind, name, started_on FROM periods WHERE factory_id = $1 AND ended_on IS NULL", [
      worker.factory_id,
    ]);
    const ledger = await workerLedger(pool, worker.factory_id, worker.id, {
      period_id: req.query.period === "current" ? period?.id : undefined,
      limit: req.query.limit,
      offset: req.query.offset,
    });

    ok(res, ledger.rows, 200, {
      worker: { name: worker.name, nickname: worker.nickname, village: worker.village },
      factory: { name: worker.factory_name, language: worker.language },
      period: period ?? null,
      totals: ledger.totals,
      balance: ledger.balance,
      pagination: ledger.pagination,
    });
  },
);

export default router;
