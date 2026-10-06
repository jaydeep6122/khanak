export const shorthands = undefined;

/**
 * The owner asked for one rate per worker, set when the worker is added: per
 * 1000 bricks, or per day. There are no group rates for brick work any more
 * (no drying or loading rate): molding, kiln loading, stacking and nikasi are
 * per_1000 kinds of work with no rate of their own (rate NULL), paid at each
 * worker's own rate. A group's bricks are shared equally, and each worker is
 * paid their share at their own rate. Loading a vehicle at a sale keeps its
 * rate per trip. A driver keeps a monthly salary.
 *
 * Existing rates carry over: a molder's rate per 1000 stays, a day rate stays
 * per day, and a bharai, khadkaniyo or nikasi worker without a rate of their
 * own takes their group's rate (stacking per lakh becomes per 1000). Past
 * entries of brick work are written the new way too (each worker's share of
 * the bricks, stacking per 1000), with the same amounts.
 */
export async function up(pgm) {
  pgm.sql(`
    ALTER TABLE workers
      DROP CONSTRAINT workers_rate_only_for_own_pay,
      DROP CONSTRAINT workers_own_pay_required,
      ADD COLUMN rate_unit text CHECK (rate_unit IN ('per_1000', 'per_day'));

    UPDATE workers SET rate_unit = 'per_1000' WHERE main_work = 'molder' AND rate IS NOT NULL;
    UPDATE workers SET rate_unit = 'per_day' WHERE rate IS NOT NULL AND rate_unit IS NULL;
    UPDATE workers w SET rate_unit = 'per_1000',
      rate = round(CASE t.pay_unit WHEN 'per_lakh' THEN t.rate / 100 ELSE t.rate END, 2)
    FROM work_types t
    WHERE w.rate IS NULL AND t.factory_id = w.factory_id AND t.rate > 0
      AND t.code = CASE w.main_work WHEN 'loader' THEN 'kiln_loading' WHEN 'stacker' THEN 'stacking'
                                    WHEN 'unloader' THEN 'unloading' WHEN 'molder' THEN 'molding' END;
    UPDATE workers SET rate = NULL, rate_unit = NULL WHERE rate = 0;

    ALTER TABLE workers
      ADD CONSTRAINT workers_rate_has_unit CHECK ((rate IS NULL) = (rate_unit IS NULL)),
      ADD CONSTRAINT workers_driver_salary
        CHECK (main_work <> 'driver' OR (rate IS NULL AND monthly_salary IS NOT NULL));

    UPDATE work_entries e
    SET rate = CASE t.pay_unit WHEN 'per_lakh' THEN round(e.rate / 100, 2) ELSE e.rate END,
        quantity = CASE WHEN e.group_size IS NULL THEN e.quantity ELSE round(e.quantity / e.group_size, 3) END
    FROM work_types t
    WHERE t.id = e.work_type_id AND t.code IN ('molding', 'kiln_loading', 'stacking', 'unloading');

    ALTER TABLE work_types DROP CONSTRAINT work_types_check;
    UPDATE work_types SET pay_unit = 'per_1000', rate = NULL
    WHERE code IN ('molding', 'kiln_loading', 'stacking', 'unloading');
    -- A kind per 1000 bricks with no rate of its own is paid at each worker's
    -- own rate; every other kind paid by a rate has one.
    ALTER TABLE work_types
      ADD CONSTRAINT work_types_check CHECK (
        CASE WHEN pay_unit IN ('lumpsum', 'per_month') THEN rate IS NULL
             ELSE rate IS NOT NULL OR pay_unit = 'per_1000' END
      );
  `);
}

export async function down(pgm) {
  pgm.sql(`
    ALTER TABLE work_types DROP CONSTRAINT work_types_check;
    UPDATE work_entries e
    SET rate = CASE t.code WHEN 'stacking' THEN e.rate * 100 ELSE e.rate END,
        quantity = CASE WHEN e.group_size IS NULL THEN e.quantity ELSE e.quantity * e.group_size END
    FROM work_types t
    WHERE t.id = e.work_type_id AND t.code IN ('molding', 'kiln_loading', 'stacking', 'unloading');
    UPDATE work_types SET pay_unit = CASE code WHEN 'stacking' THEN 'per_lakh' ELSE 'per_1000' END, rate = 0
    WHERE rate IS NULL AND pay_unit = 'per_1000';
    ALTER TABLE work_types
      ADD CONSTRAINT work_types_check CHECK ((pay_unit IN ('lumpsum', 'per_month')) = (rate IS NULL));

    ALTER TABLE workers
      DROP CONSTRAINT workers_driver_salary,
      DROP CONSTRAINT workers_rate_has_unit;
    UPDATE workers SET rate = NULL
    WHERE main_work NOT IN ('molder', 'daily', 'loader', 'unloader')
       OR (main_work IN ('loader', 'unloader') AND rate_unit = 'per_1000');
    ALTER TABLE workers DROP COLUMN rate_unit;
    UPDATE workers SET rate = 1 WHERE main_work IN ('molder', 'daily') AND rate IS NULL;
    ALTER TABLE workers
      ADD CONSTRAINT workers_rate_only_for_own_pay
        CHECK (rate IS NULL OR main_work IN ('molder', 'daily', 'loader', 'unloader')),
      ADD CONSTRAINT workers_own_pay_required
        CHECK ((main_work NOT IN ('molder', 'daily') OR rate IS NOT NULL)
               AND (main_work <> 'driver' OR monthly_salary IS NOT NULL));
  `);
}
