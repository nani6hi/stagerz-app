# Phase 21.8B — Validation Record

**Branch:** `phase-21.8b-s3-orphan-reaper`
**Base commit:** `03ece66`
**Validation level:** **1 + offline tests** — new Edge Function source; `index.html` is not touched
**Status:** **Implementation validated offline.** Not deployed, never invoked against any Supabase project.

---

## 1. What this record claims, and what it does not

**Claims:** the reaper's eligibility rules, guards and HTTP gating behave as specified in `phase-definition.md` §4–§5 **when driven by fake dependencies**; the entrypoint type-checks against the pinned `@supabase/supabase-js@2.112.1`; lint is clean; no existing tracked file changed.

**Does not claim** anything about behaviour against the real Storage API or PostgREST. The adapter in `index.ts` (listing semantics, folder detection by `id === null`, `count` behaviour, row caps) is **type-checked, not executed**. The first real exercise is the read-only dry-run in `phase-definition.md` §8 step 4, and its predicted output is a prediction.

> **Finding-status note.** Finding status lives in `analysis/phase-21.3/backend-contract.md` §0.2. **S-3 remains OPEN** — this phase implements, it does not remediate.

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

---

## 8. Mutation boundary confirmation

No deployment, invocation, secret or environment change, Storage removal, database write, policy change, workflow change or PR. **Nothing outside the repository was changed.**
