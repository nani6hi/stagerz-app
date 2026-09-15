# Phase 21.8A — Capture the deletion pipeline and prepare its drainer (S-8)

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0` (`main`, merge of PR #15 — Phase 21.7 / S-6, S-7)
**Merged:** **PR #16** — source capture `3fb81ae`, manual-only workflow `23c05b2`, merge `026bace`. **PR #17** — schedule; head `fd018b8d7aa7689628e8126dcac412a306dccfde`, merge `03ece667eedf0f75022f7a39bf0600e1df2dafd5`
**Addresses:** finding **S-8** — the pending asset-deletion pipeline has no active automatic drainer
**Classification:** **reliability / data-lifecycle defect — NOT a security vulnerability**
**Severity:** **MEDIUM**
**Status:** **COMPLETE — S-8 REMEDIATED (Phase 21.8A / PRs #16 and #17).**
- **Done:**
  - deployed Edge Function source captured and merged (PR #16);
  - manual-only workflow merged (PR #16) and statically reviewed;
  - successful manual production drain, run #5 on 2026-09-13: queue 2 → 0, `collaboration_assets` 17 → 15, Storage unchanged;
  - daily schedule added as a separate approved change (PR #17), with `workflow_dispatch` kept for manual recovery;
  - workflow **active**; scheduled runs **#6** (2026-09-14) and **#7** (2026-09-15) both succeeded;
  - gates **G-1 to G-7 all PASS** (§14.3).
- **Current queue (read-only, 2026-09-15):** empty; no failed attempts; no soft-deleted asset left.
**Validation level:** **Level 1** — documentation, forensic source capture and a workflow definition, plus production run evidence; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

> **HISTORICAL — sections 1 to 13 are the preparation record, as written on 2026-09-12/13 before any run.** They are preserved unedited in substance because they are the evidence that found and planned the fix. Statements there such as "never run", "no schedule", "no GitHub secret", "PR #16 open" and "preparation only" describe **that point in time**, not the current state. The completed remediation and current state are in **§14**; the full validation chronology is in `validation.md` §10.

---

## 1. Objective

Three things, in this order:

1. **Capture the deployed Edge Function source in version control** — it previously existed *only* inside the Supabase project, so the code holding privileged deletion authority was unreviewable from this repository. This is the Phase 20.7 **C-3** problem applied to Edge Functions. *(Done — checkpoint `3fb81ae`.)*
2. **Prepare a manual-only GitHub Actions workflow** that can call the existing drainer when, and only when, someone deliberately dispatches it. *(Prepared — not committed, never run.)*
3. **Defer automatic scheduling** to a later, separately approved change.

**Phase 21.8A contains no orphan reaper.** S-3 is handled separately in Phase 21.8B, and only after this phase is validated.

**Pattern decision (`.apos/WORKFLOW.md`): Extend**, with two new artifact classes — captured third-party-hosted source (mirroring how Phase 21.3 introduced descriptive SQL snapshots) and the repository's first CI workflow.

---

## 2. S-8 — root cause

The asset-deletion architecture is sound in design and incomplete in operation:

| Stage | State |
|---|---|
| `deleteCollaborationAssetPrompt()` → `delete_collaboration_asset` RPC | Works |
| RPC soft-deletes `collaboration_assets.deleted_at`, authorises uploader-or-owner | Works |
| RPC enqueues into `pending_asset_deletions` | Works |
| RPC logs `asset_deleted` activity | Works |
| **`process-pending-asset-deletions` performs the Storage deletion** | **Never runs** |

**Nothing invokes the drainer.** Verified read-only:

- `pg_cron` — **not installed** (available, 1.6.4)
- `pg_net` — **not installed** (available, 0.20.3)
- `supabase_functions.hooks` (database webhooks) — **absent**
- Repository CI on `main` — **none**
- Frontend — **zero** `functions.invoke` calls

**Why this went unnoticed:** the sibling `delete-account` function processes deletions **inline** and only uses its queue as a retry fallback, so account deletion works without a scheduler. `delete_collaboration_asset` has no inline processing at all — it enqueues and returns. Asset deletion is the one flow that depends entirely on an external drainer that was never wired up.

**User-visible consequence:** the UI reports "Asset deleted", the row disappears from listings (the SELECT policy filters `deleted_at IS NULL`), and the file remains in Storage indefinitely.

---

## 3. Queue baseline — read-only, captured 2026-09-12

No file names, storage paths or user identifiers are recorded here.

| Property | Row 1 | Row 2 |
|---|---|---|
| `requested_at` | 2026-07-20 | 2026-07-21 |
| `attempt_count` | **0** | **0** |
| `last_attempted_at` | **NULL (never attempted)** | **NULL (never attempted)** |
| Corresponding `collaboration_assets` row | exists, **soft-deleted** | exists, **soft-deleted** |
| Corresponding Storage object | **already absent** | **already absent** |
| Structurally valid | yes — non-null path, collaboration exists, first path segment matches `collaboration_id` | yes |

Both objects being already absent means they were removed out-of-band; the queue was never processed. This is what makes the first run exceptionally low-risk (§8).

---

## 4. Deployed Edge Function baseline

| Function | Version | `verify_jwt` | Bundle hash (`ezbr_sha256`) |
|---|---|---|---|
| `process-pending-asset-deletions` | **7** | false | `d3c3f1b5462a9ef6ee5f694f96f9332a99ff53a13fc69951cb15c67aa78baf81` |
| `process-pending-deletions` | **5** | false | `66f3c27a79be0d3578632941fcccf39e8ae0e054104aba7ce456045942716e9d` |
| `delete-account` | **4** | false | `79b2fa666bad70be1ba8907a25bc76d17dc3f08695f3bc2e003c537953710e74` |

**The bundle hash is not a source hash.** `ezbr_sha256` covers the *built bundle*, so it cannot be reproduced by hashing the committed text. It is recorded only as a deployment-identity marker. Source fidelity is established separately (§5, `validation.md` §3).

**Authorisation model.** All three run with `verify_jwt: false`. The two `process-*` functions are gated by a maintenance secret accepted as either `X-STAGERZ-Maintenance-Secret: <raw>` or `Authorization: Bearer <raw>`; `delete-account` instead requires a real user JWT and is CORS-restricted to `https://stagerz.app`. All three use the service-role key internally.

