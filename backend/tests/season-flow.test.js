import { addWorker, balanceOf, closeDb, createFactory, data, daysAgo, factoryClient, molder, per1000, setRates, signup, today, carried } from "./helpers.js";

// The planning walk-through: one ordinary season at the owner's kiln.
describe("an ordinary season", () => {
  let f;
  let types;
  let ramesh, dinesh, jagdish, mahesh, kishan, n1, n2;
  let kiln;

  beforeAll(async () => {
    const owner = await signup({ name: "Papa" });
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = await setRates(f);
    ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh", { main_work: "loader", ...per1000(100) });
    jagdish = await addWorker(f, "Jagdish", { main_work: "loader", ...per1000(100) });
    mahesh = await addWorker(f, "Mahesh", { main_work: "stacker", ...per1000(25) });
    kishan = await addWorker(f, "Kishan", { main_work: "unloader", ...per1000(120) });
    n1 = await addWorker(f, "Nikasi 1", { main_work: "unloader", ...per1000(120) });
    n2 = await addWorker(f, "Nikasi 2", { main_work: "unloader", ...per1000(120) });
    [kiln] = data(await f.get("/kilns", undefined, 200));
  });

  afterAll(closeDb);

  test("advances before any count leave the worker owing", async () => {
    await f.post(`/workers/${ramesh.id}/transactions`, { kind: "advance", txn_date: daysAgo(30), amount: 2000 }, 201);
    const res = await f.post(
      `/workers/${ramesh.id}/transactions`,
      { kind: "advance", txn_date: daysAgo(25), amount: 3000 },
      201,
    );
    expect(data(res).balance).toBe("-5000.00");
  });

  test("bricks counted on the drying ground pay the molder and add raw stock", async () => {
    const res = await f.post(
      "/brick-counts",
      { counted_on: daysAgo(20), reason: "drying_by_workers", groups: await carried(f), quantity: 18000, molder_id: ramesh.id },
      201,
    );
    expect(data(res).molder_pay).toMatchObject({ worker_id: ramesh.id, rate: "550.00", amount: "9900.00" });
    expect(await balanceOf(f, ramesh.id)).toBe("4900.00");
    expect(data(await f.get("/reports/stock", undefined, 200))).toMatchObject({ raw: 18000, kiln: 0, fired: 0 });
  });

  test("already counted bricks going into the kiln pay the loaders and khadkaniya, not the molder", async () => {
    const res = await f.post(
      "/brick-counts",
      {
        counted_on: daysAgo(12),
        reason: "kiln_by_workers",
        quantity: 18000,
        already_counted: true,
        kiln_id: kiln.id,
        groups: [
          { work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] },
          { work_type_id: types.stacking.id, workers: [{ worker_id: mahesh.id }] },
        ],
      },
      201,
    );
    const count = data(res);
    expect(count.molder_pay).toBeNull();
    expect(count.groups.find((g) => g.work_type_code === "kiln_loading")).toMatchObject({
      total: "1800.00",
      workers: expect.arrayContaining([expect.objectContaining({ worker_id: dinesh.id, amount: "900.00" })]),
    });
    expect(await balanceOf(f, ramesh.id)).toBe("4900.00");
    expect(await balanceOf(f, dinesh.id)).toBe("900.00");
    const stock = data(await f.get("/reports/stock", undefined, 200));
    expect(stock).toMatchObject({ raw: 0, kiln: 18000, fired: 0 });
    expect(stock.kilns).toEqual([expect.objectContaining({ id: kiln.id, name: "Bhatho 1", quantity: 18000 })]);
  });

  test("khadkaniya are paid for the bricks stacked, from the count, never by hand", async () => {
    // 18,000 bricks at ₹25 per 1000.
    expect(await balanceOf(f, mahesh.id)).toBe("450.00");
    await f.post(
      "/work-entries",
      { worker_id: mahesh.id, work_type_id: types.stacking.id, entry_date: daysAgo(12), quantity: 18000 },
      400,
    );
  });

  test("new bricks carried to the kiln by truck", async () => {
    const truck = data(await f.post("/trucks", { number: "gj-05-xx-1234" }, 201));
    expect(truck.number).toBe("GJ-05-XX-1234");

    const res = await f.post(
      "/brick-counts",
      {
        counted_on: daysAgo(10),
        reason: "kiln_by_truck",
        quantity: 22000,
        molder_id: ramesh.id,
        truck_id: truck.id,
        trips: 5,
        kiln_id: kiln.id,
        groups: [
          { work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }, { worker_id: jagdish.id }] },
          { work_type_id: types.stacking.id, workers: [{ worker_id: mahesh.id }] },
        ],
      },
      201,
    );
    expect(data(res)).toMatchObject({ truck_number: "GJ-05-XX-1234", trips: 5 });
    expect(await balanceOf(f, ramesh.id)).toBe("17000.00");
    expect(await balanceOf(f, dinesh.id)).toBe("2000.00");
    expect(data(await f.get("/reports/stock", undefined, 200)).kiln).toBe(40000);
  });

  test("nikasi moves bricks from the kiln to fired stock and pays the group", async () => {
    const res = await f.post(
      "/kiln-unloadings",
      {
        unloaded_on: daysAgo(5),
        kiln_id: kiln.id,
        quantity: 40000,
        groups: [
          {
            work_type_id: types.unloading.id,
            workers: [n1, n2, kishan, jagdish].map((worker) => ({ worker_id: worker.id })),
          },
        ],
      },
      201,
    );
    // 10,000 bricks each: three at ₹120 per 1000, Jagdish at his ₹100.
    expect(data(res).groups[0]).toMatchObject({ total: "4600.00" });
    expect(data(res).warnings).toEqual([]);
    expect(await balanceOf(f, n1.id)).toBe("1200.00");
    expect(data(await f.get("/reports/stock", undefined, 200))).toMatchObject({ raw: 0, kiln: 0, fired: 40000 });
  });

  test("day work and a lump sum typed in by hand", async () => {
    const day = data(
      await f.post(
        "/work-entries",
        { worker_id: kishan.id, work_type_id: types.daily.id, entry_date: daysAgo(4), quantity: 6 },
        201,
      ),
    );
    expect(day).toMatchObject({ quantity: "6.000", rate: "400.00", amount: "2400.00" });

    const lump = data(
      await f.post(
        "/work-entries",
        { worker_id: dinesh.id, work_type_id: types.lumpsum.id, entry_date: daysAgo(4), amount: 150, note: "thaki gayo" },
        201,
      ),
    );
    expect(lump.amount).toBe("150.00");
    expect(await balanceOf(f, dinesh.id)).toBe("2150.00");

    // A day paid more than the rate.
    const extra = data(
      await f.post(
        "/work-entries",
        { worker_id: kishan.id, work_type_id: types.daily.id, entry_date: daysAgo(3), quantity: 1, amount: 150 },
        201,
      ),
    );
    expect(extra).toMatchObject({ rate: "400.00", amount: "150.00" });

    await f.post("/work-entries", { worker_id: kishan.id, work_type_id: types.salary.id, entry_date: today(), quantity: 1 }, 400);
  });

  test("a molder's new rate applies to new counts only, even when an old count is edited", async () => {
    await f.patch(`/workers/${ramesh.id}`, { rate: 600 }, 200);

    const counts = data(await f.get("/brick-counts", { reason: "drying_by_workers" }, 200));
    const drying = counts[0];
    const edited = data(
      await f.put(
        `/brick-counts/${drying.id}`,
        { counted_on: drying.counted_on, reason: "drying_by_workers", groups: await carried(f), quantity: 18500, molder_id: ramesh.id },
        200,
      ),
    );
    expect(edited.molder_pay).toMatchObject({ rate: "550.00", amount: "10175.00" });

    const fresh = data(
      await f.post("/brick-counts", { counted_on: daysAgo(2), reason: "drying_by_workers", groups: await carried(f), quantity: 1000, molder_id: ramesh.id }, 201),
    );
    expect(fresh.molder_pay).toMatchObject({ rate: "600.00", amount: "600.00" });
    // 17000 + 275 (edit) + 600 (new count)
    expect(await balanceOf(f, ramesh.id)).toBe("17875.00");
  });

  test("the ledger lists every line and adds up", async () => {
    const res = await f.get(`/workers/${ramesh.id}/ledger`, undefined, 200);
    expect(res.body.balance).toBe("17875.00");
    expect(res.body.totals).toMatchObject({ earned: "22875.00", advances: "5000.00", net: "17875.00" });
    expect(data(res)).toHaveLength(5);
    expect(data(res)[0]).toMatchObject({ entry_kind: "work", work_type_code: "molding" });
  });

  test("settling pays the worker off", async () => {
    const res = await f.post(
      `/workers/${ramesh.id}/transactions`,
      { kind: "settlement", txn_date: today(), amount: 17875 },
      201,
    );
    expect(data(res).balance).toBe("0.00");
  });

  test("a cancelled count takes its pay and stock away", async () => {
    const fresh = data(
      await f.post("/brick-counts", { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 5000, molder_id: ramesh.id }, 201),
    );
    expect(await balanceOf(f, ramesh.id)).toBe("3000.00");
    const cancelled = data(await f.post(`/brick-counts/${fresh.id}/cancel`, { reason: "galat ginti" }, 200));
    expect(cancelled.cancelled_at).not.toBeNull();
    expect(await balanceOf(f, ramesh.id)).toBe("0.00");
    await f.put(
      `/brick-counts/${fresh.id}`,
      { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 5000, molder_id: ramesh.id },
      409,
    );
  });

  test("more bricks out than in the kiln is allowed, with a warning", async () => {
    const res = await f.post("/kiln-unloadings", { unloaded_on: today(), kiln_id: kiln.id, quantity: 3000 }, 201);
    expect(data(res).warnings).toEqual([
      { code: "negative_stock", stage: "kiln", kiln_id: kiln.id, kiln_name: "Bhatho 1", quantity: -3000 },
    ]);
    await f.post("/kiln-unloadings", { unloaded_on: today(), quantity: 3000 }, 400);
    await f.post(`/kiln-unloadings/${data(res).id}/cancel`, {}, 200);
  });

  test("bad counts are refused", async () => {
    await f.post("/brick-counts", { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 100 }, 400);
    await f.post(
      "/brick-counts",
      { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 100, molder_id: ramesh.id, already_counted: true },
      400,
    );
    await f.post(
      "/brick-counts",
      { counted_on: daysAgo(-1), reason: "drying_by_workers", groups: await carried(f), quantity: 100, molder_id: ramesh.id },
      400,
    );
    await f.post(
      "/brick-counts",
      { counted_on: daysAgo(400), reason: "drying_by_workers", groups: await carried(f), quantity: 100, molder_id: ramesh.id },
      400,
    );
    await f.post(
      "/brick-counts",
      {
        counted_on: today(),
        reason: "kiln_by_workers",
        quantity: 100,
        molder_id: ramesh.id,
        kiln_id: kiln.id,
        groups: [{ work_type_id: types.daily.id, workers: [{ worker_id: kishan.id }] }],
      },
      400,
    );
    // Into a kiln: the molder, who put them in and which kiln are all needed.
    const intoKiln = {
      counted_on: today(),
      reason: "kiln_by_workers",
      quantity: 100,
      molder_id: ramesh.id,
      kiln_id: kiln.id,
      groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }] }, { work_type_id: types.stacking.id, workers: [{ worker_id: mahesh.id }] }],
    };
    await f.post("/brick-counts", { ...intoKiln, molder_id: undefined }, 400);
    await f.post("/brick-counts", { ...intoKiln, groups: [] }, 400);
    await f.post("/brick-counts", { ...intoKiln, kiln_id: undefined }, 400);
    // Khadkaniya are needed going into the kiln, and loaders besides them.
    await f.post("/brick-counts", { ...intoKiln, groups: [intoKiln.groups[0]] }, 400);
    await f.post("/brick-counts", { ...intoKiln, groups: [intoKiln.groups[1]] }, 400);
    // Bricks carried to dry pay no khadkaniya.
    await f.post(
      "/brick-counts",
      { ...intoKiln, reason: "drying_by_workers", kiln_id: undefined, groups: [...(await carried(f)), intoKiln.groups[1]] },
      400,
    );
  });

  test("the summary adds everything up", async () => {
    const summary = data(await f.get("/reports/summary", undefined, 200));
    expect(summary.period.kind).toBe("season");
    // 18,500 dried (after the edit) - 18,000 into the kiln + 1,000 dried later
    expect(summary.stock).toMatchObject({ raw: 1500, kiln: 0, fired: 40000 });
    expect(summary.bricks.made_in_period).toBe(41500);
    expect(Number(summary.workers.payable)).toBeGreaterThan(0);
  });
});
