# Phase 21.8A — Validation Record

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0`
**Merged:** **PR #16** (`3fb81ae`, `23c05b2`; merge `026bace`) and **PR #17** (head `fd018b8d7aa7689628e8126dcac412a306dccfde`; merge `03ece667eedf0f75022f7a39bf0600e1df2dafd5`)
**Validation level:** **1** — documentation, forensic source capture and a workflow definition, plus production run evidence; `index.html` is not touched
**Status:** **COMPLETE — S-8 REMEDIATED (Phase 21.8A / PRs #16 and #17).** Manual production drain validated (run #5); schedule active; scheduled runs #6 and #7 succeeded; G-1 to G-7 all PASS. Chronology and final gates: **§10**.

> **HISTORICAL — sections 1 to 9 are the preparation-time validation record, written before any run.** They are preserved unedited in substance. Statements there such as "never run", "no schedule", "secret does not exist", "PENDING" and "PR #16 open" describe **that point in time**. The completed validation is **§10**.

---

## 1. What this record claims, and what it does not

**Claims:** seven Edge Function source files were captured from the currently deployed versions (checkpoint `3fb81ae`); a `.gitignore` was added; a `workflow_dispatch`-only workflow has been prepared and **statically reviewed** (§5); and nothing outside the repository has been changed.

**Does not claim** that the captured files were verified by an independent automated byte-diff. §3.2 states the method used and its limitation.

**Does not claim anything from a workflow run.** The workflow has never executed. The secret it requires does not exist. Every workflow check in this record is a **static review of the file**, not an observation of behaviour. In particular, the predicted first-run end state (§6) is a prediction.

> **Finding-status note.** Finding status lives in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-12: **S-1, S-2, S-5, S-6, S-7 REMEDIATED**; **S-3 OPEN (reclassified this date from security to storage-lifecycle/cleanup)**; **S-4 OPEN**; **S-8 OPEN**. *(Point-in-time note. Current status, 2026-09-15: S-1 to S-8 all REMEDIATED — see `backend-contract.md` §0.2 and §10 below.)*

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — no application source in the diff |
| **P-2** | No prior phase artifacts modified | **PASS** — `analysis/phase-20.*`, `21.1`–`21.7` untouched |
| **P-3** | No SQL migration file created | **PASS** |
| **P-4** | **Workflow is manual-only** — no `schedule`, `push` or `pull_request` trigger | **PASS** — see §5 |
| **P-5** | **No secret value in any file**, including the workflow | **PASS** — see §4 |
| **P-6** | Captured source unmodified from deployed form | **PASS** — see §3 |
| **P-7** | `.gitignore` excludes secret and generated material | **PASS** — `.env`, `.env.*`, `supabase/.temp/`, `supabase/.branches/`, `node_modules/` |
| **P-8** | No Supabase mutation performed or attempted | **PASS** — all interactions were `SELECT`/catalog/function-source reads |

---

## 3. Source fidelity

### 3.1 Captured files and hashes

| # | Path | SHA-256 | Bytes | Lines | Result |
|---|---|---|---|---|---|
| 1 | `supabase/functions/_shared/delete-auth-account.ts` | `dbff395911d7da5a42cd7f36d0cbbdb2ca46500eb6b82a0461ac4ec452506299` | 2608 | 83 | **PASS** |
| 2 | `supabase/functions/process-pending-asset-deletions/index.ts` | `555f43b73c1b65924926dd8b5101c30d744d658e4f3ac88df475442c5875227d` | 3781 | 111 | **PASS** |
| 3 | `supabase/functions/process-pending-asset-deletions/maintenance-auth.ts` | `15125f4fa0a6522dfcad79dcfd98ff019bc8650b8ca06f660b9c0a874da2b873` | 1456 | 37 | **PASS** |
| 4 | `supabase/functions/process-pending-deletions/index.ts` | `aee581704aab0b23dd0881117c097bd095a7adee5f73ae1ce4e0d4a8e33d64f5` | 1688 | 50 | **PASS** |
| 5 | `supabase/functions/process-pending-deletions/delete-auth-account.ts` | `151f52a30dbe41358f18a7303205e257182a914768bab9cfbfea40a060396e0c` | 2626 | 83 | **PASS** |
| 6 | `supabase/functions/process-pending-deletions/maintenance-auth.ts` | `119276d3169e71ffee10ba339f133a942d4778ec63d793293dbcd728ed9623e6` | 1456 | 37 | **PASS** |
| 7 | `supabase/functions/delete-account/index.ts` | `8cadccdfd96085e8ca0e84f4fbdd1b011ac522901e7901b51ad2a29225c9617c` | 3335 | 95 | **PASS** |

These hashes were re-verified in the working tree, the staged snapshot, and commit `3fb81ae`.

### 3.2 Method used, and its limitation — read this

The deployed source was re-fetched from Supabase after the files were written, and each captured file was compared against the returned payload. **That comparison was performed by inspection, not by an automated byte-level diff**, because the deployed source arrives as a JSON payload through the MCP tool and cannot be piped to disk for `cmp`/`diff` without passing through the same transcription step being verified.

What *was* checked mechanically, and passed:

| Check | Result |
|---|---|
| Every file's first line declares its own canonical path | **7/7** |
| Environment-variable reference counts | `process-pending-asset-deletions/index.ts` **3**, `process-pending-deletions/index.ts` **3**, `delete-account/index.ts` **4** |
| `BATCH_SIZE = 25` and bucket literal present in the asset drainer | **1 each** |
| `delete-account` imports `../_shared/delete-auth-account.ts` | **present** |
| `_shared` vs `process-pending-deletions` copies of `delete-auth-account.ts` | **identical after line 1** |
| Byte delta between those two copies | **2626 − 2608 = 18**, exactly the path-length difference between `_shared` (7) and `process-pending-deletions` (25) in the header comment |
| The two `maintenance-auth.ts` copies | **identical after the header comment**, both **1456 bytes** — their two header differences cancel exactly |

**Accepted for the checkpoint; G-7 closes it.** `supabase functions download <slug>` writes the deployed source to disk for a true `diff`. That comparison is **mandatory before Phase 21.8B modifies any captured function.**

### 3.3 Deployed versions and bundle hashes — recorded separately

| Function | Version | `ezbr_sha256` (bundle, **not** source) |
|---|---|---|
| `process-pending-asset-deletions` | 7 | `d3c3f1b5462a9ef6ee5f694f96f9332a99ff53a13fc69951cb15c67aa78baf81` |
| `process-pending-deletions` | 5 | `66f3c27a79be0d3578632941fcccf39e8ae0e054104aba7ce456045942716e9d` |
| `delete-account` | 4 | `79b2fa666bad70be1ba8907a25bc76d17dc3f08695f3bc2e003c537953710e74` |

---

## 4. Secret scan

Scanned every created and modified file — **including the workflow** — for **values**, not names.

| Pattern | Result |
|---|---|
| JWT-shaped strings (`eyJ…`) | **none** |
| Service-role key value | **none** |
| `STAGERZ_MAINTENANCE_SECRET` **value** | **none** |
| Anon/publishable key value | **none** |
| `Bearer <literal token>` | **none** — the workflow uses a `printf` format string, not a token |
| `postgres://` / `postgresql://` connection strings | **none** |
| `.env` file | **none exists** |

