// supabase/functions/_shared/delete-auth-account.ts

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type DeletionStatus = "deleted" | "already_deleted" | "retry_recorded";

export interface DeletionResult {
  authUserId: string;
  status: DeletionStatus;
}

export async function deleteAuthAccount(
  admin: SupabaseClient,
  authUserId: string,
  publicUserId: string,
): Promise<DeletionResult> {
  const { error: deleteErr } = await admin.auth.admin.deleteUser(authUserId);

  if (!deleteErr) {
    await clearPendingRecord(admin, authUserId);
    return { authUserId, status: "deleted" };
  }

  if (isAlreadyMissing(deleteErr)) {
    await clearPendingRecord(admin, authUserId);
    return { authUserId, status: "already_deleted" };
  }

  await recordRetryableFailure(admin, authUserId, publicUserId);
  console.error(`deleteAuthAccount: retryable failure for ${authUserId}: ${deleteErr.message}`);
  return { authUserId, status: "retry_recorded" };
}

function isAlreadyMissing(error: { status?: number; message?: string }): boolean {
  return error.status === 404 || /user not found/i.test(error.message ?? "");
}

async function clearPendingRecord(admin: SupabaseClient, authUserId: string): Promise<void> {
  const { error } = await admin
    .from("pending_auth_deletions")
    .delete()
    .eq("auth_user_id", authUserId);
  if (error) {
    console.error(`clearPendingRecord failed for ${authUserId}: ${error.message}`);
  }
}

async function recordRetryableFailure(
  admin: SupabaseClient,
  authUserId: string,
  publicUserId: string,
): Promise<void> {
  const { error: upsertErr } = await admin.from("pending_auth_deletions").upsert(
    {
      auth_user_id: authUserId,
      public_user_id: publicUserId,
      last_attempted_at: new Date().toISOString(),
    },
    { onConflict: "auth_user_id" },
  );
  if (upsertErr) {
    console.error(`recordRetryableFailure upsert failed for ${authUserId}: ${upsertErr.message}`);
    return;
  }

  const { data: current, error: readErr } = await admin
    .from("pending_auth_deletions")
    .select("attempt_count")
    .eq("auth_user_id", authUserId)
    .single();
  if (readErr) {
    console.error(`recordRetryableFailure read failed for ${authUserId}: ${readErr.message}`);
    return;
  }

  const { error: updateErr } = await admin
    .from("pending_auth_deletions")
    .update({ attempt_count: (current?.attempt_count ?? 0) + 1 })
    .eq("auth_user_id", authUserId);
  if (updateErr) {
    console.error(`recordRetryableFailure update failed for ${authUserId}: ${updateErr.message}`);
  }
}
