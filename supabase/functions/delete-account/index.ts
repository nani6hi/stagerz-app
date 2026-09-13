// supabase/functions/delete-account/index.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { deleteAuthAccount } from "../_shared/delete-auth-account.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ALLOWED_ORIGIN = Deno.env.get("STAGERZ_ALLOWED_ORIGIN") || "https://stagerz.app";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(401, { error: "Missing authorization." });
  }

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: getUserErr } = await userClient.auth.getUser();
  if (getUserErr || !userData?.user) {
    return jsonResponse(401, { error: "Invalid session." });
  }
  const callerAuthUserId = userData.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: mapping, error: mapErr } = await admin
    .from("user_auth_accounts")
    .select("public_user_id")
    .eq("auth_user_id", callerAuthUserId)
    .maybeSingle();

  if (mapErr) {
    console.error(`delete-account: mapping lookup failed: ${mapErr.message}`);
    return jsonResponse(500, { error: "Internal error." });
  }

  if (!mapping) {
    return jsonResponse(200, { status: "already_processed" });
  }
  const publicUserId = mapping.public_user_id;

  const { data: pendingRows, error: anonErr } = await admin.rpc(
    "admin_anonymize_account",
    { p_public_user_id: publicUserId },
  );
  if (anonErr) {
    console.error(`delete-account: anonymize failed: ${anonErr.message}`);
    return jsonResponse(500, { error: "Internal error." });
  }

  const mappedAuthUserIds: string[] = (pendingRows ?? []).map(
    (r: { pending_auth_user_id: string }) => r.pending_auth_user_id,
  );

  const { error: signOutErr } = await userClient.auth.signOut({ scope: "global" });
  if (signOutErr) {
    console.error(`delete-account: signOut returned an error (continuing): ${signOutErr.message}`);
  }

  const results = [];
  for (const authUserId of mappedAuthUserIds) {
    const { error: upsertErr } = await admin.from("pending_auth_deletions").upsert(
      { auth_user_id: authUserId, public_user_id: publicUserId },
      { onConflict: "auth_user_id" },
    );
    if (upsertErr) {
      console.error(`delete-account: pending upsert failed for ${authUserId}: ${upsertErr.message}`);
    }
    results.push(await deleteAuthAccount(admin, authUserId, publicUserId));
  }

  return jsonResponse(200, { status: "processed", results });
});
