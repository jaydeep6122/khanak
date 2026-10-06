import { addWorker, balanceOf, closeDb, createFactory, data, factoryClient, molder, per1000, setRates, signup, today } from "./helpers.js";

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
    ramesh = await addWorker(f, "Ramesh", molder(550));
    // Carrying to dry is paid like loading the kiln, at each worker's rate.
    dinesh = await addWorker(f, "Dinesh", { main_work: "loader", ...per1000(60) });
    jagdish = await addWorker(f, "Jagdish", { main_work: "loader", ...per1000(60) });
    truck = data(await f.post("/trucks", { number: "GJ05AB1111" }, 201));
  });

  afterAll(closeDb);

  const carriers = (workTypeId) => [
    { work_type_id: workTypeId, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] },
  ];

  test("there is one kind of loading, per 1000 at each worker's rate, for drying and the kiln alike", () => {
    expect(types.kiln_loading).toMatchObject({ pay_unit: "per_1000", rate: null, is_group: true });
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

  test("each carrier's bricks may be given, and must add up to the count", async () => {
    const body = (counts) => ({
      counted_on: today(),
      reason: "drying_by_workers",
      quantity: 10000,
      molder_id: ramesh.id,
      groups: [
        {
          work_type_id: types.kiln_loading.id,
          workers: [
            { worker_id: dinesh.id, bricks: counts[0] },
            { worker_id: jagdish.id, bricks: counts[1] },
          ],
        },
      ],
    });
    const before = Number(await balanceOf(f, dinesh.id));
    const wrong = await f.post("/brick-counts", body([6000, 3000]), 400);
    expect(wrong.body.message).toMatch(/add up to 9000, not 10000/);
    const count = data(await f.post("/brick-counts", body([7000, 3000]), 201));
    // ₹60 per 1000: 7,000 → ₹420, 3,000 → ₹180.
    expect(count.groups[0]).toMatchObject({ total: "600.00" });
    expect(count.groups[0].workers.find((w) => w.worker_id === dinesh.id)).toMatchObject({
      quantity: "7000.000",
      amount: "420.00",
    });
    expect(Number(await balanceOf(f, dinesh.id)) - before).toBe(420);
  });
});
