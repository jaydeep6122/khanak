import { addWorker, balanceOf, closeDb, createFactory, data, factoryClient, molder, per1000, perDay, setRates, signup, today, carried } from "./helpers.js";

// Every worker has a main kind of work and rates of their own, per 1000
// bricks or per day. A driver has a monthly salary instead.
describe("main work and each worker's own rate", () => {
  let f, types;

  beforeAll(async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = await setRates(f);
  });

  afterAll(closeDb);

  test("a worker cannot be added without what they are paid", async () => {
    await f.post("/workers", { name: "No kind", ...per1000(100) }, 400);
    const noRate = await f.post("/workers", { name: "Ramesh", main_work: "molder" }, 400);
    expect(noRate.body.message).toMatch(/rate per 1000 bricks, per day, or both/);
    await f.post("/workers", { name: "Dinesh", main_work: "stacker" }, 400);
    await f.post("/workers", { name: "Kishan", main_work: "loader", brick_rate: 0 }, 400);
    await f.post("/workers", { name: "Kishan", main_work: "loader", day_rate: -400 }, 400);
    await f.post("/workers", { name: "Suresh", main_work: "driver" }, 400);
    await f.post(
      "/workers",
      { name: "Suresh", main_work: "driver", monthly_salary: 15000, salary_from: today(), ...perDay(400) },
      400,
    );
    const driver = data(
      await f.post("/workers", { name: "Suresh", main_work: "driver", monthly_salary: 15000, salary_from: today() }, 201),
    );
    expect(driver).toMatchObject({ brick_rate: null, day_rate: null });
  });

  test("a worker may have both rates, and they need not match", async () => {
    const both = await addWorker(f, "Bhikha", { main_work: "loader", brick_rate: 250, day_rate: 300 });
    expect(both).toMatchObject({ brick_rate: "250.00", day_rate: "300.00" });
    const paatla = await addWorker(f, "Paatla 2", molder(550));
    const count = data(
      await f.post(
        "/brick-counts",
        {
          counted_on: today(),
          reason: "drying_by_workers",
          quantity: 10000,
          molder_id: paatla.id,
          groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: both.id }] }],
        },
        201,
      ),
    );
    // Brick work at ₹250 per 1000, a day's work at ₹300.
    expect(count.groups[0].workers[0]).toMatchObject({ rate: "250.00", amount: "2500.00" });
    const day = data(
      await f.post("/work-entries", { worker_id: both.id, work_type_id: types.daily.id, entry_date: today(), quantity: 1 }, 201),
    );
    expect(day).toMatchObject({ rate: "300.00", amount: "300.00" });
    expect(await balanceOf(f, both.id)).toBe("2800.00");
  });

  test("two molders are paid at their own rates", async () => {
    const ramesh = await addWorker(f, "Ramesh", molder(550));
    const mukesh = await addWorker(f, "Mukesh", molder(600));
    expect(ramesh).toMatchObject({ main_work: "molder", brick_rate: "550.00", day_rate: null });

    const groups = await carried(f);
    const count = (molderId) =>
      f.post("/brick-counts", { counted_on: today(), reason: "drying_by_workers", groups, quantity: 10000, molder_id: molderId }, 201);
    expect(data(await count(ramesh.id)).molder_pay.amount).toBe("5500.00");
    const mukeshCount = data(await count(mukesh.id));
    expect(mukeshCount.molder_pay.amount).toBe("6000.00");

    // The bricks were Ramesh's after all: his rate, not Mukesh's.
    const fixed = data(
      await f.put(
        `/brick-counts/${mukeshCount.id}`,
        { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 10000, molder_id: ramesh.id },
        200,
      ),
    );
    expect(fixed.molder_pay).toMatchObject({ worker_id: ramesh.id, rate: "550.00", amount: "5500.00" });
    expect(await balanceOf(f, mukesh.id)).toBe("0.00");
  });

  test("a group shares the bricks, each at their own rate", async () => {
    const molderOf = await addWorker(f, "Paatla", molder(550));
    const dinesh = await addWorker(f, "Dinesh", { main_work: "loader", ...per1000(100) });
    const jagdish = await addWorker(f, "Jagdish", { main_work: "loader", ...per1000(120) });
    const count = data(
      await f.post(
        "/brick-counts",
        {
          counted_on: today(),
          reason: "drying_by_workers",
          quantity: 10000,
          molder_id: molderOf.id,
          groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] }],
        },
        201,
      ),
    );
    // 5,000 bricks each: ₹500 at ₹100, ₹600 at ₹120.
    expect(count.groups[0].total).toBe("1100.00");
    expect(await balanceOf(f, dinesh.id)).toBe("500.00");
    expect(await balanceOf(f, jagdish.id)).toBe("600.00");

    // A raise applies to new counts; the old count keeps its rates.
    await f.patch(`/workers/${dinesh.id}`, { brick_rate: 200 }, 200);
    const again = data(
      await f.put(
        `/brick-counts/${count.id}`,
        {
          counted_on: today(),
          reason: "drying_by_workers",
          quantity: 10000,
          molder_id: molderOf.id,
          groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] }],
        },
        200,
      ),
    );
    expect(again.groups[0].total).toBe("1100.00");
  });

  test("a day worker's own rate prices their days", async () => {
    const kishan = await addWorker(f, "Kishan", { main_work: "daily", ...perDay(450) });
    const entry = data(
      await f.post(
        "/work-entries",
        { worker_id: kishan.id, work_type_id: types.daily.id, entry_date: today(), quantity: 2 },
        201,
      ),
    );
    expect(entry).toMatchObject({ rate: "450.00", amount: "900.00" });

    // Someone paid by the bricks doing a day's work gets the factory's day rate.
    const other = await addWorker(f, "Other");
    const theirs = data(
      await f.post(
        "/work-entries",
        { worker_id: other.id, work_type_id: types.daily.id, entry_date: today(), quantity: 1 },
        201,
      ),
    );
    expect(theirs.rate).toBe("400.00");
  });

  test("a worker keeps their rate when their main work changes; a driver has none", async () => {
    const worker = await addWorker(f, "Jagdish", molder(500));
    const moved = data(await f.patch(`/workers/${worker.id}`, { main_work: "loader" }, 200));
    expect(moved).toMatchObject({ main_work: "loader", brick_rate: "500.00" });
    await f.patch(`/workers/${worker.id}`, { main_work: "driver" }, 400);
    const driver = data(
      await f.patch(`/workers/${worker.id}`, { main_work: "driver", monthly_salary: 12000, salary_from: today() }, 200),
    );
    expect(driver).toMatchObject({ brick_rate: null, day_rate: null });
    await f.patch(`/workers/${worker.id}`, { main_work: "loader" }, 400);
  });

  test("the list can be cut by main work", async () => {
    await addWorker(f, "Mahesh", { main_work: "stacker" });
    const stackers = data(await f.get("/workers", { main_work: "stacker" }, 200));
    expect(stackers.map((w) => w.name)).toEqual(["Mahesh"]);
  });
});
