import { addWorker, balanceOf, closeDb, createFactory, data, factoryClient, molder, setRates, signup, today } from "./helpers.js";

// Every worker has a main kind of work, and molders and day workers each
// have their own rate.
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
    await f.post("/workers", { name: "No kind" }, 400);
    const noRate = await f.post("/workers", { name: "Ramesh", main_work: "molder" }, 400);
    expect(noRate.body.message).toMatch(/rate per 1000 bricks/);
    await f.post("/workers", { name: "Kishan", main_work: "daily" }, 400);
    await f.post("/workers", { name: "Suresh", main_work: "driver" }, 400);
    // Group work is paid at the group's rate, never a worker's own.
    await f.post("/workers", { name: "Dinesh", main_work: "loader", rate: 100 }, 400);
  });

  test("two molders are paid at their own rates", async () => {
    const ramesh = await addWorker(f, "Ramesh", molder(550));
    const mukesh = await addWorker(f, "Mukesh", molder(600));
    expect(ramesh).toMatchObject({ main_work: "molder", rate: "550.00" });

    const count = (molderId) =>
      f.post("/brick-counts", { counted_on: today(), reason: "drying", quantity: 10000, molder_id: molderId }, 201);
    expect(data(await count(ramesh.id)).molder_pay.amount).toBe("5500.00");
    const mukeshCount = data(await count(mukesh.id));
    expect(mukeshCount.molder_pay.amount).toBe("6000.00");

    // The bricks were Ramesh's after all: his rate, not Mukesh's.
    const fixed = data(
      await f.put(
        `/brick-counts/${mukeshCount.id}`,
        { counted_on: today(), reason: "drying", quantity: 10000, molder_id: ramesh.id },
        200,
      ),
    );
    expect(fixed.molder_pay).toMatchObject({ worker_id: ramesh.id, rate: "550.00", amount: "5500.00" });
    expect(await balanceOf(f, mukesh.id)).toBe("0.00");
  });

  test("a day worker's own rate prices their days", async () => {
    const kishan = await addWorker(f, "Kishan", { main_work: "daily", rate: 450 });
    const entry = data(
      await f.post(
        "/work-entries",
        { worker_id: kishan.id, work_type_id: types.daily.id, entry_date: today(), quantity: 2 },
        201,
      ),
    );
    expect(entry).toMatchObject({ rate: "450.00", amount: "900.00" });

    // Someone else doing a day's work gets the factory's day rate.
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

  test("moving a molder to group work drops their own rate", async () => {
    const worker = await addWorker(f, "Jagdish", molder(500));
    const moved = data(await f.patch(`/workers/${worker.id}`, { main_work: "loader" }, 200));
    expect(moved).toMatchObject({ main_work: "loader", rate: null });
    await f.patch(`/workers/${worker.id}`, { main_work: "molder" }, 400);
  });

  test("the list can be cut by main work", async () => {
    await addWorker(f, "Mahesh", { main_work: "stacker" });
    const stackers = data(await f.get("/workers", { main_work: "stacker" }, 200));
    expect(stackers.map((w) => w.name)).toEqual(["Mahesh"]);
  });
});
