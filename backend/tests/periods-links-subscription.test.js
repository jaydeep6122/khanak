import {
  addWorker,
  app,
  balanceOf,
  closeDb,
  createFactory,
  data,
  daysAgo,
  expectStatus,
  factoryClient,
  molder,
  pool,
  request,
  setRates,
  signup,
  today,
  uniqueEmail,
} from "./helpers.js";

afterAll(closeDb);

describe("a new factory", () => {
  test("starts in the off-season with a trial, default kinds of work and the creator as owner", async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth, { season_started_on: undefined });
    expect(factory).toMatchObject({ role: "owner", period: { kind: "off_season", started_on: today() } });
    expect(factory.subscription).toMatchObject({ plan_code: "trial", is_trial: true });

    const f = factoryClient(owner.auth, factory.id);
    const codes = data(await f.get("/work-types", undefined, 200)).map((type) => type.code);
    expect(codes).toEqual([
      "molding",
      "kiln_loading",
      "stacking",
      "unloading",
      "truck_loading",
      "daily",
      "salary",
      "lumpsum",
    ]);

    const list = data(await request(app).get("/v1/factories").set(owner.auth));
    expect(list.map((row) => row.id)).toContain(factory.id);
  });

  test("is invisible to anyone who is not a member", async () => {
    const owner = await signup();
    const stranger = await signup();
    const factory = await createFactory(owner.auth);
    await factoryClient(stranger.auth, factory.id).get("", undefined, 404);
    await factoryClient(stranger.auth, factory.id).get("/workers", undefined, 404);
  });
});

describe("seasons and the off-season", () => {
  let f, ramesh;

  beforeAll(async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth, { season_started_on: daysAgo(100) });
    f = factoryClient(owner.auth, factory.id);
    await setRates(f);
    ramesh = await addWorker(f, "Ramesh", molder(550));
  });

  test("ending the season opens the off-season; entries after it go there", async () => {
    await f.post("/brick-counts", { counted_on: daysAgo(40), reason: "drying", quantity: 10000, molder_id: ramesh.id }, 201);

    const switched = data(await f.post("/periods/end-season", { ended_on: daysAgo(30) }, 201));
    expect(switched.closed).toMatchObject({ kind: "season", ended_on: daysAgo(30) });
    expect(switched.opened).toMatchObject({ kind: "off_season", started_on: daysAgo(30) });
    await f.post("/periods/end-season", {}, 409);

    const advance = data(
      await f.post(`/workers/${ramesh.id}/transactions`, { kind: "advance", txn_date: daysAgo(20), amount: 3000 }, 201),
    );
    expect(advance.period_id).toBe(switched.opened.id);
    // The balance carries across: 5,500 earned in the season - 3,000 in the off-season.
    expect(advance.balance).toBe("2500.00");

    // A late entry for a day inside the season still goes to the season.
    const late = data(
      await f.post("/brick-counts", { counted_on: daysAgo(35), reason: "drying", quantity: 1000, molder_id: ramesh.id }, 201),
    );
    expect(late.period_id).toBe(switched.closed.id);
  });

  test("a new season starts where the off-season ends", async () => {
    await f.post("/periods/start-season", { started_on: daysAgo(40) }, 400);
    const switched = data(await f.post("/periods/start-season", { started_on: daysAgo(10), name: "2026-27" }, 201));
    expect(switched.opened).toMatchObject({ kind: "season", name: "2026-27" });

    const periods = data(await f.get("/periods", undefined, 200));
    expect(periods.map((period) => period.kind)).toEqual(["season", "off_season", "season"]);

    const ledger = await f.get(`/workers/${ramesh.id}/ledger`, { period_id: switched.closed.id }, 200);
    expect(data(ledger)).toHaveLength(1);
    expect(ledger.body.totals.advances).toBe("3000.00");
  });
});

