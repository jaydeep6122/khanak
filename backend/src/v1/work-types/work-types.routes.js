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
import { money, text } from "../../utils/schemas.js";

const router = Router({ mergeParams: true });

const COLUMNS = "id, code, name, pay_unit, rate, is_group, is_active, sort_order";

// Monthly pay is set on each worker, so owners cannot add per_month kinds.
const payUnit = z.enum(["per_1000", "per_lakh", "per_day", "per_trip", "lumpsum"]);

const createSchema = z.object({
  name: text(100),
  pay_unit: payUnit,
  rate: money().nullable().optional(),
  is_group: z.boolean().optional(),
});

const updateSchema = z
  .object({
    name: text(100),
    pay_unit: payUnit,
    rate: money().nullable(),
    is_group: z.boolean(),
    is_active: z.boolean(),
    sort_order: z.number().int().min(0).max(1000),
  })
  .partial();

/** The rate column must be set exactly when the pay unit has a rate. */
function checkShape({ name, pay_unit, rate, is_group }) {
  const rated = pay_unit !== "lumpsum" && pay_unit !== "per_month";
  if (rated && (rate === null || rate === undefined)) throw new ApiError(400, `"${name}" needs a rate`);
  if (!rated && rate !== null && rate !== undefined) throw new ApiError(400, `"${name}" has no rate`);
  if (is_group && pay_unit === "per_day") throw new ApiError(400, "Day work is paid to each worker, not shared");
}

router.get("/", async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ${COLUMNS} FROM work_types WHERE factory_id = $1 ORDER BY sort_order, name`,
    [req.factory.id],
  );
  ok(res, rows);
});

router.post("/", requireRole("owner"), validate(createSchema), async (req, res) => {
  const ctx = context(req);
  const type = { is_group: false, rate: null, ...req.body };
  checkShape(type);

  const row = await withTransaction(async (client) => {
    const {
      rows: [inserted],
    } = await client.query(
      `INSERT INTO work_types (factory_id, name, pay_unit, rate, is_group, sort_order)
       VALUES ($1, $2, $3, $4, $5,
               (SELECT COALESCE(max(sort_order), 0) + 1 FROM work_types WHERE factory_id = $1))
       RETURNING ${COLUMNS}`,
      [ctx.factory.id, type.name, type.pay_unit, type.rate, type.is_group],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "create", entityType: "work_type", entityId: inserted.id });
    return inserted;
  });
  created(res, row);
});

// Changing a rate applies to new entries only: every entry keeps the rate it
// was made with.
router.patch("/:typeId", requireRole("owner"), idParams("typeId"), validate(updateSchema), async (req, res) => {
  const ctx = context(req);
  const row = await withTransaction(async (client) => {
    const {
      rows: [before],
    } = await client.query(`SELECT ${COLUMNS} FROM work_types WHERE factory_id = $1 AND id = $2 FOR UPDATE`, [
      ctx.factory.id,
      req.params.typeId,
    ]);
    if (!before) throw new ApiError(404, "Not found");
    if (before.code && (req.body.pay_unit !== undefined || req.body.is_group !== undefined)) {
      throw new ApiError(400, "How a built-in kind of work is paid cannot be changed; add a new kind instead");
    }
    checkShape({ ...before, ...req.body });

    const set = setClause(req.body, ["name", "pay_unit", "rate", "is_group", "is_active", "sort_order"]);
    if (set.keys.length === 0) return before;
    const {
      rows: [after],
    } = await client.query(
      `UPDATE work_types SET ${set.sql} WHERE id = $${set.keys.length + 1} RETURNING ${COLUMNS}`,
      [...set.values, before.id],
    );
    await audit(client, { factoryId: ctx.factory.id, userId: ctx.user.id, action: "update", entityType: "work_type", entityId: before.id, before, after });
    return after;
  });
  ok(res, row);
});

export default router;
