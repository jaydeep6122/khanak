import { addWorker, closeDb, createFactory, data, factoryClient, molder, per1000, perDay, signup, today } from "./helpers.js";

// No pay is worked out from a missing rate. Brick work is paid at each
// worker's own rate, set when the worker is added; other kinds of work keep
// a rate of their own, set the first time they are used by the owner or
// munim. Or the amount is typed in by hand.
describe("a rate is needed before work is priced", () => {
  let f, m, s;
  let types;
  let ramesh, dinesh, mahesh;

  beforeAll(async () => {
    const owner = await signup({ name: "Papa" });
    const factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = Object.fromEntries(data(await f.get("/work-types", undefined, 200)).map((type) => [type.code, type]));
    ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh", { main_work: "loader", ...per1000(60) });
    mahesh = await addWorker(f, "Mahesh");

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
  const carriers = () => [{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: dinesh.id }] }];

  test("brick work has no rate of its own: it is per 1000 at each worker's rate", () => {
    for (const code of ["molding", "kiln_loading", "stacking", "unloading"]) {
      expect(types[code]).toMatchObject({ pay_unit: "per_1000", rate: null });
    }
  });

  test("everyone, the supervisor too, is paid at the worker's own rate", async () => {
    const saved = data(await s.post("/brick-counts", count(carriers()), 201));
    expect(saved.molder_pay).toMatchObject({ rate: "550.00", amount: "5500.00" });
    expect(saved.groups[0]).toMatchObject({ total: "600.00" });
    expect(saved.groups[0].workers[0]).toMatchObject({ rate: "60.00", quantity: "10000.000", amount: "600.00" });
  });

  test("the owner or munim may type the amount by hand instead", async () => {
    const groups = [{ ...carriers()[0], total_amount: 500 }];
    const saved = data(await m.post("/brick-counts", count(groups), 201));
    expect(saved.groups[0]).toMatchObject({ total: "500.00" });
  });

  test("a kind of work with a rate of its own needs it before it is used", async () => {
    const body = { worker_id: mahesh.id, work_type_id: types.lumpsum.id, entry_date: today(), amount: 100 };
    await f.post("/work-entries", body, 201);
    const trip = { ...body, work_type_id: types.truck_loading.id, quantity: 1, amount: undefined };
    await f.post("/work-entries", trip, 400);
    await s.patch(`/work-types/${types.truck_loading.id}`, { rate: 1500 }, 403);
    await m.patch(`/work-types/${types.truck_loading.id}`, { rate: 0 }, 400);
    await m.patch(`/work-types/${types.truck_loading.id}`, { name: "Gaadi" }, 403);
    await m.patch(`/work-types/${types.truck_loading.id}`, { rate: 1500 }, 200);
    await f.post("/work-entries", trip, 201);
  });

  test("brick work cannot be given a rate of its own", async () => {
    await f.patch(`/work-types/${types.kiln_loading.id}`, { rate: 60 }, 400);
  });

  test("a worker paid by the day is never paid a group's share", async () => {
    const roj = data(await f.post("/workers", { name: "Roj Bharai", main_work: "loader", ...perDay(400) }, 201));
    const res = await f.post("/brick-counts", count([{ work_type_id: types.kiln_loading.id, workers: [{ worker_id: roj.id }] }]), 400);
    expect(res.body.message).toMatch(/paid by the day/);
    // Their days are typed in as day work, at their own day rate.
    const entry = data(
      await f.post(
        "/work-entries",
        { worker_id: roj.id, work_type_id: types.daily.id, entry_date: today(), quantity: 2 },
        201,
      ),
    );
    expect(entry).toMatchObject({ rate: "400.00", amount: "800.00" });
  });

  test("a molder paid by the day earns nothing from counts", async () => {
    const roj = data(await f.post("/workers", { name: "Roj Paatla", main_work: "molder", ...perDay(500) }, 201));
    const saved = data(await f.post("/brick-counts", { ...count(carriers()), molder_id: roj.id }, 201));
    expect(saved.molder_pay).toBeNull();
  });
});
