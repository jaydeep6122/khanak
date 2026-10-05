export const shorthands = undefined;

/**
 * Supabase publishes every table in the public schema through its own REST
 * API, reachable with the project's anon key. Khanak never uses that API: the
 * Node backend is the only way in. So every table gets row level security
 * with no policies (closed to the anon and authenticated roles; the backend
 * connects as the owner, which RLS does not apply to), those roles lose their
 * grants, and the ledger view runs with the caller's rights instead of its
 * owner's. Any table added later must also `ENABLE ROW LEVEL SECURITY`.
 *
 * Outside Supabase the anon and authenticated roles do not exist and only the
 * RLS part has an effect.
 */
export async function up(pgm) {
  pgm.sql(`
    DO $$
    DECLARE
      t record;
    BEGIN
      FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = current_schema() LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t.tablename);
      END LOOP;

      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon';
        EXECUTE 'REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon';
        EXECUTE 'REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon';
      END IF;
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated';
        EXECUTE 'REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated';
        EXECUTE 'REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated';
      END IF;
    END
    $$;

    ALTER VIEW worker_ledger SET (security_invoker = true);
  `);
}

export async function down(pgm) {
  pgm.sql(`
    ALTER VIEW worker_ledger RESET (security_invoker);

    DO $$
    DECLARE
      t record;
    BEGIN
      FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = current_schema() LOOP
        EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t.tablename);
      END LOOP;
    END
    $$;
  `);
}
