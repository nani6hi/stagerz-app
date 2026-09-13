# Phase 21.8B — Server-side orphan reaper for `collaboration-assets` (S-3)

**Branch:** `phase-21.8b-s3-orphan-reaper`
**Base commit:** `03ece66` (`main`, merge of PR #17 — S-8 drainer schedule)
**Precondition:** **G-7 PASS** (2026-09-13) — all seven deployed Edge Function source files are byte-identical to `main`, proven by Supabase CLI download and raw byte comparison
**Addresses:** finding **S-3** — objects in `collaboration-assets` with no metadata row are never removed
**Classification:** **storage-lifecycle / cleanup defect — NOT a security vulnerability** (reclassified 2026-09-12)
**Status:** **IMPLEMENTED ON BRANCH, NOT DEPLOYED.** No Edge Function deployed or invoked, no secret or environment variable changed, no database, policy or Storage change
**Validation level:** **Level 1 + offline tests** — new Edge Function source with 31 offline tests; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

---

## 1. Objective

Provide a **service-role-only** path that removes Storage objects in `collaboration-assets` which no `collaboration_assets` row references — **without** giving the browser any Storage DELETE permission, and **without** changing any existing deletion pipeline.

**Rejected in Phase 21.8 and still rejected:** a client DELETE policy on `storage.objects`; any RLS change allowing frontend deletion; a user-facing cleanup function; a new SECURITY DEFINER helper.

---

## 2. Live facts the design rests on — read-only, 2026-09-13

No paths, file names or user identifiers are recorded here.

| Fact | Value | Design consequence |
|---|---|---|
| Buckets in project | **1** — `collaboration-assets`, private | Bucket is a constant; no other bucket exists to confuse |
| Objects in bucket | **28** | — |
| Path depth | **all 28 are exactly `<folder>/<file>`** | Listing descends exactly one level |
| First segment of every orphan | a UUID of an **existing** collaboration | Path-shape rule is `<uuid>/<file>` |
| `.emptyFolderPlaceholder` objects | **0** | Excluded anyway |
| Orphans (no `collaboration_assets` row) | **15**, **260 bytes**, created 2026-07-16 .. 2026-07-18, never updated | First real batch would be 15 (< 25) |
| Orphans without size metadata | **2** | Size is reported, never required |
| Orphans present in `pending_asset_deletions` | **0**; queue is empty | — |
| Live rows whose object is missing | **2** (pre-existing, not caused by any phase) | Out of scope — the reaper never touches metadata |
| `collaboration_assets.storage_path` | `NOT NULL`, **`UNIQUE`** | Total order for paging; exact-match set |
| `pending_asset_deletions.storage_path` | `NOT NULL`, **primary key** | Same |
| `users.photo_url` pointing into the bucket | **0** | No other referrer exists |
| Other columns referencing Storage paths | **none** (only the two tables above) | Two reference sources are exhaustive |
| Functions writing `storage_path` | **none** — `delete_collaboration_asset` and `edit_collaboration_asset` never change it | A row's reference is fixed once inserted |
| `storage.objects` triggers | `protect_objects_delete`, `update_objects_updated_at` | Direct SQL DELETE is blocked; removal must use the Storage API |

**How orphans arise** (all legitimate, all unreachable from the UI once they exist):

1. `uploadCollaborationAsset()` uploads the object, then inserts the row. If the insert fails, the frontend's best-effort `remove()` is denied (no DELETE policy — S-3's original observation), leaving the object.
2. `collaboration_assets` rows are deleted by `ON DELETE CASCADE` from `collaborations` and from `users`.
3. The S-8 drainer hard-deletes a metadata row after removing its object — normally no orphan, but a partial failure between steps can leave one.

---

## 3. Architecture decision

**A new, separate Edge Function: `reap-orphaned-collaboration-assets`.**

| Option | Why not chosen |
|---|---|
| **Add a mode to `process-pending-asset-deletions`** | Modifies the validated, scheduled, G-7-verified drainer; couples a scan-and-delete over the whole bucket to a queue drainer; rollback of one would roll back the other |
| **SQL function / `pg_cron`** | Deleting `storage.objects` rows does not remove the backend file, and `protect_objects_delete` blocks it anyway; would also be a schema change |
| **Query `storage.objects` over a direct Postgres connection** | Needs a database driver and the full DB credential inside the function; the Storage API listing is the supported read path |
| **Client-side cleanup** | Requires the very DELETE permission this phase must not grant |

**Why a separate function wins:** the three existing functions stay byte-identical to what G-7 verified; the reaper can be deployed, disabled or deleted independently; and its entire authority is visible in one reviewable folder.

**File layout** — mirrors the existing `process-*` functions:

