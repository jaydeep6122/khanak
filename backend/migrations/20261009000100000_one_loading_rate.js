export const shorthands = undefined;

/**
 * The owner asked for one loading rate, not two: carrying bricks to dry is
 * paid like loading the kiln, at the rate set when a bharai worker is added.
 * "Carrying to drying" goes; whatever it paid is kept as kiln loading, and
 * its rate is taken over where kiln loading had none.
 *
 * And a bharai or nikasi worker may be paid by the day instead of the
 * group's rate per 1000: their own rate is then a day rate. Such a worker is
 * not picked for group work; their days are typed in as day work.
 */
export async function up(pgm) {
  pgm.sql(`
    UPDATE work_types k SET rate = d.rate
    FROM work_types d
    WHERE d.factory_id = k.factory_id AND d.code = 'drying_carry' AND k.code = 'kiln_loading'
      AND (k.rate IS NULL OR k.rate = 0) AND d.rate > 0;
    UPDATE work_entries e SET work_type_id = k.id
    FROM work_types d
    JOIN work_types k ON k.factory_id = d.factory_id AND k.code = 'kiln_loading'
    WHERE e.work_type_id = d.id AND d.code = 'drying_carry';
    DELETE FROM work_types WHERE code = 'drying_carry';

    ALTER TABLE work_types DROP CONSTRAINT work_types_code_check;
    ALTER TABLE work_types ADD CONSTRAINT work_types_code_check
      CHECK (code IN ('molding', 'kiln_loading', 'stacking', 'truck_loading',
                      'unloading', 'daily', 'salary', 'lumpsum'));

    ALTER TABLE workers DROP CONSTRAINT workers_rate_only_for_own_pay;
    ALTER TABLE workers ADD CONSTRAINT workers_rate_only_for_own_pay
      CHECK (rate IS NULL OR main_work IN ('molder', 'daily', 'loader', 'unloader'));
  `);
}

export async function down(pgm) {
  pgm.sql(`
    UPDATE workers SET rate = NULL WHERE main_work IN ('loader', 'unloader');
    ALTER TABLE workers DROP CONSTRAINT workers_rate_only_for_own_pay;
    ALTER TABLE workers ADD CONSTRAINT workers_rate_only_for_own_pay
      CHECK (rate IS NULL OR main_work IN ('molder', 'daily'));

    ALTER TABLE work_types DROP CONSTRAINT work_types_code_check;
    ALTER TABLE work_types ADD CONSTRAINT work_types_code_check
      CHECK (code IN ('molding', 'drying_carry', 'kiln_loading', 'stacking', 'truck_loading',
                      'unloading', 'daily', 'salary', 'lumpsum'));
    INSERT INTO work_types (factory_id, code, name, pay_unit, rate, is_group, sort_order)
    SELECT k.factory_id, 'drying_carry', 'Carrying to drying', 'per_1000', k.rate, true, k.sort_order
    FROM work_types k
    WHERE k.code = 'kiln_loading'
      AND NOT EXISTS (SELECT 1 FROM work_types t WHERE t.factory_id = k.factory_id AND lower(t.name) = 'carrying to drying');
  `);
}
