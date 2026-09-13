# Phase 21.8B — Validation Record

**Branch:** `phase-21.8b-s3-orphan-reaper`
**Base commit:** `03ece66`
**Implementation merged:** PR #18, merge commit `4bdb426028e68f58e2b67480a38a74d0c35fa89f`
**Validation level:** **1 + offline tests** — new Edge Function source; `index.html` is not touched
**Status:** **COMPLETE — S-3 REMEDIATED. Production validation closed 2026-09-13 (UTC).** Implementation validated offline (§2–§8); deployment, dry-run, backup, one delete run and delete disablement validated in production (§9).

---

## 1. What this record claims, and what it does not

**Claims:** the reaper's eligibility rules, guards and HTTP gating behave as specified in `phase-definition.md` §4–§5 **when driven by fake dependencies**; the entrypoint type-checks against the pinned `@supabase/supabase-js@2.112.1`; lint is clean; no existing tracked file changed.

**Does not claim** anything about behaviour against the real Storage API or PostgREST. The adapter in `index.ts` (listing semantics, folder detection by `id === null`, `count` behaviour, row caps) is **type-checked, not executed**. The first real exercise is the read-only dry-run in `phase-definition.md` §8 step 4, and its predicted output is a prediction.

> **Finding-status note.** Finding status lives in `analysis/phase-21.3/backend-contract.md` §0.2. *As written for the implementation branch:* "S-3 remains OPEN — this phase implements, it does not remediate." **Superseded 2026-09-13: S-3 is REMEDIATED** by the production operation recorded in §9.

**§1's "does not claim" paragraph is superseded by §9**, which records the adapter's real behaviour against the production Storage API and PostgREST. §2–§8 are preserved unchanged as the offline record.

---

## 2. Precondition

| Gate | Result |
|---|---|
| **G-7** — deployed source byte-identical to `main` | **PASS** (2026-09-13): 7/7 files raw MATCH via `supabase functions download --use-api`, compared against `HEAD` blobs; no one-sided files. Versions 8 / 6 / 5, bundle hashes `d3c3f1b5…`, `66f3c27a…`, `79b2fa66…` |

---

## 3. Files added

| Path | SHA-256 | Bytes | Lines |
|---|---|---|---|
| `supabase/functions/reap-orphaned-collaboration-assets/index.ts` | `0b3b17967fb7db2f806f0841ac9e91af47be30e292ebbb276469749394f80a2e` | 7538 | 197 |
| `supabase/functions/reap-orphaned-collaboration-assets/maintenance-auth.ts` | `fe499abe4cc53cb1c5a027bfd71f6f33ec4ac327890a2f3b6221f6d3a67d7030` | 1464 | 37 |
| `supabase/functions/reap-orphaned-collaboration-assets/reaper.ts` | `1732e7f9739850d3f47a715ea9bfb3f315b692330c0fab9896f533c22a1e1dd9` | 13249 | 390 |
| `supabase/functions/reap-orphaned-collaboration-assets/reaper.test.ts` | `9f2e3f6c4e73de25ae1fe3f478d22bfd871dd1196c1f2d39d524a97d2ab7a9da` | 20780 | 542 |

All four: LF line endings, **0** CR bytes, **0** control bytes.

---

## 4. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **R-1** | No existing tracked file modified | **PASS** — `git diff` against `03ece66` is empty for tracked files; only new files added |
| **R-2** | The three captured functions untouched | **PASS** — G-7 byte identity preserved |
| **R-3** | `index.html` unmodified | **PASS** |
| **R-4** | No SQL, migration, policy or workflow file | **PASS** |
| **R-5** | No secret value in any file | **PASS** — only environment variable **names**; the test secret is the literal `test-maintenance-secret-not-real` |
| **R-6** | `maintenance-auth.ts` logic identical to both existing copies | **PASS** — lines 7–end byte-identical to both `HEAD` blobs; only the 6-line header differs (path, "all three copies") |
| **R-7** | Test file not part of the deployed bundle | **PASS** — not imported by `index.ts` |
| **R-8** | No Supabase mutation | **PASS** — `SELECT` and catalog reads only |

---

## 5. Executed checks — code

Toolchain: **Deno 2.9.6**, official Windows release, checksum verified against the published `.sha256sum` (`15e5300b…e3cd11`), run from a scratch directory, not installed.

