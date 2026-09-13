// supabase/functions/process-pending-deletions/index.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { deleteAuthAccount } from "./delete-auth-account.ts";
import { isMaintenanceAuthorized } from "./maintenance-auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAINTENANCE_SECRET = Deno.env.get("STAGERZ_MAINTENANCE_SECRET")!;
const BATCH_SIZE = 25;

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
    .from("pending_auth_deletions")
    .select("auth_user_id, public_user_id")
    .order("requested_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (batchErr) {
    console.error(`process-pending-deletions: batch fetch failed: ${batchErr.message}`);
    return jsonResponse(500, { error: "Internal error." });
  }

  const results = [];
  for (const row of batch ?? []) {
    results.push(await deleteAuthAccount(admin, row.auth_user_id, row.public_user_id));
  }

  return jsonResponse(200, { processed: results.length, results });
});