**Names appear, and that is intended:** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET`, `SUPABASE_ANON_KEY`, `STAGERZ_ALLOWED_ORIGIN` in the captured source as `Deno.env.get(...)` lookups, and `STAGERZ_MAINTENANCE_SECRET` in the workflow as a `${{ secrets.… }}` reference. References only, never values.

**Self-matching artefact:** this record's own scan table contains the strings `eyJ` and `postgres://`, so a naive grep over `analysis/` will match it. The same artefact was recorded in Phase 21.3 §3.1. Scans must exclude this table or expect those hits.

The project ref `kbnmkyvbwkuvcklywdhk` appears in the workflow URL and in documentation. It is not a secret: it is already committed in `index.html` and public in every deployed page.

---

## 5. Workflow static review

**File:** `.github/workflows/process-pending-asset-deletions.yml`. **Reviewed as written. Never executed.**

| # | Check | Required | Result |
|---|---|---|---|
| **W-1** | Trigger | `workflow_dispatch` only | **PASS** |
| **W-2** | `schedule:` present | absent | **PASS — absent** |
| **W-3** | `push:` / `pull_request:` / `pull_request_target:` present | absent | **PASS — absent** |
| **W-4** | Workflow inputs | none | **PASS — none** |
| **W-5** | Permissions | `permissions: {}` | **PASS** |
| **W-6** | Checkout action | absent | **PASS — absent**; no `uses:` of any kind |
| **W-7** | Concurrency | group `process-pending-asset-deletions`, `cancel-in-progress: false` | **PASS** |
| **W-8** | Runner / timeout | `ubuntu-latest`, `timeout-minutes: 5` | **PASS** |
| **W-9** | Secret source | `env:` from `secrets.STAGERZ_MAINTENANCE_SECRET` | **PASS** |
| **W-10** | Secret literal in YAML | absent | **PASS — absent** |
| **W-11** | Missing/empty secret | fail **before** any HTTP request | **PASS** — `[ -z … ]` check precedes curl and exits 1 |
| **W-12** | Shell tracing | no `set -x` / `xtrace` | **PASS — absent**; `set -euo pipefail` only |
| **W-13** | Secret echoed or printed | never | **PASS** — no `echo`/`cat`/`printenv`/`env` of it; `printf` output goes to curl stdin, not the log |
| **W-14** | Secret in a process argument list | never | **PASS** — delivered via `--header @-` from stdin |
| **W-15** | Endpoint | exact URL, `POST` | **PASS** |
| **W-16** | Headers | `Authorization: Bearer …`, `Content-Type: application/json` | **PASS** |
| **W-17** | `curl --max-time 60` | present | **PASS** |
| **W-18** | Automatic retry | absent | **PASS** — no `--retry`, no loop, no re-dispatch |
| **W-19** | Non-200 handling | job fails; logs HTTP status only | **PASS** |
| **W-19a** | Response body printed on failure | never | **PASS** — no `cat`/`echo` of the response file on any failure path; the body is read only by `jq` on the success path |
| **W-20** | Response body captured | yes | **PASS** — `--output` to a `mktemp` file removed on exit |
| **W-21** | Output content | non-secret, aggregate only | **PASS** — `processed` count and status tally; no per-asset identifiers |
| **W-22** | `GITHUB_TOKEN` usage | none | **PASS** |

