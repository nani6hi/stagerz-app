// supabase/functions/reap-orphaned-collaboration-assets/reaper.ts
//
// Phase 21.8B - S-3. Dependency-free core of the orphan reaper: request
// handling, eligibility rules and the dry-run/delete orchestration.
//
// Every side effect is injected through ReaperDeps, so this file imports
// nothing remote and is exercised offline by reaper.test.ts. index.ts
// only wires it to the Supabase service-role client.
//
// An object in the collaboration-assets bucket is deleted ONLY when all
// of the following hold (see classifyObject and runReaper):
//   1. its path has the exact upload shape <collaboration-uuid>/<file>
//   2. NO collaboration_assets row references it - live OR soft-deleted
//   3. NO pending_asset_deletions row references it (the drainer owns it)
//   4. both its created_at and updated_at are at least 48 hours old
//   5. it is within the 25 oldest eligible objects of this run
//   6. an immediate per-object re-check still finds no reference
//   7. the request explicitly asked for delete mode with the confirmation
//      token AND delete mode is enabled in the function environment
// Anything uncertain - a failed query, an unparseable timestamp, an
// unexpected path - is kept, never deleted.

import { isMaintenanceAuthorized } from "./maintenance-auth.ts";

export const BUCKET = "collaboration-assets";
export const GRACE_PERIOD_HOURS = 48;
export const GRACE_PERIOD_MS = GRACE_PERIOD_HOURS * 60 * 60 * 1000;
export const MIN_GRACE_PERIOD_MS = 24 * 60 * 60 * 1000;
export const BATCH_SIZE = 25;
export const MAX_BATCH_SIZE = 25;
export const MAX_OBJECTS_SCANNED = 10_000;
export const MAX_BODY_BYTES = 1024;
export const DELETE_CONFIRMATION = "DELETE_ORPHANED_OBJECTS";

export type Mode = "dry-run" | "delete";

export interface StoredObject {
  path: string;
  createdAt: string | null;
  updatedAt: string | null;
  sizeBytes: number | null;
}

export interface ObjectListing {
  objects: StoredObject[];
  // false when the scan stopped at MAX_OBJECTS_SCANNED or skipped nested
  // folders. Objects that were not scanned are never deleted.
  complete: boolean;
}

export interface ReaperDeps {
  // All four throw on any error. The two fetch* functions must also throw
  // if they cannot prove they returned every row.
  listObjects(maxObjects: number): Promise<ObjectListing>;
  fetchReferencedPaths(): Promise<Set<string>>;
  fetchQueuedPaths(): Promise<Set<string>>;
  isStillUnreferenced(path: string): Promise<boolean>;
  removeObject(path: string): Promise<"deleted" | "already_absent">;
}

export type Classification =
  | "eligible"
  | "kept_referenced"
  | "kept_queued"
  | "skipped_unexpected_path"
  | "skipped_unknown_age"
  | "skipped_within_grace_period";

export type BatchStatus =
  | "would_delete"
  | "deleted"
  | "already_absent"
  | "kept_on_recheck"
  | "recheck_failed"
  | "delete_failed";

// ---------------------------------------------------------------------
// Request parsing
// ---------------------------------------------------------------------

export type ParsedMode = { ok: true; mode: Mode } | { ok: false; error: string };

// Dry-run is the default: an empty body, {} and {"mode":"dry-run"} all
// select it. Delete mode requires BOTH {"mode":"delete"} and the exact
// confirmation token. Anything else is rejected rather than guessed at.
export function parseMode(bodyText: string): ParsedMode {
  if (bodyText.trim() === "") return { ok: true, mode: "dry-run" };

  let body: unknown;
  try {
    body = JSON.parse(bodyText);
  } catch {
    return { ok: false, error: "Body must be JSON." };
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "Body must be a JSON object." };
  }

  const record = body as Record<string, unknown>;
  for (const key of Object.keys(record)) {
    if (key !== "mode" && key !== "confirm") {
      return { ok: false, error: "Unknown field in body." };
    }
  }

  const mode = record.mode;
  if (mode === undefined || mode === "dry-run") {
    if (record.confirm !== undefined) {
      return { ok: false, error: "confirm is only valid with mode delete." };
    }
    return { ok: true, mode: "dry-run" };
  }
  if (mode === "delete") {
    if (record.confirm !== DELETE_CONFIRMATION) {
      return { ok: false, error: "Delete mode requires the confirmation token." };
    }
    return { ok: true, mode: "delete" };
  }
  return { ok: false, error: "mode must be dry-run or delete." };
}

