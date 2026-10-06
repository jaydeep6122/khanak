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

const REASONS = ["drying_by_workers", "drying_by_truck", "kiln_by_workers", "kiln_by_truck", "final"];
const KILN_REASONS = ["kiln_by_workers", "kiln_by_truck"];
const TRUCK_REASONS = ["drying_by_truck", "kiln_by_truck"];

export const brickCountSchema = z
  .object({
    counted_on: date,
    // drying_by_workers / drying_by_truck: carried to the drying ground;
    // kiln_by_workers / kiln_by_truck: carried into the kiln; final: the
    // season's last count when the workers leave.
    reason: z.enum(REASONS),
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
    const byTruck = TRUCK_REASONS.includes(count.reason);
    // Bricks carried somewhere, to dry or into a kiln, were carried by
    // someone who is paid for it. The last count moves nothing.
    const carried = count.reason !== "final";
    if (count.already_counted && !kiln) {
      fail("already_counted", "Only bricks going into the kiln can be already counted");
    }
    if (!count.already_counted && !count.molder_id) fail("molder_id", "Whose bricks are these?");
    if (count.already_counted && count.molder_amount !== undefined) {
      fail("molder_amount", "Already counted bricks pay no molder");
    }
    if (!byTruck && (count.truck_id || count.trips)) {
      fail("truck_id", "A truck is only for bricks carried by truck");
    }
    if (byTruck && !count.truck_id) fail("truck_id", "Which truck carried the bricks?");
    if (byTruck && !count.trips) fail("trips", "How many trips did the truck make?");
    // Bricks going into a kiln are always some molder's, put in by someone,
    // into one kiln: none of the three may be left out.
    if (kiln && !count.kiln_id) fail("kiln_id", "Which kiln did the bricks go into?");
    if (!kiln && count.kiln_id) fail("kiln_id", "Only bricks going into a kiln have a kiln");
    // Which groups are carriers and which khadkaniya is checked against the
    // kinds of work when saving.
    if (carried && !(count.groups ?? []).some((group) => group.workers.length > 0)) {
      fail("groups", kiln ? "Who put the bricks into the kiln?" : "Who carried the bricks to dry?");
    }
    if (!carried && (count.groups ?? []).length > 0) {
      fail("groups", "The last count pays no one for carrying");
    }
  });

export const listBrickCountsQuery = listQuery({
  kiln_id: id.optional(),
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  reason: z.enum(REASONS).optional(),
  molder_id: id.optional(),
  include_cancelled: queryBoolean.optional(),
});
