import request from "supertest";
import app from "../src/app.js";
import { closeDb, createFactory, data, daysAgo, expectStatus, factoryClient, signup } from "./helpers.js";

afterAll(closeDb);

describe("deleting an account", () => {
  test("needs the right password", async () => {
    const user = await signup();
    expectStatus(await request(app).post("/v1/auth/me/delete").set(user.auth).send({ password: "wrong-one" }), 400);
    expectStatus(await request(app).get("/v1/auth/me").set(user.auth), 200);
  });

  test("wipes the person, closes their factories and signs them out", async () => {
    const owner = await signup({ name: "Papa", phone: "9876543210" });
    const munim = await signup({ name: "Munim" });
    const factory = await createFactory(owner.auth);
    const f = factoryClient(owner.auth, factory.id);
    await f.post("/members", { email: munim.user.email, role: "munim" }, 201);

    // The owner is also a munim in someone else's factory, which stays open.
    const other = await signup({ name: "Other owner" });
    const otherFactory = await createFactory(other.auth);
    const o = factoryClient(other.auth, otherFactory.id);
    await o.post("/members", { email: owner.user.email, role: "munim" }, 201);

    expectStatus(await request(app).post("/v1/auth/me/delete").set(owner.auth).send({ password: "password123" }), 200);

    // Signed out everywhere, and the old password no longer works.
    expectStatus(await request(app).get("/v1/auth/me").set(owner.auth), 401);
    expectStatus(await request(app).post("/v1/auth/refresh").send({ refresh_token: owner.refresh_token }), 401);
    expectStatus(
      await request(app).post("/v1/auth/login").send({ email: owner.user.email, password: "password123" }),
      401,
    );

    // Their factory is closed for the munim too.
    await factoryClient(munim.auth, factory.id).get("", undefined, 404);

    // In the other factory they are gone, and their name with them.
    const members = data(await o.get("/members", undefined, 200));
    expect(members.map((m) => m.name)).toEqual(["Other owner"]);

    // The email is free to sign up again, as a new account.
    const again = await signup({ email: owner.user.email });
    expect(again.user.id).not.toBe(owner.user.id);
  });
});

describe("help and legal pages", () => {
  const saved = process.env.SUPPORT_WHATSAPP;
  afterAll(() => {
    if (saved === undefined) delete process.env.SUPPORT_WHATSAPP;
    else process.env.SUPPORT_WHATSAPP = saved;
  });

  test("the support details need no sign-in", async () => {
    process.env.SUPPORT_WHATSAPP = "+91 98765 43210";
    const support = data(expectStatus(await request(app).get("/v1/app/support"), 200));
    expect(support.whatsapp).toBe("919876543210");
    expect(support.privacy_url).toMatch(/\/legal\/privacy$/);
    expect(support.terms_url).toMatch(/\/legal\/terms$/);
    expect(support.delete_account_url).toMatch(/\/legal\/delete-account$/);

    delete process.env.SUPPORT_WHATSAPP;
    expect(data(await request(app).get("/v1/app/support")).whatsapp).toBeNull();
  });

  test.each(["terms", "privacy", "delete-account"])("/legal/%s is a web page", async (name) => {
    process.env.SUPPORT_WHATSAPP = "919876543210";
    const res = expectStatus(await request(app).get(`/legal/${name}`), 200);
    expect(res.headers["content-type"]).toMatch(/text\/html/);
    expect(res.text).toContain("https://wa.me/919876543210");
  });
});

describe("a payment can be read back for editing", () => {
  test("with its mode and note", async () => {
    const owner = await signup();
    const factory = await createFactory(owner.auth);
    const f = factoryClient(owner.auth, factory.id);
    const party = data(await f.post("/parties", { kind: "customer", name: "Patel bhai" }, 201));
    const paid = data(
      await f.post(
        `/parties/${party.id}/payments`,
        { kind: "received", paid_on: daysAgo(1), amount: 2500, mode: "upi", note: "GPay" },
        201,
      ),
    );

    const payment = data(await f.get(`/party-payments/${paid.id}`, undefined, 200));
    expect(payment).toMatchObject({ kind: "received", amount: "2500.00", mode: "upi", note: "GPay", party_id: party.id });

    await f.put(`/party-payments/${paid.id}`, { amount: 3000, mode: "cash" }, 200);
    expect(data(await f.get(`/party-payments/${paid.id}`, undefined, 200))).toMatchObject({ amount: "3000.00", mode: "cash" });
  });
});
