# Phase 21.8A — Capture the deletion pipeline and prepare its scheduler (S-8)

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0` (`main`, merge of PR #15 — Phase 21.7 / S-6, S-7)
**Addresses:** finding **S-8** — the pending asset-deletion pipeline has no active automatic drainer
**Classification:** **reliability / data-lifecycle defect — NOT a security vulnerability**
**Severity:** **MEDIUM**
**Status:** **PREPARATION ONLY. Nothing deployed, nothing scheduled, nothing invoked, no database change.**
**Validation level:** **Level 1** — documentation and forensic source capture; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

---

## 1. Objective

Two things, in this order:

1. **Capture the deployed Edge Function source in version control** — it currently exists *only* inside the Supabase project, so the code that holds privileged deletion authority is unreviewable from this repository. This is the Phase 20.7 **C-3** problem applied to Edge Functions.
2. **Prepare** (not create) a GitHub Actions scheduler for the existing drainer.

**Phase 21.8A contains no orphan reaper.** S-3 is handled separately in Phase 21.8B, and only after this phase is validated.

**Pattern decision (`.apos/WORKFLOW.md`): Extend**, with one new artifact class — captured third-party-hosted source, mirroring how Phase 21.3 introduced descriptive SQL snapshots.

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
- Repository CI — **none**; no `.github`, no `netlify.toml`, no `supabase/` directory before this phase
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

Both objects being already absent means they were removed out-of-band; the queue was never processed. This is what makes the first activation exceptionally low-risk (§7).

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

Captured verbatim, with **no refactoring, no dependency pinning, no improvement of any kind** — this is a forensic record of what is deployed, not a cleanup.

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

**`supabase init` was deliberately not run.** No `config.toml`, no seed files, no CLI scaffolding. Capturing source alone satisfies "capture before modify" with the least new surface; CLI scaffolding can be added deliberately later if CLI-based deploys are ever wanted.

**Two duplication facts preserved as-is**, because they are properties of the deployed system:

- `maintenance-auth.ts` exists **twice**, once per `process-*` function, and each copy's header says the duplication is deliberate (Edge Function bundling constraints) and that both copies must be kept in sync.
- `delete-auth-account.ts` exists **twice**: `_shared/` (used by `delete-account`) and a private copy inside `process-pending-deletions/`. The two differ **only** in their first-line path comment.

---

## 6. Scheduler decision

**GitHub Actions**, on evidence, over four alternatives.

| Option | Why not chosen |
|---|---|
| **Netlify Scheduled Function** | Needs `netlify.toml` and a functions directory, neither of which exists; adds backend logic to a surface that is currently a static mirror |
| **`pg_cron` + `pg_net`** | Requires installing two extensions, puts the maintenance secret **inside the database**, and — decisively — **the schedule would live only in the database**, which is exactly the C-3 invisibility this project keeps paying for |
| **Database webhooks** | Event-driven, not periodic; cannot retry failures and cannot drive a future periodic scan |
| **External scheduler** | Hands the maintenance secret to a third party; worst on custody and reviewability |

**Why GitHub Actions wins:** the schedule becomes a **diffable file in this repository**, reviewable under the same process as every other change. It adds no database extensions, keeps the secret out of the database, needs no new deployment surface, and gives run history and failure notifications for free. Its one weakness — GitHub cron is best-effort and can be delayed or skipped — is irrelevant for an idempotent deferred-cleanup queue.

**One important technical finding that removes the main argument for `pg_cron`:** deleting a row from `storage.objects` does **not** remove the underlying file from the storage backend. Only the Storage API does. A SQL-only scheduler could therefore never complete the job; it would still have to make an HTTP call out to the Edge Function.

**Supabase Pro is NOT required.** The organization is on **Free**, and everything here fits: `pg_cron`/`pg_net` are available but unused under this decision, Edge Function invocations run about 30/month against a 500K allowance, and Storage volumes are trivial. **This is not the point at which Pro becomes necessary, and it should not be purchased for this.**

---

## 7. Intended first-activation procedure — NOT performed in this phase

Ordered for the smallest possible blast radius:

1. Commit and push this capture; review.
2. **Manual** configuration of the GitHub repository secret `STAGERZ_MAINTENANCE_SECRET`, reusing the value already set in the Edge Function environment. **No new secret is created.**
3. **One manual invocation, under explicit approval**, before any schedule exists.
4. Validate against the predicted end state below.
5. Only then add the workflow, initially with `workflow_dispatch` **only**.
6. Only after a successful dispatch run, add the `schedule:` trigger as its own change.

**Predicted end state of the single first invocation:**

| | Before | After |
|---|---|---|
| HTTP response | — | `200`, `{processed: 2, results: [already_deleted, already_deleted]}` |
| `pending_asset_deletions` | 2 rows | **0 rows** |
| `collaboration_assets` | 17 (15 live + 2 soft-deleted) | **15** — the two soft-deleted rows hard-deleted |
| `storage.objects` | 28 | **28 — unchanged** |
| Orphan objects | 15 | **15 — unchanged** |
| Live assets | 15 | **15 — untouched** |

Two notes for whoever approves it. The metadata hard-delete is **irreversible**, so both queue rows should be snapshotted into the phase record first. And `already_deleted` is the *expected* status — seeing `deleted` would mean an object existed that this analysis says does not, and must stop the phase.

---

## 8. Rollback concept

**For this phase: `git revert`.** It adds documentation, a `.gitignore` and captured source. It changes no production system, so there is nothing to roll back outside the repository.

**For the later steps** (not in this phase): deleting the workflow file disables the schedule; removing the GitHub secret revokes CI's ability to call the function; neither touches Supabase. The Edge Function itself is not modified in 21.8A, so its deployed version remains **7** throughout.

---

## 9. Explicit mutation boundary

**Nothing in this phase mutates anything outside the repository working tree.**

| Not done | Confirmed |
|---|---|
| Edge Function invoked | No |
| Edge Function deployed or modified | No — still version 7 / 5 / 4 |
| Queue row, metadata row or Storage object deleted | No |
| Database policy, schema, function or grant changed | No |
| GitHub Actions workflow created | **No — deliberately deferred** |
| GitHub secret created or changed | **No** |
| Committed or pushed | No |

Every Supabase interaction in this phase was a `SELECT`, a catalog read, or an Edge Function **metadata/source read**.

---

## 10. Validation gates

Full detail in `validation.md`. Gates for this phase: all seven captured files match the deployed source; no secret value appears in any tracked file; no application source changed; no workflow exists; no SQL migration exists; Supabase unmutated.

Gates for the *next* steps, recorded here so the ordering is not lost: the manual invocation must produce exactly the §7 end state before any workflow is added, and the workflow must run successfully via `workflow_dispatch` before any `schedule:` trigger is introduced.

---

## 11. Scope boundary

**In scope:** source capture, `.gitignore`, documentation, scheduler decision.

**Explicitly out of scope:** the orphan reaper (S-3 → Phase 21.8B); any change to the Edge Functions, including pinning the floating `@supabase/supabase-js@2` import; any database change; the workflow file; the secret; S-4.

**One observation deliberately left unactioned:** all three functions import `https://esm.sh/@supabase/supabase-js@2` — a **floating major version**, so any redeploy may resolve a different minor or patch. The frontend was pinned to exactly `2.112.1` with SRI in Phase 21.2; the Edge Functions have no equivalent. Pin it when the function is next modified in 21.8B — **not** as a drive-by change to a forensic capture.

---

## 12. Summary

The asset-deletion pipeline is well designed and never finished: a soft delete, a queue, an activity record and a privileged service-role drainer all exist, but nothing has ever called the drainer. Two deletion requests have sat unprocessed since 2026-07-20.

Before changing any of it, this phase does the thing that should have happened first — **puts the deployed source under version control**, all seven files, fidelity-checked, with no improvements folded in. It then records the scheduler decision (GitHub Actions, on reviewability grounds) and the first-activation procedure, without creating either.

**Nothing has been deployed, scheduled, invoked or mutated.** S-3 remains open and belongs to Phase 21.8B.