**Environment variables referenced** (names only — no values exist anywhere in this repository): `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET`, `SUPABASE_ANON_KEY`, `STAGERZ_ALLOWED_ORIGIN`.

---

## 5. Source capture

Captured verbatim in checkpoint `3fb81ae`, with **no refactoring, no dependency pinning, no improvement of any kind** — this is a forensic record of what is deployed, not a cleanup.

| Path | SHA-256 | Bytes |
|---|---|---|
| `supabase/functions/_shared/delete-auth-account.ts` | `dbff395911d7da5a42cd7f36d0cbbdb2ca46500eb6b82a0461ac4ec452506299` | 2608 |
| `supabase/functions/process-pending-asset-deletions/index.ts` | `555f43b73c1b65924926dd8b5101c30d744d658e4f3ac88df475442c5875227d` | 3781 |
| `supabase/functions/process-pending-asset-deletions/maintenance-auth.ts` | `15125f4fa0a6522dfcad79dcfd98ff019bc8650b8ca06f660b9c0a874da2b873` | 1456 |
| `supabase/functions/process-pending-deletions/index.ts` | `aee581704aab0b23dd0881117c097bd095a7adee5f73ae1ce4e0d4a8e33d64f5` | 1688 |
| `supabase/functions/process-pending-deletions/delete-auth-account.ts` | `151f52a30dbe41358f18a7303205e257182a914768bab9cfbfea40a060396e0c` | 2626 |
| `supabase/functions/process-pending-deletions/maintenance-auth.ts` | `119276d3169e71ffee10ba339f133a942d4778ec63d793293dbcd728ed9623e6` | 1456 |
| `supabase/functions/delete-account/index.ts` | `8cadccdfd96085e8ca0e84f4fbdd1b011ac522901e7901b51ad2a29225c9617c` | 3335 |

