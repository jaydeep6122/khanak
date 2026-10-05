import { Router } from "express";
import pool from "../../db/db.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { context, created, ok, paged } from "../../utils/http.js";
import { cancelSchema } from "../../utils/schemas.js";
import * as schemas from "./brick-counts.schemas.js";
import * as service from "./brick-counts.service.js";

// Open to every role: a supervisor enters counts too, and sees and changes
// only their own (the service enforces it).
const router = Router({ mergeParams: true });

router.get("/", validate(schemas.listBrickCountsQuery, "query"), async (req, res) => {
  paged(res, await service.listBrickCounts(context(req), req.query));
});

router.post("/", validate(schemas.brickCountSchema), async (req, res) => {
  created(res, await service.createBrickCount(context(req), req.body));
});

router.get("/:countId", idParams("countId"), async (req, res) => {
  ok(res, await service.getBrickCount(pool, context(req), req.params.countId));
});

router.put("/:countId", idParams("countId"), validate(schemas.brickCountSchema), async (req, res) => {
  ok(res, await service.updateBrickCount(context(req), req.params.countId, req.body));
});

router.post("/:countId/cancel", idParams("countId"), validate(cancelSchema), async (req, res) => {
  ok(res, await service.cancelBrickCount(context(req), req.params.countId, req.body.reason));
});

export default router;
