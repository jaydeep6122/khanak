import { Router } from "express";
import pool from "../../db/db.js";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { context, created, ok, paged } from "../../utils/http.js";
import { cancelSchema } from "../../utils/schemas.js";
import * as schemas from "./sales.schemas.js";
import * as service from "./sales.service.js";

// Selling fired bricks. Owner and munim only.
const router = Router({ mergeParams: true });
router.use(requireRole("munim"));

router.get("/", validate(schemas.listSalesQuery, "query"), async (req, res) => {
  paged(res, await service.listSales(context(req), req.query));
});

// The rate to start a new sale with: the customer's last, or the last sale's.
router.get("/last-rate", validate(schemas.lastRateQuery, "query"), async (req, res) => {
  ok(res, await service.lastRate(context(req), req.query.party_id));
});

router.post("/", validate(schemas.saleSchema), async (req, res) => {
  created(res, await service.createSale(context(req), req.body));
});

router.get("/:saleId", idParams("saleId"), async (req, res) => {
  ok(res, await service.getSale(pool, context(req), req.params.saleId));
});

router.put("/:saleId", idParams("saleId"), validate(schemas.saleSchema), async (req, res) => {
  ok(res, await service.updateSale(context(req), req.params.saleId, req.body));
});

router.post("/:saleId/cancel", idParams("saleId"), validate(cancelSchema), async (req, res) => {
  ok(res, await service.cancelSale(context(req), req.params.saleId, req.body.reason));
});

export default router;
