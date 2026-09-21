# Phase 22.5 — T2 Execution Record (non-destructive)

**Dates:** 2026-09-20 → 2026-09-22. **Branch:** `phase-22.5-t2-execution`, from `main` @
`375eac5b76ad8f7f7e97720e48eb9c2206893518`.
**Scope executed:** T2 creation, canonical baseline, fingerprint gate, seeds / C3, T2-only
configuration, Edge Function deployment, and safe non-destructive probes.
**Not executed, and not authorized:** `delete-account`; a seeded `process-pending-deletions` run;
creation or destruction of destructive-test throwaway accounts; any destructive Storage cleanup.
*(Scope statement for the original run, preserved. SUPERSEDED: Gates D/G and the destructive half
of Gate E were later executed under separate owner approvals — see §12 and §14.)*

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

## 11. Gate status after this run — **SUPERSEDED by §13 (Gates D and G, 2026-09-22)**

| Gate | Status |
|---|---|
| **C3** | **CLOSED — PASS** (§5) |
| **D** | Backend prerequisites ready; the browser session run is still to do |
| **G** | Bucket and policies proven by the fingerprint; the upload / download / refusal run is still to do |
| **E** | Non-destructive half done (§8). **Destructive half awaits separate owner approval** |

Housekeeping: CLI link residue (`supabase/.temp/`, pointing at the deleted first T2) was removed
from the working tree; the repository contains no CLI state, secret or backup artifact.

---

## 12. Gates D and G — executed 2026-09-22 against T2 only

**Approval scope:** Gates D and G on T2 (`kjhszwlddzqxcglkpzrn`) only. **Not approved and not run:**
the destructive half of Gate E (`delete-account` with a valid session, a seeded
`process-pending-deletions`, any throwaway account, any Auth-user deletion, reaper delete mode).

### Preflight — all invariants PASS

`main` = `a11c7183f5f002006025b07621663c5280ce513f`, clean tree; T2 `ACTIVE_HEALTHY`; production and
legacy refs refused by a guard in every query and delete helper; **fingerprint 20/20 before
testing**; fixture/C3 state consistent (3 auth users, 0 non-fixture, 3 mappings, 7 users, 0
anonymised, 1 collaboration with 2 participants); all 4 Edge Functions `ACTIVE`; reaper delete flag
unset.

### Method

- The **shipped application** (`index.html` served content-identical to `main` at
  `http://localhost:8080`) ran in **real Microsoft Edge (headless)**, driven over the DevTools
  protocol. It targeted T2 through the approved `stagerz:local-supabase-url` /
  `stagerz:local-supabase-key` override — **no application code was changed**. Resolved
  environment: `local`, URL = T2, `startupFailure = null`.
- Sign-in used an **admin-generated magic link**: the browser was navigated to the link exactly as a
  user clicking it would be, and no mail was sent. Second-user sessions (for controls) were minted
  from the same admin API and verified server-side. **No link, token, key or secret was printed or
  stored in the repository.**
- Every test went through the **app's own functions** where one exists: `getMyDomainId()`,
  `fetchMyProfile()`, `supaSelect()`, `supaUpdate()`, `openCollaboration()` (with its own Realtime
  subscription), `uploadCollaborationAsset()` and `deleteCollaborationAssetPrompt()`.

### Gate D — PASS

| ID | Result | Evidence |
|---|---|---|
| **D1** Authentication | **PASS** | Real Auth session for `fixture_owner` (`aud=authenticated`, access and refresh tokens present); landed on `localhost:8080` with the token cleared from the URL; the app entered `screen-stage`. **After a full page reload the session was restored** for the same user and Stage was shown again |
| **D2** Account contract | **PASS** | `getMyDomainId()` resolved the public user id through `user_auth_accounts`; `fetchMyProfile()` returned `username = fixture_owner` |
| **D3** Authenticated reads | **PASS** | Own profile, `public_profiles` (another artist, non-empty `display_name`), Stage (`wanted_posts` open: 4 rows), collaboration, participants (2), messages (1), tasks (1) — all HTTP 200, with `supaSelect()` returning the same rows. Own `users` row read with **exactly the app's 7 columns** → HTTP 200, 1 row; **another user's row → 0 rows** (policy *"authenticated can read own row"*) |
| **D4** Anonymous denial | **PASS** | Anonymous `users`, `user_auth_accounts` and `collaboration_messages` → **HTTP 401 / `42501`, 0 rows** |
| **D5** Reversible write | **PASS** | `supaUpdate('profiles', …, {bio: marker})` → HTTP 200; read-back showed the marker; restored to the exact original (an **empty string**); read-back equal. Independently confirmed by an unchanged fixture row-hash that distinguishes `null` from `''` |
| **D6** Realtime | **PASS** | `openCollaboration()` joined the app's own channel `realtime:collaboration-…0301` (`state = joined`); the G1 upload produced `postgres_changes` that **the app's own channel received**, for both `collaboration_assets` and `collaboration_activity` |

