import { z } from "zod";
import { date, email, id, optionalText, phone, text } from "../../utils/schemas.js";

const factoryFields = {
  name: text(255),
  owner_name: optionalText(255),
  phone: phone.nullable().optional(),
  city: optionalText(100),
  state: optionalText(100),
  language: z.enum(["gu", "hi", "en"]).optional(),
};

export const createFactorySchema = z.object({
  ...factoryFields,
  // Already in the middle of a season: start it from this date. Without it the
  // factory starts in the off-season, from today.
  season_started_on: date.optional(),
});

export const updateFactorySchema = z.object(factoryFields).partial();

export const addMemberSchema = z.object({
  email,
  role: z.enum(["munim", "supervisor"]),
  worker_id: id.nullable().optional(),
});

export const updateMemberSchema = z
  .object({
    role: z.enum(["munim", "supervisor"]),
    worker_id: id.nullable(),
  })
  .partial();
