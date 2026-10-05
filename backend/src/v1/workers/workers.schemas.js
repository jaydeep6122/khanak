import { z } from "zod";
import { date, id, listQuery, money, optionalText, phone, queryBoolean, text } from "../../utils/schemas.js";

const workerFields = {
  name: text(255),
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

export const createWorkerSchema = z
  .object(workerFields)
  .refine(salaryPair, { message: "Give both monthly_salary and salary_from, or neither", path: ["salary_from"] });

export const updateWorkerSchema = z.object(workerFields).partial();

export const listWorkersQuery = z.object({
  active: queryBoolean.optional(),
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
