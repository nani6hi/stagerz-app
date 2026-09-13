# Phase 21.8B — Server-side orphan reaper for `collaboration-assets` (S-3)

**Branch:** `phase-21.8b-s3-orphan-reaper`
**Base commit:** `03ece66` (`main`, merge of PR #17 — S-8 drainer schedule)
**Precondition:** **G-7 PASS** (2026-09-13) — all seven deployed Edge Function source files are byte-identical to `main`, proven by Supabase CLI download and raw byte comparison
**Addresses:** finding **S-3** — objects in `collaboration-assets` with no metadata row are never removed
**Classification:** **storage-lifecycle / cleanup defect — NOT a security vulnerability** (reclassified 2026-09-12)
**Implementation merged:** PR #18, merge commit `4bdb426028e68f58e2b67480a38a74d0c35fa89f`
**Status:** **COMPLETE — S-3 REMEDIATED.** Deployed and operated in production 2026-09-13 (UTC), each step under its own explicit approval: one dry-run, one private pre-deletion backup, one controlled delete run, then delete capability disabled again. `storage.objects` 28 → **13**, orphans 15 → **0**, referenced objects and `collaboration_assets` fingerprint-identical before and after. See §12.
**Validation level:** **Level 1 + offline tests** — new Edge Function source with 31 offline tests; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

Sections 1–11 are the implementation record as written before deployment and are preserved unchanged in substance; §2's live facts describe the state **before** the delete run. §12 records what happened in production.

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

## 8. Deployment procedure — PERFORMED 2026-09-13; each step had its own approval

> Performed as planned, with step 5 strengthened from "optionally download" to a mandatory, hash-verified private backup before the delete flag was set. Step 8 was **not** taken: no scheduled caller exists. Outcomes in §12.

1. Review and merge the PR.
2. **Deploy** `reap-orphaned-collaboration-assets` with `verify_jwt = false`. **Do not set** the delete flag.
3. Re-run G-7 for the three existing functions (they must be unchanged) and record the new function's version and bundle hash.
4. **One dry-run.** Predicted against today's data: `objectsScanned 28`, `kept_referenced 13`, `eligible 15`, `batch 15 × would_delete`, `scan.complete true`. Any object in the batch that the phase record did not predict **stops the phase**.
5. Snapshot the eligible paths and sizes into a private record; optionally download the 15 objects (260 bytes).
6. Set the flag; **one** delete run; unset the flag.
7. Validate: bucket 28 → **13**, orphans **0**, `collaboration_assets` **15** unchanged, queue **0**, live rows with objects **13** unchanged.
8. Only then consider a scheduled caller — as its own change, printing counts only.

---

## 9. Explicit mutation boundary — implementation branch

> This table describes the implementation branch only, and remains true of it. The production operation that followed made a deliberate, separately approved set of mutations, listed exhaustively in §12.8.

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

## 11. Summary — as written before deployment

S-3 leaves unreferenced files in Storage forever, because the only party that tries to clean them up — the browser — has, correctly, no permission to delete. This phase adds the smallest server-side counterpart: a separate, maintenance-secret-gated function that is **dry-run by default**, can only delete when both the request and the deployment environment say so, never removes more than 25 objects per run, and never removes anything a live **or soft-deleted** row or a queued deletion still refers to.

*At the time of writing:* nothing had been deployed, invoked or mutated, and S-3 was to remain OPEN until the §8 procedure was completed and validated. **It now has been — see §12 and §13.**

---

## 12. Production result — 2026-09-13 (UTC)

**S-3 is REMEDIATED.** Full evidence, check by check, is in `validation.md` §9. No orphan path, file name, user identifier, secret value or backup content is recorded anywhere in this repository.

### 12.1 Deployment

| Property | Value |
|---|---|
| Deployed from | `main` @ `4bdb426028e68f58e2b67480a38a74d0c35fa89f`, exported with line-ending conversion disabled so the uploaded bytes equal the committed blobs |
| Files deployed | `index.ts`, `reaper.ts`, `maintenance-auth.ts` — `reaper.test.ts` is not imported and was not bundled |
| `verify_jwt` | **false** |
| Source fidelity | Deployed source downloaded with the Supabase CLI and compared **byte-for-byte** against `main`: **3/3 MATCH** — at deployment, after enabling delete, and after disabling it |
| Bundle hash | `b0663090cefb06aad9d062d1d9c2cc30b6a14fee5a3cf7ce686842162c559397`, unchanged from deployment to phase close |
| Version at phase close | **v4** — v1 at deployment; v2, v3 and v4 are platform-side secret reloads (§12.7), not deployments |
| Existing three functions | G-7 re-run after deployment: all 7 captured files still byte-identical; versions, hashes and `updated_at` unchanged by the deployment |

### 12.2 Dry-run

One dry-run request, default body. **HTTP 200**, `mode: dry-run`, **28** objects scanned, `scan.complete: true`, **13** `kept_referenced`, **15** `eligible`, **15** in the batch, all **15** `would_delete`, **0** remaining after the batch, every other classification 0.

The batch's sorted-path SHA-256 was `1415420641f550b39860f0e51f706d5647cafe889dbf2595ba37271c09863632`, and an **independent** computation over the database-derived orphan set produced the same value — proving the batch was exactly the 15 orphans without either side revealing a path. No mutation occurred.

**Logging gap, recorded honestly:** the gateway row for the inbound function request never appeared in `function_edge_logs`. One complete dry-run is nonetheless established by the function runtime log (one boot) and the downstream gateway call pattern, which matches a single run exactly: 5 Storage listings, 16 + 16 exact-count reads, 1 + 1 reference pages, **zero** removals.

### 12.3 Backup — before any deletion

A **private local backup** was taken and its durable copy validated **before** the delete flag was set:

| Property | Value |
|---|---|
| Stored objects recovered | **13** of 15 |
| Bytes | **260** — every byte the 15 orphans were known to hold |
| Integrity | **13/13** files re-hashed against the manifest; durable copy byte-identical to the working copy |
| Manifest SHA-256 | `7ad89c2ab8611f00204e23cd5964a14755fb4de347ad8ff750b25da4d430e128` |
| Method | One authenticated `GET` per object; no Storage write |

**The backup and its manifest live outside this repository and must never be committed.** They contain object paths and file names. Their location is deliberately not recorded here.

### 12.4 The two fixture rows

2 of the 15 orphan `storage.objects` rows could not be downloaded. Both had `metadata = NULL`, `version = NULL` and no size metadata, consistent with synthetic fixture rows not backed by an uploaded Storage object. Both sat under synthetic fixture collaboration identifiers created in the same instant, before the first real upload, and no migration inserts into `storage.objects`. The exact mechanism that originally created the rows was not conclusively established.

A separate authenticated diagnostic `GET` for each returned **HTTP 400**, `statusCode 404`, `code NoSuchKey`, `error Not found`, `message The resource was not found`, with **no ETag and no Last-Modified**. **No underlying stored file existed, so there was nothing to recover.** Their paths and file names are not recorded.

### 12.5 Delete run

Delete flag set; pre-delete check passed (flag present by name, fingerprint and count unchanged, reaper source byte-identical to `main`). Then **exactly one** authorized request with body `{"mode":"delete","confirm":"DELETE_ORPHANED_OBJECTS"}`:

**HTTP 200**, `mode: delete`, **28** scanned, `scan.complete: true`, **15** eligible, batch **15**, **15** `deleted`, **0** remaining. The batch fingerprint matched the validated target fingerprint exactly. The 13 real objects accounted for all **260** known bytes; the 2 NoSuchKey fixture rows were removed from `storage.objects` as well, each reported `deleted`.

The gateway and Storage logs show exactly one run's calls: 5 listings, 16 + 16 count reads, 1 + 1 pages, **15** `DELETE` calls answered 200, 15 `storage.object.delete_many` and 15 `ObjectRemoved:Delete` lifecycle events, and nothing else. As in the dry-run, the inbound request row itself did not appear in `function_edge_logs`.

### 12.6 Post-delete validation and final safety state

| Check | Before | After |
|---|---|---|
| `storage.objects` | 28 | **13** |
| `collaboration_assets` | 15 / 15 live | **15 / 15 live** |
| `pending_asset_deletions` | 0 | **0** |
| Orphans / orphan bytes | 15 / 260 | **0 / 0** |
| The 15 target paths in Storage metadata | 15 | **0** — compared by per-path SHA-256 |
| Referenced-object snapshot (13 objects: path, created, updated, version, ETag) | `dc4c75460a285b899be44b07e67fbf0b4f78ffd0ebe9c6484df9d33caa4bdb98` | **identical** |
| `collaboration_assets` snapshot (15 rows: id, storage path, deleted_at) | `a910b6eee3c9c637ca93048b7896dd2facc33e3a5b5287c684163a07ef07f567` | **identical** |
| Objects created or updated during the run | — | **0** |

**No referenced object was changed or removed.** After validation, `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` was **removed** and confirmed absent by name. At phase close the reaper is **ACTIVE, v4**, bundle and source unchanged and byte-identical to `main` — back in its fail-closed, default-disabled state. With the flag absent, a delete request is refused with 403 before any Storage call — guard G-B, proven by the offline tests. That refusal was deliberately **not** re-exercised in production.

### 12.7 Platform and tooling observations

- **Secret changes reload every function.** Each project-secret change — the operator's rotation of `STAGERZ_MAINTENANCE_SECRET` before the dry-run, setting the delete flag, and removing it — incremented the version of **all four** deployed functions together, while every bundle hash and `updated_at` stayed identical and downloaded source stayed byte-identical. This was treated as a platform-side secret reload, not a source deployment. It matches the v7 → v8 bump observed in Phase 21.8A.
- **`supabase db query` has a database side effect.** One harmless `SELECT 1` run through it caused the CLI to create or renew the CLI-managed role `cli_login_postgres` with a short validity window. The role had **zero sessions**, was not dropped or altered, and **no application data was changed**. All later work avoided that command; read-only SQL went through the established read-only tool, and the role's expiry was verified unchanged afterwards.
- **A first backup attempt aborted before any request** because of a PowerShell 5.1 argument-parsing defect in the local script. The failing line runs before the only network call, so — by script-flow analysis, confirmed by an empty object directory and no manifest — no request was sent and no file was written. The corrected script was validated offline before use.

### 12.8 Production mutation boundary

Exhaustive. Every other interaction was a read.

| Mutation | Approval | Outcome |
|---|---|---|
| Deploy `reap-orphaned-collaboration-assets` (`verify_jwt=false`) | Deployment step | v1, source byte-identical to `main` |
| Rotate `STAGERZ_MAINTENANCE_SECRET` in Supabase and GitHub | Operator | Reload only (§12.7) |
| Set `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED=true` | Delete enablement | Reload only |
| One delete-mode invocation | Single delete run | 15 `storage.objects` rows and their stored objects removed |
| Remove `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` | Disablement | Reload only; delete capability off |
| `cli_login_postgres` created or renewed by the CLI | Unintended tooling side effect, accepted and documented | No application data changed |

**Not changed at any point:** any database schema, policy, grant, function or application row; `index.html`; any workflow; the three pre-existing Edge Functions' source.

### 12.9 What remains open or out of scope

- **S-4** remains OPEN.
- **Live rows with missing objects** — 2 live `collaboration_assets` rows reference Storage objects that do not exist. Pre-existing, unaffected by the reaper by design, and a separate issue.
- **New orphans can still arise** from the upload-then-insert failure path. Reclaiming them requires a future operator-initiated run under the same procedure; **no schedule exists**, and adding one would be its own reviewed change that prints counts only.
- **The inbound function-request log row** was missing for both production invocations. The downstream evidence was conclusive both times; the gap itself is a platform logging observation.

---

## 13. Summary

S-3 was never a leak: the browser correctly cannot delete from Storage. The defect was that nothing else could either, so every orphan stayed forever. Phase 21.8B added a separate, service-role, maintenance-secret-gated reaper that is dry-run by default and needs two independent keys to delete, and then used it exactly once, after a fingerprint-matched dry-run and a verified private backup.

**All 15 orphans are gone, nothing referenced was touched, and delete capability is off again. S-3 is REMEDIATED.**