| File | Role |
|---|---|
| `supabase/functions/reap-orphaned-collaboration-assets/index.ts` | Wiring only: environment, service-role client, Storage listing, reference reads, `remove()` |
| `…/reaper.ts` | **Dependency-free core**: request parsing, eligibility rules, guards, orchestration, HTTP handling. No remote imports |
| `…/maintenance-auth.ts` | Third copy of the maintenance-secret check — **logic byte-identical** to both existing copies; only the 6-line header differs |
| `…/reaper.test.ts` | 31 offline tests; never imported by `index.ts`, so never bundled |

**Authorization:** the existing `STAGERZ_MAINTENANCE_SECRET`, accepted exactly as the two `process-*` functions accept it. **No new secret is created.** Intended deployment flag: `verify_jwt = false`, as for its siblings.

**Dependency:** `https://esm.sh/@supabase/supabase-js@2.112.1` — **pinned** to the frontend's exact version (Phase 21.2). The floating `@2` import in the three captured functions is **deliberately not changed**: they are forensic captures, and touching them would void G-7.

---

## 4. Deletion eligibility — exact rules

An object is removed **only if every rule holds**. Rules are evaluated per object in this order; the first that fails decides its classification.

| # | Rule | Fails as |
|---|---|---|
| **E-1** | Path is **not** the `storage_path` of **any** `collaboration_assets` row — **live or soft-deleted**. The read has **no filter** | `kept_referenced` |
| **E-2** | Path is **not** in `pending_asset_deletions` — queued objects belong to the S-8 drainer | `kept_queued` |
| **E-3** | Path matches `^<lowercase-uuid>/<one segment>$`; no leading/trailing whitespace; no control characters; file segment is not `.`, `..` or `.emptyFolderPlaceholder` | `skipped_unexpected_path` |
| **E-4** | `created_at` parses; `updated_at`, if present, parses | `skipped_unknown_age` |
| **E-5** | `now − max(created_at, updated_at) ≥ 48 h`. A future timestamp gives a negative age and is protected | `skipped_within_grace_period` |
| **E-6** | Among the **25 oldest** eligible objects (by newest timestamp, then path) | stays eligible, reported in `eligibleRemainingAfterBatch` |
| **E-7** | **Immediately before removal**, exact-match counts in **both** tables are still `0` | `kept_on_recheck`, or `recheck_failed` if the re-check errors |
| **E-8** | Request is `{"mode":"delete","confirm":"DELETE_ORPHANED_OBJECTS"}` **and** environment `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED=true` | dry-run (`would_delete`), `400` or `403` |

**Matching is exact, case-sensitive string equality** against an in-memory set built from every row. There is no filter expression in the bulk read, so no encoding of special characters in file names can cause a missed match.

**The reaper never writes to the database.** Its only mutation is `storage.from('collaboration-assets').remove([path])`, one path per call.

---

## 5. Safety guards

| Guard | Where | Behaviour |
|---|---|---|
| **G-A Dry-run default** | `parseMode` | Empty body, `{}` and `{"mode":"dry-run"}` → dry-run. Unknown fields, wrong types, wrong case, or `confirm` without `delete` → **400**, never a guess |
| **G-B Two-key delete** | `handleRequest` | Delete needs the confirmation token **and** the environment flag. Flag absent → **403 before any Storage or database call**. The flag is **not set** by this phase |
| **G-C Bucket** | `BUCKET` constant | Only `collaboration-assets` is listed or removed; the bucket is not request-controllable |
| **G-D Grace period** | `GRACE_PERIOD_MS` = 48 h | `selectBatch` **throws** if called with less than 24 h |
| **G-E Batch limit** | `BATCH_SIZE` = 25 | `selectBatch` **throws** outside 1..25; not request-controllable |
| **G-F Complete reference read** | `fetchAllStoragePaths` | Exact `count` first, then paged read ordered by the unique key; **fewer rows than the count aborts the run** — catches a silent PostgREST row cap |
| **G-G Per-object re-check** | `isStillUnreferenced` | Exact-match counts in both tables right before each removal; an error keeps the object |
| **G-H Service-role sanity** | `runReaper` | Objects exist but **zero** metadata rows visible → **409 refused, nothing removed**. This is what a wrong key (RLS hiding every row) would look like |
| **G-I Fail closed** | `handleRequest` | Any listing or reference error → **500 before any removal** |
| **G-J Scan bounds** | `index.ts` | 10 000 objects, 1 000 pages per prefix, 100 000 reference rows; nested folders are not descended. Anything unscanned is never deleted; `scan.complete` reports it |
| **G-K Body bound** | `handleRequest` | Bodies over 1 KiB → **400** |
| **G-L Configuration** | `handleRequest` | Missing URL, service-role key or maintenance secret → **500** before authorization |