**Three test-design corrections, recorded rather than hidden:**

1. **D3 own `users` row — run 1 returned 403.** The probe requested `select=*`. `authenticated` has
   **no table-level** `SELECT` on `users`, only **column-level** `SELECT` on 7 columns (the Phase
   21.3 W-1/W-3 narrowing), which are exactly the columns the app requests in `fetchMyProfile()`.
   With those columns the read returns 200. The 403 came from the test's column list, not a defect.
2. **D4 `profiles` — anonymous read returned 200.** `profiles` carries the explicit policy
   **`profiles are publicly readable`** (roles `public`, `using true`), with anonymous column grants
   limited to 16 public artist fields (display name, bio, skills, location, counts, …). It is a
   **deliberate public surface**, identical in production (the fingerprint matches policies and
   grants 20/20), so the test had misclassified it as protected. `public_profiles` is likewise
   public (INFO).
3. **Separate cross-user Realtime control — INCONCLUSIVE, and NOT used as evidence.** Beyond the
   required test, a second participant (`fixture_member`) and a nonparticipant
   (`fixture_applicant`) were subscribed from a separate Deno script. The member received nothing,
   although the app's own channel did. Because that positive control failed, the nonparticipant's
   "0 events" is uninterpretable. **This control is used neither as evidence for D6 nor as evidence
   of nonparticipant Realtime isolation**, and **it is not required to close Gate D**. A plausible
   cause is how the script authenticated its Realtime connection; that was not investigated, and it
   was not re-run, to avoid further writes and scope.

   **The required D6 PASS rests solely on the application's own Realtime collaboration channel**
   (`openCollaboration()` → `realtime:collaboration-…0301`, `state = joined`), which received the
   `postgres_changes` events for `collaboration_assets` and `collaboration_activity`.

### Gate G — PASS

| ID | Result | Evidence |
|---|---|---|
| **G1** Authorised upload | **PASS** | `uploadCollaborationAsset()` as `fixture_owner`: a 321-byte object (a text header plus every byte value 0–255) accepted by Storage under the fixture collaboration folder; metadata row created |
| **G2** Authorised download | **PASS** | Owner download: 321 bytes, **SHA-256 identical**. Control: the other participant (`fixture_member`) also downloaded an identical object |
| **G3** Nonparticipant refusal | **PASS** | `fixture_applicant` (verified not a participant): download **refused** (`Object not found`), **no content returned**; folder listing showed **0 objects**. Anonymous download: **HTTP 400**, no content |
| **G4** Deletion path + drainer | **PASS** (see caveat) | `deleteCollaborationAssetPrompt()` (confirm answered OK) soft-deleted the asset and queued **exactly 1** row matching its id and path. `process-pending-asset-deletions` with the T2 maintenance secret → **HTTP 200, `processed = 1`, status `deleted`** — the **first exercise of the drainer's present-object branch**. Afterwards: catalog 0 objects, queue 0, asset rows 0; participant listing 0; metadata API 400; one immediate download on the previously used URL returned 200 (see caveat), after which that URL and a cache-busted URL returned **HTTP 400, no content**; a second drainer run processed 0 |

**G4 caveat — a transient post-delete 200.**

*Observation (fact):*

- `process-pending-asset-deletions` reported `processed = 1`, status `deleted`.
- The Storage catalog then held **0 objects**; `pending_asset_deletions` and `collaboration_assets`
  were both **empty**; a participant's folder listing showed 0 objects.
- A participant download issued **immediately** afterwards, on the **previously used URL**, returned
  **HTTP 200 — once**. The same participant token had downloaded that same URL moments before the
  drain.
- **Shortly afterwards the same URL returned HTTP 400** with no content.
- A **cache-busted URL returned HTTP 400** with no content, and the metadata API returned 400.
- A **second drainer run processed 0**.

*Hypothesis (not proven):* a plausible explanation for the single 200 is **CDN / edge caching** of
the earlier response to the same URL and token, with invalidation not yet propagated. **This is not
established:** cache-related response headers were **not captured** on the 200 response, so the
cause cannot be confirmed from this run. It was deliberately not re-investigated, to avoid another
T2 write.

