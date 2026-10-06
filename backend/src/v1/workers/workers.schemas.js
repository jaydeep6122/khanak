import { z } from "zod";
import { date, id, listQuery, money, optionalText, phone, queryBoolean, text } from "../../utils/schemas.js";

// paatla, bharai, khadkaniyo, nikasi, driver, roj, other.
export const MAIN_WORKS = ["molder", "loader", "stacker", "unloader", "driver", "daily", "other"];

/** A molder (per 1000 bricks) and a day worker (per day) must have a rate of their own. */
export const HAS_OWN_RATE = new Set(["molder", "daily"]);

/**
 * A bharai or nikasi worker is paid either at the group's rate per 1000, or
 * by the day: then their own rate is a day rate, and they are not picked for
 * group work; their days are typed in as day work.
 */
export const MAY_BE_PAID_BY_DAY = new Set(["loader", "unloader"]);

/**
 * Group work each main work is paid for, at the group's rate. That rate must
 * be set before such a worker is added: it is asked right there (sent as
 * group_rates) the first time. Loading a vehicle is asked at the first sale.
 */
export const GROUP_WORK = {
  // Carrying to dry and loading the kiln are paid at the one loading rate.
  loader: ["kiln_loading"],
  stacker: ["stacking"],
  unloader: ["unloading"],
};

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
  // Rates of group work not priced yet, set together with the worker.
  group_rates: z
    .array(z.object({ work_type_id: id, rate: money({ gt: 0 }) }))
    .max(5)
    .optional(),
};

const salaryPair = (worker) =>
  (worker.monthly_salary == null) === (worker.salary_from == null);

/** A bharai or nikasi worker with a day rate of their own: not paid as a group. */
export const paidByDay = (worker) => MAY_BE_PAID_BY_DAY.has(worker.main_work) && worker.rate != null;

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
  if (!HAS_OWN_RATE.has(worker.main_work) && !MAY_BE_PAID_BY_DAY.has(worker.main_work) && worker.rate != null) {
    return { path: "rate", message: "Only a molder, a day worker, or bharai or nikasi paid by the day has a rate of their own" };
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