**Layout rationale.** The paths are not invented — every captured file's own first line already declares them (`// supabase/functions/…`). The deployed `delete-account` bundle exposes its files under platform paths (`user_fn_…/source/index.ts` and `user_fn_…/_shared/delete-auth-account.ts`), which map to `delete-account/index.ts` and `_shared/delete-auth-account.ts` respectively — consistent with its own `../_shared/…` import.

**`supabase init` was deliberately not run.** No `config.toml`, no seed files, no CLI scaffolding.

**Two duplication facts preserved as-is**, because they are properties of the deployed system:

- `maintenance-auth.ts` exists **twice**, once per `process-*` function, and each copy's header says the duplication is deliberate (Edge Function bundling constraints) and that both copies must be kept in sync.
- `delete-auth-account.ts` exists **twice**: `_shared/` (used by `delete-account`) and a private copy inside `process-pending-deletions/`. The two differ **only** in their first-line path comment.

**Fidelity limitation — accepted for the checkpoint.** Fidelity was verified by inspection and mechanical cross-checks, **not** by a byte-level diff. A Supabase CLI download-and-diff (**gate G-7**) remains mandatory before Phase 21.8B modifies any captured function.

---

## 6. Scheduler decision

**GitHub Actions**, on evidence, over four alternatives.

| Option | Why not chosen |
|---|---|
| **Netlify Scheduled Function** | Needs `netlify.toml` and a functions directory, neither of which exists; adds backend logic to a surface that is currently a static mirror |
| **`pg_cron` + `pg_net`** | Requires installing two extensions, puts the maintenance secret **inside the database**, and — decisively — **the schedule would live only in the database**, which is exactly the C-3 invisibility this project keeps paying for |
| **Database webhooks** | Event-driven, not periodic; cannot retry failures and cannot drive a future periodic scan |
| **External scheduler** | Hands the maintenance secret to a third party; worst on custody and reviewability |

**Why GitHub Actions wins:** the workflow is a **diffable file in this repository**, reviewable under the same process as every other change. It adds no database extensions, keeps the secret out of the database, needs no new deployment surface, and gives run history and failure notifications for free. Its one weakness — GitHub cron is best-effort — is irrelevant for an idempotent deferred-cleanup queue, and does not arise at all while the workflow is manual-only.

**A SQL-only scheduler could never do this job anyway.** Deleting a row from `storage.objects` does **not** remove the underlying file from the storage backend; only the Storage API does. Any database-native scheduler would still have to make an HTTP call out to the Edge Function.

**Supabase Pro is NOT required.** The organization is on **Free**, and everything here fits. This is not the point at which Pro becomes necessary, and it should not be purchased for this.

---

## 7. The prepared workflow

**File:** `.github/workflows/process-pending-asset-deletions.yml` — **prepared, not committed, never run.**

| Property | Setting | Why |
|---|---|---|
| Trigger | **`workflow_dispatch` only** | Nothing runs unless a person with write access deliberately starts it. No `schedule`, `push` or `pull_request` |
| Inputs | **None** | Nothing a dispatcher can type changes what the function does — including any future dry-run/delete switch in 21.8B |
| Permissions | **`permissions: {}`** | No `GITHUB_TOKEN` scopes at all |
| Checkout | **None** | The job never reads repository contents |
| Concurrency | group `process-pending-asset-deletions`, `cancel-in-progress: false` | Two drains can never overlap, and a running drain is never killed mid-batch |
| Timeout | job `5 min`; `curl --max-time 60` | Bounded; a hung call cannot consume runner minutes |
| Retries | **None** | A failed run is investigated, never repeated automatically |
| Secret source | `env:` from `secrets.STAGERZ_MAINTENANCE_SECRET` | Never a literal in the YAML |
| Missing/empty secret | **Fails before any HTTP request** | A misconfigured repository cannot send an unauthenticated call |
| Secret transmission | `printf` (shell builtin) → curl stdin via `--header @-` | The `Authorization: Bearer …` header on the wire is exactly as specified, but the secret **never appears in a process argument list or the log** |
| Transport | `--proto '=https'`, redirects not followed | Cannot be downgraded or bounced elsewhere |
| Success rule | **HTTP 200 only** | Any other status fails the job and logs **only the HTTP status** |
| Failure output | HTTP status only — **response body never printed** | Workflow logs may be public; arbitrary server responses do not belong in them, even though the deployed function's errors are currently generic |
| Output | `processed` count and a tally by status | **Never per-asset identifiers** — workflow logs may be publicly visible |
| Unexpected 200 body | Fails the job without printing the body | Strict: a malformed success is not treated as success |
| `retry_recorded` result | Emits a `::warning::` | Surfaces a partial failure without silently re-running |

