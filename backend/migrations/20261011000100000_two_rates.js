export const shorthands = undefined;

/**
 * A worker may have both rates, and they need not match: e.g. ₹250 per 1000
 * bricks and ₹300 a day. brick_rate prices their share of brick work (counts,
 * nikasi, loading by the bricks); day_rate prices their days typed in as day
 * work. Everyone but a driver has at least one (checked by the API, so older
 * workers without a rate can still be edited to add one). A driver has a
 * monthly salary and neither rate.
 */
export async function up(pgm) {
  pgm.sql(`
    ALTER TABLE workers
      ADD COLUMN brick_rate numeric(12, 2) CHECK (brick_rate > 0),
      ADD COLUMN day_rate numeric(12, 2) CHECK (day_rate > 0);
    UPDATE workers SET brick_rate = rate WHERE rate_unit = 'per_1000';
    UPDATE workers SET day_rate = rate WHERE rate_unit = 'per_day';
    ALTER TABLE workers
      DROP CONSTRAINT workers_driver_salary,
      DROP CONSTRAINT workers_rate_has_unit,
      DROP COLUMN rate_unit,
      DROP COLUMN rate,
      ADD CONSTRAINT workers_driver_salary
        CHECK (main_work <> 'driver' OR (brick_rate IS NULL AND day_rate IS NULL AND monthly_salary IS NOT NULL));
  `);
}

export async function down(pgm) {
  pgm.sql(`
    ALTER TABLE workers
      DROP CONSTRAINT workers_driver_salary,
      ADD COLUMN rate numeric(12, 2) CHECK (rate > 0),
      ADD COLUMN rate_unit text CHECK (rate_unit IN ('per_1000', 'per_day'));
    UPDATE workers SET rate = brick_rate, rate_unit = 'per_1000' WHERE brick_rate IS NOT NULL;
    UPDATE workers SET rate = day_rate, rate_unit = 'per_day' WHERE brick_rate IS NULL AND day_rate IS NOT NULL;
    ALTER TABLE workers
      DROP COLUMN brick_rate,
      DROP COLUMN day_rate,
      ADD CONSTRAINT workers_rate_has_unit CHECK ((rate IS NULL) = (rate_unit IS NULL)),
      ADD CONSTRAINT workers_driver_salary
        CHECK (main_work <> 'driver' OR (rate IS NULL AND monthly_salary IS NOT NULL));
  `);
}
