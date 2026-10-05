import { z } from "zod";
import { bricks, date, id, listQuery, money, optionalText, queryBoolean } from "../../utils/schemas.js";

/**
 * One group of workers paid together, e.g. the two who loaded the kiln.
 * Amounts per worker and total_amount are for the owner or munim only; left
 * out, the rate gives the total and it is split equally.
 */
export const groupSchema = z.object({
  work_type_id: id,
  workers: z
    .array(z.object({ worker_id: id, amount: money().optional() }))
    .min(1, "A group needs at least one worker")
    .max(100),
  total_amount: money().optional(),
});

const KILN_REASONS = ["kiln_by_workers", "kiln_by_truck"];

export const brickCountSchema = z
  .object({
    counted_on: date,
    // drying: the drying ground is full or the bricks are lifted from it;
    // kiln_by_workers / kiln_by_truck: they go into the kiln; final: the
    // season's last count when the workers leave.
    reason: z.enum(["drying", "kiln_by_workers", "kiln_by_truck", "final"]),
    quantity: bricks,
    molder_id: id.nullable().optional(),
    // Bricks an earlier count already paid the molder for, now going into
    // the kiln: no molder pay, and they leave raw stock.
    already_counted: z.boolean().optional(),
    molder_amount: money().optional(),
    // Which kiln the bricks went into; required when they went into one.
    kiln_id: id.nullable().optional(),
    truck_id: id.nullable().optional(),
    trips: z.number().int().min(1).max(1000).nullable().optional(),
    groups: z.array(groupSchema).max(10).optional(),
    note: optionalText(1000),
  })
  .superRefine((count, ctx) => {
    const fail = (path, message) => ctx.addIssue({ code: "custom", path: [path], message });
    const kiln = KILN_REASONS.includes(count.reason);
    if (count.already_counted && !kiln) {
      fail("already_counted", "Only bricks going into the kiln can be already counted");
    }
    if (!count.already_counted && !count.molder_id) fail("molder_id", "Whose bricks are these?");
    if (count.already_counted && count.molder_amount !== undefined) {
      fail("molder_amount", "Already counted bricks pay no molder");
    }
    if (count.reason !== "kiln_by_truck" && (count.truck_id || count.trips)) {
      fail("truck_id", "A truck is only for bricks carried to the kiln by truck");
    }
    // Bricks going into a kiln are always some molder's, put in by someone,
    // into one kiln: none of the three may be left out.
    if (kiln && !count.kiln_id) fail("kiln_id", "Which kiln did the bricks go into?");
    if (!kiln && count.kiln_id) fail("kiln_id", "Only bricks going into a kiln have a kiln");
    if (kiln && !(count.groups ?? []).some((group) => group.workers.length > 0)) {
      fail("groups", "Who put the bricks into the kiln?");
    }
    if (!kiln && (count.groups ?? []).length > 0) {
      fail("groups", "Only bricks going into a kiln pay a loading group");
    }
  });

export const listBrickCountsQuery = listQuery({
  kiln_id: id.optional(),
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  reason: z.enum(["drying", "kiln_by_workers", "kiln_by_truck", "final"]).optional(),
  molder_id: id.optional(),
  include_cancelled: queryBoolean.optional(),
});
