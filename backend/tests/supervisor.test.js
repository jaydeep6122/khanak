import {
  addWorker,
  balanceOf,
  closeDb,
  createFactory,
  data,
  factoryClient,
  molder,
  pool,
  setRates,
  signup,
  today, carried } from "./helpers.js";

// The owner is away; Mahesh (the khadkaniyo) runs the kiln as supervisor.
describe("a supervisor running the kiln", () => {
  let owner, f, s, types, factory;
  let ramesh, dinesh, mahesh, supervisorUser;

  beforeAll(async () => {
    owner = await signup({ name: "Papa" });
    factory = await createFactory(owner.auth);
    f = factoryClient(owner.auth, factory.id);
    types = await setRates(f);
    ramesh = await addWorker(f, "Ramesh", molder(550));
    dinesh = await addWorker(f, "Dinesh");
    mahesh = await addWorker(f, "Mahesh", { main_work: "stacker", nickname: "Khadkaniyo" });

    supervisorUser = await signup({ name: "Mahesh" });
    const member = data(
      await f.post("/members", { email: supervisorUser.user.email, role: "supervisor", worker_id: mahesh.id }, 201),
    );
    expect(member).toMatchObject({ role: "supervisor", worker_id: mahesh.id });
    s = factoryClient(supervisorUser.auth, factory.id);
  });

  afterAll(closeDb);

  test("only someone with an account can be added", async () => {
    await f.post("/members", { email: "nobody-here@example.com", role: "munim" }, 404);
  });

  test("the supervisor sees the factory with their role and their worker", async () => {
    const view = data(await s.get("", undefined, 200));
    expect(view).toMatchObject({ role: "supervisor", worker_id: mahesh.id });
  });

  test("owner hands over cash", async () => {
    const summary = data(
      await f.post(
        "/cash/handovers",
        { holder_id: supervisorUser.user.id, kind: "given", handover_date: today(), amount: 20000 },
        201,
      ),
    );
    expect(summary.in_hand).toBe("20000.00");
  });

  test("the supervisor enters a count at the set rates, but cannot set amounts", async () => {
    const [kiln] = data(await s.get("/kilns", undefined, 200));
    const body = {
      counted_on: today(),
      reason: "kiln_by_workers",
      quantity: 15000,
      molder_id: ramesh.id,
      kiln_id: kiln.id,
      groups: [
        { work_type_id: types.kiln_loading.id, workers: [{ worker_id: mahesh.id }] },
        { work_type_id: types.stacking.id, workers: [{ worker_id: mahesh.id }] },
      ],
    };
    const count = data(await s.post("/brick-counts", body, 201));
    expect(count).toMatchObject({ kiln_name: "Bhatho 1" });
    expect(count.groups[0].workers[0].amount).toBe("1500.00");

    await s.post("/brick-counts", { ...body, molder_amount: 99999 }, 403);
    await s.post(
      "/brick-counts",
      { ...body, groups: [{ work_type_id: types.kiln_loading.id, total_amount: 5000, workers: [{ worker_id: mahesh.id }] }, body.groups[1]] },
      403,
    );
  });

  test("advances come out of the supervisor's cash; never to themselves", async () => {
    await s.post(`/workers/${ramesh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 12000 }, 201);
    const last = data(
      await s.post(`/workers/${dinesh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 8500 }, 201),
    );
    expect(last.cash_holder_id).toBe(supervisorUser.user.id);

    await s.post(`/workers/${mahesh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 500 }, 403);
    await s.post(`/workers/${ramesh.id}/transactions`, { kind: "settlement", txn_date: today(), amount: 100 }, 403);

    const cash = data(await s.get(`/cash/${supervisorUser.user.id}`, undefined, 200));
    expect(cash).toMatchObject({ given: "20000.00", advances_paid: "20500.00", in_hand: "-500.00" });
    expect(cash.lines).toHaveLength(3);
  });

  test("what the supervisor can and cannot see", async () => {
    const list = data(await s.get("/workers", undefined, 200));
    expect(list[0]).not.toHaveProperty("balance");
    expect(list[0]).not.toHaveProperty("phone");

    // Before an advance: the balance number only.
    expect(data(await s.get(`/workers/${ramesh.id}/balance`, undefined, 200)).balance).toBe("-3750.00");
    await s.get(`/workers/${ramesh.id}/ledger`, undefined, 404);
    await s.get(`/workers/${ramesh.id}`, undefined, 404);

    // Their own account is open to them.
    const own = await s.get(`/workers/${mahesh.id}/ledger`, undefined, 200);
    // ₹1,500 loading and ₹375 stacking (15,000 bricks at ₹2,500 a lakh).
    expect(own.body.balance).toBe("1875.00");

    await s.get("/reports/summary", undefined, 403);
    await s.get("/reports/stock", undefined, 403);
    await s.get("/members", undefined, 403);
    await s.post("/workers", { name: "New" }, 403);
    await s.post("/work-entries", { worker_id: ramesh.id, work_type_id: types.daily.id, entry_date: today(), quantity: 1 }, 403);
    await s.get(`/cash/${owner.user.id}`, undefined, 404);
  });

  test("the supervisor changes only their own entries, the same day", async () => {
    const owners = data(
      await f.post("/brick-counts", { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 1000, molder_id: ramesh.id }, 201),
    );
    await s.get(`/brick-counts/${owners.id}`, undefined, 404);
    await s.post(`/brick-counts/${owners.id}/cancel`, {}, 403);

    const mine = data(
      await s.post("/brick-counts", { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 51000, molder_id: ramesh.id }, 201),
    );
    const fixed = data(
      await s.put(`/brick-counts/${mine.id}`, { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 15000, molder_id: ramesh.id }, 200),
    );
    expect(fixed.quantity).toBe(15000);

    // The next day it is too late.
    await pool.query("UPDATE brick_counts SET created_at = now() - interval '2 days' WHERE id = $1", [mine.id]);
    await s.put(`/brick-counts/${mine.id}`, { counted_on: today(), reason: "drying_by_workers", groups: await carried(f), quantity: 1, molder_id: ramesh.id }, 403);
    // The owner still can.
    await f.post(`/brick-counts/${mine.id}/cancel`, { reason: "duplicate" }, 200);

    const listed = data(await s.get("/brick-counts", undefined, 200));
    expect(listed.every((count) => count.created_by === supervisorUser.user.id)).toBe(true);
  });

  test("the owner sees what the supervisor entered today", async () => {
    const activity = data(await f.get("/reports/activity", { user_id: supervisorUser.user.id }, 200));
    expect(activity.length).toBeGreaterThan(0);
    expect(activity.every((row) => row.user_name === "Mahesh")).toBe(true);
  });

  test("settling the cash pays back what the supervisor spent", async () => {
    const settled = data(await f.post(`/cash/${supervisorUser.user.id}/settle`, {}, 200));
    expect(settled.in_hand).toBe("0.00");
    await f.post(`/cash/${supervisorUser.user.id}/settle`, {}, 409);
  });

  test("only the owner writes off, and only what is owed", async () => {
    const owed = await balanceOf(f, dinesh.id);
    expect(owed).toBe("-8500.00");
    await f.post(`/workers/${dinesh.id}/transactions`, { kind: "writeoff", txn_date: today(), amount: 9000 }, 400);
    await s.post(`/workers/${dinesh.id}/transactions`, { kind: "writeoff", txn_date: today(), amount: 100 }, 403);
    const res = data(
      await f.post(`/workers/${dinesh.id}/transactions`, { kind: "writeoff", txn_date: today(), amount: 8500, note: "bhagi gayo" }, 201),
    );
    expect(res.balance).toBe("0.00");
  });

  test("a removed supervisor loses access", async () => {
    await f.del(`/members/${supervisorUser.user.id}`, undefined, 200);
    await s.get("", undefined, 404);
  });
});
