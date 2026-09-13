// supabase/functions/reap-orphaned-collaboration-assets/reaper.test.ts
//
// Offline tests for reaper.ts. No network, no Supabase, no remote imports:
//   deno test supabase/functions/reap-orphaned-collaboration-assets/
// Not imported by index.ts, so it is never part of the deployed bundle.

import {
  BATCH_SIZE,
  BUCKET,
  classifyObject,
  DELETE_CONFIRMATION,
  GRACE_PERIOD_HOURS,
  GRACE_PERIOD_MS,
  handleRequest,
  type HandlerConfig,
  isExpectedPath,
  MAX_OBJECTS_SCANNED,
  parseMode,
  type ReaperDeps,
  runReaper,
  selectBatch,
  type StoredObject,
} from "./reaper.ts";

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message = ""): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${message} expected ${e} but got ${a}`);
}

async function assertRejects(fn: () => Promise<unknown>): Promise<void> {
  let threw = false;
  try {
    await fn();
  } catch {
    threw = true;
  }
  assert(threw, "expected rejection");
}

const HOUR = 60 * 60 * 1000;
const NOW = Date.parse("2026-09-14T12:00:00.000Z");
const COLLAB_A = "11111111-2222-4333-8444-555555555555";
const COLLAB_B = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

function iso(ms: number): string {
  return new Date(ms).toISOString();
}

function obj(path: string, ageHours: number, updatedAgeHours: number | null = ageHours): StoredObject {
  return {
    path,
    createdAt: iso(NOW - ageHours * HOUR),
    updatedAt: updatedAgeHours === null ? null : iso(NOW - updatedAgeHours * HOUR),
    sizeBytes: 17,
  };
}

interface FakeState {
  objects: StoredObject[];
  complete?: boolean;
  referenced: string[];
  queued: string[];
  // Paths that gained a reference after the bulk read (race simulation).
  referencedOnRecheck?: string[];
  recheckThrowsFor?: string[];
  removeThrowsFor?: string[];
  absent?: string[];
  listThrows?: boolean;
  referencesThrow?: boolean;
}

interface Fake {
  deps: ReaperDeps;
  removed: string[];
  rechecked: string[];
  calls: string[];
}

function fakeDeps(state: FakeState): Fake {
  const removed: string[] = [];
  const rechecked: string[] = [];
  const calls: string[] = [];
  const deps: ReaperDeps = {
    listObjects: (max) => {
      calls.push("list");
      if (state.listThrows) return Promise.reject(new Error("list failed"));
      assertEquals(max, MAX_OBJECTS_SCANNED);
      return Promise.resolve({ objects: state.objects, complete: state.complete ?? true });
    },
    fetchReferencedPaths: () => {
      calls.push("referenced");
      if (state.referencesThrow) return Promise.reject(new Error("read failed"));
      return Promise.resolve(new Set(state.referenced));
    },
    fetchQueuedPaths: () => {
      calls.push("queued");
      return Promise.resolve(new Set(state.queued));
    },
    isStillUnreferenced: (path) => {
      rechecked.push(path);
      if (state.recheckThrowsFor?.includes(path)) return Promise.reject(new Error("recheck failed"));
      const nowReferenced = state.referenced.includes(path) || state.queued.includes(path) ||
        (state.referencedOnRecheck ?? []).includes(path);
      return Promise.resolve(!nowReferenced);
    },
    removeObject: (path) => {
      if (state.removeThrowsFor?.includes(path)) return Promise.reject(new Error("remove failed"));
      removed.push(path);
      return Promise.resolve((state.absent ?? []).includes(path) ? "already_absent" : "deleted");
    },
  };
  return { deps, removed, rechecked, calls };
}

// deno-lint-ignore no-explicit-any
function batchOf(body: Record<string, unknown>): any[] {
  // deno-lint-ignore no-explicit-any
  return body.batch as any[];
}

// ---------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------

Deno.test("constants: bucket, 48h grace period, batch of 25", () => {
  assertEquals(BUCKET, "collaboration-assets");
  assertEquals(GRACE_PERIOD_HOURS, 48);
  assertEquals(GRACE_PERIOD_MS, 172_800_000);
  assertEquals(BATCH_SIZE, 25);
});

// ---------------------------------------------------------------------
// parseMode
// ---------------------------------------------------------------------

Deno.test("parseMode: dry-run is the default", () => {
  for (const body of ["", "   ", "{}", '{"mode":"dry-run"}']) {
    assertEquals(parseMode(body), { ok: true, mode: "dry-run" }, `body ${body}`);
  }
});

Deno.test("parseMode: delete requires the exact confirmation token", () => {
  assertEquals(
    parseMode(JSON.stringify({ mode: "delete", confirm: DELETE_CONFIRMATION })),
    { ok: true, mode: "delete" },
  );
  for (
    const body of [
      '{"mode":"delete"}',
      '{"mode":"delete","confirm":"yes"}',
      '{"mode":"delete","confirm":"delete_orphaned_objects"}',
      '{"mode":"delete","confirm":true}',
    ]
  ) {
    assertEquals(parseMode(body).ok, false, `body ${body}`);
  }
});

Deno.test("parseMode: malformed or unexpected bodies are rejected, never guessed", () => {
  for (
    const body of [
      "not json",
      "[]",
      "null",
      '"delete"',
      '{"mode":"DELETE","confirm":"DELETE_ORPHANED_OBJECTS"}',
      '{"mode":"purge"}',
      '{"mode":"dry-run","confirm":"DELETE_ORPHANED_OBJECTS"}',
      '{"mode":"dry-run","batchSize":1000}',
      '{"gracePeriodHours":0}',
    ]
  ) {
    assertEquals(parseMode(body).ok, false, `body ${body}`);
  }
});

// ---------------------------------------------------------------------
// isExpectedPath
// ---------------------------------------------------------------------

Deno.test("isExpectedPath: only <collaboration-uuid>/<file> is accepted", () => {
  assert(isExpectedPath(`${COLLAB_A}/1721123456789-abc123-report.pdf`));
  assert(isExpectedPath(`${COLLAB_A}/file with spaces.png`));

  const rejected = [
    "report.pdf",
    `${COLLAB_A}`,
    `${COLLAB_A}/`,
    `${COLLAB_A}/nested/file.pdf`,
    `not-a-uuid/file.pdf`,
    `${COLLAB_B.toUpperCase()}/file.pdf`,
    `/${COLLAB_A}/file.pdf`,
    `${COLLAB_A}/..`,
    `${COLLAB_A}/.`,
    `${COLLAB_A}/.emptyFolderPlaceholder`,
    `${COLLAB_A}/file.pdf `,
    ` ${COLLAB_A}/file.pdf`,
    `${COLLAB_A}/bad${String.fromCharCode(0)}name`,
    `${COLLAB_A}/bad${String.fromCharCode(10)}name`,
    `${COLLAB_A}/bad${String.fromCharCode(127)}name`,
  ];
  for (const path of rejected) {
    assert(!isExpectedPath(path), `should reject ${JSON.stringify(path)}`);
  }
});

// ---------------------------------------------------------------------
// classifyObject
// ---------------------------------------------------------------------

Deno.test("classifyObject: a referenced object is kept however old it is", () => {
  const p = `${COLLAB_A}/old.pdf`;
  // The referenced set contains live AND soft-deleted rows alike.
  assertEquals(classifyObject(obj(p, 10_000), new Set([p]), new Set(), NOW, GRACE_PERIOD_MS), "kept_referenced");
});

Deno.test("classifyObject: a queued object is left to the drainer", () => {
  const p = `${COLLAB_A}/queued.pdf`;
  assertEquals(classifyObject(obj(p, 10_000), new Set(), new Set([p]), NOW, GRACE_PERIOD_MS), "kept_queued");
});

Deno.test("classifyObject: grace period boundary is exactly 48 hours", () => {
  const p = `${COLLAB_A}/f.pdf`;
  const none = new Set<string>();
  assertEquals(classifyObject(obj(p, 47.99), none, none, NOW, GRACE_PERIOD_MS), "skipped_within_grace_period");
  assertEquals(classifyObject(obj(p, 48), none, none, NOW, GRACE_PERIOD_MS), "eligible");
  assertEquals(classifyObject(obj(p, 49), none, none, NOW, GRACE_PERIOD_MS), "eligible");
});

Deno.test("classifyObject: a recent updated_at protects an old object", () => {
  const p = `${COLLAB_A}/f.pdf`;
  const none = new Set<string>();
  assertEquals(classifyObject(obj(p, 500, 1), none, none, NOW, GRACE_PERIOD_MS), "skipped_within_grace_period");
});

Deno.test("classifyObject: future timestamps stay protected", () => {
  const p = `${COLLAB_A}/f.pdf`;
  const none = new Set<string>();
  assertEquals(classifyObject(obj(p, -5), none, none, NOW, GRACE_PERIOD_MS), "skipped_within_grace_period");
});

Deno.test("classifyObject: unknown age is never eligible", () => {
  const p = `${COLLAB_A}/f.pdf`;
  const none = new Set<string>();
  const cases: StoredObject[] = [
    { path: p, createdAt: null, updatedAt: null, sizeBytes: 1 },
    { path: p, createdAt: "", updatedAt: null, sizeBytes: 1 },
    { path: p, createdAt: "garbage", updatedAt: null, sizeBytes: 1 },
    { path: p, createdAt: iso(NOW - 500 * HOUR), updatedAt: "garbage", sizeBytes: 1 },
  ];
  for (const c of cases) {
    assertEquals(classifyObject(c, none, none, NOW, GRACE_PERIOD_MS), "skipped_unknown_age");
  }
  // A missing updated_at alone is fine: created_at decides.
  assertEquals(classifyObject(obj(p, 500, null), none, none, NOW, GRACE_PERIOD_MS), "eligible");
});

Deno.test("classifyObject: unexpected paths are never eligible", () => {
  const none = new Set<string>();
  assertEquals(classifyObject(obj("root-file.pdf", 500), none, none, NOW, GRACE_PERIOD_MS), "skipped_unexpected_path");
});

// ---------------------------------------------------------------------
// selectBatch
// ---------------------------------------------------------------------

Deno.test("selectBatch: at most 25, oldest first, deterministic", () => {
  const objects: StoredObject[] = [];
  for (let i = 0; i < 40; i++) objects.push(obj(`${COLLAB_A}/f${String(i).padStart(2, "0")}.pdf`, 100 + i));
  const s = selectBatch(objects, new Set(), new Set(), NOW, GRACE_PERIOD_MS, BATCH_SIZE);
  assertEquals(s.eligible.length, 40);
  assertEquals(s.batch.length, 25);
  assertEquals(s.batch[0].path, `${COLLAB_A}/f39.pdf`);
  assertEquals(s.batch[24].path, `${COLLAB_A}/f15.pdf`);
});

Deno.test("selectBatch: duplicate listing entries are considered once", () => {
  const p = obj(`${COLLAB_A}/dup.pdf`, 100);
  const s = selectBatch([p, p], new Set(), new Set(), NOW, GRACE_PERIOD_MS, BATCH_SIZE);
  assertEquals(s.eligible.length, 1);
  assertEquals(s.counts.eligible, 1);
});

Deno.test("selectBatch: refuses a grace period under 24h or a batch outside 1..25", () => {
  const run = (grace: number, batch: number) => () => selectBatch([], new Set(), new Set(), NOW, grace, batch);
  for (const f of [run(23 * HOUR, 25), run(0, 25), run(Number.NaN, 25), run(GRACE_PERIOD_MS, 26), run(GRACE_PERIOD_MS, 0), run(GRACE_PERIOD_MS, 2.5)]) {
    let threw = false;
    try {
      f();
    } catch {
      threw = true;
    }
    assert(threw, "expected selectBatch to throw");
  }
});

// ---------------------------------------------------------------------
// runReaper
// ---------------------------------------------------------------------

function productionShapedState(): FakeState {
  // Mirrors the live bucket at design time: 28 objects, 13 referenced by
  // live rows, 15 unreferenced and months old; plus fixtures for every
  // protective rule.
  const objects: StoredObject[] = [];
  const referenced: string[] = [];
  for (let i = 0; i < 13; i++) {
    const p = `${COLLAB_A}/live-${i}.pdf`;
    objects.push(obj(p, 1500));
    referenced.push(p);
  }
  for (let i = 0; i < 15; i++) objects.push(obj(`${COLLAB_B}/orphan-${String(i).padStart(2, "0")}.pdf`, 1400 + i));
  return { objects, referenced, queued: [] };
}

Deno.test("runReaper: dry-run never removes anything", async () => {
  const f = fakeDeps(productionShapedState());
  const out = await runReaper(f.deps, "dry-run", NOW);
  assert(out.kind === "ok");
  assertEquals(f.removed, []);
  assertEquals(out.body.eligibleTotal, 15);
  assertEquals(batchOf(out.body).length, 15);
  assert(batchOf(out.body).every((r) => r.status === "would_delete"));
  assertEquals(f.calls, ["list", "referenced", "queued"]);
});

Deno.test("runReaper: delete removes only unreferenced, aged, expected-path objects", async () => {
  const state = productionShapedState();
  const soft = `${COLLAB_A}/soft-deleted.pdf`;
  const queued = `${COLLAB_A}/queued.pdf`;
  const young = `${COLLAB_B}/young.pdf`;
  const odd = `${COLLAB_B}/nested/deep.pdf`;
  const noAge: StoredObject = { path: `${COLLAB_B}/no-age.pdf`, createdAt: null, updatedAt: null, sizeBytes: 1 };
  state.objects.push(obj(soft, 3000), obj(queued, 3000), obj(young, 2), obj(odd, 3000), noAge);
  state.referenced.push(soft); // soft-deleted rows are in the referenced set
  state.queued.push(queued, soft);

  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");

  const protectedPaths = new Set([...state.referenced, queued, young, odd, noAge.path]);
  assertEquals(f.removed.length, 15);
  assert(f.removed.every((p) => !protectedPaths.has(p)), "a protected object was removed");
  assert(f.rechecked.every((p) => !protectedPaths.has(p)), "a protected object reached the batch");
  assertEquals(out.body.counts, {
    eligible: 15,
    kept_referenced: 14,
    kept_queued: 1,
    skipped_unexpected_path: 1,
    skipped_unknown_age: 1,
    skipped_within_grace_period: 1,
  });
});

Deno.test("runReaper: delete stops at 25 per run", async () => {
  const state = productionShapedState();
  for (let i = 0; i < 30; i++) state.objects.push(obj(`${COLLAB_B}/extra-${i}.pdf`, 900));
  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");
  assertEquals(f.removed.length, 25);
  assertEquals(out.body.eligibleTotal, 45);
  assertEquals(out.body.eligibleRemainingAfterBatch, 20);
});

Deno.test("runReaper: a reference that appears before deletion wins", async () => {
  const state = productionShapedState();
  const raced = `${COLLAB_B}/orphan-00.pdf`;
  state.referencedOnRecheck = [raced];
  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");
  assert(!f.removed.includes(raced));
  assertEquals(batchOf(out.body).find((r) => r.path === raced).status, "kept_on_recheck");
});

Deno.test("runReaper: a failed re-check keeps the object", async () => {
  const state = productionShapedState();
  const p = `${COLLAB_B}/orphan-03.pdf`;
  state.recheckThrowsFor = [p];
  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");
  assert(!f.removed.includes(p));
  assertEquals(batchOf(out.body).find((r) => r.path === p).status, "recheck_failed");
});

Deno.test("runReaper: remove failures and already-absent objects are reported, not retried", async () => {
  const state = productionShapedState();
  const failing = `${COLLAB_B}/orphan-01.pdf`;
  const gone = `${COLLAB_B}/orphan-02.pdf`;
  state.removeThrowsFor = [failing];
  state.absent = [gone];
  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");
  const statusOf = (p: string) => batchOf(out.body).find((r) => r.path === p).status;
  assertEquals(statusOf(failing), "delete_failed");
  assertEquals(statusOf(gone), "already_absent");
  assertEquals(f.removed.length, 14);
});

Deno.test("runReaper: refuses when no metadata row is visible", async () => {
  const state = productionShapedState();
  state.referenced = [];
  const f = fakeDeps(state);
  const out = await runReaper(f.deps, "delete", NOW);
  assertEquals(out, { kind: "refused", guard: "no_metadata_rows_visible" });
  assertEquals(f.removed, []);
  assertEquals(f.rechecked, []);
});

Deno.test("runReaper: an empty bucket is a clean no-op", async () => {
  const f = fakeDeps({ objects: [], referenced: [], queued: [] });
  const out = await runReaper(f.deps, "delete", NOW);
  assert(out.kind === "ok");
  assertEquals(out.body.eligibleTotal, 0);
  assertEquals(f.removed, []);
});

Deno.test("runReaper: listing or reference failures abort before any deletion", async () => {
  for (const patch of [{ listThrows: true }, { referencesThrow: true }]) {
    const f = fakeDeps({ ...productionShapedState(), ...patch });
    await assertRejects(() => runReaper(f.deps, "delete", NOW));
    assertEquals(f.removed, []);
  }
});

// ---------------------------------------------------------------------
// handleRequest
// ---------------------------------------------------------------------

const SECRET = "test-maintenance-secret-not-real";

function config(overrides: Partial<HandlerConfig> & { fake?: Fake } = {}): HandlerConfig & { depsCreated: () => number } {
  let created = 0;
  const fake = overrides.fake ?? fakeDeps(productionShapedState());
  return {
    maintenanceSecret: SECRET,
    supabaseConfigured: true,
    deleteEnabled: false,
    createDeps: () => {
      created++;
      return fake.deps;
    },
    now: () => NOW,
    logError: () => {},
    ...overrides,
    depsCreated: () => created,
  };
}

function post(body: string, headers: Record<string, string> = { Authorization: `Bearer ${SECRET}` }): Request {
  return new Request("https://example.invalid/functions/v1/reap-orphaned-collaboration-assets", {
    method: "POST",
    headers,
    body,
  });
}

Deno.test("handleRequest: method, configuration and authorization gates", async () => {
  const c = config();
  assertEquals((await handleRequest(new Request("https://example.invalid", { method: "GET" }), c)).status, 405);
  assertEquals((await handleRequest(new Request("https://example.invalid", { method: "OPTIONS" }), c)).status, 204);
  assertEquals((await handleRequest(post(""), config({ maintenanceSecret: undefined }))).status, 500);
  assertEquals((await handleRequest(post(""), config({ maintenanceSecret: "  " }))).status, 500);
  assertEquals((await handleRequest(post(""), config({ supabaseConfigured: false }))).status, 500);
  assertEquals((await handleRequest(post("", {}), c)).status, 401);
  assertEquals((await handleRequest(post("", { Authorization: "Bearer wrong" }), c)).status, 401);
  assertEquals(c.depsCreated(), 0);
});

Deno.test("handleRequest: both documented auth headers are accepted", async () => {
  const f = fakeDeps(productionShapedState());
  assertEquals((await handleRequest(post("", { Authorization: `Bearer ${SECRET}` }), config({ fake: f }))).status, 200);
  assertEquals((await handleRequest(post("", { "X-STAGERZ-Maintenance-Secret": SECRET }), config({ fake: f }))).status, 200);
  assertEquals(f.removed, []);
});

Deno.test("handleRequest: default request is a dry-run", async () => {
  const f = fakeDeps(productionShapedState());
  const res = await handleRequest(post(""), config({ fake: f }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.mode, "dry-run");
  assertEquals(f.removed, []);
});

Deno.test("handleRequest: delete is refused while disabled, before any I/O", async () => {
  const f = fakeDeps(productionShapedState());
  const c = config({ fake: f, deleteEnabled: false });
  const res = await handleRequest(post(JSON.stringify({ mode: "delete", confirm: DELETE_CONFIRMATION })), c);
  assertEquals(res.status, 403);
  assertEquals(c.depsCreated(), 0);
  assertEquals(f.calls, []);
  assertEquals(f.removed, []);
});

Deno.test("handleRequest: delete needs the token even when enabled", async () => {
  const f = fakeDeps(productionShapedState());
  const c = config({ fake: f, deleteEnabled: true });
  assertEquals((await handleRequest(post('{"mode":"delete"}'), c)).status, 400);
  assertEquals(f.removed, []);
});

Deno.test("handleRequest: enabled + confirmed delete removes the batch", async () => {
  const f = fakeDeps(productionShapedState());
  const res = await handleRequest(
    post(JSON.stringify({ mode: "delete", confirm: DELETE_CONFIRMATION })),
    config({ fake: f, deleteEnabled: true }),
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).mode, "delete");
  assertEquals(f.removed.length, 15);
});

Deno.test("handleRequest: oversized body, guard refusal and internal errors", async () => {
  assertEquals((await handleRequest(post("x".repeat(2000)), config())).status, 400);

  const noRefs = fakeDeps({ ...productionShapedState(), referenced: [] });
  const refused = await handleRequest(post(""), config({ fake: noRefs }));
  assertEquals(refused.status, 409);
  assertEquals((await refused.json()).guard, "no_metadata_rows_visible");

  const broken = fakeDeps({ ...productionShapedState(), referencesThrow: true });
  const failed = await handleRequest(
    post(JSON.stringify({ mode: "delete", confirm: DELETE_CONFIRMATION })),
    config({ fake: broken, deleteEnabled: true }),
  );
  assertEquals(failed.status, 500);
  assertEquals(broken.removed, []);
});