// ---------------------------------------------------------------------
// Eligibility rules
// ---------------------------------------------------------------------

const EXPECTED_PATH =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[^/]+$/;

// The frontend uploads to <collaboration-uuid>/<timestamp>-<rand>-<name>.
// Only that shape is ever eligible; everything else is left alone.
export function isExpectedPath(path: string): boolean {
  if (!EXPECTED_PATH.test(path)) return false;
  if (path !== path.trim()) return false;
  for (let i = 0; i < path.length; i++) {
    const code = path.charCodeAt(i);
    if (code < 0x20 || code === 0x7f) return false;
  }
  const fileName = path.slice(path.indexOf("/") + 1);
  if (fileName === "." || fileName === "..") return false;
  if (fileName === ".emptyFolderPlaceholder") return false;
  return true;
}

function parseTimestamp(value: string | null): number {
  if (value === null || value.trim() === "") return Number.NaN;
  return Date.parse(value);
}

// Newest of created_at and updated_at, or null if age cannot be proven.
export function youngestTimestampMs(obj: StoredObject): number | null {
  const created = parseTimestamp(obj.createdAt);
  if (!Number.isFinite(created)) return null;
  if (obj.updatedAt === null) return created;
  const updated = parseTimestamp(obj.updatedAt);
  if (!Number.isFinite(updated)) return null;
  return Math.max(created, updated);
}

export function classifyObject(
  obj: StoredObject,
  referencedPaths: ReadonlySet<string>,
  queuedPaths: ReadonlySet<string>,
  nowMs: number,
  gracePeriodMs: number,
): Classification {
  if (referencedPaths.has(obj.path)) return "kept_referenced";
  if (queuedPaths.has(obj.path)) return "kept_queued";
  if (!isExpectedPath(obj.path)) return "skipped_unexpected_path";
  const youngest = youngestTimestampMs(obj);
  if (youngest === null) return "skipped_unknown_age";
  // A timestamp in the future yields a negative age and stays protected.
  if (nowMs - youngest < gracePeriodMs) return "skipped_within_grace_period";
  return "eligible";
}

export interface Selection {
  counts: Record<Classification, number>;
  eligible: StoredObject[];
  batch: StoredObject[];
}

export function selectBatch(
  objects: readonly StoredObject[],
  referencedPaths: ReadonlySet<string>,
  queuedPaths: ReadonlySet<string>,
  nowMs: number,
  gracePeriodMs: number,
  batchSize: number,
): Selection {
  if (!(gracePeriodMs >= MIN_GRACE_PERIOD_MS)) {
    throw new Error("Grace period below the 24 hour minimum.");
  }
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > MAX_BATCH_SIZE) {
    throw new Error("Batch size outside 1..25.");
  }

  const counts: Record<Classification, number> = {
    eligible: 0,
    kept_referenced: 0,
    kept_queued: 0,
    skipped_unexpected_path: 0,
    skipped_unknown_age: 0,
    skipped_within_grace_period: 0,
  };
  const eligible: StoredObject[] = [];
  const seen = new Set<string>();

  for (const obj of objects) {
    // A path listed twice is counted and considered once.
    if (seen.has(obj.path)) continue;
    seen.add(obj.path);
    const c = classifyObject(obj, referencedPaths, queuedPaths, nowMs, gracePeriodMs);
    counts[c]++;
    if (c === "eligible") eligible.push(obj);
  }

  // Oldest first; path as a deterministic tie-breaker.
  eligible.sort((a, b) =>
    (youngestTimestampMs(a)! - youngestTimestampMs(b)!) ||
    (a.path < b.path ? -1 : a.path > b.path ? 1 : 0)
  );

  return { counts, eligible, batch: eligible.slice(0, batchSize) };
}

// ---------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------

export interface BatchResult {
  path: string;
  sizeBytes: number | null;
  createdAt: string | null;
  updatedAt: string | null;
  status: BatchStatus;
}

export type ReaperOutcome =
  | { kind: "ok"; body: Record<string, unknown> }
  | { kind: "refused"; guard: string };

