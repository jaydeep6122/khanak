import { Router } from "express";
import pool from "../../db/db.js";
import { loadFactory, requireAuth, requireRole, requireWritable } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { context, created, ok } from "../../utils/http.js";
import brickCountsRouter from "../brick-counts/brick-counts.routes.js";
import cashRouter from "../cash/cash.routes.js";
import kilnUnloadingsRouter from "../kiln-unloadings/kiln-unloadings.routes.js";
import kilnsRouter from "../kilns/kilns.routes.js";
import periodsRouter from "../periods/periods.routes.js";
import reportsRouter from "../reports/reports.routes.js";
import trucksRouter from "../trucks/trucks.routes.js";
import workEntriesRouter from "../work-entries/work-entries.routes.js";
import workTypesRouter from "../work-types/work-types.routes.js";
import { transactionsRouter, workersRouter } from "../workers/workers.routes.js";
import * as schemas from "./factories.schemas.js";
import * as service from "./factories.service.js";

const router = Router();
router.use(requireAuth);

router.post("/", validate(schemas.createFactorySchema), async (req, res) => {
  created(res, await service.createFactory(req.user, req.body));
});

router.get("/", async (req, res) => {
  ok(res, await service.listFactories(req.user.id));
});

// Everything below acts on one factory the caller is an active member of.
// Without a running subscription it can still be read, but not changed.
const factory = Router({ mergeParams: true });
router.use("/:factoryId", loadFactory, requireWritable, factory);

factory.get("/", async (req, res) => {
  ok(res, await service.factoryView(pool, req.factory.id, { role: req.role, workerId: req.member.worker_id }));
});

factory.patch("/", requireRole("owner"), validate(schemas.updateFactorySchema), async (req, res) => {
  ok(res, await service.updateFactory(context(req), req.body));
});

factory.delete("/", requireRole("owner"), async (req, res) => {
  await service.archiveFactory(context(req));
  ok(res, { archived: true });
});

factory.get("/members", requireRole("munim"), async (req, res) => {
  ok(res, await service.listMembers(context(req)));
});

factory.post("/members", requireRole("owner"), validate(schemas.addMemberSchema), async (req, res) => {
  created(res, await service.addMember(context(req), req.body));
});

factory.patch(
  "/members/:userId",
  requireRole("owner"),
  idParams("userId"),
  validate(schemas.updateMemberSchema),
  async (req, res) => {
    ok(res, await service.updateMember(context(req), req.params.userId, req.body));
  },
);

factory.delete("/members/:userId", requireRole("owner"), idParams("userId"), async (req, res) => {
  await service.removeMember(context(req), req.params.userId);
  ok(res, { removed: true });
});

factory.get("/subscription", requireRole("owner"), async (req, res) => {
  ok(res, await service.subscriptionHistory(context(req)));
});

factory.use("/periods", periodsRouter);
factory.use("/work-types", workTypesRouter);
factory.use("/workers", workersRouter);
factory.use("/worker-transactions", transactionsRouter);
factory.use("/work-entries", workEntriesRouter);
factory.use("/brick-counts", brickCountsRouter);
factory.use("/kiln-unloadings", kilnUnloadingsRouter);
factory.use("/trucks", trucksRouter);
factory.use("/kilns", kilnsRouter);
factory.use("/cash", cashRouter);
factory.use("/reports", reportsRouter);

export default router;
