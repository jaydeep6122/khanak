import { Router } from "express";
import { z } from "zod";
import { validate } from "../../middlewares/validation.middlewares.js";
import { ok, publicBaseUrl } from "../../utils/http.js";
import { supportWhatsApp } from "../../legal/legal.routes.js";
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

// Unauthenticated: where to get help, and the terms and privacy pages, so
// the number can change without a new app release.
router.get("/support", (req, res) => {
  const legal = `${publicBaseUrl(req)}/legal`;
  ok(res, {
    whatsapp: supportWhatsApp(),
    terms_url: `${legal}/terms`,
    privacy_url: `${legal}/privacy`,
    delete_account_url: `${legal}/delete-account`,
  });
});

export default router;