**The first actual invocation of the drainer will be the first explicitly approved `workflow_dispatch` run of this workflow. No separate local or manual `curl` invocation is planned before it.** Earlier planning placed a separate manual call before any workflow existed; that step has been removed. Using the dispatch-only workflow for the first call is strictly better: the exact request is reviewed in advance as a file, the run is logged, and the secret never has to be handled on a workstation. The approval gate is unchanged — **the first dispatch still requires explicit approval.**

**State at preparation (HISTORICAL — superseded by §14):** the workflow has **never run**, the secret it needs is **not configured**, **no schedule exists**, and **no Supabase mutation has occurred**.

---

## 8. Intended first-run procedure — not performed at the time of writing (HISTORICAL; carried out later, see §14)

1. ~~Commit and push the source capture.~~ **Done** — `3fb81ae`, PR #16 open.
2. Commit the workflow on this branch; review it in PR #16.
3. **Manual:** configure the GitHub repository secret `STAGERZ_MAINTENANCE_SECRET`, reusing the value already set in the Edge Function environment. **No new secret value is created.**
4. Snapshot both queue rows into the phase record — the metadata hard-delete in step 5 is irreversible.
5. **Explicit approval**, then **one** `workflow_dispatch` run.
6. Validate against the predicted end state below.
7. Only after a validated run: propose adding a `schedule:` trigger, as its own separately approved change.

**Predicted end state of the first run:**

| | Before | After |
|---|---|---|
| Job result | — | success, `HTTP status: 200` |
| Logged summary | — | `Processed: 2`; `already_deleted: 2` |
| `pending_asset_deletions` | **2** rows | **0** rows |
| `collaboration_assets` | **17** (15 live + 2 soft-deleted) | **15** — the two soft-deleted rows hard-deleted |
| `storage.objects` | **28** | **28 — unchanged** |
| Orphan objects | **15** | **15 — unchanged** |
| Live assets | **15** | **15 — untouched** |

**`already_deleted` is the expected status for both rows.** A result of `deleted` would mean a Storage object existed that this analysis concluded was absent, and must stop the phase for re-investigation. Any `retry_recorded` result likewise stops the phase.

---

## 9. Rollback concept

**For this phase: `git revert`** of the relevant commits. The phase adds documentation, a `.gitignore`, captured source and a workflow definition. It changes no production system.

**For the workflow specifically:** deleting the file removes the ability to dispatch it; removing the GitHub secret revokes it independently even if the file remains. Neither touches Supabase.

**For the first run** (later, not in this phase): the queue-row and metadata-row hard-deletes are irreversible, which is why step 4 snapshots both rows first. The Storage side is a no-op, since both objects are already absent.

**The Edge Function is not modified in 21.8A**; its deployed version remains **7** throughout.

---

## 10. Explicit mutation boundary — preparation step (HISTORICAL)

**Nothing in the preparation step mutated anything outside the repository.** The later, separately approved production steps are recorded in §14.

| Action | Status |
|---|---|
| Edge Function invoked | **No** |
| Edge Function deployed or modified | **No** — still version 7 / 5 / 4 |
| Queue row, metadata row or Storage object deleted | **No** |
| Database policy, schema, function or grant changed | **No** |
| GitHub Actions workflow file | **Prepared in the working tree — not committed, never run** |
| Automatic schedule | **None** |
| GitHub secret created or changed | **No** |
| PR #16 merged | **No** |

