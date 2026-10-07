import pool from "../db/db.js";
import { assertWritable } from "../services/subscriptions.js";
import { ApiError } from "../utils/ApiError.js";
import { verifyAccessToken } from "../services/tokens.js";

/**
 * owner: everything. munim: every entry and report, but not members, rates
 * or write-offs. supervisor: brick counts, unloadings and advances only.
 */
export const ROLE_RANK = { supervisor: 1, munim: 2, owner: 3 };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function requireAuth(req, res, next) {
  const [scheme, token] = (req.headers.authorization || "").split(" ");
  if (scheme !== "Bearer" || !token) {
    throw new ApiError(401, "Authorization token is required");
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (error) {
    throw new ApiError(
      401,
      error.name === "TokenExpiredError" ? "Access token expired" : "Invalid access token",
    );
  }

  const {
    rows: [user],
  } = await pool.query(
    "SELECT id, name, email, phone, is_active, deleted_at FROM users WHERE id = $1",
    [payload.sub],
  );
  // A deleted account is signed out, not shown as suspended.
  if (!user || user.deleted_at) throw new ApiError(401, "Invalid access token");
  if (!user.is_active) throw new ApiError(403, "User account is suspended");

  req.user = user;
  next();
}

/**
 * Loads `:factoryId` for an active member. Non-members get 404, not 403, so
 * factory ids cannot be probed.
 */
export async function loadFactory(req, res, next) {
  const { factoryId } = req.params;
  if (!UUID_RE.test(factoryId)) throw new ApiError(404, "Factory not found");

  const {
    rows: [row],
  } = await pool.query(
    `SELECT f.*, m.role, m.worker_id AS member_worker_id
     FROM factories f
     JOIN factory_members m
       ON m.factory_id = f.id AND m.user_id = $2 AND m.status = 'active'
     WHERE f.id = $1 AND f.archived_at IS NULL`,
    [factoryId.toLowerCase(), req.user.id],
  );
  if (!row) throw new ApiError(404, "Factory not found");

  const { role, member_worker_id, ...factory } = row;
  req.factory = factory;
  req.role = role;
  req.member = { worker_id: member_worker_id };
  next();
}

/** owner > munim > supervisor */
export const hasRole = (role, minimum) => ROLE_RANK[role] >= ROLE_RANK[minimum];

export const requireRole = (minimum) => (req, res, next) => {
  if (!hasRole(req.role, minimum)) {
    throw new ApiError(403, `This action needs the ${minimum} role or higher`);
  }
  next();
};

/** Every change to a factory's data needs a running subscription; reads never do. */
export async function requireWritable(req, res, next) {
  if (req.method !== "GET" && req.method !== "HEAD") {
    await assertWritable(pool, req.factory.id);
  }
  next();
}
