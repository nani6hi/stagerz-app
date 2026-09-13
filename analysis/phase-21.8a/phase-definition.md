# Phase 21.8A — Capture the deletion pipeline and prepare its drainer (S-8)

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0` (`main`, merge of PR #15 — Phase 21.7 / S-6, S-7)
**Source-capture checkpoint:** `3fb81ae` — pushed; **PR #16** open, not merged
**Addresses:** finding **S-8** — the pending asset-deletion pipeline has no active automatic drainer
**Classification:** **reliability / data-lifecycle defect — NOT a security vulnerability**
**Severity:** **MEDIUM**
**Status:** **PREPARATION ONLY.** A manual-only (`workflow_dispatch`) workflow has been prepared in the working tree but **not committed and never run**. **No schedule, no GitHub secret, no Edge Function invocation or deployment, no Supabase mutation.**
**Validation level:** **Level 1** — documentation, forensic source capture and an unexecuted workflow definition; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

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

**Current state:** the workflow has **never run**, the secret it needs is **not configured**, **no schedule exists**, and **no Supabase mutation has occurred**.

---

## 8. Intended first-run procedure — NOT performed

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

## 10. Explicit mutation boundary

**Nothing in this phase mutates anything outside the repository.**

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

## 13. Summary

The asset-deletion pipeline is well designed and never finished: a soft delete, a queue, an activity record and a privileged service-role drainer all exist, but nothing has ever called the drainer. Two deletion requests have sat unprocessed since 2026-07-20.

This phase first put the deployed source under version control — all seven files, with no improvements folded in — and now prepares the smallest possible caller: a workflow that runs **only** when a person deliberately dispatches it, holds no permissions, checks out nothing, retries nothing, and refuses to make a request without its secret.

**Nothing has been deployed, scheduled, invoked or mutated. The workflow has never run, and the secret it needs does not exist yet.** S-3 remains open and belongs to Phase 21.8B.
