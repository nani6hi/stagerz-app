# Phase 22.5 — T2 Execution Record (non-destructive)

**Dates:** 2026-09-20 → 2026-09-22. **Branch:** `phase-22.5-t2-execution`, from `main` @
`375eac5b76ad8f7f7e97720e48eb9c2206893518`.
**Scope executed:** T2 creation, canonical baseline, fingerprint gate, seeds / C3, T2-only
configuration, Edge Function deployment, and safe non-destructive probes.
**Not executed, and not authorized:** `delete-account`; a seeded `process-pending-deletions` run;
creation or destruction of destructive-test throwaway accounts; any destructive Storage cleanup.

---

## 1. Result summary

| Step | Result |
|---|---|
| T2 attempt 1 (`nkolvtdskgdgmebiehnz`) | Baseline applied, **fingerprint gate FAIL 19/20** — CRLF transport artifact (§2). **Deleted** with owner approval |
| T2 replacement (`kjhszwlddzqxcglkpzrn`) | **Clean room verified** |
| Canonical baseline | **Applied, exit 0**, from an LF scratch copy whose **raw** SHA-256 equals the canonical value |
| Fingerprint gate | **PASS 20/20** vs `supabase/verify/expected-production.json` — nothing waived |
| `showcase.sql` | **PASS**, idempotent |
| `fixtures.sql` / **C3** | **PASS — gate C3 CLOSED.** Unmodified, against a real GoTrue `auth.users`; idempotent |
| T2 Auth configuration | Site URL and redirect list set for localhost testing |
| T2 secrets | Fresh `STAGERZ_MAINTENANCE_SECRET`; `STAGERZ_ALLOWED_ORIGIN = http://localhost:8080`; reaper delete flag **unset** |
| Edge Functions | All 4 deployed to T2, `ACTIVE`, `verify_jwt: false` |
| Safe probes | **16 / 16 PASS** |
| Admin-generated magic link | **Available** without mail delivery |
| Production `kbnmkyvbwkuvcklywdhk` | **Unchanged** |
| Legacy `edxicnafggnnvcdvxemk` | **Still `INACTIVE`** |
| Destructive tests | **None run** |

---

## 2. The CRLF incident (T2 attempt 1)

**T2 attempt 1:** `stagerz-t2-disposable-test`, ref `nkolvtdskgdgmebiehnz`, `eu-north-1`.

The baseline was applied with `supabase db query --linked --project-ref … --file` directly from the
repository **working tree**. It applied with exit 0, but the fingerprint gate returned **19 PASS /
1 FAIL**: `functions` expected `c501ddb300762848cb0340bd33f7d6a9`, got
`0185fc188d3bebb7e6af4790190e226c`. The sequence was stopped there, as required.

**Diagnosis.** All **34 of 34** function definitions differed, which ruled out a content error.
Byte-level comparison of one definition showed the only difference: **carriage returns inside the
`$function$ … $function$` bodies** on T2 and none in production.

**Root cause.** The baseline is stored in Git with LF endings (blob SHA-256 =
`8c292ef427c2c2c1ddf1d7833a6530e0a0f33ccb166c5da480eb228c41d78c82`), but the **Windows working-tree
checkout is CRLF** (102,653 bytes; 2,044 CR bytes). The CLI transmitted the on-disk bytes
verbatim, so Postgres stored the CRs inside each function body. Phase 22.3's local runs scored
20/20 because there the file was applied with LF endings inside a Linux container.

**Classification.** Not a baseline defect, not a T2 defect — a **line-ending artifact of
transport**. The gate caught it as designed, and it was **not waived**: the whole purpose of this
phase is to prove faithful reproduction.

**Disposition.** Owner-approved deletion of `nkolvtdskgdgmebiehnz` (pre-checked: 0 auth users, 0
data rows, 0 Storage objects, 0 queue rows, 0 Edge Functions) and recreation. The deletion command
was guarded so that it could not accept any production or legacy ref.

### Measurement caveat, recorded for accuracy

