// supabase/functions/reap-orphaned-collaboration-assets/index.ts
//
// Phase 21.8B - S-3. Maintenance-secret-gated orphan reaper for the
// collaboration-assets bucket. DRY-RUN BY DEFAULT.
//
// This file only wires the Supabase service-role client into the
// dependency-free core in reaper.ts, where every eligibility rule and
// safety guard lives (and is tested by reaper.test.ts). It never writes
// to the database: its only mutation is Storage remove() of an object
// that no collaboration_assets or pending_asset_deletions row references.
//
// Delete mode needs BOTH a request body of
//   {"mode":"delete","confirm":"DELETE_ORPHANED_OBJECTS"}
// AND the function environment variable
//   STAGERZ_ORPHAN_REAPER_DELETE_ENABLED=true
// Without that variable the function can only ever dry-run.
//
// supabase-js is pinned to the exact version the frontend uses, unlike
// the three captured functions, whose floating @2 import is left as-is.

import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.112.1";
import {
  BUCKET,
  handleRequest,
  type ObjectListing,
  type ReaperDeps,
  type StoredObject,
} from "./reaper.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const LIST_PAGE_SIZE = 100;
const MAX_LIST_PAGES_PER_PREFIX = 1_000;
const REFERENCE_PAGE_SIZE = 1_000;
const MAX_REFERENCE_ROWS = 100_000;

interface ListedEntry {
  id: string | null;
  name: string;
  created_at?: string | null;
  updated_at?: string | null;
  metadata?: { size?: unknown } | null;
}

function toStoredObject(path: string, entry: ListedEntry): StoredObject {
  const size = entry.metadata?.size;
  return {
    path,
    createdAt: entry.created_at ?? null,
    updatedAt: entry.updated_at ?? null,
    sizeBytes: typeof size === "number" ? size : null,
  };
}

// One level of the bucket, all pages. Throws on any Storage error.
async function listPrefix(admin: SupabaseClient, prefix: string): Promise<ListedEntry[]> {
  const entries: ListedEntry[] = [];
  for (let page = 0; page < MAX_LIST_PAGES_PER_PREFIX; page++) {
    const { data, error } = await admin.storage.from(BUCKET).list(prefix, {
      limit: LIST_PAGE_SIZE,
      offset: page * LIST_PAGE_SIZE,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(`storage list failed: ${error.message}`);
    const rows = (data ?? []) as unknown as ListedEntry[];
    entries.push(...rows);
    if (rows.length < LIST_PAGE_SIZE) return entries;
  }
  throw new Error("storage list exceeded the page limit.");
}

// Uploads live exactly one folder deep (<collaboration-uuid>/<file>).
// Root-level files are listed (and later rejected by the path rule);
// nested folders are not descended, so nothing below them is ever deleted.
async function listObjects(admin: SupabaseClient, maxObjects: number): Promise<ObjectListing> {
  const objects: StoredObject[] = [];
  let complete = true;

  const rootEntries = await listPrefix(admin, "");
  const folders: string[] = [];
  for (const entry of rootEntries) {
    if (entry.id === null || entry.id === undefined) folders.push(entry.name);
    else objects.push(toStoredObject(entry.name, entry));
  }

  for (const folder of folders) {
    if (objects.length >= maxObjects) {
      complete = false;
      break;
    }
    for (const entry of await listPrefix(admin, folder)) {
      if (entry.id === null || entry.id === undefined) {
        complete = false;
        continue;
      }
      if (objects.length >= maxObjects) {
        complete = false;
        break;
      }
      objects.push(toStoredObject(`${folder}/${entry.name}`, entry));
    }
  }

  return { objects, complete };
}

// Every storage_path in a table, with no filter at all - live and
// soft-deleted rows alike. Proves completeness against an exact count
// taken first, so a silently truncated read (for example a PostgREST
// max-rows cap) aborts the run instead of making objects look orphaned.
async function fetchAllStoragePaths(
  admin: SupabaseClient,
  table: "collaboration_assets" | "pending_asset_deletions",
): Promise<Set<string>> {
  const { count, error: countErr } = await admin
    .from(table)
    .select("storage_path", { count: "exact", head: true });
  if (countErr) throw new Error(`${table} count failed: ${countErr.message}`);
  if (typeof count !== "number") throw new Error(`${table} count unavailable.`);
  if (count > MAX_REFERENCE_ROWS) throw new Error(`${table} exceeds the row limit.`);

  const paths = new Set<string>();
  let rowsRead = 0;
  // storage_path is UNIQUE NOT NULL in both tables, so this order is total.
  for (let from = 0; from <= MAX_REFERENCE_ROWS; from += REFERENCE_PAGE_SIZE) {
    const { data, error } = await admin
      .from(table)
      .select("storage_path")
      .order("storage_path", { ascending: true })
      .range(from, from + REFERENCE_PAGE_SIZE - 1);
    if (error) throw new Error(`${table} read failed: ${error.message}`);
    const rows = (data ?? []) as { storage_path: unknown }[];
    for (const row of rows) {
      if (typeof row.storage_path !== "string") {
        throw new Error(`${table} returned a non-text storage_path.`);
      }
      paths.add(row.storage_path);
    }
    rowsRead += rows.length;
    if (rows.length < REFERENCE_PAGE_SIZE) break;
  }

  // Rows inserted meanwhile can only raise rowsRead; fewer rows than the
  // count means the read cannot be trusted - including a server-side row
  // cap below REFERENCE_PAGE_SIZE, which ends the loop early.
  if (rowsRead < count) throw new Error(`${table} read was incomplete.`);
  return paths;
}

async function countReferences(
  admin: SupabaseClient,
  table: "collaboration_assets" | "pending_asset_deletions",
  path: string,
): Promise<number> {
  const { count, error } = await admin
    .from(table)
    .select("storage_path", { count: "exact", head: true })
    .eq("storage_path", path);
  if (error) throw new Error(`${table} re-check failed: ${error.message}`);
  if (typeof count !== "number") throw new Error(`${table} re-check count unavailable.`);
  return count;
}

function createSupabaseDeps(url: string, serviceRoleKey: string): ReaperDeps {
  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    listObjects: (maxObjects) => listObjects(admin, maxObjects),
    fetchReferencedPaths: () => fetchAllStoragePaths(admin, "collaboration_assets"),
    fetchQueuedPaths: () => fetchAllStoragePaths(admin, "pending_asset_deletions"),
    isStillUnreferenced: async (path) =>
      (await countReferences(admin, "collaboration_assets", path)) === 0 &&
      (await countReferences(admin, "pending_asset_deletions", path)) === 0,
    removeObject: async (path) => {
      const { data, error } = await admin.storage.from(BUCKET).remove([path]);
      if (error) throw new Error(`storage remove failed: ${error.message}`);
      return Array.isArray(data) && data.length > 0 ? "deleted" : "already_absent";
    },
  };
}

Deno.serve((req: Request): Promise<Response> =>
  handleRequest(req, {
    maintenanceSecret: Deno.env.get("STAGERZ_MAINTENANCE_SECRET"),
    supabaseConfigured: Boolean(SUPABASE_URL && SERVICE_ROLE_KEY),
    deleteEnabled: Deno.env.get("STAGERZ_ORPHAN_REAPER_DELETE_ENABLED") === "true",
    createDeps: () => createSupabaseDeps(SUPABASE_URL!, SERVICE_ROLE_KEY!),
    now: Date.now,
    logError: (message) => console.error(message),
  })
);
