import { z } from "zod";
import { date, id, listQuery, money, optionalText, phone, queryBoolean, text } from "../../utils/schemas.js";

// pathera, bharai, khadkaniyo, nikasi, driver, roj, other.
export const MAIN_WORKS = ["molder", "loader", "stacker", "unloader", "driver", "daily", "other"];

/** Only a molder (per 1000 bricks) or day worker (per day) has a rate of their own. */
export const HAS_OWN_RATE = new Set(["molder", "daily"]);

const workerFields = {
  name: text(255),
  main_work: z.enum(MAIN_WORKS),
  // The worker's own rate, when it differs from the factory's.
  rate: money({ gt: 0 }).nullable().optional(),
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
 * What is wrong with how this worker is paid, or null. No two molders are
 * paid alike, so a molder and a day worker each need their own rate, and a
 * driver needs a monthly salary. Group work is paid at the group's rate.
 */
export function ownPayProblem(worker) {
  if (HAS_OWN_RATE.has(worker.main_work) && worker.rate == null) {
    return {
      path: "rate",
      message: worker.main_work === "molder" ? "Give this molder's rate per 1000 bricks" : "Give this worker's rate per day",
    };
  }
  if (!HAS_OWN_RATE.has(worker.main_work) && worker.rate != null) {
    return { path: "rate", message: "Only a molder or day worker has a rate of their own" };
  }
  if (worker.main_work === "driver" && worker.monthly_salary == null) {
    return { path: "monthly_salary", message: "Give the driver's monthly salary" };
  }
  return null;
}

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