**Two strictness additions beyond the brief, noted so they are not surprises:** a `200` whose body is not the expected JSON shape **fails** the job without printing the body; and any `retry_recorded` result emits a `::warning::`. Also, `--proto '=https'` is set and redirects are not followed.

**What static review cannot establish:** that `jq` behaves as expected on the runner, that the secret check passes once the secret exists, or that the function returns the predicted body. Those are observations for the first approved run.

---

## 6. Queue baseline and predicted first run

### 6.1 Baseline — read-only

| Property | Row 1 | Row 2 |
|---|---|---|
| `requested_at` | 2026-07-20 | 2026-07-21 |
| `attempt_count` | 0 | 0 |
| `last_attempted_at` | NULL | NULL |
| Metadata row present and soft-deleted | yes | yes |
| Storage object present | **no** | **no** |
| Structurally valid | yes | yes |

Recorded without file names, storage paths or user identifiers.

### 6.2 Predicted end state — NOT observed

| | Before | Predicted after first run |
|---|---|---|
| `pending_asset_deletions` | 2 | **0** |
| `collaboration_assets` | 17 | **15** |
| `storage.objects` (`collaboration-assets`) | 28 | **28** |
| Orphan objects | 15 | **15** |
| Live assets | 15 | **15** |
| Workflow log | — | `HTTP status: 200`, `Processed: 2`, `already_deleted: 2` |

**These are predictions.** A result of `deleted` for either row, or any `retry_recorded`, stops the phase.

---

## 7. Gates — at preparation (HISTORICAL; final results in §10.4)

| # | Gate | Status |
|---|---|---|
| **G-1** | Source-capture checkpoint committed, pushed and reviewed | **Committed and pushed** (`3fb81ae`); **PR #16 open — review PENDING** |
| **G-2** | `STAGERZ_MAINTENANCE_SECRET` configured as a GitHub repository secret — **manual user action** | **PENDING — does not exist** |
| **G-3** | Explicit approval for the first `workflow_dispatch` run | **PENDING — NOT GIVEN** |
| **G-4** | First run produces exactly the §6.2 end state | **PENDING** |
| **G-5** | Manual-only workflow prepared and statically reviewed | **PREPARED — not yet committed** |
| **G-6** | Only after G-4: propose a `schedule:` trigger as a separate approved change | **PENDING** |
| **G-7** | Supabase CLI download-and-diff before 21.8B modifies any function | **PENDING — mandatory** |

**Ordering change from earlier planning.** Earlier planning placed a separate manual invocation before any workflow existed. **That step has been removed: the first actual invocation of the drainer will be the first explicitly approved `workflow_dispatch` run of this workflow, and no separate local or manual `curl` invocation is planned before it.** The request is reviewed in advance as a file, the run is logged, and the secret is never handled on a workstation. **The approval requirement is unchanged** — G-3 still gates it.

