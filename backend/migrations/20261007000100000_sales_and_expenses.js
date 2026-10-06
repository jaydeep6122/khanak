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

/**
 * Phase 2: selling bricks, the factory's customers and suppliers, money
 * received and paid, and what the factory spends (soil, coal, husk, diesel,
 * truck upkeep).
 */
export async function up(pgm) {
  pgm.sql(`
    -- Customers and suppliers. Most are one-off, so a party is only needed
    -- when money is left owing either way; a cash sale needs none.
    CREATE TABLE parties (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      kind       text NOT NULL CHECK (kind IN ('customer', 'supplier')),
      name       text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 255),
      phone      text CHECK (length(phone) <= 20),
      village    text CHECK (length(village) <= 100),
      note       text CHECK (length(note) <= 1000),
      is_active  boolean NOT NULL DEFAULT true,
      created_by uuid REFERENCES users (id) ON DELETE SET NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id)
    );
    CREATE INDEX parties_factory_kind_name_idx ON parties (factory_id, kind, lower(name));

    -- A load of fired bricks sold. The price changes from load to load, so
    -- every sale carries its own rate per 1000. Delivery by the factory's own
    -- truck counts as truck trips and pays the loaders; a hired truck's rent
    -- is owed to its owner. bhadu is the delivery charge billed to the
    -- customer, when it is billed separately.
    CREATE TABLE sales (
      id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id    uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id     uuid NOT NULL,
      sold_on       date NOT NULL,
      party_id      uuid,
      customer_name text CHECK (length(customer_name) <= 255),
      quantity      integer NOT NULL CHECK (quantity > 0),
      rate          numeric(12, 2) NOT NULL CHECK (rate >= 0),
      bricks_amount numeric(14, 2) NOT NULL CHECK (bricks_amount >= 0),
      bhadu         numeric(14, 2) CHECK (bhadu >= 0),
      total         numeric(14, 2) NOT NULL CHECK (total >= 0),
      paid_amount   numeric(14, 2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
      delivery      text NOT NULL CHECK (delivery IN ('own_truck', 'customer', 'hired')),
      truck_id      uuid,
      driver_id     uuid,
      trips         integer CHECK (trips BETWEEN 1 AND 100),
      destination   text CHECK (length(destination) <= 255),
      hire_party_id uuid,
      hire_amount   numeric(14, 2) CHECK (hire_amount >= 0),
      note          text CHECK (length(note) <= 1000),
      created_by    uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at    timestamptz NOT NULL DEFAULT now(),
      updated_at    timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, party_id) REFERENCES parties (factory_id, id),
      FOREIGN KEY (factory_id, truck_id) REFERENCES trucks (factory_id, id),
      FOREIGN KEY (factory_id, driver_id) REFERENCES workers (factory_id, id),
      FOREIGN KEY (factory_id, hire_party_id) REFERENCES parties (factory_id, id),
      CHECK (total = bricks_amount + COALESCE(bhadu, 0)),
      -- Without a customer on record, nothing can be left owing.
      CHECK (party_id IS NOT NULL OR paid_amount = total),
      CHECK ((delivery = 'own_truck') = (truck_id IS NOT NULL)),
      CHECK (delivery = 'own_truck' OR (driver_id IS NULL AND trips IS NULL)),
      CHECK ((delivery = 'hired') = (hire_party_id IS NOT NULL AND hire_amount IS NOT NULL))
    );
    CREATE INDEX sales_factory_date_idx ON sales (factory_id, sold_on DESC);
    CREATE INDEX sales_party_idx ON sales (party_id) WHERE party_id IS NOT NULL;
    CREATE INDEX sales_truck_idx ON sales (truck_id) WHERE truck_id IS NOT NULL;

    -- What the factory spends. Diesel and truck upkeep can name the truck;
    -- a full-tank diesel fill with the odometer gives the truck's average.
    -- A supplier is needed only when part is left unpaid.
    CREATE TABLE expenses (
      id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id  uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id   uuid NOT NULL,
      spent_on    date NOT NULL,
      category    text NOT NULL CHECK (category IN ('soil', 'coal', 'husk', 'diesel', 'truck_upkeep', 'other')),
      quantity    numeric(14, 3) CHECK (quantity > 0),
      unit        text CHECK (length(unit) <= 20),
      amount      numeric(14, 2) NOT NULL CHECK (amount > 0),
      paid_amount numeric(14, 2) NOT NULL CHECK (paid_amount >= 0),
      party_id    uuid,
      truck_id    uuid,
      litres      numeric(10, 2) CHECK (litres > 0),
      odometer    integer CHECK (odometer >= 0),
      note        text CHECK (length(note) <= 1000),
      created_by  uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at  timestamptz NOT NULL DEFAULT now(),
      updated_at  timestamptz NOT NULL DEFAULT now(),
      UNIQUE (factory_id, id),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, party_id) REFERENCES parties (factory_id, id),
      FOREIGN KEY (factory_id, truck_id) REFERENCES trucks (factory_id, id),
      CHECK (paid_amount <= amount),
      CHECK (party_id IS NOT NULL OR paid_amount = amount),
      CHECK (category IN ('diesel', 'truck_upkeep') OR truck_id IS NULL),
      CHECK (category = 'diesel' OR (litres IS NULL AND odometer IS NULL))
    );
    CREATE INDEX expenses_factory_date_idx ON expenses (factory_id, spent_on DESC);
    CREATE INDEX expenses_truck_idx ON expenses (truck_id, spent_on) WHERE truck_id IS NOT NULL;
    CREATE INDEX expenses_party_idx ON expenses (party_id) WHERE party_id IS NOT NULL;

    -- Money with a customer or supplier after the sale or purchase itself:
    -- received from a customer, paid to a supplier, or a customer's debt
    -- written off (owner only; a loss in reports).
    CREATE TABLE party_payments (
      id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      factory_id uuid NOT NULL REFERENCES factories (id) ON DELETE CASCADE,
      period_id  uuid NOT NULL,
      party_id   uuid NOT NULL,
      kind       text NOT NULL CHECK (kind IN ('received', 'paid', 'writeoff')),
      paid_on    date NOT NULL,
      amount     numeric(14, 2) NOT NULL CHECK (amount > 0),
      mode       text NOT NULL DEFAULT 'cash' CHECK (mode IN ('cash', 'bank', 'upi')),
      note       text CHECK (length(note) <= 1000),
      created_by uuid REFERENCES users (id) ON DELETE SET NULL,
      ${cancelColumns}
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (factory_id, period_id) REFERENCES periods (factory_id, id),
      FOREIGN KEY (factory_id, party_id) REFERENCES parties (factory_id, id)
    );
    CREATE INDEX party_payments_party_idx ON party_payments (party_id, paid_on DESC);

    -- A party's account, from the factory's side: owed = what the party owes
    -- the factory, negative when the factory owes them (a supplier's credit,
    -- or a customer's advance). Balance = sum(owed).
    CREATE VIEW party_ledger WITH (security_invoker = true) AS
      SELECT s.factory_id, s.party_id, s.period_id, s.sold_on AS entry_date,
             'sale'::text AS entry_kind, s.id AS entry_id,
             s.total - s.paid_amount AS owed, s.total AS amount, s.paid_amount,
             s.quantity, s.rate, s.note, s.created_at
      FROM sales s
      WHERE s.cancelled_at IS NULL AND s.party_id IS NOT NULL
      UNION ALL
      SELECT s.factory_id, s.hire_party_id, s.period_id, s.sold_on,
             'truck_hire', s.id, -s.hire_amount, s.hire_amount, 0, s.quantity, NULL, s.note, s.created_at
      FROM sales s
      WHERE s.cancelled_at IS NULL AND s.delivery = 'hired'
      UNION ALL
      SELECT e.factory_id, e.party_id, e.period_id, e.spent_on,
             'expense', e.id, -(e.amount - e.paid_amount), e.amount, e.paid_amount, e.quantity, NULL, e.note, e.created_at
      FROM expenses e
      WHERE e.cancelled_at IS NULL AND e.party_id IS NOT NULL
      UNION ALL
      SELECT p.factory_id, p.party_id, p.period_id, p.paid_on,
             p.kind, p.id, CASE WHEN p.kind = 'paid' THEN p.amount ELSE -p.amount END,
             p.amount, NULL, NULL, NULL, p.note, p.created_at
      FROM party_payments p
      WHERE p.cancelled_at IS NULL;

    -- Truck loaders are paid from a sale, and a sale takes bricks out of
    -- fired stock.
    ALTER TABLE work_entries ADD COLUMN sale_id uuid;
    ALTER TABLE work_entries
      DROP CONSTRAINT work_entries_source_check,
      ADD CONSTRAINT work_entries_source_check
        CHECK (source IN ('manual', 'brick_count', 'kiln_unloading', 'salary', 'sale')),
      ADD CONSTRAINT work_entries_sale_source CHECK ((source = 'sale') = (sale_id IS NOT NULL)),
      ADD CONSTRAINT work_entries_sale_fkey
        FOREIGN KEY (factory_id, sale_id) REFERENCES sales (factory_id, id) ON DELETE CASCADE;
    CREATE INDEX work_entries_sale_idx ON work_entries (sale_id) WHERE sale_id IS NOT NULL;

    ALTER TABLE brick_movements ADD COLUMN sale_id uuid;
    ALTER TABLE brick_movements
      DROP CONSTRAINT brick_movements_one_source,
      ADD CONSTRAINT brick_movements_one_source
        CHECK (num_nonnulls(brick_count_id, kiln_unloading_id, sale_id) = 1),
      ADD CONSTRAINT brick_movements_sale_fkey
        FOREIGN KEY (factory_id, sale_id) REFERENCES sales (factory_id, id) ON DELETE CASCADE;

    ALTER TABLE parties ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
    ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
    ALTER TABLE party_payments ENABLE ROW LEVEL SECURITY;

    ${updatedAt("parties", "sales", "expenses", "party_payments")}
  `);
}

export async function down(pgm) {
  pgm.sql(`
    ALTER TABLE brick_movements
      DROP CONSTRAINT brick_movements_sale_fkey,
      DROP CONSTRAINT brick_movements_one_source,
      ADD CONSTRAINT brick_movements_one_source CHECK (num_nonnulls(brick_count_id, kiln_unloading_id) = 1);
    ALTER TABLE brick_movements DROP COLUMN sale_id;
    DROP INDEX work_entries_sale_idx;
    ALTER TABLE work_entries
      DROP CONSTRAINT work_entries_sale_fkey,
      DROP CONSTRAINT work_entries_sale_source,
      DROP CONSTRAINT work_entries_source_check,
      ADD CONSTRAINT work_entries_source_check
        CHECK (source IN ('manual', 'brick_count', 'kiln_unloading', 'salary'));
    ALTER TABLE work_entries DROP COLUMN sale_id;
    DROP VIEW party_ledger;
    DROP TABLE party_payments;
    DROP TABLE expenses;
    DROP TABLE sales;
    DROP TABLE parties;
  `);
}
