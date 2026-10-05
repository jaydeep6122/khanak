import jwt from "jsonwebtoken";
import { createHash, randomBytes, randomUUID } from "node:crypto";

export const TOKEN_ISSUER = "khanak";
const ACCESS_TOKEN_SECONDS = 15 * 60;
const REFRESH_TOKEN_DAYS = 30;
const ACCESS_AUDIENCE = "access";

export const signAccessToken = (userId) =>
  jwt.sign({}, process.env.JWT_SECRET, {
    subject: userId,
    issuer: TOKEN_ISSUER,
    audience: ACCESS_AUDIENCE,
    expiresIn: ACCESS_TOKEN_SECONDS,
    algorithm: "HS256",
  });

export const verifyAccessToken = (token) =>
  jwt.verify(token, process.env.JWT_SECRET, {
    algorithms: ["HS256"],
    issuer: TOKEN_ISSUER,
    audience: ACCESS_AUDIENCE,
  });

/** Refresh tokens are opaque random strings; only their SHA-256 is stored. */
export const hashToken = (token) =>
  createHash("sha256").update(token).digest("hex");

/** The secret in a worker's own link: 24 URL-safe characters, unguessable. */
export const newShareToken = () => randomBytes(18).toString("base64url");

export async function issueRefreshToken(db, { userId, familyId, deviceInfo }) {
  const token = randomBytes(32).toString("base64url");
  const {
    rows: [row],
  } = await db.query(
    `INSERT INTO refresh_tokens (user_id, family_id, token_hash, device_info, expires_at)
     VALUES ($1, $2, $3, $4, now() + make_interval(days => $5))
     RETURNING id`,
    [
      userId,
      familyId ?? randomUUID(),
      hashToken(token),
      deviceInfo ?? null,
      REFRESH_TOKEN_DAYS,
    ],
  );
  return { token, id: row.id };
}

export function sessionPayload(userId, refreshToken) {
  return {
    access_token: signAccessToken(userId),
    refresh_token: refreshToken,
    token_type: "Bearer",
    expires_in: ACCESS_TOKEN_SECONDS,
  };
}
