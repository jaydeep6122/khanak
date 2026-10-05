import pool from "../db/db.js";
import { withTransaction } from "../db/transaction.js";
import { todayIst } from "../utils/dates.js";
import { dec, money } from "../utils/money.js";

const pad = (n) => String(n).padStart(2, "0");
const ymd = (year, month, day) => `${year}-${pad(month)}-${pad(day)}`;
const daysIn = (year, month) => new Date(Date.UTC(year, month, 0)).getUTCDate();
const dayNumber = (date) => Date.parse(`${date}T00:00:00Z`) / 86_400_000;

/**
 * The months a salaried worker is owed, each as { month, upTo, amount }.
 * A month is paid once it is over, or up to the day the worker left. Pay is
 * never cut for absence; only the first and last months are part months,
 * paid by calendar days (joined on the 16th of a 30-day month: half).
 */
export function salaryMonths({ monthly_salary, salary_from, left_on }, today = todayIst()) {
  if (!monthly_salary || !salary_from) return [];

  const [ty, tm] = today.split("-").map(Number);
  const lastCompleted = ymd(ty, tm, 1) > salary_from ? new Date(Date.UTC(ty, tm - 1, 0)) : null;
  const end = left_on ?? (lastCompleted ? lastCompleted.toISOString().slice(0, 10) : null);
  if (!end || end < salary_from) return [];

  const months = [];
  let [year, month] = salary_from.split("-").map(Number);
  for (;;) {
    const first = ymd(year, month, 1);
    if (first > end) break;
    const last = ymd(year, month, daysIn(year, month));
    const from = salary_from > first ? salary_from : first;
    const upTo = end < last ? end : last;
    const days = dayNumber(upTo) - dayNumber(from) + 1;
    const amount =
      days === daysIn(year, month)
        ? money(monthly_salary)
        : money(dec(monthly_salary).times(days).dividedBy(daysIn(year, month)));
    months.push({ month: first, upTo, amount });
    [year, month] = month === 12 ? [year + 1, 1] : [year, month + 1];
  }
  return months;
}

/**
 * Writes every salary month that is due and not yet written, for every
 * salaried worker of the factory. Safe to call on every read that shows a
 * balance: months already written are left as they are, so a later change
 * of salary only affects months still to come.
 */
export async function accrueSalaries(factoryId) {
  const { rows: workers } = await pool.query(
    `SELECT w.id, w.monthly_salary, w.salary_from, w.left_on,
            (SELECT max(salary_month) FROM work_entries e
             WHERE e.worker_id = w.id AND e.source = 'salary') AS last_month
     FROM workers w
     WHERE w.factory_id = $1 AND w.monthly_salary IS NOT NULL`,
    [factoryId],
  );

  const due = workers.flatMap((worker) =>
    salaryMonths(worker)
      .filter((month) => !worker.last_month || month.month > worker.last_month)
      .map((month) => ({ worker, ...month })),
  );
  if (due.length === 0) return;

  await withTransaction(async (client) => {
    for (const { worker, month, upTo, amount } of due) {
      // Months before the factory's first period go into its first period.
      await client.query(
        `INSERT INTO work_entries
           (factory_id, period_id, worker_id, work_type_id, entry_date, quantity, amount, source, salary_month)
         SELECT $1,
                COALESCE(
                  (SELECT id FROM periods WHERE factory_id = $1 AND started_on <= $4
                   ORDER BY started_on DESC, created_at DESC LIMIT 1),
                  (SELECT id FROM periods WHERE factory_id = $1 ORDER BY started_on, created_at LIMIT 1)),
                $2, t.id, $4, 1, $5, 'salary', $3
         FROM work_types t
         WHERE t.factory_id = $1 AND t.code = 'salary'
         ON CONFLICT (worker_id, salary_month) WHERE source = 'salary' DO NOTHING`,
        [factoryId, worker.id, month, upTo, amount],
      );
    }
  });
}
