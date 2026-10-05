export const shorthands = undefined;

const updatedAt = (...tables) =>
  tables
    .map(
      (table) =>
        `CREATE TRIGGER ${table}_set_updated_at BEFORE UPDATE ON ${table}
         FOR EACH ROW EXECUTE FUNCTION set_updated_at();`,
    )
    .join("\n");

export async function up(pgm) {
  pgm.sql(`
    CREATE TABLE users (
      id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name          text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 255),
      email         citext NOT NULL UNIQUE CHECK (length(email) <= 255),
      phone         text CHECK (length(phone) <= 20),
      password_hash text NOT NULL,
      is_active     boolean NOT NULL DEFAULT true,
      last_login_at timestamptz,
      created_at    timestamptz NOT NULL DEFAULT now(),
      updated_at    timestamptz NOT NULL DEFAULT now()
    );

    -- Only a hash of each refresh token is stored. Rotation keeps family_id, so
    -- presenting an already-rotated token revokes the whole family.
    CREATE TABLE refresh_tokens (
      id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      family_id      uuid NOT NULL,
      token_hash     text NOT NULL UNIQUE,
      device_info    text,
      expires_at     timestamptz NOT NULL,
      revoked_at     timestamptz,
      replaced_by_id uuid REFERENCES refresh_tokens (id) ON DELETE SET NULL,
      created_at     timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
    CREATE INDEX refresh_tokens_family_id_idx ON refresh_tokens (family_id);
    CREATE INDEX refresh_tokens_expires_at_idx ON refresh_tokens (expires_at);

    -- One-time codes for "forgot password". Only an HMAC of each code is
    -- stored; the newest unused code for a user is the only one that counts.
    CREATE TABLE password_resets (
      id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id      uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      code_hash    text NOT NULL,
      attempts     smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
      expires_at   timestamptz NOT NULL,
      used_at      timestamptz,
      requested_ip text,
      created_at   timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX password_resets_user_created_idx ON password_resets (user_id, created_at DESC);

    ${updatedAt("users")}
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DROP TABLE password_resets;
    DROP TABLE refresh_tokens;
    DROP TABLE users;
  `);
}
