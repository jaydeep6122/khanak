import { payFor, resolveGroup, splitEqually } from "../src/services/pay.js";
import { salaryMonths } from "../src/services/salaries.js";

describe("payFor", () => {
  test("per 1000 and per lakh bricks", () => {
    expect(payFor("per_1000", "550", 22000)).toBe("12100.00");
    expect(payFor("per_1000", "550", 18500)).toBe("10175.00");
    expect(payFor("per_lakh", "2500", 22000)).toBe("550.00");
    expect(payFor("per_lakh", "2500", 550000)).toBe("13750.00");
  });

  test("days and trips", () => {
    expect(payFor("per_day", "400", "6")).toBe("2400.00");
    expect(payFor("per_day", "400", "0.5")).toBe("200.00");
    expect(payFor("per_trip", "1500", 1)).toBe("1500.00");
  });

  test("lump sums and monthly pay have no formula", () => {
    expect(payFor("lumpsum", null, 1)).toBeNull();
    expect(payFor("per_month", null, 1)).toBeNull();
  });
});

describe("splitEqually", () => {
  test("shares add up exactly, leftover paise go to the first workers", () => {
    expect(splitEqually("1000", 3)).toEqual(["333.34", "333.33", "333.33"]);
    expect(splitEqually("2200", 2)).toEqual(["1100.00", "1100.00"]);
    expect(splitEqually("0.05", 3)).toEqual(["0.02", "0.02", "0.01"]);
  });
});