| # | Check | Command | Result |
|---|---|---|---|
| **C-1** | Offline tests | `deno test --no-remote supabase/functions/reap-orphaned-collaboration-assets/` | **PASS — 31 passed, 0 failed**, exit 0. `--no-remote` proves no network import |
| **C-2** | Type check, including pinned SDK types | `deno check index.ts reaper.ts reaper.test.ts` | **PASS**, exit 0 |
| **C-3** | Lint | `deno lint supabase/functions/reap-orphaned-collaboration-assets/` | **PASS** — 4 files, 0 problems, exit 0 |
| **C-4** | Formatter | `deno fmt --check` | **Not enforced** — the repository has no formatter convention, and the captured functions are not `deno fmt`-formatted either. Informational only |

**One test defect found and fixed during validation:** the uppercase-UUID rejection case used a digits-only UUID, which is unchanged by `toUpperCase()`, so the assertion was testing an accepted path. The fixture was changed to a UUID containing letters. **No product code changed as a result.**

---

## 6. Test coverage by rule and guard

| Rule / guard | Tests |
|---|---|
| Constants: bucket, 48 h, 25 | `constants` |
| **G-A** dry-run default, strict parsing | 3 × `parseMode`; `handleRequest: default request is a dry-run` |
| **G-B** two-key delete | `delete is refused while disabled, before any I/O` (asserts **no dependency was created and no call made**); `delete needs the token even when enabled`; `enabled + confirmed delete removes the batch` |
| **E-1** live **and** soft-deleted rows protect | `a referenced object is kept however old it is`; `delete removes only unreferenced…` (soft-deleted fixture) |
| **E-2** queued objects protected | `a queued object is left to the drainer`; mixed fixture |
| **E-3** path shape | `isExpectedPath` (2 accepted, 15 rejected incl. nested, root, uppercase, whitespace, NUL/LF/DEL, `.`/`..`, placeholder) |
| **E-4** unknown age | `unknown age is never eligible` (4 cases) |
| **E-5** grace period | boundary at exactly 48 h; recent `updated_at`; future timestamps |
| **E-6 / G-E** batch | `at most 25, oldest first, deterministic`; `delete stops at 25 per run`; `refuses … a batch outside 1..25` |
| **G-D** minimum grace | `refuses a grace period under 24h` (23 h, 0, NaN) |
| **E-7 / G-G** re-check | `a reference that appears before deletion wins`; `a failed re-check keeps the object` |
| **G-H** zero-reference guard | `refuses when no metadata row is visible` (no re-check, no removal); HTTP 409 |
| **G-I** fail closed | `listing or reference failures abort before any deletion`; HTTP 500 with nothing removed |
| **G-K / G-L** | oversized body → 400; missing secret / blank secret / missing Supabase config → 500 |
| Auth | missing header, wrong secret → 401; both documented headers accepted |
| Dry-run inertness | `dry-run never removes anything`; every HTTP dry-run test asserts zero removals |
| Production-shaped fixture | 28 objects: 13 referenced, 15 aged orphans → `eligible 15`, batch 15 |

**Every test that could delete asserts the exact set removed**, and the mixed-fixture test asserts that **no protected path ever reached the re-check or removal step**.

---

## 7. Not validated — carried to deployment

1. Real Storage API listing semantics (folder entries, timestamps, pagination) — first exercised by the §8 step 4 dry-run.
2. PostgREST `count: "exact"` and row-cap behaviour on this project — guarded by G-F, which fails closed.
3. Supabase Edge Runtime vs local Deno 2.9.6 differences.
4. The deployed function's `verify_jwt` setting — must be `false` at deploy time.

**Resolution, 2026-09-13:**

| # | Outcome |
|---|---|
| 1 | **Resolved.** The production dry-run listed all **28** objects across the root and 4 folders with `scan.complete: true`, and its 15-object batch fingerprint matched the independently derived orphan set (§9.2) |
| 2 | **Resolved.** Both reference reads completed without tripping G-F: exact counts, one page each, 15 per-object re-checks per table, all HTTP 200 (§9.2, §9.6) |
| 3 | **Resolved in practice.** The function ran on Supabase Edge Runtime (`Deno/2.1.4`) and produced exactly the offline-predicted classification and call pattern |
| 4 | **Resolved.** Deployed with `verify_jwt = false`, confirmed after deployment and at every later check (§9.1) |

---

## 8. Mutation boundary confirmation — implementation branch

No deployment, invocation, secret or environment change, Storage removal, database write, policy change, workflow change or PR. **Nothing outside the repository was changed.** *(True of the implementation branch. The later production mutations are listed in `phase-definition.md` §12.8.)*

---

## 9. Production validation — 2026-09-13 (UTC)

Every check below was read-only unless marked as the approved mutation. No orphan path, file name, user identifier, secret value or backup content is recorded here.