The earlier report of *"2,044 CRs"* in the working-tree file was obtained with `grep -c $'\r'`,
which is **unreliable in this Git-Bash environment** — it also reported 2,044 for a file that
contains none. Re-measured byte-exactly with `tr -cd '\r' | wc -c` and confirmed with `od`, the
working tree genuinely has **2,044 CR bytes** and the LF copy **0**. The figure was right; the
instrument was not. The diagnosis never rested on it alone — byte counts, both hashes and the
`cat -A` view of the stored function bodies established the cause independently.

### Two further line-ending traps found during this run

- **`git archive` is not a raw export on this machine.** With Windows `autocrlf`, it emitted the
  Edge Function sources **with CRLF**, so none matched their Git blobs. Sources were re-exported
  per file with `git cat-file -p`, which emits raw blob bytes; all 11 then matched their blobs
  exactly with 0 CR bytes.
- **The same applies to the seed files.** Both were applied from `git cat-file -p` copies, each
  confirmed equal to its LF-normalised working-tree content.

**Durable fix, not made in this step (by instruction):** a `.gitattributes` entry such as
`supabase/**/*.sql text eol=lf` and `supabase/functions/**/*.ts text eol=lf`.

---

## 3. Replacement T2

| Field | Value |
|---|---|
| Name | `stagerz-t2-disposable-test-r2` |
| Ref | **`kjhszwlddzqxcglkpzrn`** |
| Region | `eu-north-1` (matches production) |
| Status | `ACTIVE_HEALTHY` |
| Plan | Free (organisation `STAGERZ`) |
| Database | PostgreSQL 17.6.1.166 |
| API URL | `https://kjhszwlddzqxcglkpzrn.supabase.co` |
| API keys | 1 publishable, 1 secret, plus legacy `anon` / `service_role` JWTs — **presence only; no value is recorded anywhere in this repository** |

**Clean-room verification before apply:** `public` 0 relations and 0 functions; `auth` schema
present; `storage.buckets` and `storage.objects` present, 0 buckets; `supabase_realtime`
publication present with 0 members; `extensions` schema present; roles `anon`, `authenticated`,
`authenticator`, `service_role`, `supabase_admin`, `supabase_auth_admin`,
`supabase_storage_admin` all present; **0 auth users**. None of the local-only scaffolding that
Phase 22.3 needed was required.

---

## 4. Baseline and fingerprint gate

**Source:** `git cat-file -p origin/main:supabase/migrations/20260919120000_stagerz_baseline.sql`,
written to a scratch path **outside the repository**. **Raw SHA-256 =
`8c292ef427c2c2c1ddf1d7833a6530e0a0f33ccb166c5da480eb228c41d78c82`**, 100,609 bytes, 0 CR bytes;
re-verified immediately before apply. The repository file was not modified and the scratch copy
was not committed.

**Apply:** `supabase db query --linked --project-ref kjhszwlddzqxcglkpzrn --file <scratch copy>` —
read from disk, never retyped or inlined. **Exit 0.**

**Fingerprint gate — PASS 20 / 20, no extra keys:**

| Key | Result | Value |
|---|---|---|
| `app_extensions` | PASS | `pgcrypto@extensions,uuid-ossp@extensions` |
| `buckets` | PASS | `collaboration-assets:false:-:-` |
| `column_count` | PASS | 141 |
| `column_grants` | PASS | `32a364a97747c33874fd1770a656ebe6` |
| `columns` | PASS | `fcd704c20a0297d76c014aa848838645` |
| `constraints` | PASS | `ab65275e52cbe811f33732d10fc2cb41` |
| `default_privileges` | PASS | `1abceade114422b1e791294209e9e79c` |
| `function_count` | PASS | 34 |
| `function_grants` | PASS | `7cdd6702ad38e6d8ba3bbdd8d2893816` |
| **`functions`** | **PASS** | **`c501ddb300762848cb0340bd33f7d6a9`** — the key that failed on attempt 1 |
| `indexes` | PASS | `55bc8b0a291bf22614213ffd6fcea534` |
| `policies` | PASS | `4d9679798c6a3e3e83b14a5892a55b39` |
| `policy_count` | PASS | 23 |
| `realtime_members` | PASS | `collaboration_activity, collaboration_assets, collaboration_credits, collaboration_messages, collaboration_tasks` |
| `relation_count` | PASS | 18 |
| `relation_grants` | PASS | `409b6162c47dc3caeb5fd99e3d58f280` |
| `relations` | PASS | `2278f76df8f503c5a2a6642956feffa8` |
| `trigger_count` | PASS | 4 |
| `triggers` | PASS | `1e27344d5b09eaf29da03972c2103b28` |
| `views` | PASS | `5cae11e32a9f03ea2ef399a53cf90782` |