export async function runReaper(
  deps: ReaperDeps,
  mode: Mode,
  nowMs: number,
): Promise<ReaperOutcome> {
  // Listing first, references second: the reference sets are then at
  // least as fresh as the listing they are compared against.
  const listing = await deps.listObjects(MAX_OBJECTS_SCANNED);
  const referencedPaths = await deps.fetchReferencedPaths();
  const queuedPaths = await deps.fetchQueuedPaths();

  // If the bucket holds objects but no metadata row is visible at all,
  // the client is almost certainly not the service role (RLS would hide
  // every row) or the table was read wrongly. Treating everything as an
  // orphan in that state would be catastrophic, so refuse outright.
  if (listing.objects.length > 0 && referencedPaths.size === 0) {
    return { kind: "refused", guard: "no_metadata_rows_visible" };
  }

  const selection = selectBatch(
    listing.objects,
    referencedPaths,
    queuedPaths,
    nowMs,
    GRACE_PERIOD_MS,
    BATCH_SIZE,
  );

  const results: BatchResult[] = [];
  for (const obj of selection.batch) {
    results.push({
      path: obj.path,
      sizeBytes: obj.sizeBytes,
      createdAt: obj.createdAt,
      updatedAt: obj.updatedAt,
      status: await processCandidate(deps, mode, obj.path),
    });
  }

  return {
    kind: "ok",
    body: {
      mode,
      bucket: BUCKET,
      gracePeriodHours: GRACE_PERIOD_HOURS,
      batchSize: BATCH_SIZE,
      now: new Date(nowMs).toISOString(),
      cutoff: new Date(nowMs - GRACE_PERIOD_MS).toISOString(),
      scan: { objectsScanned: listing.objects.length, complete: listing.complete },
      counts: selection.counts,
      eligibleTotal: selection.eligible.length,
      eligibleRemainingAfterBatch: selection.eligible.length - selection.batch.length,
      batch: results,
    },
  };
}

async function processCandidate(
  deps: ReaperDeps,
  mode: Mode,
  path: string,
): Promise<BatchStatus> {
  // Defence in depth: selectBatch already enforced the path shape.
  if (!isExpectedPath(path)) return "recheck_failed";

  let unreferenced: boolean;
  try {
    unreferenced = await deps.isStillUnreferenced(path);
  } catch {
    return "recheck_failed";
  }
  if (unreferenced !== true) return "kept_on_recheck";

  if (mode !== "delete") return "would_delete";

  try {
    return await deps.removeObject(path);
  } catch {
    return "delete_failed";
  }
}

// ---------------------------------------------------------------------
// HTTP handling
// ---------------------------------------------------------------------

export interface HandlerConfig {
  maintenanceSecret: string | undefined;
  supabaseConfigured: boolean;
  deleteEnabled: boolean;
  createDeps: () => ReaperDeps;
  now: () => number;
  logError: (message: string) => void;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

export async function handleRequest(req: Request, config: HandlerConfig): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const secret = config.maintenanceSecret;
  if (!config.supabaseConfigured || secret === undefined || secret.trim() === "") {
    config.logError("reap-orphaned-collaboration-assets: missing required environment.");
    return jsonResponse(500, { error: "Server misconfigured." });
  }

  if (!isMaintenanceAuthorized(req, secret)) {
    return jsonResponse(401, { error: "Unauthorized." });
  }

  const bodyText = await req.text();
  if (new TextEncoder().encode(bodyText).length > MAX_BODY_BYTES) {
    return jsonResponse(400, { error: "Body too large." });
  }
  const parsed = parseMode(bodyText);
  if (!parsed.ok) {
    return jsonResponse(400, { error: parsed.error });
  }

  // Checked before any Storage or database call is made.
  if (parsed.mode === "delete" && !config.deleteEnabled) {
    return jsonResponse(403, { error: "Delete mode is disabled." });
  }

  let outcome: ReaperOutcome;
  try {
    outcome = await runReaper(config.createDeps(), parsed.mode, config.now());
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    config.logError(`reap-orphaned-collaboration-assets: aborted before deleting anything: ${message}`);
    return jsonResponse(500, { error: "Internal error." });
  }

  if (outcome.kind === "refused") {
    config.logError(`reap-orphaned-collaboration-assets: refused by guard ${outcome.guard}`);
    return jsonResponse(409, { error: "Refused by safety guard.", guard: outcome.guard });
  }
  return jsonResponse(200, outcome.body);
}
