import { z } from "zod";
import { date, id, listQuery, money, optionalText, phone, queryBoolean, text } from "../../utils/schemas.js";

// paatla, bharai, khadkaniyo, nikasi, driver, roj, other.
export const MAIN_WORKS = ["molder", "loader", "stacker", "unloader", "driver", "daily", "other"];

const workerFields = {
  name: text(255),
  main_work: z.enum(MAIN_WORKS),
  // Every worker but a driver has a rate of their own, and may have both:
  // per 1000 bricks for their share of brick work, and per day for their
  // days typed in as day work. The two need not match.
  brick_rate: money({ gt: 0 }).nullable().optional(),
  day_rate: money({ gt: 0 }).nullable().optional(),
  nickname: optionalText(100),
  village: optionalText(100),
  phone: phone.nullable().optional(),
  note: optionalText(1000),
  // Drivers: a monthly salary from a date. Both or neither.
  monthly_salary: money({ gt: 0 }).nullable().optional(),
  salary_from: date.nullable().optional(),
};

const salaryPair = (worker) =>
  (worker.monthly_salary == null) === (worker.salary_from == null);

/**
 * What is wrong with how this worker is paid, or null. A driver is paid a
 * monthly salary; everyone else at a rate of their own, per 1000 bricks, per
 * day or both, set when they are added.
 */
export function ownPayProblem(worker) {
  if (worker.main_work === "driver") {
    if (worker.monthly_salary == null) return { path: "monthly_salary", message: "Give the driver's monthly salary" };
    if (worker.brick_rate != null || worker.day_rate != null) {
      return { path: "brick_rate", message: "A driver is paid a monthly salary, not a rate" };
    }
    return null;
  }
  if (worker.brick_rate == null && worker.day_rate == null) {
    return { path: "brick_rate", message: "Give this worker's rate per 1000 bricks, per day, or both" };
  }
  return null;
}

/**
 * Paid only by the day (a day rate, no rate per 1000 bricks): never in a
 * group's pay, and a molder earns nothing from counts. Their days are typed
 * in as day work.
 */
export const paidOnlyByDay = (worker) => worker?.brick_rate == null && worker?.day_rate != null;

export const createWorkerSchema = z
  .object(workerFields)
  .refine(salaryPair, { message: "Give both monthly_salary and salary_from, or neither", path: ["salary_from"] })
  .superRefine((worker, ctx) => {
    const problem = ownPayProblem(worker);
    if (problem) ctx.addIssue({ code: "custom", path: [problem.path], message: problem.message });
  });

export const updateWorkerSchema = z.object(workerFields).partial();

export const listWorkersQuery = z.object({
  active: queryBoolean.optional(),
  main_work: z.enum(MAIN_WORKS).optional(),
  search: z.string().trim().max(100).optional(),
});

export const leaveSchema = z.object({ left_on: date });

export const shareSchema = z.object({ enabled: z.boolean() });

export const ledgerQuery = listQuery({
  period_id: id.optional(),
  from: date.optional(),
  to: date.optional(),
});

// advance = upad, settlement = chukti, recovery = the worker paid money
// back, writeoff = forgive what the worker owes (owner only).
export const transactionSchema = z.object({
  kind: z.enum(["advance", "settlement", "recovery", "writeoff"]),
  txn_date: date,
  amount: money({ gt: 0 }),
  note: optionalText(1000),
  // The member whose cash in hand paid this advance (a supervisor away from
  // the owner). A supervisor's own advances always come from their cash.
  cash_holder_id: id.nullable().optional(),
});

export const updateTransactionSchema = z
  .object({ txn_date: date, amount: money({ gt: 0 }), note: optionalText(1000) })
  .partial();
