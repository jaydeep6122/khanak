const toJson = (value) => (value == null ? null : JSON.stringify(value));

const isRecord = (value) => value != null && typeof value === "object" && !Array.isArray(value);
const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

// Moves on every save, so it would make every edit look like a change.
const IGNORED_KEYS = new Set(["updated_at"]);

/**
 * Only the fields that changed: `{ before: { rate: "550.00" }, after: { rate:
 * "600.00" } }` instead of two copies of the whole record. A list such as a
 * count's worker groups is kept whole on both sides when anything in it changed.
 */
function changes(before, after) {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const was = {};
  const now = {};
  for (const key of keys) {
    if (IGNORED_KEYS.has(key) || same(before[key], after[key])) continue;
    was[key] = before[key] ?? null;
    now[key] = after[key] ?? null;
  }
  return { before: was, after: now };
}

/**
 * What is worth keeping for one action. An edit keeps only what changed. A
 * create keeps nothing: the record itself holds what was created, and each
 * later edit keeps the values it replaced, so any earlier version can be
 * rebuilt. Anything else (a cancel with its reason) is kept as given.
 */
function trimmed(action, before, after) {
  if (isRecord(before) && isRecord(after)) return changes(before, after);
  if (action === "create") return { before, after: null };
  return { before, after };
}

/** Appends one audit_log row inside the caller's transaction. */
export async function audit(
  client,
  { factoryId = null, userId = null, action, entityType, entityId = null, before = null, after = null },
) {
  const kept = trimmed(action, before, after);
  await client.query(
    `INSERT INTO audit_log (factory_id, user_id, action, entity_type, entity_id, before, after)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [factoryId, userId, action, entityType, entityId, toJson(kept.before), toJson(kept.after)],
  );
}
