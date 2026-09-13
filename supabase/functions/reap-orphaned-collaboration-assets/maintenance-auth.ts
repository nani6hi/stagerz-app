// supabase/functions/reap-orphaned-collaboration-assets/maintenance-auth.ts
//
// Same logic as process-pending-deletions' maintenance-auth.ts (kept
// as a duplicated file rather than a true cross-function shared
// module, due to Edge Function bundling constraints -- all three copies
// must be kept in sync if this logic ever changes again).
//
// Accepts either:
//   Authorization: Bearer <secret>              (external/CI callers)
//   X-STAGERZ-Maintenance-Secret: <raw secret>   (Supabase Dashboard
//     Test UI, which reserves/replaces Authorization with its own
//     role JWT and therefore cannot carry the secret at all)
// Never logs the secret or any header value.

function extractBearerToken(headerValue: string | null): string | null {
  if (!headerValue) return null;
  const trimmed = headerValue.trim();
  const match = trimmed.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1].trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function isMaintenanceAuthorized(req: Request, maintenanceSecret: string): boolean {
  const expectedToken = maintenanceSecret.trim();

  const dedicatedHeader = req.headers.get("X-STAGERZ-Maintenance-Secret");
  if (dedicatedHeader !== null && dedicatedHeader.trim() === expectedToken) {
    return true;
  }

  const bearerToken = extractBearerToken(req.headers.get("Authorization"));
  if (bearerToken !== null && bearerToken === expectedToken) {
    return true;
  }

  return false;
}
