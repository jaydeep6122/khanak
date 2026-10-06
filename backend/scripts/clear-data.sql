-- Empties every factory and everything entered in them, keeping the people:
-- accounts (users), their sign-ins (refresh_tokens, password_resets), the
-- subscription plans and the migration history stay. After this, everyone
-- signs in as before and creates their factory again.
--
-- This cannot be undone. Run it only on purpose, against the database you
-- mean:
--   psql "$DATABASE_URL" -f scripts/clear-data.sql
BEGIN;

TRUNCATE
  audit_log,
  brick_movements,
  work_entries,
  worker_transactions,
  cash_handovers,
  party_payments,
  sales,
  expenses,
  parties,
  brick_counts,
  kiln_unloadings,
  workers,
  work_types,
  trucks,
  kilns,
  periods,
  subscriptions,
  factory_members,
  factories;

-- What is left, to check before it is kept.
SELECT
  (SELECT count(*) FROM users) AS users,
  (SELECT count(*) FROM plans) AS plans,
  (SELECT count(*) FROM factories) AS factories,
  (SELECT count(*) FROM workers) AS workers;

COMMIT;
