import { ApiError } from "../utils/ApiError.js";
import { dec, money, sum } from "../utils/money.js";

/**
 * Pay for `quantity` units at `rate`: bricks for per_1000 and per_lakh, days
 * for per_day, trips for per_trip. Lump sums and monthly pay have no formula
 * and return null.
 */
export function payFor(payUnit, rate, quantity) {
  switch (payUnit) {
    case "per_1000":
      return money(dec(quantity).times(rate).dividedBy(1000));
    case "per_lakh":
      return money(dec(quantity).times(rate).dividedBy(100_000));
    case "per_day":
    case "per_trip":
      return money(dec(quantity).times(rate));
    default:
      return null;
  }
}

/** A rate that prices work: set, and above zero. */
export const hasRate = (rate) => rate !== null && rate !== undefined && dec(rate).gt(0);

export const rateMissing = (workType) => new ApiError(400, `No rate is set for "${workType.name}" yet`);

/**
 * Splits `total` into `count` shares that add up to it exactly: everyone gets
 * the same to the paisa, and the leftover paise go one each to the first in
 * the list. ₹1,000 among 3 is 333.34, 333.33, 333.33.
 */
export function splitEqually(total, count) {
  const paise = dec(total).times(100);
  const base = paise.dividedToIntegerBy(count);
  const leftover = paise.minus(base.times(count)).toNumber();
  return Array.from({ length: count }, (_, i) =>
    money(base.plus(i < leftover ? 1 : 0).dividedBy(100)),
  );
}

/**
 * Turns one group of a brick count or unloading into one work entry per
 * worker. `units` is what the group's pay unit counts: bricks, or trips for
 * per_trip. The total comes from the rate unless it is a lump sum, which needs
 * `total_amount`. Amounts per worker may be set by hand, as long as they add
 * up to the total; otherwise the total is split equally.
 *
 * `rateFor(workType)` gives the rate to use: an edited entry keeps the rate
 * it was first made with, so a later rate change never alters past pay.
 */
export function resolveGroup(group, workType, { bricks, trips, rateFor, allowAmounts }) {
  if (!workType) throw new ApiError(400, "Unknown work type in groups");
  if (!workType.is_group) {
    throw new ApiError(400, `"${workType.name}" is not group work`);
  }

  const workerIds = group.workers.map((worker) => worker.worker_id);
  if (new Set(workerIds).size !== workerIds.length) {
    throw new ApiError(400, `A worker appears twice in "${workType.name}"`);
  }

  const handAmounts = group.workers.filter((worker) => worker.amount !== undefined);
  const setByHand = handAmounts.length > 0 || group.total_amount !== undefined;
  if (setByHand && !allowAmounts) {
    throw new ApiError(403, "Only the owner or munim can change how much is paid");
  }
  if (handAmounts.length > 0 && handAmounts.length !== group.workers.length) {
    throw new ApiError(400, `Give every worker's amount in "${workType.name}", or none`);
  }

  let quantity = null;
  let rate = null;
  let byRate = null;
  if (workType.pay_unit !== "lumpsum") {
    if (workType.pay_unit === "per_trip") {
      if (!trips) throw new ApiError(400, `"${workType.name}" is paid per trip: give the number of trips`);
      quantity = trips;
    } else {
      quantity = bricks;
    }
    rate = rateFor(workType);
    // Pay is never worked out from a missing rate: it is set the first time
    // the kind of work is used, or the amount is typed in by hand.
    if (!setByHand && !hasRate(rate)) throw rateMissing(workType);
    byRate = payFor(workType.pay_unit, rate, quantity);
  }

  // A total given by hand wins; amounts given per worker make the total;
  // otherwise the rate does.
  const total =
    group.total_amount ??
    (handAmounts.length > 0 ? money(sum(handAmounts.map((worker) => worker.amount))) : byRate);
  if (total === null) {
    throw new ApiError(400, `"${workType.name}" is a lump sum: give total_amount`);
  }

  const amounts =
    handAmounts.length > 0 ? group.workers.map((worker) => money(worker.amount)) : splitEqually(total, workerIds.length);
  if (!sum(amounts).eq(dec(total))) {
    throw new ApiError(400, `The amounts in "${workType.name}" must add up to ${money(total)}`);
  }

  return workerIds.map((workerId, i) => ({
    worker_id: workerId,
    work_type_id: workType.id,
    quantity,
    rate,
    amount: amounts[i],
    group_total: money(total),
    group_size: workerIds.length,
  }));
}