describe("resolveGroup", () => {
  const loading = { id: "t1", name: "Kiln loading", pay_unit: "per_1000", rate: null, is_group: true };
  const custom = { id: "t3", name: "Patthar", pay_unit: "per_1000", rate: "100", is_group: true };
  const truck = { id: "t2", name: "Truck loading", pay_unit: "per_trip", rate: "1500", is_group: true };
  const own = { a: "100", b: "100", c: "120" };
  const options = {
    bricks: 22000,
    trips: null,
    rateFor: (type) => type.rate,
    workerRate: (type, workerId) => ({ name: workerId, rate: own[workerId] ?? null }),
    allowAmounts: true,
  };

  test("no rate of its own: the bricks are shared equally, each paid at their own rate", () => {
    const rows = resolveGroup({ workers: [{ worker_id: "a" }, { worker_id: "c" }] }, loading, options);
    // 11,000 bricks each: ₹100 and ₹120 per 1000.
    expect(rows.map((row) => row.amount)).toEqual(["1100.00", "1320.00"]);
    expect(rows[1]).toMatchObject({ quantity: "11000", rate: "120", group_total: "2420.00", group_size: 2 });
  });

  test("every worker's rate is needed, unless the amounts are typed in", () => {
    const group = { workers: [{ worker_id: "a" }, { worker_id: "nobody" }] };
    expect(() => resolveGroup(group, loading, options)).toThrow(/No rate per 1000 bricks is set for "nobody"/);
    const rows = resolveGroup({ ...group, total_amount: "1000" }, loading, options);
    expect(rows.map((row) => row.amount)).toEqual(["500.00", "500.00"]);
  });

  test("each worker's bricks, at their own rate, must add up to the bricks", () => {
    const group = { workers: [{ worker_id: "a", bricks: 15000 }, { worker_id: "c", bricks: 7000 }] };
    const rows = resolveGroup(group, loading, options);
    // 15,000 at ₹100 and 7,000 at ₹120 per 1000.
    expect(rows.map((row) => row.amount)).toEqual(["1500.00", "840.00"]);
    expect(rows.map((row) => row.quantity)).toEqual(["15000", "7000"]);
    expect(rows[0].group_total).toBe("2340.00");

    const short = { workers: [{ worker_id: "a", bricks: 15000 }, { worker_id: "c", bricks: 6000 }] };
    expect(() => resolveGroup(short, loading, options)).toThrow(/add up to 21000, not 22000/);
    const some = { workers: [{ worker_id: "a", bricks: 22000 }, { worker_id: "c" }] };
    expect(() => resolveGroup(some, loading, options)).toThrow(/every worker's bricks/);
    const trip = { workers: [{ worker_id: "a", bricks: 1 }] };
    expect(() => resolveGroup(trip, truck, { ...options, trips: 1 })).toThrow(/only for work paid at each worker's own rate/);
  });

  test("a kind with a rate of its own splits the rate's total equally", () => {
    const rows = resolveGroup({ workers: [{ worker_id: "a" }, { worker_id: "b" }] }, custom, options);
    expect(rows.map((row) => row.amount)).toEqual(["1100.00", "1100.00"]);
    expect(rows[0]).toMatchObject({ quantity: 22000, rate: "100", group_total: "2200.00", group_size: 2 });
  });

  test("per trip needs trips", () => {
    expect(() => resolveGroup({ workers: [{ worker_id: "a" }] }, truck, options)).toThrow(/per trip/);
    const rows = resolveGroup(
      { workers: [{ worker_id: "a" }, { worker_id: "b" }, { worker_id: "c" }] },
      truck,
      { ...options, trips: 1 },
    );
    expect(rows.map((row) => row.amount)).toEqual(["500.00", "500.00", "500.00"]);
  });

  test("amounts by hand must match a total given by hand", () => {
    const group = {
      total_amount: "1500",
      workers: [
        { worker_id: "a", amount: "1000" },
        { worker_id: "b", amount: "400" },
      ],
    };
    expect(() => resolveGroup(group, loading, options)).toThrow(/add up to 1500.00/);
  });

  test("amounts by hand without a total make the total", () => {
    const rows = resolveGroup(
      { workers: [{ worker_id: "a", amount: "1300" }, { worker_id: "b", amount: "900" }] },
      loading,
      options,
    );
    expect(rows.map((row) => row.group_total)).toEqual(["2200.00", "2200.00"]);
  });

  test("a supervisor cannot set amounts", () => {
    expect(() =>
      resolveGroup({ total_amount: "5000", workers: [{ worker_id: "a" }] }, loading, { ...options, allowAmounts: false }),
    ).toThrow(/owner or munim/);
  });

  test("a worker cannot appear twice", () => {
    expect(() => resolveGroup({ workers: [{ worker_id: "a" }, { worker_id: "a" }] }, loading, options)).toThrow(/twice/);
  });
});

describe("salaryMonths", () => {
  const driver = { monthly_salary: "15000.00", salary_from: "2026-07-16", left_on: null };

  test("only finished months, the first one by calendar days", () => {
    expect(salaryMonths(driver, "2026-10-05")).toEqual([
      { month: "2026-07-01", upTo: "2026-07-31", amount: "7741.94" },
      { month: "2026-08-01", upTo: "2026-08-31", amount: "15000.00" },
      { month: "2026-09-01", upTo: "2026-09-30", amount: "15000.00" },
    ]);
  });

  test("joined on the 16th of a 30-day month: half", () => {
    expect(salaryMonths({ ...driver, salary_from: "2026-09-16" }, "2026-10-05")).toEqual([
      { month: "2026-09-01", upTo: "2026-09-30", amount: "7500.00" },
    ]);
  });

  test("nothing before the first month ends", () => {
    expect(salaryMonths({ ...driver, salary_from: "2026-10-01" }, "2026-10-05")).toEqual([]);
  });

  test("a worker who left is paid up to the day they left", () => {
    expect(salaryMonths({ ...driver, salary_from: "2026-09-01", left_on: "2026-10-15" }, "2026-10-20")).toEqual([
      { month: "2026-09-01", upTo: "2026-09-30", amount: "15000.00" },
      { month: "2026-10-01", upTo: "2026-10-15", amount: "7258.06" },
    ]);
  });

  test("across a new year", () => {
    const months = salaryMonths({ ...driver, salary_from: "2026-12-01" }, "2027-02-10");
    expect(months.map((month) => month.month)).toEqual(["2026-12-01", "2027-01-01"]);
  });
});
