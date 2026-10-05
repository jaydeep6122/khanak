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
import { optionalText } from "../../utils/schemas.js";

const router = Router({ mergeParams: true });

const COLUMNS = "id, number, name, is_active, created_at, updated_at";

const truckNumber = z
  .string()
  .trim()
  .toUpperCase()
  .min(1, "Cannot be empty")
  .max(20);

const createSchema = z.object({ number: truckNumber, name: optionalText(100) });
const updateSchema = z.object({ number: truckNumber, name: optionalText(100), is_active: z.boolean() }).partial();

// Everyone sees the trucks: a supervisor picks one when bricks go to the kiln by truck.
router.get("/", async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ${COLUMNS} FROM trucks WHERE factory_id = $1 ORDER BY is_active DESC, number`,
    [req.factory.id],
  );
  ok(res, rows);
});

router.post("/", requireRole("munim"), validate(createSchema), async (req, res) => {
  const ctx = context(req);
  const truck = await withTransaction(async (client) => {
    const {
      rows: [row],
    } = await client.query(
      `INSERT INTO trucks (factory_id, number, name) VALUES ($1, $2, $3) RETURNING ${COLUMNS}`,
      [ctx.factory.id, req.body.number, req.body.name ?? null],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "truck", entityId: row.id });
    return row;
  });
  created(res, truck);
});

router.patch("/:truckId", requireRole("munim"), idParams("truckId"), validate(updateSchema), async (req, res) => {
  const ctx = context(req);
  const truck = await withTransaction(async (client) => {
    const {
      rows: [before],
    } = await client.query(`SELECT ${COLUMNS} FROM trucks WHERE factory_id = $1 AND id = $2 FOR UPDATE`, [
      ctx.factory.id,
      req.params.truckId,
    ]);
    if (!before) throw new ApiError(404, "Not found");
    const set = setClause(req.body, ["number", "name", "is_active"]);
    if (set.keys.length === 0) return before;
    const {
      rows: [after],
    } = await client.query(`UPDATE trucks SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${COLUMNS}`, [
      ...set.values,
      before.id,
    ]);
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "truck", entityId: before.id, before, after });
    return after;
  });
  ok(res, truck);
});

export default router;
