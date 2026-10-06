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
 * Brick work paid per 1000 bricks at each worker's own rate: a kind per 1000
 * with no rate of its own.
 */
export const paidAtOwnRate = (workType) => workType.pay_unit === "per_1000" && workType.rate == null;

export const workerRateMissing = (worker) =>
  new ApiError(400, `No rate per 1000 bricks is set for "${worker.name}" yet`);

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
 * Turns one group of a brick count, unloading or sale into one work entry per
 * worker. `units` is what the group's pay unit counts: bricks, or trips for
 * per_trip. Amounts per worker may be set by hand (every worker's, or none),
 * or a total set by hand is split equally. Otherwise:
 *
 * - work at each worker's own rate (see paidAtOwnRate): the bricks are
 *   shared equally, and each worker is paid
 *   their share at their own rate (`workerRate(workType, workerId)` gives
 *   `{ name, rate }`).
 * - other work: the total comes from the kind's rate (`rateFor(workType)`)
 *   and is split equally. A lump sum needs `total_amount`.
 *
 * Both rate lookups give the rate an edited entry was first made with, so a
 * later rate change never alters past pay.
 */
export function resolveGroup(group, workType, { bricks, trips, rateFor, workerRate, allowAmounts }) {
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

  if (paidAtOwnRate(workType)) return ownRateRows(group, workType, workerIds, { bricks, workerRate, setByHand });

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
  return groupEntries(workType, workerIds, amounts, total, () => ({ quantity, rate }));
}

/**
 * A group paid at each worker's own rate: their share of the bricks at it. A
 * worker's quantity is their share of the bricks, so their line reads
 * "2,500 × ₹100 / 1000".
 */
function ownRateRows(group, workType, workerIds, { bricks, workerRate, setByHand }) {
  const size = workerIds.length;
  const share = dec(bricks).dividedBy(size).toDecimalPlaces(3).toString();
  const workers = workerIds.map((workerId) => workerRate(workType, workerId));
  const rates = workers.map((worker) => (hasRate(worker.rate) ? worker.rate : null));
  // Pay is never worked out from a missing rate: the worker's rate is set on
  // the worker, or the amounts are typed in by hand.
  const missing = workers.find((worker) => !hasRate(worker.rate));
  if (!setByHand && missing) throw workerRateMissing(missing);
  let amounts;
  if (group.workers.some((worker) => worker.amount !== undefined)) {
    amounts = group.workers.map((worker) => money(worker.amount));
  } else if (group.total_amount !== undefined) {
    amounts = splitEqually(group.total_amount, size);
  } else {
    amounts = rates.map((rate) => money(dec(bricks).times(rate).dividedBy(1000 * size)));
  }
  const total = group.total_amount ?? money(sum(amounts));
  return groupEntries(workType, workerIds, amounts, total, (i) => ({
    quantity: share,
    rate: rates[i],
  }));
}

function groupEntries(workType, workerIds, amounts, total, quantityAndRate) {
  if (!sum(amounts).eq(dec(total))) {
    throw new ApiError(400, `The amounts in "${workType.name}" must add up to ${money(total)}`);
  }
  return workerIds.map((workerId, i) => ({
    worker_id: workerId,
    work_type_id: workType.id,
    ...quantityAndRate(i),
    amount: amounts[i],
    group_total: money(total),
    group_size: workerIds.length,
  }));
}