### 9.1 Deployment and source fidelity

| # | Check | Result |
|---|---|---|
| **D-1** | Deployed from `main` @ `4bdb426` | **PASS** — exported from the commit with line-ending conversion disabled; 4/4 exported files equal the committed blobs before upload |
| **D-2** | Only the reaper deployed; `verify_jwt=false` | **PASS** — CLI uploaded `index.ts`, `reaper.ts`, `maintenance-auth.ts`; `verify_jwt` false; ACTIVE |
| **D-3** | Deployed source byte-identical to `main` | **PASS — 3/3 raw MATCH** (`index.ts` `0b3b1796…`, `reaper.ts` `1732e7f9…`, `maintenance-auth.ts` `fe499abe…`); `reaper.test.ts` present only in `main`, as expected |
| **D-4** | Existing three functions unaffected | **PASS** — G-7 re-run: 7/7 captured files byte-identical; versions, bundle hashes and `updated_at` unchanged by the deployment |
| **D-5** | Delete flag absent after deployment | **PASS** — by secret name only |

### 9.2 Dry-run

| # | Check | Expected | Result |
|---|---|---|---|
| **R-D1** | HTTP status / mode | 200 / dry-run | **200 / dry-run** |
| **R-D2** | Objects scanned / `scan.complete` | 28 / true | **28 / true** |
| **R-D3** | `kept_referenced` / `eligible` / all other classifications | 13 / 15 / 0 | **13 / 15 / 0** |
| **R-D4** | Batch / `would_delete` / remaining | 15 / 15 / 0 | **15 / 15 / 0** |
| **R-D5** | Batch fingerprint equals independent database fingerprint | match | **MATCH** — `1415420641f550b39860f0e51f706d5647cafe889dbf2595ba37271c09863632` |
| **R-D6** | No mutation | — | **PASS** — 28 objects / 15 live assets / 0 queue / 15 orphans / 260 bytes before and after |
| **R-D7** | Exactly one run | 1 | **1**, established by one runtime boot and the downstream call pattern (5 listings, 16 + 16 count reads, 1 + 1 pages, 0 removals). The inbound row in `function_edge_logs` never appeared |

### 9.3 Private backup

| # | Check | Result |
|---|---|---|
| **B-1** | Path set re-derived and fingerprint re-verified before download | **PASS** — 15 paths, fingerprint matches, verified in the database, in the private list and inside the script |
| **B-2** | Read-only transfer | **PASS** — exactly 15 authenticated `GET`s at the gateway, no Storage write, no access-timestamp change |
| **B-3** | Objects recovered / bytes | **13 / 260** |
| **B-4** | Integrity | **PASS** — 13/13 files match manifest SHA-256 and size; manifest SHA-256 `7ad89c2ab8611f00204e23cd5964a14755fb4de347ad8ff750b25da4d430e128` |
| **B-5** | Durable copy | **PASS** — byte-identical to the working copy (0 missing, 0 extra, 0 differing files); re-verified intact after the delete run and after disablement |
| **B-6** | Kept out of the repository | **PASS** — local and private; location not recorded; nothing committed |

### 9.4 The two non-recoverable fixture rows

| # | Check | Result |
|---|---|---|
| **F-1** | The 2 failures are exactly the 2 orphans without size metadata | **PASS** — exact-string comparison, privately |
| **F-2** | Row signature | `metadata = NULL`, `version = NULL`, no `user_metadata`; synthetic fixture collaborations; created before the first real upload; no migration inserts into `storage.objects` |
| **F-3** | Authenticated diagnostic `GET`, one per row | Both: **HTTP 400**, `statusCode 404`, `code NoSuchKey`, `error Not found`, `message The resource was not found`, **no ETag, no Last-Modified** |
| **F-4** | Conclusion | **No underlying stored file existed; nothing was recoverable.** Deleting the rows lost no data |

### 9.5 Pre-delete check

| # | Check | Result |
|---|---|---|
| **P-D1** | Delete flag set, and only it | **PASS** — secret names 8 → 9, one name added, none removed |
| **P-D2** | Flag change was a reload, not a deployment | **PASS** — all four functions version +1; every bundle hash, `updated_at` and `verify_jwt` unchanged |
| **P-D3** | Reaper source still byte-identical to `main` | **PASS — 3/3 MATCH** |
| **P-D4** | Target set unchanged | **PASS** — 28 / 15 live / 0 / 15 orphans / 260 bytes; fingerprint unchanged |
| **P-D5** | Snapshots taken | referenced objects `dc4c75460a285b899be44b07e67fbf0b4f78ffd0ebe9c6484df9d33caa4bdb98`; `collaboration_assets` rows `a910b6eee3c9c637ca93048b7896dd2facc33e3a5b5287c684163a07ef07f567` |

