import { Router } from "express";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { context, created, ok, publicBaseUrl } from "../../utils/http.js";
import { cancelSchema } from "../../utils/schemas.js";
import * as schemas from "./workers.schemas.js";
import * as service from "./workers.service.js";

export const workersRouter = Router({ mergeParams: true });
export const transactionsRouter = Router({ mergeParams: true });

/**
 * The worker's own page. WORKER_LINK_BASE_URL points at the web page once it
 * exists; until then the link opens the API's JSON for that worker.
 */
const shareUrl = (req, token) =>
  `${(process.env.WORKER_LINK_BASE_URL || `${publicBaseUrl(req)}/v1/public/workers`).replace(/\/+$/, "")}/${token}`;

const withUrl = (req, share) => ({ ...share, url: shareUrl(req, share.token) });

// Everyone sees the list; a supervisor gets names only, no balances.
workersRouter.get("/", validate(schemas.listWorkersQuery, "query"), async (req, res) => {
  ok(res, await service.listWorkers(context(req), req.query));
});

workersRouter.post("/", requireRole("munim"), validate(schemas.createWorkerSchema), async (req, res) => {
  created(res, await service.createWorker(context(req), req.body));
});

// A supervisor may open only the worker they are linked to (their own account).
workersRouter.get("/:workerId", idParams("workerId"), async (req, res) => {
  ok(res, await service.getWorker(context(req), req.params.workerId));
});

workersRouter.patch(
  "/:workerId",
  requireRole("munim"),
  idParams("workerId"),
  validate(schemas.updateWorkerSchema),
  async (req, res) => {
    ok(res, await service.updateWorker(context(req), req.params.workerId, req.body));
  },
);

workersRouter.post(
  "/:workerId/leave",
  requireRole("munim"),
  idParams("workerId"),
  validate(schemas.leaveSchema),
  async (req, res) => {
    ok(res, await service.markLeft(context(req), req.params.workerId, req.body.left_on));
  },
);

workersRouter.post("/:workerId/return", requireRole("munim"), idParams("workerId"), async (req, res) => {
  ok(res, await service.markReturned(context(req), req.params.workerId));
});

// What a supervisor sees before giving an advance: the balance, nothing else.
workersRouter.get("/:workerId/balance", idParams("workerId"), async (req, res) => {
  ok(res, await service.getBalance(context(req), req.params.workerId));
});

workersRouter.get(
  "/:workerId/ledger",
  idParams("workerId"),
  validate(schemas.ledgerQuery, "query"),
  async (req, res) => {
    const { rows, pagination, totals, balance } = await service.getLedger(context(req), req.params.workerId, req.query);
    ok(res, rows, 200, { pagination, totals, balance });
  },
);

workersRouter.get("/:workerId/share", requireRole("munim"), idParams("workerId"), async (req, res) => {
  ok(res, withUrl(req, await service.getShare(context(req), req.params.workerId)));
});

workersRouter.post("/:workerId/share/regenerate", requireRole("munim"), idParams("workerId"), async (req, res) => {
  ok(res, withUrl(req, await service.regenerateShare(context(req), req.params.workerId)));
});

workersRouter.patch(
  "/:workerId/share",
  requireRole("munim"),
  idParams("workerId"),
  validate(schemas.shareSchema),
  async (req, res) => {
    ok(res, withUrl(req, await service.setShareEnabled(context(req), req.params.workerId, req.body.enabled)));
  },
);

workersRouter.post(
  "/:workerId/transactions",
  idParams("workerId"),
  validate(schemas.transactionSchema),
  async (req, res) => {
    created(res, await service.addTransaction(context(req), req.params.workerId, req.body));
  },
);

// /worker-transactions/:txnId — editing and cancelling an advance or payment.
transactionsRouter.put(
  "/:txnId",
  idParams("txnId"),
  validate(schemas.updateTransactionSchema),
  async (req, res) => {
    ok(res, await service.updateTransaction(context(req), req.params.txnId, req.body));
  },
);

transactionsRouter.post("/:txnId/cancel", idParams("txnId"), validate(cancelSchema), async (req, res) => {
  ok(res, await service.cancelTransaction(context(req), req.params.txnId, req.body.reason));
});