**Current state at this record:** workflow **never run**; secret **not configured**; **no schedule**; **no Supabase mutation**.

---

## 8. Unresolved concerns — at preparation (HISTORICAL; current follow-ups in §10.7)

1. **Source fidelity is inspection-verified, not machine-verified** (§3.2). G-7 closes it.
2. **The workflow is statically reviewed only** (§5). Runtime behaviour is unobserved until the first approved dispatch.
3. **If the repository is public, workflow logs are public.** The workflow therefore prints only aggregate results, never asset identifiers. Repository visibility has not been verified.
4. **The floating `@supabase/supabase-js@2` import** in all three functions means a redeploy may silently change the SDK version. Deliberately not fixed here; belongs to 21.8B.
5. **`maintenance-auth.ts` is duplicated** across two functions and must be kept in sync by hand. Captured as-is.
6. **S-3 remains OPEN** as a storage-lifecycle/cleanup finding. **S-4 remains OPEN.**
7. **No automatic schedule exists**, by design. Until G-6, deletions are drained only when someone dispatches the workflow.

---

## 9. Summary — at preparation (HISTORICAL)

Seven Edge Function source files are captured and hash-verified in checkpoint `3fb81ae`, and a manual-only workflow is now prepared: dispatch-only, no inputs, no permissions, no checkout, no retries, secret delivered through stdin, and a hard failure before any network call if the secret is missing.

**Eight repository-safety checks and twenty-two workflow static-review checks pass.** No schedule, no secret, no workflow run, no deployment, no invocation, no database change. `index.html` and all prior phase artifacts are untouched.

**Level 1 is satisfied for the preparation step.** Everything that touches production is gated behind G-2 and G-3, and neither the secret nor the approval exists.

---

## 10. Completed validation and S-8 closure

**Closed:** 2026-09-15. No identifiers, file names, storage paths, user IDs or secret values are recorded here.

### 10.1 HISTORICAL — failed manual runs #1 to #4

All four were `workflow_dispatch` runs on `main` at `026bace`, on 2026-09-13 (UTC): 10:59, 11:31, 11:36 and 11:47.

- **Result:** job failure; the workflow's own annotation reads "process-pending-asset-deletions returned HTTP 401".
- **Cause:** the maintenance secret had not yet been applied and aligned on the function side.
- **Effect:** none. A 401 is returned before the service-role client is created, so nothing was read or changed.

### 10.2 SUCCESSFUL MANUAL VALIDATION — run #5

`workflow_dispatch`, 2026-09-13 12:39 UTC, on `main` at `026bace`. **Result: success**, all steps succeeded, **0 annotations**, so no `retry_recorded` warning was emitted.

| | Before | After run #5 |
|---|---|---|
| `pending_asset_deletions` | 2 | **0** |
| `collaboration_assets` total | 17 | **15** |
| — live | 15 | **15**, unchanged |
| — soft-deleted | 2 | **0** |
| `storage.objects` (`collaboration-assets`) | 28 | **28**, unchanged — both queued objects were already absent |
| Retry state | — | none: no rows left, no attempt counts |

- **HTTP 200:** the Supabase gateway log showed the POST answered by the function.
- **Status `already_deleted` for both rows:** deduced from the code and the data (queue drained, no Storage object changed), not read from the job log.

**Version reload observation.** Between run #4 and run #5 the drainer's deployed version changed **7 → 8**, while its bundle hash and `updated_at` stayed the same. `process-pending-deletions` (5 → 6) and `delete-account` (4 → 5) changed at the same moment in the same way. Run #4 hit v7 and got 401; run #5 hit v8 and got 200. This is a platform reload that applied the saved secret, not a source change. Phase 21.8B later observed the same pattern on every project-secret change (`analysis/phase-21.8b/phase-definition.md` §12.7). It is the only difference from the predicted end state (§6.2).

### 10.3 AUTOMATIC VALIDATION — scheduled runs

PR #17 (merge `03ece66`, 2026-09-13 17:32 UTC) added the daily schedule.

| Run | Event | Started (UTC) | `main` at | Result |
|---|---|---|---|---|
| **#6** | `schedule` | 2026-09-14 08:50 | `b1582a9` | **success** — all steps succeeded, 0 annotations |
| **#7** | `schedule` | 2026-09-15 08:37 | `2df2734` | **success** — all steps succeeded, 0 annotations |