*Recorded finding:* immediately after deletion, the previously used URL returned the object once for
a participant who had just fetched it; the object was unavailable shortly afterwards. The cause is
unconfirmed.

### Post-test state

| Check | Result |
|---|---|
| Fixture row-hash (users, profiles incl. `bio`, posts, messages, collaboration, participants) | **Identical** to pre-test (`5201c9e527f03ea5f18525a3ee9178fa`) |
| Auth users / mappings / anonymised | 3 / 3 / 0 — **no Auth user deleted** |
| `pending_auth_deletions` | **0 — never seeded** |
| Storage objects / `pending_asset_deletions` / `collaboration_assets` | 0 / 0 / 0 — **the G test object is gone** |
| Auth sessions | 0 — every test session signed out |
| Expected residual fixture data | +2 `collaboration_activity` (`asset_uploaded`, `asset_deleted`) and +1 notification (`collaboration_asset_uploaded`) — trigger side effects of the app's own upload and delete paths |
| Reaper delete flag | Unset |
| **Fingerprint after testing** | **20/20 PASS** |

CLI residue (`supabase/.temp/`, created by a CLI call from the repository root) was removed again;
the working tree contains no CLI state, key, secret or backup artifact.

### Production and legacy — unchanged

- **Production `kbnmkyvbwkuvcklywdhk`:** `ACTIVE_HEALTHY`; **43 migrations, latest
  `20260917143322`**; Edge Functions still v8 / v9 / v11 / v4 with identical bundle hashes and
  timestamps. Read-only queries only.
- **Legacy `edxicnafggnnvcdvxemk`:** `INACTIVE`, untouched.
- No DNS, Netlify, GitHub Pages or GitHub Actions change.

---

## 13. Gate status after Gates D and G — **SUPERSEDED by §15 (Gate E, 2026-09-22)**

| Gate | Status |
|---|---|
| **C3** | **CLOSED — PASS** (§5) |
| **D** | **CLOSED — PASS** (§12). D6 rests on the app's own Realtime channel; the separate cross-user control was inconclusive, is not used as evidence, and is not required |
| **G** | **CLOSED — PASS** (§12), with one transient post-delete HTTP 200 recorded (cause unconfirmed; caching is a hypothesis only) |
| **E** | Non-destructive half done (§8); the drainer's present-object branch is now exercised (G4). **Destructive half — `delete-account` and a seeded `process-pending-deletions` — NOT APPROVED, NOT RUN** |

---

## 14. Destructive Gate E — executed 2026-09-22 against T2 only

### Owner approval boundary

Approved: **E1** — one dedicated, newly created disposable T2 Auth account tested through
`delete-account` with a valid session; **E2** — one different dedicated, newly created disposable
T2 Auth account tested through a seeded `process-pending-deletions` run.

Explicitly **not** approved, and **not** done: deleting, anonymising or queueing any fixture or
showcase/system user; any account beyond E1 and E2; destructive orphan-reaper mode; repeating the
asset drainer (already proven in G4); any change to Edge Function source, Auth configuration,
secrets, schema, RLS, baseline, seeds or GitHub Actions; any production or legacy change.

### Safety preflight — all invariants PASS

`main` = `d6839c4a61c53c9676bc23c383398016cf65cb03`, clean tree; T2 `kjhszwlddzqxcglkpzrn`
`ACTIVE_HEALTHY`; production `kbnmkyvbwkuvcklywdhk` and legacy `edxicnafggnnvcdvxemk` (`INACTIVE`)
confirmed by ref, not by name; **fingerprint 20/20**; 3 fixture Auth users and 0 others; 3
mappings; 0 anonymised; `pending_auth_deletions` empty and no fixture pending; Storage empty;
asset queue empty; 0 sessions; collaboration scenario intact; reaper delete flag unset.

### Deny-list procedure

1. **Captured before any creation:** the 3 fixture Auth user ids and **all 7 pre-existing public
   user ids** (so showcase/system users were protected too), plus a content hash over every
   pre-existing user, profile, mapping, Auth user, collaboration and participant row
   (`6bbcc06c7d11cce29314b0bbe4a1d9ef`).
2. **A single guard module** used by every destructive step: it refuses any URL containing the
   production or legacy ref, refuses anything not on the T2 host, refuses malformed ids, and
   refuses any Auth id or public id on the deny-list.
3. **The guard was proven before use:** it refused all 3 fixture Auth ids, a pre-existing public
   id, both protected refs and a malformed id, and allowed only novel ids (the control).
