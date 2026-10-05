import { Router } from "express";
import { z } from "zod";
import pool from "../../db/db.js";
import { setClause } from "../../db/sql.js";
import { withTransaction } from "../../db/transaction.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { audit } from "../../services/audit.js";
import { ApiError } from "../../utils/ApiError.js";
import { context, created, ok } from "../../utils/http.js";
import { text } from "../../utils/schemas.js";

// The factory's kilns (bhatha). Bricks are counted into one and nikasi takes
// them out of one, so each kiln's stock is known.
const router = Router({ mergeParams: true });

const COLUMNS = "id, name, is_active, created_at, updated_at";

const createSchema = z.object({ name: text(100) });
const updateSchema = z.object({ name: text(100), is_active: z.boolean() }).partial();

// Everyone sees the kilns: a supervisor picks one for every count and nikasi.
router.get("/", async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ${COLUMNS} FROM kilns WHERE factory_id = $1 ORDER BY is_active DESC, created_at`,
    [req.factory.id],
  );
  ok(res, rows);
});

router.post("/", requireRole("munim"), validate(createSchema), async (req, res) => {
  const ctx = context(req);
  const kiln = await withTransaction(async (client) => {
    const {
      rows: [row],
    } = await client.query(`INSERT INTO kilns (factory_id, name) VALUES ($1, $2) RETURNING ${COLUMNS}`, [
      ctx.factory.id,
      req.body.name,
    ]);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "kiln", entityId: row.id });
    return row;
  });
  created(res, kiln);
});

router.patch("/:kilnId", requireRole("munim"), idParams("kilnId"), validate(updateSchema), async (req, res) => {
  const ctx = context(req);
  const kiln = await withTransaction(async (client) => {
    const {
      rows: [before],
    } = await client.query(`SELECT ${COLUMNS} FROM kilns WHERE factory_id = $1 AND id = $2 FOR UPDATE`, [
      ctx.factory.id,
      req.params.kilnId,
    ]);
    if (!before) throw new ApiError(404, "Not found");
    const set = setClause(req.body, ["name", "is_active"]);
    if (set.keys.length === 0) return before;
    const {
      rows: [after],
    } = await client.query(`UPDATE kilns SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${COLUMNS}`, [
      ...set.values,
      before.id,
    ]);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "kiln", entityId: before.id, before, after });
    return after;
  });
  ok(res, kiln);
});

export default router;