- **Workflow state:** **active** (GitHub API, 2026-09-15).
- **Meaning of success:** the workflow passes only on HTTP 200 with the expected response shape, so both scheduled runs authenticated and completed. 0 annotations means no `retry_recorded` warning.
- **Secret alignment:** the maintenance secret was rotated in Supabase and GitHub during Phase 21.8B (`analysis/phase-21.8b/phase-definition.md` §12.8), before these runs. Their success shows the GitHub secret and the function's secret currently agree.
- **Timing:** both runs started about 5½ hours after the 03:17 UTC cron time. GitHub schedules are best-effort (§6 of `phase-definition.md`); that is acceptable for a deferred-cleanup queue.

### 10.4 Gates — final

| Gate | Result | Evidence |
|---|---|---|
| **G-1** | **PASS** | Source capture `3fb81ae` committed, pushed, reviewed and merged (PR #16, `026bace`) |
| **G-2** | **PASS** | GitHub maintenance secret configured and aligned — proven by authenticated runs #5, #6 and #7 |
| **G-3** | **PASS** | First production dispatch explicitly approved |
| **G-4** | **PASS** | Run #5 reached the intended queue-drain end state (§10.2), with the explained version reload difference |
| **G-5** | **PASS** | Manual workflow committed (`23c05b2`) and statically reviewed (§5) |
| **G-6** | **PASS** | Schedule added afterwards, as the separately approved PR #17 |
| **G-7** | **PASS** | Supabase CLI download-and-diff during Phase 21.8B: 7/7 captured files byte-identical to `main`, 2026-09-13 (`analysis/phase-21.8b/validation.md` §2), re-run after the reaper deployment |

### 10.5 CURRENT READ-ONLY SNAPSHOT — 2026-09-15

Aggregate `SELECT` only, no identifiers:

| Measure | Value |
|---|---|
| `pending_asset_deletions` rows | **0** |
| Maximum `attempt_count` | **0** |
| `collaboration_assets` total | **15** |
| Soft-deleted `collaboration_assets` | **0** |
| Soft-deleted assets with no queue entry | **0** |
| Objects in `collaboration-assets` | **13** (28 → 13 was Phase 21.8B's orphan reclaim, not this drainer) |
| `delete_collaboration_asset` still enqueues to `pending_asset_deletions` | **yes** |
| `pg_cron` / `pg_net` installed | **no** — not used |
| `pending_asset_deletions` protection | RLS enabled, 0 policies, no `anon` / `authenticated` grants |

**Repository:** no commit after `03ece66` touches `.github/workflows/` or the drainer source; the PR #17 implementation is unchanged on `main`.

### 10.6 Evidence limits

- **Log lines not retrieved.** Literal job log lines for runs #6 and #7, and for #5, were not retrieved: the log endpoint requires authenticated access. The GitHub API established each run's conclusion, step results and annotations.
- **Function metadata not re-read.** The current Edge Function version and bundle metadata were not re-read in the final revalidation, because that read was denied. This does not invalidate the G-7 source-identity evidence or the scheduled-execution evidence.
- **Present-object branch never exercised.** The only production run that processed rows handled objects that were **already absent**. The drainer's branch where an object is present and removed has **not** been exercised in production.

### 10.7 Non-blocking follow-ups

None keeps S-8 open; none is raised as a new finding here:

1. **Throughput cap:** 25 deletions per day.
2. **Stuck rows:** permanently failing oldest rows could eventually fill a whole batch; there is no attempt cap.
3. **Partial failure:** a failed metadata-row delete after a successful Storage removal is only logged, and the run still reports success.
4. **Unknown outcome:** a `curl --max-time 60` timeout leaves the outcome of that call unknown.
5. **Unpinned dependency:** `@supabase/supabase-js@2` is not pinned in the drainer.
6. **Schedule auto-disable:** GitHub may eventually disable scheduled workflows in an inactive public repository.
7. **Possible hardening:** attempt cap and retry ordering; stronger (constant-time) secret comparison; explicit rejection of an empty configured maintenance secret; dependency pinning.

### 10.8 Closure

The original defect — no active automatic drainer — no longer exists:
- the drainer is scheduled and the workflow is active;
- two consecutive scheduled runs succeeded;
- manual recovery remains available;
- the queue is healthy and empty.

The classification is unchanged: **reliability / data-lifecycle, MEDIUM, not a security vulnerability**.

**S-8 REMEDIATED — Phase 21.8A / PRs #16 and #17.**
