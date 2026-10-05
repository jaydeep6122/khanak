import { Router } from "express";
import { z } from "zod";
import { validate } from "../../middlewares/validation.middlewares.js";
import { ok } from "../../utils/http.js";
import { underMaintenance } from "../../middlewares/maintenance.middlewares.js";

// Read on every request so raising a minimum only needs the environment
// changed, not a new release of the API.
const minBuild = () => {
  const value = Number.parseInt(process.env.MIN_APP_BUILD_ANDROID ?? "", 10);
  return Number.isFinite(value) && value > 0 ? value : 0;
};

const router = Router();

// Unauthenticated: the app asks before anyone signs in. Builds below
// min_build must update before they can be used; while maintenance is on,
// no build can be used. Still answered during maintenance, so the app can
// tell when it is over. Khanak is Android only.
router.get(
  "/version",
  validate(z.object({ platform: z.literal("android") }), "query"),
  (req, res) => {
    ok(res, {
      platform: "android",
      min_build: minBuild(),
      maintenance: underMaintenance(),
      store_url: process.env.APP_STORE_URL_ANDROID || null,
    });
  },
);

export default router;