4. **Re-checked immediately before each destructive call:** before `delete-account` (the session's
   own user id and the target public id), before seeding (inside the SQL transaction), and before
   the drainer (every row in the **live** queue).

### E1 — `delete-account` end-to-end: **PASS (14/14)**

Target: a new account labelled `gate-e1-disposable-…@stagerz.test`, created with the Auth admin API
(`email_confirm`), whose `on_auth_user_created` trigger produced the public row, profile and
mapping as for a real sign-up. It was **not** on the deny-list. Before deletion, server-side: 4
Auth users (3 fixtures + E1), 4 mappings, E1 not anonymised, pre-existing hash unchanged.

| Check | Result |
|---|---|
| Real session | Minted for the E1 account only via an admin-generated magic link (never printed); `uid` matched the target; `GET /auth/v1/user` 200; own mapping row visible |
| **Invocation** | **First approved valid-session call:** `delete-account` → **HTTP 200, `status: processed`, one result, E1's Auth id, `status: deleted`** |
| Auth user | **Removed** (admin API 404) |
| Mapping | **Removed** — `user_auth_accounts` row cascaded (FK `ON DELETE CASCADE`) |
| Application account | `public.users` row **retained and anonymised**: `anonymized_at` set; `username`, `first_name`, `last_name`, `photo_url`, `bio`, `location` all null |
| Profile | `display_name = 'Deleted User'`; `role`, `location`, `country_flag` empty; `skills`, `looking_for` empty arrays |
| Public surface | `public_profiles`: `display_name = 'Deleted User'`, `is_deleted = true` |
| Queue | `pending_auth_deletions` entry **cleared** |
| Old session — Auth | `GET /auth/v1/user` → **403** |
| Old session — refresh | Refresh token → **400**, no new session |
| Old session — data | The database API (PostgREST) still **accepted** the unexpired access JWT (HTTP 200); the **one tested** own-identity lookup (own `user_auth_accounts` row) returned **0 rows**, because the mapping was gone. Other endpoints were not tested — see Findings (hardening follow-up) |
| **Idempotency** | Second call with the same, now-deleted session → **401 `Invalid session.`**, refused at `getUser()` before any admin action |

**`already_processed` branch — NOT exercised, and it does not block E1 PASS.** The implementation
reaches that branch only for a caller whose Auth user still exists but whose mapping is already
gone — for example after a failed Auth deletion. In the successful-deletion scenario the deleted Auth
identity can no longer authenticate, so `getUser()` rejects it (401) before the branch can be
reached. Exercising it would need another account; **no additional account was created**, per the
approval boundary.

### E2 — `process-pending-deletions` end-to-end: **PASS (8/8)**

Target: a **different** new account labelled `gate-e2-disposable-…@stagerz.test` (Auth id, public
id and e-mail all distinct from E1), created the same way, not on the deny-list.

**Seeded state.** In production a `pending_auth_deletions` row exists only after
`admin_anonymize_account` has run — `delete-account` anonymises first, queues, and then deletes the
Auth user; the drainer exists for the case where that last step fails. The faithful pre-state is
therefore **anonymised + queued**, and exactly that was seeded, **for E2 only**, in one transaction
guarded against fixture ids, pre-existing public ids, any account that was not the E2 disposable
account, a mapping mismatch, and a non-empty queue. Result: queue rows = 1, the sole row = E2,
fixture rows queued = 0, E2 anonymised, E2 Auth user present.

> *Harness incident, recorded:* the first seed attempt failed with an SQL syntax error (malformed
> dollar-quoting in the generated SQL) and was rejected before executing anything. **Zero mutation
> was verified** — queue still empty, only E1 anonymised, E2 untouched — before the same seed, for
> the same target, was regenerated correctly and applied. No replacement target was created.

| Check | Result |
|---|---|
| Live-queue pre-check | Exactly 1 row, the E2 target; no fixture queued; differs from E1; every row passed the deny-list guard; project ref re-verified |
| **Invocation** | `process-pending-deletions` with the T2 maintenance secret (never printed) → **HTTP 200, `processed = 1`, E2's Auth id, `status: deleted`** |
| Auth user | **Removed** (admin API 404) |
| Mapping | **Removed** (cascade) |
| Application account | `public.users` row retained and still anonymised — the drainer deletes only the Auth user, per contract |
| Queue | Entry **cleared** |
| Second invocation | **HTTP 200, `processed = 0`** |

### Fixture preservation and post-state