**This is the first proof on a real hosted Supabase project** that the canonical baseline
reproduces the production contract exactly — Phase 22.3's two proofs used a bare database image.

---

## 5. Seeds and C3

Both seeds applied from raw Git-blob copies (`showcase.sql` SHA-256 prefix `5f3fdd69b74e7180…`,
`fixtures.sql` `b871893585ad0e30…`, each equal to its LF-normalised working-tree content).

**`showcase.sql` — PASS, idempotent.** 4 users (all `is_system`), 4 profiles, 3 wanted posts,
0 auth users. A second run left counts and a content row-hash identical.

**`fixtures.sql` — PASS; gate C3 CLOSED.** Applied **unmodified** against a real GoTrue-managed
`auth.users` — the step Phase 22.3 could not run on a 2021-era stub:

| Measure | Result |
|---|---|
| Auth users / identities | 3 / 3 |
| All on the reserved `@stagerz.test` domain | 3 of 3; **0** non-fixture auth users |
| Email-confirmed | 3 of 3 |
| `user_auth_accounts` created by the real `on_auth_user_created` trigger | 3 |
| Public users / profiles | 7 / 7 (4 showcase + 3 fixture) |
| Fixture usernames | `fixture_applicant`, `fixture_member`, `fixture_owner` |
| Scenario | 5 posts, 1 application, 1 collaboration, 2 participants (`fixture_owner` = owner), 1 task, 1 message |
| Trigger side effects | 1 `collaboration_activity` row and 1 notification, from the message trigger |
| **Idempotency** | Second run: **identical counts and identical row-hash** (`877f783b7d9cfdd3420cb120acfcfa60`) |

**The three fixture accounts must never be destroyed.** Gates D and G depend on them.

---

## 6. T2-only configuration

**Auth.** `site_url = http://localhost:8080`; `additional_redirect_urls = [http://localhost:8080,
http://127.0.0.1:8080]`. Read-only confirmation of the public Auth settings: sign-ups **ON**,
confirm-email **ON**, email provider **ON**, phone **OFF**, anonymous sign-ins **OFF**, no other
providers — matching the production capture's key settings.

> **Process deviation, recorded honestly.** The Auth change was pushed with `supabase config push`
> from a minimal scratch `config.toml`. It was *intended as a preview* (answering "n"), but this CLI
> version **did not prompt** and applied immediately. The effect was exactly the authorized change
> and nothing else: API, DB and Storage reported "up to date", and 11 undeclared remote properties
> were explicitly "left unchanged". It was then verified with the read-only `supabase config diff`
> (no differences). Future config pushes should be treated as immediate.

**Secrets.** Names only; no value is recorded anywhere:

| Secret | State |
|---|---|
| `STAGERZ_MAINTENANCE_SECRET` | **Freshly generated for T2** — 256-bit random, never printed, never the production value |
| `STAGERZ_ALLOWED_ORIGIN` | `http://localhost:8080` — set explicitly, so CORS no longer defaults to `https://stagerz.app` |
| `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` | **Unset** — the reaper can only dry-run |

**Key-handling note:** `supabase projects api-keys` returns the `sb_secret_` key **masked** unless
`--reveal` is passed. Revealed keys were held only in a scratch file outside the repository and
deleted after use.

---

## 7. Edge Functions

All four deployed to **T2 only** (`--no-verify-jwt`, server-side bundling), from raw-blob sources:

| Function | Status | Version | `verify_jwt` | Bundle hash vs production |
|---|---|---|---|---|
| `delete-account` | ACTIVE | 1 | false | differs |
| `process-pending-deletions` | ACTIVE | 1 | false | differs |
| `process-pending-asset-deletions` | ACTIVE | 1 | false | differs |
| `reap-orphaned-collaboration-assets` | ACTIVE | 1 | false | **identical** — `b0663090cefb06aad9d062d1d9c2cc30b6a14fee5a3cf7ce686842162c559397` |