**No retries.** A failed removal is reported as `delete_failed`; the object is reconsidered on the next run.

**Response.** Aggregate counts plus the batch — `path`, `sizeBytes`, `createdAt`, `updatedAt`, `status`. **Paths contain a collaboration UUID and a user-chosen file name**, so a response must never be printed to a public log. No caller or workflow is added in this phase. Error logs contain counts and messages only, never paths.

---

## 6. Blast radius

| State | What can be removed |
|---|---|
| **This phase (branch only)** | **Nothing** — not deployed |
| **Deployed, flag unset** | **Nothing.** Dry-run reads the bucket listing and two tables; delete requests get 403 |
| **Deployed, flag set, one delete run** | **At most 25 objects**, all in `collaboration-assets`, each unreferenced by any live or soft-deleted row, not queued, ≥ 48 h old and re-checked. Against today's data: **exactly the 15 orphans, 260 bytes** |
| **Never** | Any `collaboration_assets` row; any `pending_asset_deletions` row; any object referenced by either table; any object in another bucket; any database schema, policy, grant or secret |

**Irreversibility.** A removed Storage object cannot be recovered — Supabase backups cover the database, not Storage files. This is why E-1 protects soft-deleted rows as well as live ones, and why the first delete run is preceded by a dry-run review and an optional download of the eligible objects (§8).

**Interaction with existing pipelines:**

- **S-8 drainer** — unaffected. It only acts on queued paths; the reaper never touches queued paths (E-2, E-7). Concurrent runs are safe: if the drainer removes an object and its row mid-scan, the reaper's `remove()` returns `already_absent`.
- **Account deletion** (`delete-account`, `process-pending-deletions`) — unaffected; neither touches Storage.
- **Frontend upload** — the object-then-row gap is seconds; the grace period is 48 hours.

---

## 7. Rollback

| Layer | Rollback |
|---|---|
| **Repository** | Do not merge, or `git revert` the phase commit. Adds files only; changes none |
| **Deployed function — instant** | Unset `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` → dry-run only |
| **Deployed function — complete** | `supabase functions delete reap-orphaned-collaboration-assets`. Nothing else calls or depends on it |
| **Removed objects** | **Not reversible.** Mitigated by the §8 pre-deletion snapshot |

---

## 8. Deployment procedure — NOT performed; each step needs its own approval

1. Review and merge the PR.
2. **Deploy** `reap-orphaned-collaboration-assets` with `verify_jwt = false`. **Do not set** the delete flag.
3. Re-run G-7 for the three existing functions (they must be unchanged) and record the new function's version and bundle hash.
4. **One dry-run.** Predicted against today's data: `objectsScanned 28`, `kept_referenced 13`, `eligible 15`, `batch 15 × would_delete`, `scan.complete true`. Any object in the batch that the phase record did not predict **stops the phase**.
5. Snapshot the eligible paths and sizes into a private record; optionally download the 15 objects (260 bytes).
6. Set the flag; **one** delete run; unset the flag.
7. Validate: bucket 28 → **13**, orphans **0**, `collaboration_assets` **15** unchanged, queue **0**, live rows with objects **13** unchanged.
8. Only then consider a scheduled caller — as its own change, printing counts only.

---

## 9. Explicit mutation boundary

| Action | Status |
|---|---|
| Edge Function deployed, modified or invoked | **No** — the three existing functions are unchanged (G-7 byte identity preserved) |
| Environment variable or secret created or changed | **No** |
| Storage object removed | **No** |
| Database schema, policy, grant, function or row changed | **No** |
| `index.html` changed | **No** |
| Workflow added or changed | **No** |
| PR created | **No** |

Every Supabase interaction in this phase was a `SELECT` or catalog read.

---

## 10. Scope boundary

**In scope:** the new function source, its offline tests, and this record.

**Out of scope:** deployment; any invocation; the delete flag; a scheduled caller; the 2 live rows whose objects are missing; pinning the captured functions' `@supabase/supabase-js@2` import; S-4.

---

## 11. Summary

S-3 leaves unreferenced files in Storage forever, because the only party that tries to clean them up — the browser — has, correctly, no permission to delete. This phase adds the smallest server-side counterpart: a separate, maintenance-secret-gated function that is **dry-run by default**, can only delete when both the request and the deployment environment say so, never removes more than 25 objects per run, and never removes anything a live **or soft-deleted** row or a queued deletion still refers to.

**Nothing has been deployed, invoked or mutated. S-3 remains OPEN until the §8 procedure is completed and validated.**
