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
import { dec, money } from "../../utils/money.js";
import { date, optionalText } from "../../utils/schemas.js";

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

const reportQuery = z
  .object({ from: date.optional(), to: date.optional() })
  .refine((q) => !q.from || !q.to || q.from <= q.to, { message: "from must be on or before to", path: ["from"] });

// An average this far below the truck's usual one is flagged: diesel going
// missing, or the truck needing a look.
const AVERAGE_DROP = 0.8;

/**
 * Every full-tank fill with what it covered: the diesel bought at a fill was
 * burnt since the one before, so each fill is measured against the trips
 * and kilometres since the previous fill.
 */
async function fuelFills(db, factoryId, truckId, to) {
  const { rows: fills } = await db.query(
    `SELECT id, spent_on, amount, litres, odometer
     FROM expenses
     WHERE factory_id = $1 AND truck_id = $2 AND category = 'diesel' AND cancelled_at IS NULL
       AND ($3::date IS NULL OR spent_on <= $3)
     ORDER BY spent_on, created_at`,
    [factoryId, truckId, to ?? null],
  );
  const { rows: trips } = await db.query(
    `SELECT sold_on AS day, trips FROM sales
     WHERE factory_id = $1 AND truck_id = $2 AND cancelled_at IS NULL
     UNION ALL
     SELECT counted_on, trips FROM brick_counts
     WHERE factory_id = $1 AND truck_id = $2 AND cancelled_at IS NULL`,
    [factoryId, truckId],
  );

  const averages = [];
  return fills.map((fill, i) => {
    const previous = fills[i - 1];
    if (!previous) return { ...fill, trips: null, km: null, km_per_litre: null, per_trip: null, low_average: false };

    const tripCount = trips
      .filter((t) => t.day > previous.spent_on && t.day <= fill.spent_on)
      .reduce((sum, t) => sum + t.trips, 0);
    const km = fill.odometer != null && previous.odometer != null ? fill.odometer - previous.odometer : null;
    const kmPerLitre = km != null && km > 0 && fill.litres ? dec(km).dividedBy(fill.litres).toDecimalPlaces(2).toFixed(2) : null;
    const usual = averages.length >= 2 ? averages.reduce((a, b) => a.plus(b), dec(0)).dividedBy(averages.length) : null;
    const lowAverage = kmPerLitre != null && usual != null && dec(kmPerLitre).lt(usual.times(AVERAGE_DROP));
    if (kmPerLitre != null) averages.push(dec(kmPerLitre));
    return {
      ...fill,
      trips: tripCount,
      km,
      km_per_litre: kmPerLitre,
      per_trip: tripCount > 0 ? money(dec(fill.amount).dividedBy(tripCount)) : null,
      low_average: lowAverage,
    };
  });
}

/**
 * What a truck did and earned between two dates: trips with sales and to
 * the kiln, delivery charges billed (and trips that billed none), diesel,
 * upkeep and the loaders' pay, and so what each trip made.
 */
router.get(
  "/:truckId/report",
  requireRole("munim"),
  idParams("truckId"),
  validate(reportQuery, "query"),
  async (req, res) => {
    const factoryId = req.factory.id;
    const { truckId } = req.params;
    const { from, to } = req.query;
    const range = [factoryId, truckId, from ?? null, to ?? null];

    const {
      rows: [truck],
    } = await pool.query(`SELECT ${COLUMNS} FROM trucks WHERE factory_id = $1 AND id = $2`, [factoryId, truckId]);
    if (!truck) throw new ApiError(404, "Not found");

    const {
      rows: [sales],
    } = await pool.query(
      `SELECT COALESCE(sum(trips), 0)::int AS trips,
              COALESCE(sum(trips) FILTER (WHERE COALESCE(bhadu, 0) = 0), 0)::int AS trips_without_bhadu,
              COALESCE(sum(quantity), 0)::bigint AS bricks,
              COALESCE(sum(bhadu), 0) AS bhadu
       FROM sales
       WHERE factory_id = $1 AND truck_id = $2 AND cancelled_at IS NULL
         AND ($3::date IS NULL OR sold_on >= $3) AND ($4::date IS NULL OR sold_on <= $4)`,
      range,
    );
    const {
      rows: [kiln],
    } = await pool.query(
      `SELECT COALESCE(sum(trips), 0)::int AS trips, COALESCE(sum(quantity), 0)::bigint AS bricks
       FROM brick_counts
       WHERE factory_id = $1 AND truck_id = $2 AND cancelled_at IS NULL
         AND ($3::date IS NULL OR counted_on >= $3) AND ($4::date IS NULL OR counted_on <= $4)`,
      range,
    );
    const {
      rows: [costs],
    } = await pool.query(
      `SELECT COALESCE(sum(amount) FILTER (WHERE category = 'diesel'), 0) AS diesel,
              COALESCE(sum(litres) FILTER (WHERE category = 'diesel'), 0) AS litres,
              COALESCE(sum(amount) FILTER (WHERE category = 'truck_upkeep'), 0) AS upkeep
       FROM expenses
       WHERE factory_id = $1 AND truck_id = $2 AND cancelled_at IS NULL
         AND ($3::date IS NULL OR spent_on >= $3) AND ($4::date IS NULL OR spent_on <= $4)`,
      range,
    );
    const {
      rows: [loaders],
    } = await pool.query(
      `SELECT COALESCE(sum(e.amount), 0) AS wages
       FROM work_entries e JOIN sales s ON s.id = e.sale_id
       WHERE s.factory_id = $1 AND s.truck_id = $2 AND s.cancelled_at IS NULL
         AND ($3::date IS NULL OR s.sold_on >= $3) AND ($4::date IS NULL OR s.sold_on <= $4)`,
      range,
    );

    const totalTrips = sales.trips + kiln.trips;
    const profit = dec(sales.bhadu).minus(costs.diesel).minus(costs.upkeep).minus(loaders.wages);
    const fills = (await fuelFills(pool, factoryId, truckId, to)).filter((fill) => !from || fill.spent_on >= from);

    ok(res, {
      truck,
      trips: { sales: sales.trips, kiln: kiln.trips, total: totalTrips, without_bhadu: sales.trips_without_bhadu },
      bricks: { sold: Number(sales.bricks), to_kiln: Number(kiln.bricks) },
      earned: { bhadu: money(sales.bhadu) },
      costs: { diesel: money(costs.diesel), litres: dec(costs.litres).toFixed(2), upkeep: money(costs.upkeep), loaders: money(loaders.wages) },
      // The driver's monthly salary is not in here yet.
      profit: money(profit),
      profit_per_trip: totalTrips > 0 ? money(profit.dividedBy(totalTrips)) : null,
      fuel: fills,
      warnings: fills.filter((fill) => fill.low_average).map((fill) => ({ code: "low_average", expense_id: fill.id, km_per_litre: fill.km_per_litre })),
    });
  },
);

export default router;
