export const shorthands = undefined;

/**
 * A user may delete their own account. The row stays, because entries and the
 * audit log point at it, but their name, email and phone are wiped and it can
 * never sign in again. deleted_at marks such a row.
 */
export async function up(pgm) {
  pgm.sql(`ALTER TABLE users ADD COLUMN deleted_at timestamptz;`);
}

export async function down(pgm) {
  pgm.sql(`ALTER TABLE users DROP COLUMN deleted_at;`);
}
