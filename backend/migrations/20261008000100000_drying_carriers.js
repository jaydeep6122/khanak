export const shorthands = undefined;

/**
 * Bricks reach the drying ground the same way they reach a kiln: carried by
 * workers or by truck, and whoever carries them is paid. A drying count now
 * says which ("drying_by_workers" / "drying_by_truck", like the kiln's two),
 * and every factory gets a kind of work for it, "Carrying to drying", paid
 * per 1000 bricks and shared by the group. Drying counts made before this
 * were carried by workers.
 */
export async function up(pgm) {
  pgm.sql(`
    ALTER TABLE brick_counts
      DROP CONSTRAINT brick_counts_reason_check,
      DROP CONSTRAINT brick_counts_check2;
    UPDATE brick_counts SET reason = 'drying_by_workers' WHERE reason = 'drying';
    ALTER TABLE brick_counts
      ADD CONSTRAINT brick_counts_reason_check
        CHECK (reason IN ('drying_by_workers', 'drying_by_truck', 'kiln_by_workers', 'kiln_by_truck', 'final')),
      ADD CONSTRAINT brick_counts_truck_only_by_truck
        CHECK (reason IN ('drying_by_truck', 'kiln_by_truck') OR (truck_id IS NULL AND trips IS NULL));

    ALTER TABLE work_types DROP CONSTRAINT work_types_code_check;
    ALTER TABLE work_types ADD CONSTRAINT work_types_code_check
      CHECK (code IN ('molding', 'drying_carry', 'kiln_loading', 'stacking', 'truck_loading',
                      'unloading', 'daily', 'salary', 'lumpsum'));
    -- A kind left behind by an earlier down migration is taken back as is.
    UPDATE work_types SET code = 'drying_carry'
    WHERE code IS NULL AND lower(name) = 'carrying to drying' AND pay_unit = 'per_1000' AND is_group;
    INSERT INTO work_types (factory_id, code, name, pay_unit, rate, is_group, sort_order)
    SELECT f.id, 'drying_carry', 'Carrying to drying', 'per_1000', 0, true,
           COALESCE((SELECT max(sort_order) FROM work_types t WHERE t.factory_id = f.id), 0) + 1
    FROM factories f
    WHERE NOT EXISTS (SELECT 1 FROM work_types t WHERE t.factory_id = f.id AND t.code = 'drying_carry');
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DELETE FROM work_types WHERE code = 'drying_carry'
      AND NOT EXISTS (SELECT 1 FROM work_entries e WHERE e.work_type_id = work_types.id);
    -- One already paid for stays as the owner's own kind of work.
    UPDATE work_types SET code = NULL WHERE code = 'drying_carry';
    ALTER TABLE work_types DROP CONSTRAINT work_types_code_check;
    ALTER TABLE work_types ADD CONSTRAINT work_types_code_check
      CHECK (code IN ('molding', 'kiln_loading', 'stacking', 'truck_loading',
                      'unloading', 'daily', 'salary', 'lumpsum'));

    ALTER TABLE brick_counts
      DROP CONSTRAINT brick_counts_truck_only_by_truck,
      DROP CONSTRAINT brick_counts_reason_check;
    UPDATE brick_counts SET reason = 'drying', truck_id = NULL, trips = NULL
    WHERE reason IN ('drying_by_workers', 'drying_by_truck');
    ALTER TABLE brick_counts
      ADD CONSTRAINT brick_counts_reason_check CHECK (reason IN ('drying', 'kiln_by_workers', 'kiln_by_truck', 'final')),
      ADD CONSTRAINT brick_counts_check2 CHECK (reason = 'kiln_by_truck' OR (truck_id IS NULL AND trips IS NULL));
  `);
}