| Check | Result |
|---|---|
| Pre-existing data hash | **Identical** before E1, after E1 and after E2 (`6bbcc06c7d11cce29314b0bbe4a1d9ef`) |
| Fixture Auth users | **Exactly 3**, all present; 0 non-fixture Auth users |
| Fixture mappings | **3 / 3** intact |
| Disposable accounts | **Both gone** from Auth |
| Collaboration scenario | 1 collaboration, 2 participants, 1 message, 1 task — unchanged |
| `pending_auth_deletions` / `pending_asset_deletions` | 0 / 0 |
| Storage objects / `collaboration_assets` | 0 / 0 |
| Sessions / live refresh tokens | 0 / 0 |
| Reaper delete flag | **Unset** — destructive reaper mode **not run** |
| Expected residue | **2 anonymised `Deleted User` public rows** (E1, E2) — the implemented contract retains and scrubs the application row rather than deleting it |
| **Fingerprint after destructive testing** | **20/20 PASS** |

### Production and legacy — unchanged

- **Production `kbnmkyvbwkuvcklywdhk`:** `ACTIVE_HEALTHY`; **43 migrations, latest
  `20260917143322`**; Edge Functions still v8 / v9 / v11 / v4 with identical bundle hashes and
  timestamps. Read-only queries only.
- **Legacy `edxicnafggnnvcdvxemk`:** `INACTIVE`, untouched.

### Findings

1. **SECURITY / HARDENING FOLLOW-UP — existing access JWTs may remain technically usable at the
   database API until expiry.**

   *Observed, after the successful E1 deletion:*
   - Supabase Auth **rejected** the deleted user's existing session on user lookup
     (`GET /auth/v1/user` → 403).
   - The refresh token **could not** create a new session (400).
   - The still-unexpired access JWT was nevertheless **accepted** by the database API (PostgREST,
     HTTP 200).
   - With that JWT, the **one tested** own-identity lookup — the user's own `user_auth_accounts`
     row — returned **0 rows**, because the identity mapping was gone.

   *Not tested, and not claimed:* that deleted-user access tokens are harmless; that a deleted user
   can access nothing; that every RLS path, view, RPC or Storage endpoint is safe after account
   deletion. Only the single lookup above was exercised.

   *Follow-up:* existing access JWTs may remain technically usable at the database API until they
   expire, subject to the claims and RLS behaviour of each endpoint. The captured **production**
   JWT lifetime is **3600 seconds**; **T2's lifetime was not independently observed**. Candidate
   hardening options (not evaluated here): a shorter JWT lifetime, or endpoint-by-endpoint review
   of what an `authenticated` token without an application identity can reach.

2. **Account deletion is anonymisation plus Auth removal — not full data erasure.**

   *Demonstrated at runtime (E1, and E2 for the drainer path):* the Auth login is removed; the
   `user_auth_accounts` mapping is removed; the `public.users` row is **retained but anonymised**
   (personal columns nulled, `anonymized_at` set); the profile and `public_profiles` presentation
   become **`Deleted User`** (`is_deleted = true`).

   *Established from the implementation, not observed at runtime:* authored or referenced
   application content (posts, collaborations, messages, tasks, assets, credits, activity) is
   **retained** and remains attributed to the anonymised user. The deletion path contains no
   content-deletion step. **The two disposable accounts authored no content, so this retention was
   not itself exercised in these tests.**

3. **`already_processed` is not reachable from a normal client after a successful deletion** (see
   E1). It was not exercised, and that does not affect the E1 result.

---

## 15. Gate status after Gate E

| Gate | Status |
|---|---|
| **C3** | **CLOSED — PASS** (§5) |
| **D** | **CLOSED — PASS** (§12). D6 rests on the app's own Realtime channel; the separate cross-user control was inconclusive, is not used as evidence, and is not required |
| **G** | **CLOSED — PASS** (§12), with one transient post-delete HTTP 200 recorded (cause unconfirmed; caching is a hypothesis only) |
| **E** | **CLOSED — PASS.** E1 `delete-account` **PASS**; E2 `process-pending-deletions` **PASS** (§14). Retained earlier evidence: unauthorised and invalid `delete-account` requests PASS (§8); empty-queue `process-pending-deletions` PASS (§8); `process-pending-asset-deletions` real-object path PASS (G4, §12); orphan reaper dry-run PASS (§8). **Orphan-reaper destructive mode was NOT RUN**, and it is not required to close the currently defined Phase 22.5 target gates |

**Phase 22.5 itself is NOT yet marked COMPLETE.** All four currently defined target gates pass, but
the phase closeout and the disposition of T2 remain separate owner decisions. The access-token
hardening follow-up (§14, Findings 1) is carried forward.
