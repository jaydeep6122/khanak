# Khanak Backend

Express 5 + PostgreSQL (Supabase) API for brick kilns: workers and their pay, advances and settlements, brick counts and stock per kiln, kiln unloading, sales with credit, trucks and diesel, expenses and suppliers, seasons, supervisors and subscriptions.

## Setup

1. Node 20+.
2. Copy `.env.example` to `.env`. Set `DATABASE_URL` to the Supabase connection string and `JWT_SECRET` (e.g. `openssl rand -hex 32`).
3. Install, create the schema and start:

   ```bash
   npm install
   npm run migrate
   npm run dev
   ```

Supabase is used only as the Postgres database. Login, roles and every rule live in this API; Supabase Auth and its REST API are not used. The last migration closes every table to Supabase's REST API (row level security with no policies), so the database can only be reached through this backend. **Every new table needs `ENABLE ROW LEVEL SECURITY` in its migration.**

## Tests

Tests run against `DATABASE_URL_TEST`, a separate throwaway database, never Supabase. They refuse to start if it is missing or equals `DATABASE_URL`. Migrations are applied to it automatically.

```bash
DATABASE_URL_TEST=postgres://postgres@127.0.0.1:55432/khanak_test npm test
```

## Database migrations

The schema lives only in `migrations/` and is managed with [node-pg-migrate](https://salsita.github.io/node-pg-migrate/). The server never changes tables when it starts.

| Command | What it does |
|---|---|
| `npm run migrate` | Apply pending migrations to `DATABASE_URL` |
| `npm run migrate:down` | Roll back the most recent migration |
| `npm run migrate:create -- <name>` | Create a new migration file |

**Deploys must run `npm run migrate` before `npm start`.** Never edit a migration that has already been applied to a shared database; add a new one.

## How the books work

- **A worker's balance is a sum, never a stored number.** `worker_ledger` (a view) lists what a worker earned (`work_entries`) and what passed between them and the factory (`worker_transactions`). Balance = credit − debit: positive means the factory owes the worker, negative means the worker owes.
- **Brick stock is a sum too.** `brick_movements` holds signed quantities per stage: `raw` (kachi), `kiln` (in a bhatha, per kiln), `fired` (pakki). Counts into a kiln and nikasi name the kiln; sales take fired bricks out.
- **Credit with customers and suppliers is a sum.** `party_ledger` (a view) lists sales, a hired truck's rent, expenses and payments; balance = what the party owes the factory, negative when the factory owes them (a supplier, or a customer's advance). A cash sale or a fully paid expense needs no party; anything left owing does.
- **`src/services/posting.js` is the only writer** of the pay and stock that brick counts, unloadings and sales create. Saving, editing or cancelling one deletes its rows and writes them again from its current state.
- **Every worker has rates of their own**, set when they are added: `brick_rate` (per 1000 bricks) for their share of brick work, `day_rate` for their days typed in as day work, or both; the two need not match (₹250 per 1000 and ₹300 a day). A driver has a monthly salary instead. There are no group rates for brick work: molding, kiln loading (to dry or into the kiln), stacking and nikasi are `per_1000` kinds of work with no rate of their own (`rate` null), paid at each worker's own rate.
- **A group is paid for the bricks each worker carried, at their own rate.** Each worker's `bricks` are given in the group and must add up to the bricks counted (7,000 and 3,000 of 10,000: at ₹100 and ₹120 per 1000, ₹700 and ₹360). Left out, the bricks are shared equally. The owner or munim may type amounts (or a total, split equally) by hand instead.
- **Paid only by the day.** A worker with a `day_rate` and no `brick_rate` is never in a group's pay, and such a molder earns nothing from counts; their days are typed in as day work.
- **No pay from a missing rate.** Brick work is refused for a worker without a rate per 1000, and other work priced by a kind's own rate (loading a vehicle per trip, day work for someone not paid by the day, the owner's own kinds) while that rate is missing or zero, unless the owner or munim types the amount by hand. There is no rates screen: a kind's rate is asked the first time it is used.
- **Every entry keeps the rate of its day.** Editing an old count keeps the rates it was made with; a rate change only affects new entries.
- **Work paid at a kind's own rate (per trip) is one total split among the workers who did it.** Equal shares to the paisa (leftover paise go to the first workers), or amounts set by the owner or munim.
- **Monthly salaries write themselves.** Each finished month (or the part up to the day the worker left) is added the next time a balance is read. Pay is never cut for absence.
- **Seasons.** One period is open at a time: a season or the off-season between seasons. Every entry belongs to the latest period that had started on its date. Balances, credit and stock carry across.
- **Amounts never touch JS floats.** They arrive and leave as decimal strings (`"4720.00"`) and are computed with `decimal.js`.
- **Nothing is deleted.** Entries are cancelled and stay on record, and `audit_log` keeps who created, changed or cancelled what.

## Roles

