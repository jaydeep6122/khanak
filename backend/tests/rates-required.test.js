import { addWorker, closeDb, createFactory, data, factoryClient, molder, signup, today, stacked } from "./helpers.js";

// No pay is worked out from a missing rate. There is no separate rates
// screen: a kind of work's rate is set the first time it is used, by the
// owner or munim, or the amount is typed in by hand.
describe("a rate is needed before work is priced", () => {
  let f, m, s;
  let types;
  let ramesh, dinesh, mahesh;
  let kiln;

  beforeAll(async () => {
    const owner = await signup({ name: "Papa" });
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = Object.fromEntries(data(await f.get("/work-types", undefined, 200)).map((type) => [type.code, type]));
    ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh");
    mahesh = await addWorker(f, "Mahesh");
    [kiln] = data(await f.get("/kilns", undefined, 200));

    const munim = await signup({ name: "Munim" });
    await f.post("/members", { email: munim.user.email, role: "munim" }, 201);
    m = factoryClient(munim.auth, factory.id);
    const supervisor = await signup({ name: "Mahesh" });
    await f.post("/members", { email: supervisor.user.email, role: "supervisor", worker_id: mahesh.id }, 201);
    s = factoryClient(supervisor.auth, factory.id);
  });

  afterAll(closeDb);

  const count = (groups) => ({
    counted_on: today(),
    reason: "drying_by_workers",
    quantity: 10000,
    molder_id: ramesh.id,
    groups,
  });
  const carriers = () => [{ work_type_id: types.drying_carry.id, workers: [{ worker_id: dinesh.id }] }];

  test("a group whose work has no rate yet cannot be paid from it", async () => {
    const res = await f.post("/brick-counts", count(carriers()), 400);
    expect(res.body.message).toContain("No rate is set");
  });

  test("the owner or munim may type the amount by hand instead", async () => {
    const groups = [{ ...carriers()[0], total_amount: 500 }];
    const saved = data(await f.post("/brick-counts", count(groups), 201));
    expect(saved.groups[0]).toMatchObject({ total: "500.00" });
  });

  test("a supervisor can neither set a rate nor get around it", async () => {
    await s.patch(`/work-types/${types.drying_carry.id}`, { rate: 60 }, 403);
    await s.post("/brick-counts", count(carriers()), 400);
  });

  test("the munim sets the rate when first needed, but nothing else about the work", async () => {
    await m.patch(`/work-types/${types.drying_carry.id}`, { rate: 0 }, 400);
    await m.patch(`/work-types/${types.drying_carry.id}`, { name: "Sukavani" }, 403);
    await m.patch(`/work-types/${types.drying_carry.id}`, { rate: 60 }, 200);
    const saved = data(await m.post("/brick-counts", count(carriers()), 201));
    expect(saved.groups[0]).toMatchObject({ rate: "60.00", total: "600.00" });
    // Now the supervisor's counts are priced too.
    await s.post("/brick-counts", count(carriers()), 201);
  });

  test("other work typed in needs a rate too, unless the amount is given", async () => {
    const body = { worker_id: dinesh.id, work_type_id: types.daily.id, entry_date: today(), quantity: 2 };
    await f.post("/work-entries", body, 400);
    await f.post("/work-entries", { ...body, amount: 2500 }, 201);
  });

  test("bricks going into the kiln need the loading rate", async () => {
    const body = {
      counted_on: today(),
      reason: "kiln_by_workers",
      quantity: 5000,
      already_counted: true,
      kiln_id: kiln.id,
      groups: [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }] }, await stacked(f)],
    };
    await f.post("/brick-counts", body, 400);
    await f.patch(`/work-types/${types.kiln_loading.id}`, { rate: 100 }, 200);
    await f.post("/brick-counts", body, 201);
  });

  describe("adding a worker who does group work", () => {
    let g, rates;

    beforeAll(async () => {
      const owner = await signup({ name: "Kaka" });
      const factory = await createFactory(owner.auth);
      g = factoryClient(owner.auth, factory.id);
      rates = Object.fromEntries(data(await g.get("/work-types", undefined, 200)).map((type) => [type.code, type]));
    });

    test("a khadkaniyo needs the stacking rate, given with them the first time", async () => {
      await g.post("/workers", { name: "Mahesh", main_work: "stacker" }, 400);
      await g.post(
        "/workers",
        { name: "Mahesh", main_work: "stacker", group_rates: [{ work_type_id: rates.stacking.id, rate: 2500 }] },
        201,
      );
      const stacking = data(await g.get("/work-types", undefined, 200)).find((type) => type.code === "stacking");
      expect(stacking.rate).toBe("2500.00");
      // Priced now: the next one is added without it.
      await g.post("/workers", { name: "Suresh", main_work: "stacker" }, 201);
    });

    test("a loader needs carrying to drying and kiln loading both; nothing is kept from a refused try", async () => {
      await g.post(
        "/workers",
        { name: "Dinesh", main_work: "loader", group_rates: [{ work_type_id: rates.kiln_loading.id, rate: 100 }] },
        400,
      );
      const kilnLoading = data(await g.get("/work-types", undefined, 200)).find((type) => type.code === "kiln_loading");
      expect(kilnLoading.rate).toBe("0.00");
      await g.post(
        "/workers",
        {
          name: "Dinesh",
          main_work: "loader",
          group_rates: [
            { work_type_id: rates.kiln_loading.id, rate: 100 },
            { work_type_id: rates.drying_carry.id, rate: 60 },
          ],
        },
        201,
      );
    });

    test("moving a worker to nikasi needs the nikasi rate", async () => {
      const kishan = data(await g.post("/workers", { name: "Kishan", main_work: "other" }, 201));
      await g.patch(`/workers/${kishan.id}`, { main_work: "unloader" }, 400);
      await g.patch(
        `/workers/${kishan.id}`,
        { main_work: "unloader", group_rates: [{ work_type_id: rates.unloading.id, rate: 120 }] },
        200,
      );
    });
  });
});
