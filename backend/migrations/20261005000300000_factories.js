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
    CREATE TABLE factories (
      id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name        text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 255),
      owner_name  text CHECK (length(owner_name) <= 255),
      phone       text CHECK (length(phone) <= 20),
      city        text CHECK (length(city) <= 100),
      state       text CHECK (length(state) <= 100),
      language    text NOT NULL DEFAULT 'gu' CHECK (language IN ('gu', 'hi', 'en')),
      created_by  uuid REFERENCES users (id) ON DELETE SET NULL,
      archived_at timestamptz,
      created_at  timestamptz NOT NULL DEFAULT now(),
      updated_at  timestamptz NOT NULL DEFAULT now()
    );

    -- owner > munim > supervisor. A member who is also paid as a worker (a
    -- supervisor is usually the khadkaniyo) is linked to that worker, so the
    -- app can show them their own account and refuse an advance to themselves.
    -- The worker_id foreign key is added once workers exists.
    CREATE TABLE factory_members (
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      role       text NOT NULL CHECK (role IN ('owner', 'munim', 'supervisor')),
      status     text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'removed')),
      worker_id  uuid,
      added_by   uuid REFERENCES users (id) ON DELETE SET NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (factory_id, user_id)
    );
    CREATE INDEX factory_members_user_id_idx ON factory_members (user_id);
    CREATE UNIQUE INDEX factory_members_one_owner
      ON factory_members (factory_id) WHERE role = 'owner' AND status = 'active';

    -- Subscriptions: what a plan costs and how long it lasts is data, so
    -- prices can change without a release. A factory may write while it has
    -- a subscription covering now(); without one it can still read everything.
    CREATE TABLE plans (
      code          text PRIMARY KEY CHECK (code ~ '^[a-z0-9_]{2,40}$'),
      name          text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
      price         numeric(12, 2) NOT NULL DEFAULT 0 CHECK (price >= 0),
      duration_days integer NOT NULL CHECK (duration_days > 0),
      is_trial      boolean NOT NULL DEFAULT false,
      is_active     boolean NOT NULL DEFAULT true,
      created_at    timestamptz NOT NULL DEFAULT now(),
      updated_at    timestamptz NOT NULL DEFAULT now()
    );
    INSERT INTO plans (code, name, price, duration_days, is_trial)
    VALUES ('trial', 'Free trial', 0, 30, true);

    CREATE TABLE subscriptions (
      id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id  uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      plan_code   text NOT NULL REFERENCES plans (code),
      starts_at   timestamptz NOT NULL DEFAULT now(),
      ends_at     timestamptz NOT NULL,
      status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
      amount_paid numeric(12, 2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
      payment_ref text CHECK (length(payment_ref) <= 255),
      note        text CHECK (length(note) <= 1000),
      created_at  timestamptz NOT NULL DEFAULT now(),
      CHECK (ends_at > starts_at)
    );
    CREATE INDEX subscriptions_factory_ends_idx ON subscriptions (factory_id, ends_at DESC);

    -- Seasons and the off-season between them. Exactly one period is open at
    -- a time; every entry belongs to the period its date falls in, so reports
    -- can be cut by season, by off-season or by year.
    CREATE TABLE periods (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      kind       text NOT NULL CHECK (kind IN ('season', 'off_season')),
      name       text CHECK (length(name) <= 100),
      started_on date NOT NULL,
      ended_on   date,
      started_by uuid REFERENCES users (id) ON DELETE SET NULL,
      ended_by   uuid REFERENCES users (id) ON DELETE SET NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      CHECK (ended_on IS NULL OR ended_on >= started_on),
      UNIQUE (factory_id, id)
    );
    CREATE UNIQUE INDEX periods_one_open ON periods (factory_id) WHERE ended_on IS NULL;
    CREATE INDEX periods_factory_started_idx ON periods (factory_id, started_on DESC);

    -- What a kind of work pays. code marks the built-in kinds the app's own
    -- screens rely on (a brick count pays 'molding', a kiln unloading is
    -- 'unloading', monthly pay is 'salary'); owners may add their own kinds
    -- with no code. A group kind is one total shared by the workers who did it.
    CREATE TABLE work_types (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      code       text CHECK (code IN ('molding', 'kiln_loading', 'stacking', 'truck_loading',
                                      'unloading', 'daily', 'salary', 'lumpsum')),
      name       text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
      pay_unit   text NOT NULL CHECK (pay_unit IN ('per_1000', 'per_lakh', 'per_day',
                                                   'per_month', 'per_trip', 'lumpsum')),
      -- Monthly pay is set per worker and lump sums are typed in, so neither
      -- has a rate here.
      rate       numeric(12, 2) CHECK (rate >= 0),
      is_group   boolean NOT NULL DEFAULT false,
      is_active  boolean NOT NULL DEFAULT true,
      sort_order smallint NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, code),
      UNIQUE (factory_id, id),
      CHECK ((pay_unit IN ('lumpsum', 'per_month')) = (rate IS NULL)),
      CHECK (NOT (is_group AND pay_unit IN ('per_day', 'per_month')))
    );
    CREATE UNIQUE INDEX work_types_name_unique ON work_types (factory_id, lower(name));

    -- No photos are kept. Two workers with the same name are told apart by
    -- nickname or village. share_token is the secret in the worker's own link
    -- (no login); replacing it makes the old link stop working at once.
    CREATE TABLE workers (
      id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id     uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      name           text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 255),
      nickname       text CHECK (length(nickname) <= 100),
      village        text CHECK (length(village) <= 100),
      phone          text CHECK (length(phone) <= 20),
      note           text CHECK (length(note) <= 1000),
      -- Drivers: paid by the month from salary_from, never cut for absence.
      monthly_salary numeric(12, 2) CHECK (monthly_salary > 0),
      salary_from    date,
      share_token    text NOT NULL UNIQUE CHECK (length(share_token) >= 20),
      share_enabled  boolean NOT NULL DEFAULT true,
      is_active      boolean NOT NULL DEFAULT true,
      left_on        date,
      created_by     uuid REFERENCES users (id) ON DELETE SET NULL,
      created_at     timestamptz NOT NULL DEFAULT now(),
      updated_at     timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id),
      CHECK ((monthly_salary IS NULL) = (salary_from IS NULL)),
      CHECK (left_on IS NULL OR salary_from IS NULL OR left_on >= salary_from),
      CHECK (is_active OR left_on IS NOT NULL)
    );
    CREATE INDEX workers_factory_name_idx ON workers (factory_id, lower(name));

    ALTER TABLE factory_members
      ADD CONSTRAINT factory_members_worker_fkey
      FOREIGN KEY (factory_id, worker_id) REFERENCES workers (factory_id, id);
    CREATE UNIQUE INDEX factory_members_one_login_per_worker
      ON factory_members (worker_id) WHERE worker_id IS NOT NULL AND status = 'active';

    CREATE TABLE trucks (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      number     text NOT NULL CHECK (length(btrim(number)) BETWEEN 1 AND 20),
      name       text CHECK (length(name) <= 100),
      is_active  boolean NOT NULL DEFAULT true,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, number),
      UNIQUE (factory_id, id)
    );

    ${updatedAt("factories", "factory_members", "plans", "periods", "work_types", "workers", "trucks")}
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DROP TABLE trucks;
    ALTER TABLE factory_members DROP CONSTRAINT factory_members_worker_fkey;
    DROP TABLE workers;
    DROP TABLE work_types;
    DROP TABLE periods;
    DROP TABLE subscriptions;
    DROP TABLE plans;
    DROP TABLE factory_members;
    DROP TABLE factories;
  `);
}