describe("a driver on a monthly salary", () => {
  test("is paid for every finished month without anyone entering it, up to the day they leave", async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth, { season_started_on: daysAgo(200) });
    const f = factoryClient(owner.auth, factory.id);

    const [y, m] = today().split("-").map(Number);
    const firstOfMonth = (back) => new Date(Date.UTC(y, m - 1 - back, 1)).toISOString().slice(0, 10);
    const suresh = await addWorker(f, "Suresh", { main_work: "driver", monthly_salary: 15000, salary_from: firstOfMonth(3) });
    await f.post("/workers", { name: "Half", main_work: "driver", monthly_salary: 15000 }, 400);

    expect(await balanceOf(f, suresh.id)).toBe("45000.00");
    // Asking again writes nothing twice.
    expect(await balanceOf(f, suresh.id)).toBe("45000.00");

    await f.post(`/workers/${suresh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 5000 }, 201);
    expect(await balanceOf(f, suresh.id)).toBe("40000.00");

    const left = data(await f.post(`/workers/${suresh.id}/leave`, { left_on: today() }, 200));
    expect(left).toMatchObject({ is_active: false, share_enabled: false });
    const ledger = await f.get(`/workers/${suresh.id}/ledger`, undefined, 200);
    const salaries = data(ledger).filter((line) => line.source === "salary");
    expect(salaries).toHaveLength(4);
    expect(Number(ledger.body.balance)).toBeGreaterThan(40000);

    const types = data(await f.get("/work-types", undefined, 200));
    const salaryType = types.find((type) => type.code === "salary");
    await f.patch(`/work-types/${salaryType.id}`, { pay_unit: "per_day" }, 400);
  });
});

describe("a worker's own link", () => {
  let f, ramesh;

  beforeAll(async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth, { name: "Shree Bhatha" });
    f = factoryClient(owner.auth, factory.id);
    await setRates(f);
    ramesh = await addWorker(f, "Ramesh", { ...molder(550), village: "Bihar", phone: "9876543210" });
    await f.post("/brick-counts", { counted_on: today(), reason: "drying", quantity: 10000, molder_id: ramesh.id }, 201);
    await f.post(`/workers/${ramesh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 2000 }, 201);
  });

  const open = (token) => request(app).get(`/v1/public/workers/${token}`);

  test("shows that worker's account and nothing else, without a login", async () => {
    const share = data(await f.get(`/workers/${ramesh.id}/share`, undefined, 200));
    expect(share.url).toMatch(new RegExp(`/v1/public/workers/${share.token}$`));
    expect(share.phone).toBe("9876543210");

    const res = expectStatus(await open(share.token), 200);
    expect(res.headers["x-robots-tag"]).toBe("noindex, nofollow");
    expect(res.body).toMatchObject({
      worker: { name: "Ramesh", village: "Bihar" },
      factory: { name: "Shree Bhatha" },
      balance: "3500.00",
      totals: { earned: "5500.00", advances: "2000.00" },
    });
    expect(data(res)[1]).toMatchObject({ work_type_code: "molding", quantity: "10000.000", rate: "550.00" });
    expect(JSON.stringify(res.body)).not.toContain(ramesh.id);
  });

  test("a new link replaces the old one, and a link can be switched off", async () => {
    const old = data(await f.get(`/workers/${ramesh.id}/share`, undefined, 200));
    const fresh = data(await f.post(`/workers/${ramesh.id}/share/regenerate`, undefined, 200));
    expect(fresh.token).not.toBe(old.token);
    expectStatus(await open(old.token), 404);
    expectStatus(await open(fresh.token), 200);

    await f.patch(`/workers/${ramesh.id}/share`, { enabled: false }, 200);
    expectStatus(await open(fresh.token), 404);
    await f.patch(`/workers/${ramesh.id}/share`, { enabled: true }, 200);
    expectStatus(await open(fresh.token), 200);
    expectStatus(await open("short"), 404);
  });
});

describe("the subscription", () => {
  test("when it ends, everything can be read but nothing changed", async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth);
    const f = factoryClient(owner.auth, factory.id);
    const ramesh = await addWorker(f, "Ramesh");

    await pool.query("UPDATE subscriptions SET starts_at = now() - interval '40 days', ends_at = now() - interval '1 day' WHERE factory_id = $1", [
      factory.id,
    ]);

    const refused = await f.post("/workers", { name: "Dinesh" }, 402);
    expect(refused.body.code).toBe("subscription_inactive");
    await f.post(`/workers/${ramesh.id}/transactions`, { kind: "advance", txn_date: today(), amount: 100 }, 402);

    await f.get("/workers", undefined, 200);
    const view = data(await f.get("", undefined, 200));
    expect(view.subscription).toBeNull();
    const history = data(await f.get("/subscription", undefined, 200));
    expect(history.current).toBeNull();
    expect(history.history).toHaveLength(1);
  });
});

describe("accounts", () => {
  test("sign up, log in, refresh and see yourself", async () => {
    const email = uniqueEmail();
    const { user } = await signup({ name: "Papa", email });
    // Emails match whatever their case.
    const login = data(
      expectStatus(await request(app).post("/v1/auth/login").send({ email: email.toUpperCase(), password: "password123" }), 200),
    );
    expect(login.user.id).toBe(user.id);

    const refreshed = data(
      expectStatus(await request(app).post("/v1/auth/refresh").send({ refresh_token: login.refresh_token }), 200),
    );
    const me = data(
      expectStatus(await request(app).get("/v1/auth/me").set({ Authorization: `Bearer ${refreshed.access_token}` }), 200),
    );
    expect(me.name).toBe("Papa");

    expectStatus(await request(app).post("/v1/auth/login").send({ email, password: "wrong-pass" }), 401);
    expectStatus(await request(app).get("/v1/factories"), 401);
  });
});
