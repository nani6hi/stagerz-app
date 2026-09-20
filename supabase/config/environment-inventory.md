# STAGERZ backend — environment & configuration inventory (Phase 22.3)

Values of secrets are **never** recorded here, only their names and purpose. Captured read-only from the production backend of record `kbnmkyvbwkuvcklywdhk` on 2026-09-19 unless stated otherwise. The Auth capture (§6) is complete; this inventory is current, not a draft.

## 1. Edge Functions

| Function | Deployed version | `verify_jwt` | Entrypoint (repo) | Files deployed | Env / secret names read |
|---|---|---|---|---|---|
| `delete-account` | 8 | **false** | `functions/delete-account/index.ts` | `index.ts`, `../_shared/delete-auth-account.ts` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (platform-provided), `STAGERZ_ALLOWED_ORIGIN` (optional; fallback `https://stagerz.app`) |
| `process-pending-deletions` | 9 | **false** | `functions/process-pending-deletions/index.ts` | `index.ts`, `delete-auth-account.ts`, `maintenance-auth.ts` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET` |
| `process-pending-asset-deletions` | 11 | **false** | `functions/process-pending-asset-deletions/index.ts` | `index.ts`, `maintenance-auth.ts` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET` |
| `reap-orphaned-collaboration-assets` | 4 | **false** | `functions/reap-orphaned-collaboration-assets/index.ts` | `index.ts`, `reaper.ts`, `maintenance-auth.ts` (`reaper.test.ts` is test-only, not deployed) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET`, `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` (optional; delete mode only when exactly `true`) |

**Notes:**
- **Source parity:** all 10 deployed files are byte-identical to the repository (SHA-256 compared, 2026-09-19).
- **Why `verify_jwt = false` on all four:**
  - `delete-account` validates the caller's session itself (`auth.getUser()`);
  - the three maintenance functions require `STAGERZ_MAINTENANCE_SECRET` via `Authorization: Bearer` or `X-STAGERZ-Maintenance-Secret`.
  
  A rebuild must deploy them with `--no-verify-jwt`.
- **Imports:** `https://esm.sh/@supabase/supabase-js@2` (floating) in 3 functions; `@2.112.1` (pinned) in the reaper. No import map. No deployment order dependency.
- **Scheduling:** only `process-pending-asset-deletions` is scheduled, by `.github/workflows/process-pending-asset-deletions.yml`: daily at 03:17 UTC and by manual dispatch, POST to the production function URL, secret `STAGERZ_MAINTENANCE_SECRET` in GitHub Actions. `process-pending-deletions` and the reaper have **no scheduler** in the repository.

## 2. Secrets and configuration by name

| Name | Where it lives | Purpose | Per-environment? |
|---|---|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Injected by the platform into Edge Functions | Project URL and keys | Automatic per project |
| `STAGERZ_MAINTENANCE_SECRET` | Edge Function secrets **and** GitHub Actions secret (same value) | Authorises maintenance functions | **Yes**: generate a distinct value per environment |
| `STAGERZ_ALLOWED_ORIGIN` | Edge Function secret (optional) | CORS origin for `delete-account` | Yes: e.g. the test frontend origin |
| `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` | Edge Function secret (optional) | Enables reaper delete mode | Keep unset outside deliberate runs |
| Frontend environment table (`STAGERZ_ENVIRONMENTS`, `STAGERZ_HOST_ENVIRONMENT`) | `index.html` "STAGERZ ENVIRONMENT SELECTION" block (Phase 22.3): production URL and publishable key (public by design); `local` = `http://127.0.0.1:54321` | Hostname → backend; unknown hosts fail closed; the sign-in redirect follows the environment | Yes: one entry per environment |
| Local publishable key | **Not in the repository**: the developer's browser `localStorage['stagerz:local-supabase-key']` | Local stack only | Local only |

**Production API key state** (state and counts only, no values; 2026-09-19):
- legacy JWT `anon` key: **enabled** (tool and owner);
- legacy JWT `service_role` key: **enabled** (owner);
- publishable keys: **1**, enabled (tool; the one used by `index.html`);
- secret keys (`sb_secret_…`): **1** (owner, count only).

The production legacy JWT never appears in the repository's git history. The only JWT ever committed belonged to the legacy project and was disabled in Phase 22.1. Whether production's legacy JWT keys can be disabled is a later hardening question; nothing in the repository uses them.

## 3. Storage

| Item | Value |
|---|---|
| Bucket | `collaboration-assets`: **private**, no file-size limit, no MIME restriction |
| Policies (`storage.objects`) | `participants can read collaboration assets` (SELECT), `participants can upload collaboration assets` (INSERT). There is **no** UPDATE or DELETE policy: deletion runs only through `process-pending-asset-deletions` with the service role |
| Path convention | `<collaboration-uuid>/<timestamp>-<rand>-<original-name>` (all current objects are exactly 2 levels deep) |
| App assumptions | Metadata rows in `public.collaboration_assets` / `public.pending_asset_deletions` reference `storage_path`; the reaper deletes only unreferenced objects of the exact path shape older than 48 h |
| Platform vs app | The bucket row and 2 policies are application setup (in the baseline). The Storage schema, internal triggers and object metadata are platform-managed. **Objects (files) are data**: never part of the baseline, and not included in database backups |

