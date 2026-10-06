import { addWorker, closeDb, createFactory, data, daysAgo, factoryClient, molder, setRates, signup, today, stacked } from "./helpers.js";

// Phase 2: selling bricks, credit with customers and suppliers, the truck
// and what the factory spends.
describe("sales, credit, trucks and expenses", () => {
  let f, types, kiln, truck;
  let dinesh, jagdish, kishan, suresh;

  beforeAll(async () => {
    const owner = await signup({ name: "Papa" });
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = await setRates(f);
    [kiln] = data(await f.get("/kilns", undefined, 200));
    truck = data(await f.post("/trucks", { number: "GJ05XX1234" }, 201));
    const ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh", { main_work: "loader" });
    jagdish = await addWorker(f, "Jagdish", { main_work: "loader" });
    kishan = await addWorker(f, "Kishan", { main_work: "loader" });
    suresh = await addWorker(f, "Suresh", { main_work: "driver", monthly_salary: 15000, salary_from: daysAgo(10) });

    // 40,000 fired bricks to sell.
    await f.post(
      "/brick-counts",
      {
        counted_on: daysAgo(20),
        reason: "kiln_by_workers",
        quantity: 40000,
        molder_id: ramesh.id,
        kiln_id: kiln.id,
        groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }] }, await stacked(f)],
      },
      201,
    );
    await f.post("/kiln-unloadings", { unloaded_on: daysAgo(15), kiln_id: kiln.id, quantity: 40000 }, 201);
  });

  afterAll(closeDb);

  const sale = (overrides) => ({
    sold_on: daysAgo(5),
    quantity: 4000,
    rate: 6500,
    paid_amount: 26000,
    delivery: "customer",
    ...overrides,
  });

  test("a cash sale needs no customer, but credit does", async () => {
    const cash = data(await f.post("/sales", sale({ customer_name: "Walk-in" }), 201));
    expect(cash).toMatchObject({ bricks_amount: "26000.00", total: "26000.00", due: "0.00", party_id: null });
    expect(data(await f.get("/reports/stock", undefined, 200)).fired).toBe(36000);

    await f.post("/sales", sale({ paid_amount: 20000 }), 400);
    const noPhone = await f.post("/sales", sale({ paid_amount: 20000, party: { name: "Patel bhai" } }), 400);
    expect(noPhone.body.message).toMatch(/phone/);
  });

  let patel;
  test("credit goes on the customer's account, and the market's total", async () => {
    const credit = data(
      await f.post(
        "/sales",
        sale({ quantity: 3000, rate: 6800, paid_amount: 15000, party: { name: "Patel bhai", phone: "9876543210" } }),
        201,
      ),
    );
    expect(credit).toMatchObject({ total: "20400.00", due: "5400.00", party_name: "Patel bhai", party_balance: "5400.00" });
    patel = credit.party_id;

    const received = data(
      await f.post(`/parties/${patel}/payments`, { kind: "received", paid_on: daysAgo(2), amount: 3000 }, 201),
    );
    expect(received.balance).toBe("2400.00");

    const owing = data(await f.get("/parties", { kind: "customer", with_balance: "true" }, 200));
    expect(owing.map((p) => [p.name, p.balance])).toEqual([["Patel bhai", "2400.00"]]);
    expect(data(await f.get("/reports/summary", undefined, 200)).credit).toMatchObject({ receivable: "2400.00" });
  });

  test("a customer who pays more has an advance, used by the next sale", async () => {
    await f.post(`/parties/${patel}/payments`, { kind: "received", paid_on: daysAgo(1), amount: 5000 }, 201);
    expect(data(await f.get(`/parties/${patel}`, undefined, 200)).balance).toBe("-2600.00");

    const next = data(await f.post("/sales", sale({ party_id: patel, quantity: 1000, paid_amount: 0 }), 201));
    // 1,000 × ₹6,500 = ₹6,500, less the ₹2,600 advance
    expect(next.party_balance).toBe("3900.00");

    const ledger = await f.get(`/parties/${patel}/ledger`, undefined, 200);
    expect(ledger.body.balance).toBe("3900.00");
    expect(data(ledger)).toHaveLength(4);
  });

  test("only the owner writes off, and only what is owed", async () => {
    await f.post(`/parties/${patel}/payments`, { kind: "writeoff", paid_on: today(), amount: 5000 }, 400);
    const done = data(await f.post(`/parties/${patel}/payments`, { kind: "writeoff", paid_on: today(), amount: 3900 }, 201));
    expect(done.balance).toBe("0.00");
  });

  test("the last rate is suggested for the next sale", async () => {
    expect(data(await f.get("/sales/last-rate", { party_id: patel }, 200))).toMatchObject({ rate: "6500.00" });
    const someone = data(await f.post("/parties", { kind: "customer", name: "New" }, 201));
    // No sale yet for them: the factory's last.
    expect(data(await f.get("/sales/last-rate", { party_id: someone.id }, 200)).rate).toBeDefined();
  });

  let truckSale;
  test("the own truck: trips, the driver, and the loaders paid per trip", async () => {
    await f.post("/sales", sale({ delivery: "own_truck" }), 400);
    truckSale = data(
      await f.post(
        "/sales",
        sale({
          delivery: "own_truck",
          truck_id: truck.id,
          driver_id: suresh.id,
          bhadu: 2500,
          paid_amount: 28500,
          destination: "Kamrej",
          groups: [
            {
              work_type_id: types.truck_loading.id,
              workers: [dinesh, jagdish, kishan].map((w) => ({ worker_id: w.id })),
            },
          ],
        }),
        201,
      ),
    );
    expect(truckSale).toMatchObject({ total: "28500.00", trips: 1, truck_number: "GJ05XX1234", driver_name: "Suresh" });
    expect(truckSale.groups[0]).toMatchObject({ total: "1500.00" });
    expect(truckSale.groups[0].workers.map((w) => w.amount)).toEqual(["500.00", "500.00", "500.00"]);
  });

  test("editing a sale keeps the loaders' rate it was made with", async () => {
    await f.patch(`/work-types/${types.truck_loading.id}`, { rate: 1800 }, 200);
    const { id, ...rest } = truckSale;
    const edited = data(
      await f.put(
        `/sales/${id}`,
        {
          sold_on: rest.sold_on,
          quantity: 4000,
          rate: 6500,
          bhadu: 2500,
          paid_amount: 28500,
          delivery: "own_truck",
          truck_id: truck.id,
          driver_id: suresh.id,
          trips: 2,
          groups: [{ work_type_id: types.truck_loading.id, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] }],
        },
        200,
      ),
    );
    // 2 trips × ₹1,500 (the rate on the day), shared by two
    expect(edited.groups[0]).toMatchObject({ total: "3000.00", rate: "1500.00" });
  });

  test("a hired truck's rent is owed to its owner", async () => {
    const hired = data(
      await f.post(
        "/sales",
        sale({ delivery: "hired", hire_party: { name: "Raju transport", phone: "9898989898" }, hire_amount: 2000 }),
        201,
      ),
    );
    const owner = data(await f.get(`/parties/${hired.hire_party_id}`, undefined, 200));
    expect(owner).toMatchObject({ kind: "supplier", balance: "-2000.00" });
  });

  test("selling more than is fired is allowed, with a warning; cancelling puts it back", async () => {
    const big = data(await f.post("/sales", sale({ quantity: 30000, rate: 6000, paid_amount: 180000 }), 201));
    expect(big.warnings).toEqual([expect.objectContaining({ code: "negative_stock", stage: "fired" })]);
    const cancelled = data(await f.post(`/sales/${big.id}/cancel`, { reason: "galat" }, 200));
    expect(cancelled.warnings).toEqual([]);
  });

  test("expenses: paid in full needs no supplier, credit does", async () => {
    const soil = data(await f.post("/expenses", { spent_on: daysAgo(3), category: "soil", amount: 15000 }, 201));
    expect(soil).toMatchObject({ paid_amount: "15000.00", due: "0.00", party_id: null });

    await f.post("/expenses", { spent_on: daysAgo(3), category: "coal", amount: 120000, paid_amount: 80000 }, 400);
    const coal = data(
      await f.post(
        "/expenses",
        { spent_on: daysAgo(3), category: "coal", quantity: 10, unit: "ton", amount: 120000, paid_amount: 80000, party: { name: "Shree Coal" } },
        201,
      ),
    );
    expect(coal).toMatchObject({ due: "40000.00", party_balance: "-40000.00" });

    const paid = data(await f.post(`/parties/${coal.party_id}/payments`, { kind: "paid", paid_on: today(), amount: 40000 }, 201));
    expect(paid.balance).toBe("0.00");

    await f.post("/expenses", { spent_on: today(), category: "soil", amount: 100, truck_id: truck.id }, 400);
    await f.post("/expenses", { spent_on: today(), category: "soil", amount: 100, litres: 10 }, 400);
  });

  test("the truck report: trips, delivery charge, diesel and its average", async () => {
    const diesel = (day, odometer, amount = 9000, litres = 100) =>
      f.post("/expenses", { spent_on: daysAgo(day), category: "diesel", truck_id: truck.id, amount, litres, odometer }, 201);
    await diesel(9, 45000);
    await diesel(6, 45600); // 600 km on 100 litres: 6 km/l
    await diesel(4, 46200); // 6 km/l again
    await diesel(1, 46650); // 450 km on 100 litres: 4.5 km/l, well below
    await f.post("/expenses", { spent_on: daysAgo(1), category: "truck_upkeep", truck_id: truck.id, amount: 18000, note: "tyre" }, 201);

    const report = data(await f.get(`/trucks/${truck.id}/report`, undefined, 200));
    expect(report.trips).toMatchObject({ sales: 2, kiln: 0, total: 2, without_bhadu: 0 });
    expect(report.earned.bhadu).toBe("2500.00");
    expect(report.costs).toMatchObject({ diesel: "36000.00", upkeep: "18000.00", loaders: "3000.00" });
    expect(report.profit).toBe("-54500.00");
    expect(report.fuel.map((fill) => fill.km_per_litre)).toEqual([null, "6.00", "6.00", "4.50"]);
    // The sale's two trips (5 days ago) fell between the fills 6 and 4 days ago.
    expect(report.fuel[2]).toMatchObject({ trips: 2, per_trip: "4500.00" });
    expect(report.warnings).toEqual([expect.objectContaining({ code: "low_average", km_per_litre: "4.50" })]);
  });

  test("a supervisor sees no sales, expenses or credit", async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth);
    const o = factoryClient(owner.auth, factory.id);
    const sup = await signup();
    await o.post("/members", { email: sup.user.email, role: "supervisor" }, 201);
    const s = factoryClient(sup.auth, factory.id);
    await s.get("/sales", undefined, 403);
    await s.post("/expenses", { spent_on: today(), category: "soil", amount: 100 }, 403);
    await s.get("/parties", undefined, 403);
  });
});
