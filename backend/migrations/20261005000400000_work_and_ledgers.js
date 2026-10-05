export const shorthands = undefined;

const updatedAt = (...tables) =>
  tables
    .map(
      (table) =>
        `CREATE TRIGGER ${table}_set_updated_at BEFORE UPDATE ON ${table}
         FOR EACH ROW EXECUTE FUNCTION set_updated_at();`,
    )
    .join("\n");

const cancelColumns = `
      cancelled_at  timestamptz,
      cancelled_by  uuid REFERENCES users (id) ON DELETE SET NULL,
      cancel_reason text CHECK (length(cancel_reason) <= 500),`;

export async function up(pgm) {
  pgm.sql(`
    -- A brick count ("ginti"). Bricks are counted only at a few moments: the
    -- drying ground is full, the bricks go into the kiln (carried by workers
    -- or by truck), or the season's last count when the workers leave.
    -- already_counted marks bricks moved into the kiln that an earlier count
    -- already paid the molder for, so a molder is never paid twice.
    CREATE TABLE brick_counts (
      id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id      uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id       uuid NOT NULL,
      counted_on      date NOT NULL,
      reason          text NOT NULL CHECK (reason IN ('drying', 'kiln_by_workers', 'kiln_by_truck', 'final')),
      quantity        integer NOT NULL CHECK (quantity > 0),
      molder_id       uuid,
      already_counted boolean NOT NULL DEFAULT false,
      truck_id        uuid,
      trips           integer CHECK (trips BETWEEN 1 AND 1000),
      note            text CHECK (length(note) <= 1000),
      created_by      uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at      timestamptz NOT NULL DEFAULT now(),
      updated_at      timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, molder_id) REFERENCES workers (factory_id, id),
      FOREIGN KEY (factory_id, truck_id) REFERENCES trucks (factory_id, id),
      CHECK (NOT already_counted OR reason IN ('kiln_by_workers', 'kiln_by_truck')),
      CHECK (already_counted OR molder_id IS NOT NULL),
      CHECK (reason = 'kiln_by_truck' OR (truck_id IS NULL AND trips IS NULL))
    );
    CREATE INDEX brick_counts_factory_date_idx ON brick_counts (factory_id, counted_on DESC);

    -- Taking fired bricks out of the kiln ("nikasi").
    CREATE TABLE kiln_unloadings (
      id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id   uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id    uuid NOT NULL,
      unloaded_on  date NOT NULL,
      quantity     integer NOT NULL CHECK (quantity > 0),
      note         text CHECK (length(note) <= 1000),
      created_by   uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at   timestamptz NOT NULL DEFAULT now(),
      updated_at   timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id)
    );
    CREATE INDEX kiln_unloadings_factory_date_idx ON kiln_unloadings (factory_id, unloaded_on DESC);

    -- What a worker earned. Rows from a brick count, an unloading or monthly
    -- pay are written by src/services/posting.js and rewritten whenever their
    -- source changes; 'manual' rows (day work, lump sums) are typed in and
    -- cancelled rather than deleted. quantity and rate are the values on that
    -- day, so a later rate change never alters past pay. For group work,
    -- group_total is what the whole group earned and amount this worker's share.
    CREATE TABLE work_entries (
      id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id        uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id         uuid NOT NULL,
      worker_id         uuid NOT NULL,
      work_type_id      uuid NOT NULL,
      entry_date        date NOT NULL,
      quantity          numeric(14, 3) CHECK (quantity > 0),
      rate              numeric(12, 2) CHECK (rate >= 0),
      amount            numeric(14, 2) NOT NULL CHECK (amount >= 0),
      group_total       numeric(14, 2) CHECK (group_total >= amount),
      group_size        smallint CHECK (group_size >= 1),
      source            text NOT NULL CHECK (source IN ('manual', 'brick_count', 'kiln_unloading', 'salary')),
      brick_count_id    uuid,
      kiln_unloading_id uuid,
      salary_month      date CHECK (extract(day FROM salary_month) = 1),
      note              text CHECK (length(note) <= 1000),
      created_by        uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at        timestamptz NOT NULL DEFAULT now(),
      updated_at        timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, worker_id) REFERENCES workers (factory_id, id),
      FOREIGN KEY (factory_id, work_type_id) REFERENCES work_types (factory_id, id),
      FOREIGN KEY (factory_id, brick_count_id) REFERENCES brick_counts (factory_id, id) ON DELETE CASCADE,
      FOREIGN KEY (factory_id, kiln_unloading_id) REFERENCES kiln_unloadings (factory_id, id) ON DELETE CASCADE,
      CHECK ((source = 'brick_count') = (brick_count_id IS NOT NULL)),
      CHECK ((source = 'kiln_unloading') = (kiln_unloading_id IS NOT NULL)),
      CHECK ((source = 'salary') = (salary_month IS NOT NULL)),
      CHECK (source = 'manual' OR cancelled_at IS NULL),
      CHECK ((group_total IS NULL) = (group_size IS NULL))
    );
    CREATE INDEX work_entries_worker_date_idx ON work_entries (worker_id, entry_date DESC);
    CREATE INDEX work_entries_factory_date_idx ON work_entries (factory_id, entry_date DESC);
    CREATE INDEX work_entries_brick_count_idx ON work_entries (brick_count_id) WHERE brick_count_id IS NOT NULL;
    CREATE INDEX work_entries_unloading_idx ON work_entries (kiln_unloading_id) WHERE kiln_unloading_id IS NOT NULL;
    CREATE UNIQUE INDEX work_entries_one_salary_per_month
      ON work_entries (worker_id, salary_month) WHERE source = 'salary';

    -- Money between the factory and a worker. advance (upad) and settlement
    -- (chukti) are paid to the worker; recovery is money the worker paid
    -- back; writeoff forgives what a worker owes (a loss in reports).
    -- cash_holder_id is the member whose cash in hand paid an advance, so a
    -- supervisor's cash can be reconciled with what they handed out.
    CREATE TABLE worker_transactions (
      id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id     uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id      uuid NOT NULL,
      worker_id      uuid NOT NULL,
      kind           text NOT NULL CHECK (kind IN ('advance', 'settlement', 'recovery', 'writeoff')),
      txn_date       date NOT NULL,
      amount         numeric(14, 2) NOT NULL CHECK (amount > 0),
      cash_holder_id uuid REFERENCES users (id) ON DELETE SET NULL,
      note           text CHECK (length(note) <= 1000),
      created_by     uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at     timestamptz NOT NULL DEFAULT now(),
      updated_at     timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, worker_id) REFERENCES workers (factory_id, id),
      CHECK (cash_holder_id IS NULL OR kind = 'advance')
    );
    CREATE INDEX worker_transactions_worker_date_idx ON worker_transactions (worker_id, txn_date DESC);
    CREATE INDEX worker_transactions_holder_idx ON worker_transactions (factory_id, cash_holder_id)
      WHERE cash_holder_id IS NOT NULL;

    -- Cash the owner hands a supervisor to pay advances from, and cash
    -- handed back. In hand = given - returned - advances they paid.
    CREATE TABLE cash_handovers (
      id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id    uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      holder_id     uuid NOT NULL REFERENCES users (id),
      kind          text NOT NULL CHECK (kind IN ('given', 'returned')),
      handover_date date NOT NULL,
      amount        numeric(14, 2) NOT NULL CHECK (amount > 0),
      note          text CHECK (length(note) <= 1000),
      created_by    uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at    timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX cash_handovers_holder_idx ON cash_handovers (factory_id, holder_id);

    -- Brick stock by stage: raw (kachi), kiln (in the bhatha), fired (pakki).
    -- Written only by src/services/posting.js; stock is the sum of these rows.
    CREATE TABLE brick_movements (
      id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      factory_id        uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id         uuid NOT NULL,
      moved_on          date NOT NULL,
      stage             text NOT NULL CHECK (stage IN ('raw', 'kiln', 'fired')),
      quantity          integer NOT NULL CHECK (quantity <> 0),
      brick_count_id    uuid,
      kiln_unloading_id uuid,
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, brick_count_id) REFERENCES brick_counts (factory_id, id) ON DELETE CASCADE,
      FOREIGN KEY (factory_id, kiln_unloading_id) REFERENCES kiln_unloadings (factory_id, id) ON DELETE CASCADE,
      CONSTRAINT brick_movements_one_source CHECK (num_nonnulls(brick_count_id, kiln_unloading_id) = 1)
    );
    CREATE INDEX brick_movements_factory_stage_idx ON brick_movements (factory_id, stage);

    -- Every line of a worker's account, signed from the worker's side:
    -- credit = the factory owes the worker more, debit = less.
    -- Balance = sum(credit - debit); negative means the worker owes.
    CREATE VIEW worker_ledger AS
      SELECT e.factory_id, e.worker_id, e.period_id, e.entry_date,
             'work'::text AS entry_kind, e.id AS entry_id, e.work_type_id,
             e.quantity, e.rate, e.group_total, e.group_size,
             e.amount AS credit, 0::numeric(14, 2) AS debit,
             e.source, e.brick_count_id, e.kiln_unloading_id, e.salary_month,
             e.note, e.created_by, e.created_at
      FROM work_entries e
      WHERE e.cancelled_at IS NULL
      UNION ALL
      SELECT t.factory_id, t.worker_id, t.period_id, t.txn_date,
             t.kind, t.id, NULL, NULL, NULL, NULL, NULL,
             CASE WHEN t.kind IN ('recovery', 'writeoff') THEN t.amount ELSE 0 END,
             CASE WHEN t.kind IN ('advance', 'settlement') THEN t.amount ELSE 0 END,
             NULL, NULL, NULL, NULL,
             t.note, t.created_by, t.created_at
      FROM worker_transactions t
      WHERE t.cancelled_at IS NULL;

    -- Written by the application for every create, edit and cancel, so the
    -- owner can see who entered what. factory_id is NULL for user-level
    -- events such as signup.
    CREATE TABLE audit_log (
      id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      factory_id  uuid REFERENCES factories (id) ON DELETE CASCADE,
      user_id     uuid REFERENCES users (id) ON DELETE SET NULL,
      action      text NOT NULL CHECK (length(action) BETWEEN 1 AND 50),
      entity_type text NOT NULL CHECK (length(entity_type) BETWEEN 1 AND 50),
      entity_id   uuid,
      before      jsonb,
      after       jsonb,
      created_at  timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX audit_log_factory_created_idx ON audit_log (factory_id, created_at DESC);
    CREATE INDEX audit_log_entity_idx ON audit_log (entity_type, entity_id);

    ${updatedAt("brick_counts", "kiln_unloadings", "work_entries", "worker_transactions")}
  `);
}

export async function down(pgm) {
  pgm.sql(`
    DROP TABLE audit_log;
    DROP VIEW worker_ledger;
    DROP TABLE brick_movements;
    DROP TABLE cash_handovers;
    DROP TABLE worker_transactions;
    DROP TABLE work_entries;
    DROP TABLE kiln_unloadings;
    DROP TABLE brick_counts;
  `);
}
