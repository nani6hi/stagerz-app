// supabase/functions/process-pending-asset-deletions/index.ts
//
// Mirrors the existing process-pending-deletions function's shape
// exactly: maintenance-secret-gated, service-role client, batches a
// pending_* queue table, performs the privileged operation the
// client session could never safely perform itself, and only
// removes the queue entry (and here, also the soft-deleted metadata
// row) once that operation is confirmed complete.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isMaintenanceAuthorized } from "./maintenance-auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAINTENANCE_SECRET = Deno.env.get("STAGERZ_MAINTENANCE_SECRET")!;
const BUCKET = "collaboration-assets";
const BATCH_SIZE = 25;

interface PendingRow {
  asset_id: string;
  collaboration_id: string;
  file_name: string;
  storage_path: string;
  attempt_count: number;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  if (!isMaintenanceAuthorized(req, MAINTENANCE_SECRET)) {
    return jsonResponse(401, { error: "Unauthorized." });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: batch, error: batchErr } = await admin
    .from("pending_asset_deletions")
    .select("asset_id, collaboration_id, file_name, storage_path, attempt_count")
    .order("requested_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (batchErr) {
    console.error(`process-pending-asset-deletions: batch fetch failed: ${batchErr.message}`);
    return jsonResponse(500, { error: "Internal error." });
  }

  const results = [];
  for (const row of (batch ?? []) as PendingRow[]) {
    results.push(await deleteAsset(admin, row));
  }

  return jsonResponse(200, { processed: results.length, results });
});

async function deleteAsset(
  // deno-lint-ignore no-explicit-any
  admin: any,
  row: PendingRow,
): Promise<{ assetId: string; status: string }> {
  const { data: removed, error: removeErr } = await admin.storage
    .from(BUCKET)
    .remove([row.storage_path]);

  if (!removeErr) {
    const objectWasPresent = Array.isArray(removed) && removed.length > 0;

    const { error: metaDeleteErr } = await admin
      .from("collaboration_assets")
      .delete()
      .eq("id", row.asset_id);
    if (metaDeleteErr) {
      console.error(`deleteAsset: metadata cleanup failed for ${row.asset_id}: ${metaDeleteErr.message}`);
    }

    const { error: queueDeleteErr } = await admin
      .from("pending_asset_deletions")
      .delete()
      .eq("storage_path", row.storage_path);
    if (queueDeleteErr) {
      console.error(`deleteAsset: queue cleanup failed for ${row.asset_id}: ${queueDeleteErr.message}`);
    }

    return { assetId: row.asset_id, status: objectWasPresent ? "deleted" : "already_deleted" };
  }

  const { error: updateErr } = await admin
    .from("pending_asset_deletions")
    .update({
      last_attempted_at: new Date().toISOString(),
      attempt_count: (row.attempt_count ?? 0) + 1,
    })
    .eq("storage_path", row.storage_path);
  if (updateErr) {
    console.error(`deleteAsset: retry-tracking update failed for ${row.asset_id}: ${updateErr.message}`);
  }

  console.error(`deleteAsset: retryable failure for ${row.asset_id}: ${removeErr.message}`);
  return { assetId: row.asset_id, status: "retry_recorded" };
}