Every Supabase interaction in this phase was a `SELECT`, a catalog read, or an Edge Function **metadata/source read**.

---

## 11. Validation gates

Full detail in `validation.md`. For this phase: the seven captured files match the deployed source; no secret value appears in any file; no application source changed; no SQL migration exists; the workflow is dispatch-only with no schedule, no push/PR trigger, no checkout, no permissions and no secret literal; Supabase unmutated.

For the next steps, recorded so the ordering is not lost: the secret must exist before any dispatch; the first dispatch requires explicit approval and must produce exactly the §8 end state; no `schedule:` trigger may be added until that run is validated; and G-7 must pass before 21.8B modifies any function.

---

## 12. Scope boundary

**In scope:** source capture, `.gitignore`, documentation, scheduler decision, and a **manual-only** workflow definition.

**Explicitly out of scope:** any `schedule:` trigger; configuring the secret; running the workflow; the orphan reaper (S-3 → Phase 21.8B); any change to the Edge Functions, including pinning the floating `@supabase/supabase-js@2` import; any database change; S-4.

**One observation deliberately left unactioned:** all three functions import `https://esm.sh/@supabase/supabase-js@2` — a **floating major version**, so any redeploy may resolve a different minor or patch. The frontend was pinned to exactly `2.112.1` with SRI in Phase 21.2; the Edge Functions have no equivalent. Pin it when the function is next modified in 21.8B — not as a drive-by change to a forensic capture.

---

## 13. Summary — at preparation (HISTORICAL)

The asset-deletion pipeline is well designed and never finished: a soft delete, a queue, an activity record and a privileged service-role drainer all exist, but nothing has ever called the drainer. Two deletion requests have sat unprocessed since 2026-07-20.

This phase first put the deployed source under version control — all seven files, with no improvements folded in — and now prepares the smallest possible caller: a workflow that runs **only** when a person deliberately dispatches it, holds no permissions, checks out nothing, retries nothing, and refuses to make a request without its secret.

**Nothing has been deployed, scheduled, invoked or mutated. The workflow has never run, and the secret it needs does not exist yet.** S-3 remains open and belongs to Phase 21.8B.

*(Point-in-time summary. S-3 was later remediated by Phase 21.8B; the completed S-8 state is §14.)*

---

## 14. Completion — S-8 REMEDIATED

**Closed:** 2026-09-15, after a read-only revalidation of the current mechanism, repository, GitHub run history and queue state.

### 14.1 What was delivered

| Change | Commits | Effect |
|---|---|---|
| **PR #16** | source capture `3fb81ae`, manual-only workflow `23c05b2`, merge `026bace` | Deployed Edge Function source under version control; a `workflow_dispatch`-only caller of `process-pending-asset-deletions` |
| **PR #17** | `ef92844`, `fd018b8` (head `fd018b8d7aa7689628e8126dcac412a306dccfde`), merge `03ece667eedf0f75022f7a39bf0600e1df2dafd5` | Adds `schedule: cron '17 3 * * *'` (daily, 03:17 UTC) and keeps `workflow_dispatch`. **Only the workflow file changed** |

**Unchanged since:** no later commit touches `.github/workflows/` or the captured drainer source. The PR #17 implementation is present unchanged on `main`. Phase 21.8B added a separate reaper that leaves queued paths to this drainer.

### 14.2 Current mechanism

`.github/workflows/process-pending-asset-deletions.yml`, calling `supabase/functions/process-pending-asset-deletions/`:

