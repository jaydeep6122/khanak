import { addWorker, balanceOf, closeDb, createFactory, data, factoryClient, molder, setRates, signup, today } from "./helpers.js";

// Bricks reach the drying ground carried by workers or by truck, and whoever
// carries them is paid, just like bricks going into a kiln.
describe("carrying bricks to dry", () => {
  let f;
  let types;
  let ramesh, dinesh, jagdish;
  let truck;

  beforeAll(async () => {
    const owner = await signup({ name: "Papa" });
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = await setRates(f);
    // Carrying to dry is paid at the one loading rate.
    await f.patch(`/work-types/${types.kiln_loading.id}`, { rate: 60 }, 200);
    ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh");
    jagdish = await addWorker(f, "Jagdish");
    truck = data(await f.post("/trucks", { number: "GJ05AB1111" }, 201));
  });

  afterAll(closeDb);

  const carriers = (workTypeId) => [
    { work_type_id: workTypeId, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] },
  ];

  test("there is one loading rate, per 1000 and shared, for drying and the kiln alike", () => {
    expect(types.kiln_loading).toMatchObject({ pay_unit: "per_1000", is_group: true });
    expect(types.drying_carry).toBeUndefined();
  });

  test("a drying count needs someone who carried the bricks", async () => {
    const body = { counted_on: today(), reason: "drying_by_workers", quantity: 10000, molder_id: ramesh.id };
    await f.post("/brick-counts", body, 400);
    await f.post("/brick-counts", { ...body, groups: [] }, 400);
  });

  test("workers who carried bricks to dry share the pay; the molder is paid too", async () => {
    const count = data(
      await f.post(
        "/brick-counts",
        {
          counted_on: today(),
          reason: "drying_by_workers",
          quantity: 10000,
          molder_id: ramesh.id,
          groups: carriers(types.kiln_loading.id),
        },
        201,
      ),
    );
    expect(count.molder_pay).toMatchObject({ amount: "5500.00" });
    expect(count.groups[0]).toMatchObject({ work_type_code: "kiln_loading", total: "600.00" });
    expect(await balanceOf(f, dinesh.id)).toBe("300.00");
    expect(data(await f.get("/reports/stock", undefined, 200))).toMatchObject({ raw: 10000 });
  });

  test("by truck: the truck and its trips are needed, and loaders can be paid per trip", async () => {
    const body = {
      counted_on: today(),
      reason: "drying_by_truck",
      quantity: 6000,
      molder_id: ramesh.id,
      groups: carriers(types.truck_loading.id),
    };
    await f.post("/brick-counts", body, 400);
    await f.post("/brick-counts", { ...body, truck_id: truck.id }, 400);

    const count = data(await f.post("/brick-counts", { ...body, truck_id: truck.id, trips: 2 }, 201));
    expect(count).toMatchObject({ reason: "drying_by_truck", truck_id: truck.id, trips: 2, kiln_id: null });
    // ₹1500 a trip, two trips, shared by two.
    expect(count.groups[0]).toMatchObject({ total: "3000.00" });
    expect(await balanceOf(f, jagdish.id)).toBe("1800.00");
    expect(data(await f.get("/reports/stock", undefined, 200))).toMatchObject({ raw: 16000 });
  });

  test("carried by workers takes no truck; the last count pays no carriers", async () => {
    await f.post(
      "/brick-counts",
      {
        counted_on: today(),
        reason: "drying_by_workers",
        quantity: 1000,
        molder_id: ramesh.id,
        truck_id: truck.id,
        trips: 1,
        groups: carriers(types.kiln_loading.id),
      },
      400,
    );
    await f.post(
      "/brick-counts",
      {
        counted_on: today(),
        reason: "final",
        quantity: 1000,
        molder_id: ramesh.id,
        groups: carriers(types.kiln_loading.id),
      },
      400,
    );
    await f.post("/brick-counts", { counted_on: today(), reason: "final", quantity: 1000, molder_id: ramesh.id }, 201);
  });

  test("the old reason name is gone", async () => {
    await f.post(
      "/brick-counts",
      { counted_on: today(), reason: "drying", quantity: 1000, molder_id: ramesh.id, groups: carriers(types.kiln_loading.id) },
      400,
    );
  });
});
