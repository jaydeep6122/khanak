export const shorthands = undefined;

/**
 * What a worker mainly does, so each form lists the right people first:
 * molder (pathera), loader (bharai), stacker (khadkaniyo), unloader
 * (nikasi), driver, daily (roj) or other. Pay still comes from the work in
 * each entry, so a loader who stacks one day is paid for stacking.
 *
 * rate is each worker's own rate, since no two molders are paid alike: per
 * 1000 bricks for a molder, per day for day work, and required for both.
 * A driver must have a monthly salary. Group work is one total shared by
 * the group, so loaders, khadkaniya and unloaders are paid the group's rate.
 */
export async function up(pgm) {
  pgm.sql(`
    ALTER TABLE workers
      ADD COLUMN main_work text NOT NULL DEFAULT 'other'
        CHECK (main_work IN ('molder', 'loader', 'stacker', 'unloader', 'driver', 'daily', 'other')),
      ADD COLUMN rate numeric(12, 2) CHECK (rate > 0),
      ADD CONSTRAINT workers_rate_only_for_own_pay
        CHECK (rate IS NULL OR main_work IN ('molder', 'daily')),
      ADD CONSTRAINT workers_own_pay_required
        CHECK ((main_work NOT IN ('molder', 'daily') OR rate IS NOT NULL)
               AND (main_work <> 'driver' OR monthly_salary IS NOT NULL));
    CREATE INDEX workers_factory_main_work_idx ON workers (factory_id, main_work);
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DROP INDEX workers_factory_main_work_idx;
    ALTER TABLE workers
      DROP CONSTRAINT workers_own_pay_required,
      DROP CONSTRAINT workers_rate_only_for_own_pay,
      DROP COLUMN rate,
      DROP COLUMN main_work;
  `);
}
