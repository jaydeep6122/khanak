import { z } from "zod";
import { date, listQuery, money, optionalText, phone, queryBoolean, text } from "../../utils/schemas.js";

/** A new customer or supplier typed on a sale or expense. */
export const newParty = z.object({
  name: text(255),
  phone: phone.nullable().optional(),
  village: optionalText(100),
});

export const createPartySchema = newParty.extend({
  kind: z.enum(["customer", "supplier"]),
  note: optionalText(1000),
});

export const updatePartySchema = z
  .object({
    name: text(255),
    phone: phone.nullable(),
    village: optionalText(100),
    note: optionalText(1000),
    is_active: z.boolean(),
  })
  .partial();

export const listPartiesQuery = z.object({
  kind: z.enum(["customer", "supplier"]).optional(),
  search: z.string().trim().max(100).optional(),
  // Only those who owe or are owed something.
  with_balance: queryBoolean.optional(),
});

export const ledgerQuery = listQuery({ from: date.optional(), to: date.optional() });

// received from a customer, paid to a supplier, writeoff (owner only)
// forgives what a customer owes.
export const paymentSchema = z.object({
  kind: z.enum(["received", "paid", "writeoff"]),
  paid_on: date,
  amount: money({ gt: 0 }),
  mode: z.enum(["cash", "bank", "upi"]).optional(),
  note: optionalText(1000),
});

export const updatePaymentSchema = z
  .object({ paid_on: date, amount: money({ gt: 0 }), mode: z.enum(["cash", "bank", "upi"]), note: optionalText(1000) })
  .partial();