**Finding:** the reaper pins `supabase-js@2.112.1` and produces a **byte-identical bundle** to
production's. The other three import the floating `https://esm.sh/@supabase/supabase-js@2`, so
their bundles depend on what the CDN serves at deploy time; their production deployments also use
a different bundle layout. Their **sources** were already proven identical to production in Phase
22.3 (10/10). A floating dependency makes a deployment non-reproducible — worth pinning later, not
a blocker here.

---

## 8. Safe non-destructive probes — 16 / 16 PASS

Status codes and response shapes only. **No valid user session was ever sent to
`delete-account`**, and reaper delete mode was never requested.

| ID | Probe | Expected | Result |
|---|---|---|---|
| DA-1 | `delete-account` OPTIONS | 204 + CORS `http://localhost:8080` | **PASS** |
| DA-2 | `delete-account` GET | 405 | **PASS** |
| DA-3 | `delete-account` POST, no auth | 401 `Missing authorization.` | **PASS** |
| DA-4 | `delete-account` POST, invalid token | 401 `Invalid session.` | **PASS** |
| PPD-1 / PAD-1 / REP-1 | GET on each maintenance function | 405 | **PASS ×3** |
| PPD-2 / PAD-2 / REP-2 | POST without secret | 401 | **PASS ×3** |
| PPD-3 / PAD-3 / REP-3 | POST with a wrong secret | 401 | **PASS ×3** |
| **PPD-4** | `process-pending-deletions`, **empty queue**, `Authorization: Bearer` | `200 {"processed":0,"results":[]}` | **PASS — first-ever controlled execution** |
| PAD-4 | `process-pending-asset-deletions`, **empty queue**, `X-STAGERZ-Maintenance-Secret` header | `200 {"processed":0,"results":[]}` | **PASS** |
| REP-4 | reaper, default mode | `200`, `"mode":"dry-run"`, 0 objects scanned | **PASS** |

Both maintenance-secret header forms are proven. Pre- and post-probe state was identical: both
deletion queues 0, 0 Storage objects, 3 auth users, 7 users, 0 anonymised, 3 mappings.

---

## 9. Admin-generated magic link — AVAILABLE

`POST /auth/v1/admin/generate_link` with `type: magiclink` for the **existing** fixture account
`fixture_owner` returned **HTTP 200** with `action_link`, `hashed_token` and `email_otp` present
and verification type `magiclink`. No mail delivery is involved. **No account was created**
(auth users stayed 3, 0 sessions), and **the link was neither printed nor followed**.

This confirms the planned route for giving a future destructive-test throwaway account a real
session without a personal mailbox. The throwaway account itself was **not** created.

*(The first attempt returned 401 because the CLI had returned the secret key masked; with the
revealed key it succeeded. The new `sb_secret_` key is sent as `apikey` only, not as a Bearer
token.)*

---

## 10. Production and legacy — unchanged

- **Production `kbnmkyvbwkuvcklywdhk`:** `ACTIVE_HEALTHY`; **43 migrations, latest
  `20260917143322`**; Edge Functions at versions 8 / 9 / 11 / 4 with bundle hashes and timestamps
  identical to before. Only read-only queries were run against it.
- **Legacy `edxicnafggnnvcdvxemk`:** `INACTIVE` throughout. Never touched.
- **GitHub Actions workflow:** untouched. **No production secret** was used in T2.

---

## 11. Gate status after this run

| Gate | Status |
|---|---|
| **C3** | **CLOSED — PASS** (§5) |
| **D** | Backend prerequisites ready; the browser session run is still to do |
| **G** | Bucket and policies proven by the fingerprint; the upload / download / refusal run is still to do |
| **E** | Non-destructive half done (§8). **Destructive half awaits separate owner approval** |

Housekeeping: CLI link residue (`supabase/.temp/`, pointing at the deleted first T2) was removed
from the working tree; the repository contains no CLI state, secret or backup artifact.