| Stage | Behaviour |
|---|---|
| Trigger | Daily schedule, plus `workflow_dispatch` for manual recovery. No push or pull-request trigger |
| Workflow permissions | `permissions: {}`; no checkout; no inputs |
| Secret handling | Missing or empty `STAGERZ_MAINTENANCE_SECRET` fails the job before any request; the secret is sent through stdin, never logged or passed as an argument |
| Function authorization | POST only. The maintenance secret (`maintenance-auth.ts`) must match, otherwise HTTP 401. The service-role client is created only after that check |
| Work per call | At most `BATCH_SIZE = 25` queue rows, oldest `requested_at` first. For each: Storage `remove`, then delete the soft-deleted metadata row, then delete the queue row |
| Bounds | Job `timeout-minutes: 5`; `curl --max-time 60`; HTTPS only, no redirects |
| Failure handling | A Storage error increments `attempt_count`, keeps the queue row and reports `retry_recorded`, which the workflow surfaces as a warning. Non-200 or a malformed body fails the job |
| Retry | No retries within a run; remaining rows are retried by the next scheduled run. Removing an already-absent object reports `already_deleted`, so repeated processing is safe |
| Concurrency | Workflow concurrency group, `cancel-in-progress: false`: runs never overlap |
| Observability | HTTP status, processed count and a tally by status only — no asset, file or user identifiers |
| Queue protection | `pending_asset_deletions` has RLS enabled, no policies, and no `anon` / `authenticated` grants |

### 14.3 Gates — final

| Gate | Result | Evidence |
|---|---|---|
| **G-1** Source capture committed, pushed, reviewed | **PASS** | `3fb81ae`, merged in PR #16 (`026bace`) |
| **G-2** GitHub maintenance secret configured and aligned | **PASS** | Authenticated HTTP 200 on runs #5, #6 and #7; #6 and #7 came after the secret rotation recorded in Phase 21.8B §12.8 |
| **G-3** First production dispatch explicitly approved | **PASS** | Operator approval before the dispatches |
| **G-4** First successful run reaches the intended end state | **PASS** — with one explained difference | Run #5: queue 2 → 0, assets 17 → 15, Storage unchanged, no retry state. The predicted "version still 7" did not hold: it went 7 → 8, a platform reload with bundle hash and `updated_at` unchanged (`validation.md` §10.2) |
| **G-5** Manual workflow committed and statically reviewed | **PASS** | `23c05b2`; W-1 to W-22 (`validation.md` §5) |
| **G-6** Schedule added afterwards as a separate approved change | **PASS** | PR #17, merged after run #5 |
| **G-7** Deployed source identity by download-and-diff | **PASS** | Phase 21.8B validation §2: 7/7 captured files byte-identical to `main` (2026-09-13), re-run after the reaper deployment |

### 14.4 Why S-8 is remediated

The defect was **no active automatic drainer**. Now:
- the drainer is scheduled daily and the workflow is **active**;
- two consecutive scheduled runs (#6, #7) succeeded;
- manual recovery through `workflow_dispatch` remains available;
- the queue is empty, with no failed attempts and no soft-deleted asset left behind.

**S-8 REMEDIATED — Phase 21.8A / PRs #16 and #17.**

### 14.5 Evidence limits

- The only production run that processed rows (#5) handled two queue entries whose Storage objects were **already absent**. The branch where an object is present and removed has **not** been exercised in production by this drainer.
- Literal job log lines for runs #5, #6 and #7 were not retrieved: the log endpoint requires authentication. Run conclusions, step results and annotations came from the GitHub API.
- The current Edge Function version and bundle metadata were not re-read during the final revalidation; that read was denied. Source identity rests on G-7 and on no repository change since.

### 14.6 Non-blocking follow-ups

Reliability and operational items. **None keeps S-8 open**, and none is raised as a new finding here:

1. **Throughput cap:** one batch per day, at most 25 deletions per day.
2. **Stuck rows:** rows that fail permanently stay oldest-first, so enough of them could eventually fill a whole batch; there is no attempt cap.
3. **Partial failure:** if the metadata-row delete fails after a successful Storage removal, the error is only logged, the queue row is still removed and the run still reports success.
4. **Unknown outcome:** a function call longer than `curl --max-time 60` fails the job without knowing what the function did.
5. **Unpinned dependency:** the drainer imports `@supabase/supabase-js@2` (floating major).
6. **Schedule auto-disable:** GitHub may disable scheduled workflows in a public repository after a long period without repository activity.
7. **Possible hardening:** an attempt cap and retry ordering; a constant-time secret comparison; explicit rejection of an empty configured maintenance secret; dependency pinning.
