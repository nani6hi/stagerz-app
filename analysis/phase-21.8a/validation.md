# Phase 21.8A — Validation Record

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0`
**Source-capture checkpoint:** `3fb81ae` — pushed; PR #16 open, not merged
**Validation level:** **1** — documentation, forensic source capture and an unexecuted workflow definition; `index.html` is not touched
**Status:** **Preparation validated statically.** The manual-only workflow is prepared but **not committed and never run**. No schedule, no secret, no Edge Function invocation or deployment, no Supabase mutation.

---

## 1. What this record claims, and what it does not

**Claims:** seven Edge Function source files were captured from the currently deployed versions (checkpoint `3fb81ae`); a `.gitignore` was added; a `workflow_dispatch`-only workflow has been prepared and **statically reviewed** (§5); and nothing outside the repository has been changed.

**Does not claim** that the captured files were verified by an independent automated byte-diff. §3.2 states the method used and its limitation.

**Does not claim anything from a workflow run.** The workflow has never executed. The secret it requires does not exist. Every workflow check in this record is a **static review of the file**, not an observation of behaviour. In particular, the predicted first-run end state (§6) is a prediction.

> **Finding-status note.** Finding status lives in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-12: **S-1, S-2, S-5, S-6, S-7 REMEDIATED**; **S-3 OPEN (reclassified this date from security to storage-lifecycle/cleanup)**; **S-4 OPEN**; **S-8 OPEN**.

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

## 7. Gates

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

## 8. Unresolved concerns

1. **Source fidelity is inspection-verified, not machine-verified** (§3.2). G-7 closes it.
2. **The workflow is statically reviewed only** (§5). Runtime behaviour is unobserved until the first approved dispatch.
3. **If the repository is public, workflow logs are public.** The workflow therefore prints only aggregate results, never asset identifiers. Repository visibility has not been verified.
4. **The floating `@supabase/supabase-js@2` import** in all three functions means a redeploy may silently change the SDK version. Deliberately not fixed here; belongs to 21.8B.
5. **`maintenance-auth.ts` is duplicated** across two functions and must be kept in sync by hand. Captured as-is.
6. **S-3 remains OPEN** as a storage-lifecycle/cleanup finding. **S-4 remains OPEN.**
7. **No automatic schedule exists**, by design. Until G-6, deletions are drained only when someone dispatches the workflow.

---

## 9. Summary

Seven Edge Function source files are captured and hash-verified in checkpoint `3fb81ae`, and a manual-only workflow is now prepared: dispatch-only, no inputs, no permissions, no checkout, no retries, secret delivered through stdin, and a hard failure before any network call if the secret is missing.

**Eight repository-safety checks and twenty-two workflow static-review checks pass.** No schedule, no secret, no workflow run, no deployment, no invocation, no database change. `index.html` and all prior phase artifacts are untouched.

**Level 1 is satisfied for the preparation step.** Everything that touches production is gated behind G-2 and G-3, and neither the secret nor the approval exists.
