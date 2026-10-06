import request from "supertest";
import app from "../src/app.js";
import pool from "../src/db/db.js";
import { todayIst } from "../src/utils/dates.js";

let sequence = 0;

export const uniqueEmail = () =>
  `user${Date.now()}${sequence++}${Math.random().toString(36).slice(2, 7)}@example.com`;

export const data = (res) => res.body.data;

export function expectStatus(res, status) {
  if (res.status !== status) {
    throw new Error(`Expected HTTP ${status}, got ${res.status}: ${JSON.stringify(res.body)}`);
  }
  return res;
}

/** 'YYYY-MM-DD', `days` before today (IST). */
export function daysAgo(days) {
  const [y, m, d] = todayIst().split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d - days)).toISOString().slice(0, 10);
}

export const today = () => todayIst();

export async function signup(overrides = {}) {
  const res = await request(app)
    .post("/v1/auth/signup")
    .send({ name: "Test User", email: uniqueEmail(), password: "password123", ...overrides });
  expectStatus(res, 201);

  const { user, access_token, refresh_token } = data(res);
  return { user, access_token, refresh_token, auth: { Authorization: `Bearer ${access_token}` } };
}

/** A factory whose season started 60 days ago. */
export async function createFactory(auth, overrides = {}) {
  const res = await request(app)
    .post("/v1/factories")
    .set(auth)
    .send({ name: "Shree Bhatha", city: "Surat", season_started_on: daysAgo(60), ...overrides });
  return data(expectStatus(res, 201));
}

/**
 * Request helper scoped to one factory: `f.post("/workers", body, 201)`.
 * The optional last argument asserts the status.
 */
export function factoryClient(auth, factoryId) {
  const call = (method) => async (path, body, expected) => {
    let req = request(app)[method](`/v1/factories/${factoryId}${path}`).set(auth);
    if (body !== undefined) req = method === "get" ? req.query(body) : req.send(body);
    const res = await req;
    return expected === undefined ? res : expectStatus(res, expected);
  };
  return { get: call("get"), post: call("post"), patch: call("patch"), put: call("put"), del: call("delete") };
}

/**
 * Sets the rates of the kinds of work that keep one (the ones from the
 * planning examples). Brick work is paid at each worker's own rate.
 */
export async function setRates(f) {
  const types = data(await f.get("/work-types", undefined, 200));
  const byCode = Object.fromEntries(types.map((type) => [type.code, type]));
  const rates = { truck_loading: 1500, daily: 400 };
  for (const [code, rate] of Object.entries(rates)) {
    await f.patch(`/work-types/${byCode[code].id}`, { rate }, 200);
  }
  return byCode;
}

/** ₹`rate` per 1000 bricks. */
export const per1000 = (rate) => ({ brick_rate: rate });

/** ₹`rate` per day. */
export const perDay = (rate) => ({ day_rate: rate });

/**
 * A worker; main_work is 'other' unless given. Everyone but a driver needs a
 * rate: ₹100 per 1000 bricks unless given.
 */
export async function addWorker(f, name, extra = {}) {
  const rate = extra.main_work === "driver" ? {} : per1000(100);
  return data(await f.post("/workers", { name, main_work: "other", ...rate, ...extra }, 201));
}

const carrierGroups = new WeakMap();

/**
 * Who carried bricks to the drying ground: one bharai worker at ₹100 per 1000
 * bricks, made once per factory.
 */
export async function carried(f) {
  if (!carrierGroups.has(f)) {
    const types = data(await f.get("/work-types", undefined, 200));
    const carry = types.find((type) => type.code === "kiln_loading");
    const worker = await addWorker(f, "Sukavani carrier", { main_work: "loader", ...per1000(100) });
    carrierGroups.set(f, [{ work_type_id: carry.id, workers: [{ worker_id: worker.id }] }]);
  }
  return carrierGroups.get(f);
}

const stackerGroups = new WeakMap();

/**
 * The khadkaniyo who stacked bricks into the kiln: one worker at ₹25 per
 * 1000 bricks, made once per factory.
 */
export async function stacked(f) {
  if (!stackerGroups.has(f)) {
    const types = data(await f.get("/work-types", undefined, 200));
    const stacking = types.find((type) => type.code === "stacking");
    const worker = await addWorker(f, "Khadkaniyo", { main_work: "stacker", ...per1000(25) });
    stackerGroups.set(f, { work_type_id: stacking.id, workers: [{ worker_id: worker.id }] });
  }
  return stackerGroups.get(f);
}

/** A molder at ₹`rate` per 1000 bricks. */
export const molder = (rate = 550) => ({ main_work: "molder", ...per1000(rate) });

export async function balanceOf(f, workerId) {
  return data(await f.get(`/workers/${workerId}/balance`, undefined, 200)).balance;
}

export { app, pool, request };
export const closeDb = () => pool.end();
