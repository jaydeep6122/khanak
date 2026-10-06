import { z } from "zod";
import { dec } from "../../utils/money.js";
import { bricks, date, id, listQuery, money, optionalText, queryBoolean } from "../../utils/schemas.js";
import { groupSchema } from "../brick-counts/brick-counts.schemas.js";
import { newParty } from "../parties/parties.schemas.js";

/**
 * A load of fired bricks sold. The customer is an existing party
 * (`party_id`), a new one (`party`), or for a cash sale just a name
 * (`customer_name`) or nothing at all.
 */
export const saleSchema = z
  .object({
    sold_on: date,
    party_id: id.nullable().optional(),
    party: newParty.optional(),
    customer_name: optionalText(255),
    quantity: bricks,
    // Per 1000 bricks; it changes from load to load.
    rate: money(),
    // The delivery charge, when billed apart from the bricks.
    bhadu: money().nullable().optional(),
    paid_amount: money(),
    delivery: z.enum(["own_truck", "customer", "hired"]),
    truck_id: id.nullable().optional(),
    driver_id: id.nullable().optional(),
    trips: z.number().int().min(1).max(100).nullable().optional(),
    destination: optionalText(255),
    // A hired truck: whose it is and the rent owed to them.
    hire_party_id: id.nullable().optional(),
    hire_party: newParty.optional(),
    hire_amount: money().nullable().optional(),
    // The workers who loaded (and unloaded) the truck, paid together.
    groups: z.array(groupSchema).max(5).optional(),
    note: optionalText(1000),
  })
  .superRefine((sale, ctx) => {
    const fail = (path, message) => ctx.addIssue({ code: "custom", path: [path], message });
    const total = dec(sale.quantity).times(sale.rate).dividedBy(1000).toDecimalPlaces(2).plus(sale.bhadu ?? 0);
    const hasParty = Boolean(sale.party_id || sale.party);

    if (sale.party_id && sale.party) fail("party", "Give party_id or a new party, not both");
    // Money left owing needs someone to collect it from.
    if (!hasParty && !dec(sale.paid_amount).eq(total)) {
      fail("party", "Something is left owing: give the customer's name and phone");
    }
    if (sale.party && dec(sale.paid_amount).lt(total) && !sale.party.phone) {
      fail("party.phone", "Something is left owing: give the customer's phone");
    }

    if (sale.delivery === "own_truck" && !sale.truck_id) fail("truck_id", "Which truck took the bricks?");
    if (sale.delivery !== "own_truck" && (sale.truck_id || sale.driver_id || sale.trips)) {
      fail("truck_id", "A truck, driver and trips are only for the factory's own truck");
    }
    if (sale.delivery === "hired") {
      if (!sale.hire_party_id && !sale.hire_party) fail("hire_party", "Whose truck was hired?");
      if (sale.hire_amount == null) fail("hire_amount", "What is the truck's rent?");
    } else if (sale.hire_party_id || sale.hire_party || sale.hire_amount != null) {
      fail("hire_amount", "Rent is only for a hired truck");
    }
  });

export const listSalesQuery = listQuery({
  from: date.optional(),
  to: date.optional(),
  period_id: id.optional(),
  party_id: id.optional(),
  truck_id: id.optional(),
  include_cancelled: queryBoolean.optional(),
});

export const lastRateQuery = z.object({ party_id: id.optional() });
