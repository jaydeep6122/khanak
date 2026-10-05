/** Every successful response is `{ success: true, data, ...extra }`. */
export const ok = (res, data, status = 200, extra = {}) =>
  res.status(status).json({ success: true, data, ...extra });

export const created = (res, data) => ok(res, data, 201);

export const paged = (res, { rows, pagination }) =>
  ok(res, rows, 200, { pagination });

/** Base URL for links sent to people outside the app. */
export const publicBaseUrl = (req) =>
  (process.env.PUBLIC_BASE_URL || `${req.protocol}://${req.get("host")}`).replace(/\/+$/, "");

/** What services need to know about the caller and the factory. */
export const context = (req) => ({
  factory: req.factory,
  user: req.user,
  role: req.role,
  member: req.member,
});