| | owner | munim | supervisor |
|---|---|---|---|
| Brick counts, kiln unloading | ✓ | ✓ | own entries, same day, at the set rates |
| Sales, expenses, customers and suppliers | ✓ | ✓ | |
| Advances | ✓ | ✓ | from their own cash, never to themselves |
| Settlements, day work, lump sums | ✓ | ✓ | |
| Workers, trucks, seasons | ✓ | ✓ | names only |
| Balances, ledgers | ✓ | ✓ | a worker's balance number; their own ledger |
| Reports, cash of others | ✓ | ✓ | |
| Setting a kind of work's rate | ✓ | ✓ | |
| Other changes to kinds of work, members, write-offs (workers and customers), subscription | ✓ | | |

Without a running subscription a factory can be read but not changed (`402`, `code: "subscription_inactive"`).

## API

All responses are JSON: `{ "success": true, "data": ..., "pagination"? }` or `{ "success": false, "statusCode", "code"?, "message", "constraint"? }`.

Authenticated routes need `Authorization: Bearer <access_token>`. Factory routes live under `/v1/factories/:factoryId`.

| Area | Routes |
|---|---|
| Auth | `POST /v1/auth/signup`, `/login`, `/refresh`, `/logout` · `GET/PATCH /v1/auth/me` · `POST /v1/auth/me/password` · `POST /v1/auth/password/forgot`, `/password/reset` |
| Factories | `POST/GET /v1/factories` · `GET/PATCH/DELETE /:factoryId` · `GET /subscription` |
| Members | `GET/POST /members` · `PATCH/DELETE /members/:userId` |
| Seasons | `GET /periods` · `GET /periods/current` · `POST /periods/start-season`, `/end-season` · `PATCH /periods/:id` |
| Kinds of work | `GET/POST /work-types` · `PATCH /work-types/:id` |
| Workers | `GET/POST /workers` · `GET/PATCH /workers/:id` · `POST /workers/:id/leave`, `/return` · `GET /workers/:id/balance`, `/ledger` · `GET/PATCH /workers/:id/share` · `POST /workers/:id/share/regenerate` · `POST /workers/:id/transactions` |
| Advances and payments | `PUT /worker-transactions/:id` · `POST /worker-transactions/:id/cancel` |
| Brick counts | `GET/POST /brick-counts` · `GET/PUT /brick-counts/:id` · `POST /brick-counts/:id/cancel` |
| Kiln unloading | `GET/POST /kiln-unloadings` · `GET/PUT /kiln-unloadings/:id` · `POST /kiln-unloadings/:id/cancel` |
| Day work, lump sums | `GET/POST /work-entries` · `GET/PUT /work-entries/:id` · `POST /work-entries/:id/cancel` |
| Kilns | `GET/POST /kilns` · `PATCH /kilns/:id` |
| Trucks | `GET/POST /trucks` · `PATCH /trucks/:id` · `GET /trucks/:id/report` (trips, delivery charges, diesel and its average, profit) |
| Sales | `GET/POST /sales` · `GET /sales/last-rate` · `GET/PUT /sales/:id` · `POST /sales/:id/cancel` |
| Expenses | `GET/POST /expenses` · `GET/PUT /expenses/:id` · `POST /expenses/:id/cancel` |
| Customers, suppliers | `GET/POST /parties` · `GET/PATCH /parties/:id` · `GET /parties/:id/ledger` · `POST /parties/:id/payments` · `PUT /party-payments/:id` · `POST /party-payments/:id/cancel` |
| Supervisor cash | `GET /cash` · `GET /cash/:holderId` · `POST /cash/handovers` · `POST /cash/handovers/:id/cancel` · `POST /cash/:holderId/settle` |
| Reports | `GET /reports/summary`, `/stock`, `/activity` |
| Public | `GET /v1/public/workers/:token` (a worker's own link, no login) |
| App | `GET /v1/app/version?platform=android` |

### A brick count

```json
{
  "counted_on": "2026-10-05",
  "reason": "kiln_by_truck",
  "quantity": 22000,
  "molder_id": "…",
  "truck_id": "…",
  "trips": 5,
  "groups": [
    { "work_type_id": "<kiln_loading>", "workers": [{ "worker_id": "…" }, { "worker_id": "…" }] },
    { "work_type_id": "<stacking>", "workers": [{ "worker_id": "…" }] }
  ]
}
```

- `reason`: `drying_by_workers` / `drying_by_truck` (carried to the drying ground), `kiln_by_workers` / `kiln_by_truck` (carried into a kiln), `final` (last count when workers leave). Every reason but `final` needs `groups` (who carried them, paid e.g. as `kiln_loading` per 1000 bricks at each worker's own rate (to dry or into the kiln), or `truck_loading` per trip); the `*_by_truck` ones also need `truck_id` and `trips`. Bricks going into a kiln also need the khadkaniya who stacked them: a `stacking` group, paid for the count's bricks at each khadkaniyo's rate per 1000. Khadkaniya are paid only this way, not as typed-in work.
- `already_counted: true`: bricks an earlier count already paid the molder for, now going into the kiln. No molder pay; they move from raw to kiln stock.
- Owner and munim may add `molder_amount`, a group's `total_amount` or each worker's `amount`.
- The response carries `warnings` such as `{ "code": "negative_stock", "stage": "kiln", "quantity": -3000 }`. Stock never blocks an entry.
