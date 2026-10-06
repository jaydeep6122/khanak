import { Router } from "express";
import { requireRole } from "../../middlewares/auth.middlewares.js";
import { idParams } from "../../middlewares/params.middlewares.js";
import { validate } from "../../middlewares/validation.middlewares.js";
import { context, created, ok } from "../../utils/http.js";
import { cancelSchema } from "../../utils/schemas.js";
import * as schemas from "./parties.schemas.js";
import * as service from "./parties.service.js";

// Customers and suppliers, and money received from or paid to them. Owner
// and munim only: a supervisor never sees sales, purchases or credit.
export const partiesRouter = Router({ mergeParams: true });
export const partyPaymentsRouter = Router({ mergeParams: true });
partiesRouter.use(requireRole("munim"));
partyPaymentsRouter.use(requireRole("munim"));

partiesRouter.get("/", validate(schemas.listPartiesQuery, "query"), async (req, res) => {
  ok(res, await service.listParties(context(req), req.query));
});

partiesRouter.post("/", validate(schemas.createPartySchema), async (req, res) => {
  created(res, await service.createParty(context(req), req.body));
});

partiesRouter.get("/:partyId", idParams("partyId"), async (req, res) => {
  ok(res, await service.getParty(context(req), req.params.partyId));
});

partiesRouter.patch("/:partyId", idParams("partyId"), validate(schemas.updatePartySchema), async (req, res) => {
  ok(res, await service.updateParty(context(req), req.params.partyId, req.body));
});

partiesRouter.get("/:partyId/ledger", idParams("partyId"), validate(schemas.ledgerQuery, "query"), async (req, res) => {
  const { rows, pagination, balance } = await service.partyLedger(context(req), req.params.partyId, req.query);
  ok(res, rows, 200, { pagination, balance });
});

partiesRouter.post("/:partyId/payments", idParams("partyId"), validate(schemas.paymentSchema), async (req, res) => {
  created(res, await service.addPayment(context(req), req.params.partyId, req.body));
});

// /party-payments/:paymentId — editing and cancelling money received or paid.
partyPaymentsRouter.put("/:paymentId", idParams("paymentId"), validate(schemas.updatePaymentSchema), async (req, res) => {
  ok(res, await service.updatePayment(context(req), req.params.paymentId, req.body));
});

partyPaymentsRouter.post("/:paymentId/cancel", idParams("paymentId"), validate(cancelSchema), async (req, res) => {
  ok(res, await service.cancelPayment(context(req), req.params.paymentId, req.body.reason));
});