### 9.6 Delete run — the approved mutation

| # | Check | Expected | Result |
|---|---|---|---|
| **X-1** | Requests sent | 1 | **1** |
| **X-2** | HTTP status / mode | 200 / delete | **200 / delete** |
| **X-3** | Scanned / `scan.complete` | 28 / true | **28 / true** |
| **X-4** | Eligible / batch / remaining | 15 / 15 / 0 | **15 / 15 / 0** |
| **X-5** | Status tally | 13 deleted + 2 fixture rows | **15 `deleted`** — the 2 NoSuchKey rows were also removed from `storage.objects` |
| **X-6** | Batch fingerprint | validated target fingerprint | **MATCH** |
| **X-7** | Known bytes removed | 260 | **260** across the 13 real objects |
| **X-8** | Exactly one run, nothing else touched | — | **PASS** — one boot; 5 listings, 16 + 16 count reads, 1 + 1 pages, **15** `DELETE` calls (all 200), 15 `delete_many`, 15 `ObjectRemoved:Delete` lifecycle events; no other Storage write |

### 9.7 Post-delete validation

| # | Check | Expected | Result |
|---|---|---|---|
| **V-1** | `storage.objects` | 13 | **13** — all in `collaboration-assets`; 0 in other buckets |
| **V-2** | `collaboration_assets` | 15 / 15 live | **15 / 15 live** |
| **V-3** | `pending_asset_deletions` | 0 | **0** |
| **V-4** | Remaining orphans / bytes | 0 / 0 | **0 / 0** |
| **V-5** | Target paths remaining | 0 | **0 of 15** — per-path SHA-256 comparison |
| **V-6** | Referenced-object snapshot | unchanged | **identical** — `dc4c7546…bdb98` |
| **V-7** | `collaboration_assets` snapshot | unchanged | **identical** — `a910b6ee…f567` |
| **V-8** | No unexpected Storage change | — | **PASS** — 0 objects created or updated during the run |

### 9.8 Delete disablement and final safety state

| # | Check | Result |
|---|---|---|
| **S-D1** | Delete flag removed, and only it | **PASS** — secret names 9 → 8; `STAGERZ_MAINTENANCE_SECRET` still present; confirmed absent by name |
| **S-D2** | Reaper state | **ACTIVE, v4**, bundle `b0663090cefb06aad9d062d1d9c2cc30b6a14fee5a3cf7ce686842162c559397`, `updated_at` unchanged, `verify_jwt=false` |
| **S-D3** | Reload only | **PASS** — all four functions version +1; hashes and `updated_at` unchanged |
| **S-D4** | Source still byte-identical to `main` | **PASS — 3/3 MATCH** |
| **S-D5** | Final application state | **PASS** — 13 objects, 15 / 15 live assets, 0 queue, 0 orphans; both snapshots identical |
| **S-D6** | No further invocation | **PASS** — no function activity after the delete run; the only later Storage entry is internal platform tenant-configuration traffic |
| **S-D7** | Durable backup intact | **PASS** — 13 files / 260 bytes / manifest `7ad89c2a…e128` |

### 9.9 Platform and tooling observations

1. **Every project-secret change incremented all four function versions together**, with bundle hashes, `updated_at` and downloaded source unchanged. Treated as a platform-side secret reload, not a deployment. The reaper's v1 → v4 at phase close is entirely such reloads.
2. **`supabase db query` created or renewed the CLI-managed role `cli_login_postgres`** during one harmless `SELECT 1`. The role had zero sessions and a short expiry, was left unaltered as a documented tooling side effect, and **no application data changed**. Later work avoided the command, and the role's expiry was verified unchanged afterwards.
3. **The inbound function-request row was absent from `function_edge_logs` for both production invocations**, while the runtime and downstream gateway logs were complete. Treated as a logging gap, not a functional failure.

---

## 10. Unresolved concerns — explicitly out of scope

1. **S-4** remains OPEN.
2. **2 live `collaboration_assets` rows reference Storage objects that do not exist.** Pre-existing; the reaper never touches metadata and does not address this.
3. **New orphans can still be created** by the upload-then-insert failure path. Reclaiming them needs a future operator-initiated run under the same approvals; **no schedule exists**.
4. **The private backup is local only.** Its retention and eventual disposal are the operator's decision; it must never be committed.
