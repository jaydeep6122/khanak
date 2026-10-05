import "dotenv/config"; // MUST be first
import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { errorHandler, notFoundHandler } from "./middlewares/error.middlewares.js";
import { maintenanceGate } from "./middlewares/maintenance.middlewares.js";
import appRouter from "./v1/app/app.routes.js";
import authRouter from "./v1/auth/auth.routes.js";
import factoriesRouter from "./v1/factories/factories.routes.js";
import publicRouter from "./v1/public/public.routes.js";
import pool from "./db/db.js";

const app = express();

// Requests arrive through the hosting provider's proxy. Without this every
// client shares the proxy's IP, and so a single rate-limit bucket.
app.set("trust proxy", 1);

app.use(helmet());

// The mobile app sends no Origin header, so CORS only affects browsers (the
// worker's page). CORS_ORIGINS is a comma-separated allowlist; without it any
// origin may call the API, but never with credentials.
const corsOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(
  cors(
    corsOrigins.length > 0
      ? { origin: corsOrigins, credentials: true }
      : { origin: "*" },
  ),
);

if (process.env.NODE_ENV !== "test") {
  app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));
}

const isHealthCheck = (req) => req.path === "/" || req.path === "/health";
// The test suite makes hundreds of requests from one address.
const isTestRun = () => process.env.NODE_ENV === "test";

const tooMany = (message) => ({ success: false, statusCode: 429, message });

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 1000,
    message: tooMany("Too many requests, please try again later"),
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) => isTestRun() || isHealthCheck(req),
  }),
);

// Password guessing gets a much smaller budget than normal API use.
app.use(
  ["/v1/auth/login", "/v1/auth/signup", "/v1/auth/password/forgot", "/v1/auth/password/reset"],
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    message: tooMany("Too many attempts, please try again after 15 minutes"),
    standardHeaders: true,
    legacyHeaders: false,
    skip: isTestRun,
  }),
);

// Worker links are unguessable, but trying many is still cut short.
app.use(
  "/v1/public",
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 120,
    message: tooMany("Too many requests, please try again later"),
    standardHeaders: true,
    legacyHeaders: false,
    skip: isTestRun,
  }),
);

app.use(express.json({ limit: "200kb" }));

// Pinged by the keep-alive cron (only match root path)
app.get("/", (req, res) => {
  res.status(200).json({ message: "Khanak API" });
});

// Health check that also proves the database is reachable
app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.status(200).json({ status: "ok", database: "ok" });
  } catch {
    res.status(503).json({ status: "error", database: "unreachable" });
  }
});

// Unauthenticated: which app builds may still be used.
app.use("/v1/app", appRouter);
// Everything after this is refused while MAINTENANCE_MODE is "true".
app.use("/v1", maintenanceGate);
app.use("/v1/auth", authRouter);
app.use("/v1/factories", factoriesRouter);
// Unauthenticated: workers' own links only.
app.use("/v1/public", publicRouter);

// 404 and error handling middleware MUST be registered last
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