## 4. Realtime

- **Publication:** `supabase_realtime` (platform-created), with the application adding the whole tables `collaboration_activity`, `collaboration_assets`, `collaboration_credits`, `collaboration_messages`, `collaboration_tasks` (no column lists, no row filters).
- `supabase_realtime_messages_publication` and its daily partitions are platform-managed.

## 5. Database role settings (platform defaults, not reproduced)

`anon` `statement_timeout=3s`; `authenticated` `statement_timeout=8s`; `authenticator` `statement_timeout=8s`, `lock_timeout=8s`, `session_preload_libraries=supautils, safeupdate`.

## 6. Auth configuration

**Status:** **COMPLETE owner capture, 2026-09-19** (dashboard screenshots of production `kbnmkyvbwkuvcklywdhk`, in two parts; values are owner/dashboard-confirmed unless marked "tool"). Nothing was changed. No key, secret or e-mail value is recorded.

Known from code:
- sign-in is **passwordless magic link** (`signInWithOtp`, `shouldCreateUser: true`, redirect from the environment table, which is `https://stagerz.app` for production);
- sessions are stored under `sb-<project-ref>-auth-token` in localStorage.

Known from the database:
- providers in use: `email` only;
- trigger `on_auth_user_created` → `public.handle_new_auth_user()`.

| Area | Setting | Production value | Source |
|---|---|---|---|
| URL | Site URL | `https://stagerz.app` | owner |
| URL | Redirect URLs (allow-list) | `https://stagerz.app` (**1 entry**) | owner |
| Sign-ups / providers | Allow new users to sign up | **ON** | owner |
| Sign-ups / providers | Allow manual linking | OFF | owner |
| Sign-ups / providers | Allow anonymous sign-ins | OFF | owner |
| Sign-ups / providers | Confirm email | ON | owner |
| Sign-ups / providers | Email provider | ENABLED | owner |
| Sign-ups / providers | Phone provider | DISABLED | owner |
| Sign-ups / providers | Other providers | all disabled | owner |
| Sign-ups / providers | Secure email change | ON | owner |
| Password settings | Secure password change | OFF | owner |
| Password settings | Require current password when updating | OFF | owner |
| Password settings | Prevent use of leaked passwords | OFF | owner |
| Password settings | Minimum password length | 6 | owner |
| Password settings | Password requirements | none selected | owner |
| Email | Custom SMTP | **OFF** (default SMTP; delivers only to organisation team members) | owner |
| Email | Email OTP expiry | 3600 s | owner |
| Email | Email OTP length | 6 digits | owner |
| Email | Magic Link template mode (link / code / both) | **link-based** | owner |
| Rate limits | Sending emails | **2 emails / hour** | owner |
| Rate limits | SMS | 30 / hour | owner |
| Rate limits | Token refreshes | 150 requests / 5 min per IP | owner |
| Rate limits | Token verifications | 30 requests / 5 min per IP | owner |
| Rate limits | Anonymous users | 30 requests / hour per IP | owner |
| Rate limits | Sign-ups and sign-ins | 30 requests / 5 min per IP | owner |
| Rate limits | Web3 sign-ups and sign-ins | 30 requests / 5 min per IP | owner |
| Rate limits | IP address forwarding | OFF | owner |
| Attack protection | CAPTCHA | **OFF** | owner |
| Attack protection | Leaked-password protection | DISABLED (Pro-only) | owner, and Advisor |
| Sessions | Enforce single session per user | OFF | owner |
| Sessions | Session time-box | 0 (never) | owner |
| Sessions | Inactivity timeout | 0 (never) | owner |
| Sessions | Access-token (JWT) expiry | 3600 s | owner |
| Sessions | Refresh-token compromise detection / rotation | ON | owner |
| Sessions | Refresh-token reuse interval | 10 s | owner |
| Hooks / MFA | Auth hooks | none | owner |
| Hooks / MFA | TOTP MFA | ENABLED (0 factors enrolled, per database) | owner, and tool |
| Hooks / MFA | Phone MFA | DISABLED | owner |
| Hooks / MFA | Maximum MFA factors per user | 10 | owner |
| Hooks / MFA | AAL1 session limit | ON | owner |
| Keys | Legacy `anon` JWT | enabled | tool (2026-09-19) |
| Keys | Legacy `service_role` JWT | enabled | owner |
| Keys | Publishable key | 1, enabled | tool |
| Keys | Secret keys (`sb_secret_…`) | 1 (count only) | owner |

**Rebuild note:** a rebuilt environment copies these values, but its **Site URL and redirect allow-list must be its own URLs** (for example `http://localhost:<port>` for T1). For local T1 the CLI's `config.toml` `[auth]` section holds them.
