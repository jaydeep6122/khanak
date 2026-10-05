export const shorthands = undefined;

/**
 * A factory may run more than one kiln (bhatho). Bricks going in are counted
 * into one kiln and nikasi takes them out of one, so each kiln's stock is
 * known. Every factory gets "Bhatho 1"; what was entered before kilns
 * existed goes into it.
 */
export async function up(pgm) {
  pgm.sql(`
    CREATE TABLE kilns (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      name       text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
      is_active  boolean NOT NULL DEFAULT true,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id)
    );
    CREATE UNIQUE INDEX kilns_name_unique ON kilns (factory_id, lower(name));
    ALTER TABLE kilns ENABLE ROW LEVEL SECURITY;
    CREATE TRIGGER kilns_set_updated_at BEFORE UPDATE ON kilns
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();

    INSERT INTO kilns (factory_id, name) SELECT id, 'Bhatho 1' FROM factories;

    ALTER TABLE brick_counts ADD COLUMN kiln_id uuid;
    ALTER TABLE kiln_unloadings ADD COLUMN kiln_id uuid;
    ALTER TABLE brick_movements ADD COLUMN kiln_id uuid;

    UPDATE brick_counts c SET kiln_id = k.id
    FROM kilns k
    WHERE k.factory_id = c.factory_id AND c.reason IN ('kiln_by_workers', 'kiln_by_truck');
    UPDATE kiln_unloadings u SET kiln_id = k.id FROM kilns k WHERE k.factory_id = u.factory_id;
    UPDATE brick_movements m SET kiln_id = k.id
    FROM kilns k
    WHERE k.factory_id = m.factory_id AND m.stage = 'kiln';

    ALTER TABLE brick_counts
      ADD CONSTRAINT brick_counts_kiln_fkey FOREIGN KEY (factory_id, kiln_id) REFERENCES kilns (factory_id, id),
      ADD CONSTRAINT brick_counts_kiln_only_into_kiln
        CHECK ((reason IN ('kiln_by_workers', 'kiln_by_truck')) = (kiln_id IS NOT NULL));
    ALTER TABLE kiln_unloadings
      ALTER COLUMN kiln_id SET NOT NULL,
      ADD CONSTRAINT kiln_unloadings_kiln_fkey FOREIGN KEY (factory_id, kiln_id) REFERENCES kilns (factory_id, id);
    ALTER TABLE brick_movements
      ADD CONSTRAINT brick_movements_kiln_fkey FOREIGN KEY (factory_id, kiln_id) REFERENCES kilns (factory_id, id),
      ADD CONSTRAINT brick_movements_kiln_stage CHECK ((stage = 'kiln') = (kiln_id IS NOT NULL));
    CREATE INDEX brick_movements_kiln_idx ON brick_movements (kiln_id) WHERE kiln_id IS NOT NULL;
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DROP INDEX brick_movements_kiln_idx;
    ALTER TABLE brick_movements DROP CONSTRAINT brick_movements_kiln_stage, DROP CONSTRAINT brick_movements_kiln_fkey, DROP COLUMN kiln_id;
    ALTER TABLE kiln_unloadings DROP CONSTRAINT kiln_unloadings_kiln_fkey, DROP COLUMN kiln_id;
    ALTER TABLE brick_counts DROP CONSTRAINT brick_counts_kiln_only_into_kiln, DROP CONSTRAINT brick_counts_kiln_fkey, DROP COLUMN kiln_id;
    DROP TABLE kilns;
  `);
}
