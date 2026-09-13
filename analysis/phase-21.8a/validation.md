# Phase 21.8A — Validation Record

**Branch:** `phase-21.8a-s8-deletion-drainer`
**Base commit:** `abefeb0`
**Validation level:** **1** — documentation and forensic source capture; `index.html` is not touched
**Status:** **Preparation validated. Nothing deployed, nothing scheduled, nothing invoked. No Supabase mutation.**

---

## 1. What this record claims, and what it does not

**Claims:** seven Edge Function source files have been captured into the repository from the currently deployed versions; a `.gitignore` has been added; the phase documentation records the S-8 root cause, the queue baseline, the scheduler decision and the first-activation procedure; and nothing outside the repository working tree was changed.

**Does not claim** that the captured files were verified by an independent automated byte-diff. See §3.2 for the exact method used and its limitation — this is the one place where the evidence is weaker than the usual standard in this project, and it is stated rather than glossed.

**Does not claim** that a scheduler exists. It does not. No workflow file, no secret, no schedule.

> **Finding-status note.** Security-finding status lives in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-12: **S-1, S-2, S-5, S-6, S-7 REMEDIATED**; **S-3 OPEN (reclassified this date from security to storage-lifecycle/cleanup)**; **S-4 OPEN**; **S-8 OPEN**.

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — no application source in the diff |
| **P-2** | No prior phase artifacts modified | **PASS** — `analysis/phase-20.*`, `21.1`–`21.7` untouched |
| **P-3** | No SQL migration file created | **PASS** — this phase contains no `.sql` |
| **P-4** | **No GitHub Actions workflow created** | **PASS** — `.github/` does not exist |
| **P-5** | **No secret value in any file** | **PASS** — see §4 |
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

### 3.2 Method used, and its limitation — read this

The deployed source was re-fetched from Supabase after the files were written, and each captured file was compared against the returned payload. **That comparison was performed by inspection, not by an automated byte-level diff**, because the deployed source arrives as a JSON payload through the MCP tool and cannot be piped to disk for `cmp`/`diff` without passing through the same transcription step being verified. Verifying a transcription against itself would prove nothing, so it was not claimed.

What *was* checked mechanically, and passed:

| Check | Result |
|---|---|
| Every file's first line declares its own canonical path | **7/7** |
| Environment-variable reference counts | `process-pending-asset-deletions/index.ts` **3**, `process-pending-deletions/index.ts` **3**, `delete-account/index.ts` **4** |
| `BATCH_SIZE = 25` and bucket literal present in the asset drainer | **1 each** |
| `delete-account` imports `../_shared/delete-auth-account.ts` | **present** |
| `_shared` vs `process-pending-deletions` copies of `delete-auth-account.ts` | **identical after line 1** |
| Byte delta between those two copies | **2626 − 2608 = 18**, exactly the path-length difference between `_shared` (7) and `process-pending-deletions` (25) in the header comment |
| The two `maintenance-auth.ts` copies | **identical after the header comment**, both **1456 bytes** — their two header differences (`asset-` in line 1 vs line 3) cancel exactly |

Those last two are meaningful integrity evidence rather than formatting trivia: an independent transcription error in either pair would almost certainly have broken the byte arithmetic or the post-header diff.

**How to close this gap properly.** `supabase functions download <slug>` writes the deployed source to disk, after which a true `diff` against the committed files is possible. That requires the Supabase CLI and project authentication, neither of which is set up here. **Recommendation: run that comparison before Phase 21.8B modifies `process-pending-asset-deletions`**, so the pre-modification baseline is machine-verified rather than inspection-verified.

### 3.3 Deployed versions and bundle hashes — recorded separately

| Function | Version | `ezbr_sha256` (bundle, **not** source) |
|---|---|---|
| `process-pending-asset-deletions` | 7 | `d3c3f1b5462a9ef6ee5f694f96f9332a99ff53a13fc69951cb15c67aa78baf81` |
| `process-pending-deletions` | 5 | `66f3c27a79be0d3578632941fcccf39e8ae0e054104aba7ce456045942716e9d` |
| `delete-account` | 4 | `79b2fa666bad70be1ba8907a25bc76d17dc3f08695f3bc2e003c537953710e74` |

**These are bundle hashes and are deliberately not equated with source hashes.** They cannot be reproduced by hashing the committed text; they serve only to identify which deployment the capture corresponds to, and to detect a redeploy.

---

## 4. Secret scan

Scanned every created and modified file for **values**, not names.

| Pattern | Result |
|---|---|
| JWT-shaped strings (`eyJ…`) | **none** |
| Service-role key value | **none** |
| `STAGERZ_MAINTENANCE_SECRET` **value** | **none** |
| Anon/publishable key value | **none** |
| `postgres://` / `postgresql://` connection strings | **none** |
| `.env` file contents | **none — no `.env` file exists** |

**Environment-variable names do appear**, and that is intended and safe: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET`, `SUPABASE_ANON_KEY`, `STAGERZ_ALLOWED_ORIGIN`. Every one is a `Deno.env.get("…")` lookup in the captured source — a reference, never a value. The functions are also written never to log the secret or any header value.

The project ref `kbnmkyvbwkuvcklywdhk` appears in documentation. It is not a secret: it is already committed in `index.html` and public in every deployed page.

---

## 5. Queue baseline — read-only

| Property | Row 1 | Row 2 |
|---|---|---|
| `requested_at` | 2026-07-20 | 2026-07-21 |
| `attempt_count` | 0 | 0 |
| `last_attempted_at` | NULL | NULL |
| Metadata row present and soft-deleted | yes | yes |
| Storage object present | **no** | **no** |
| Structurally valid | yes | yes |

Recorded without file names, storage paths or user identifiers.

Supporting counts, unchanged by this phase: `collaboration_assets` 17 (15 live, 2 soft-deleted), `storage.objects` in `collaboration-assets` 28, orphan objects 15 totalling 260 bytes.

---

## 6. Gates for the steps that follow — ALL PENDING

Recorded now so the ordering cannot be lost.

| # | Gate | Status |
|---|---|---|
| **G-1** | Checkpoint committed, pushed and reviewed | **PENDING** |
| **G-2** | `STAGERZ_MAINTENANCE_SECRET` configured as a GitHub repository secret — **manual user action** | **PENDING** |
| **G-3** | Explicit approval for a single manual invocation | **PENDING — NOT GIVEN** |
| **G-4** | First invocation produces exactly the predicted end state: queue 2 → 0, `collaboration_assets` 17 → 15, `storage.objects` 28 unchanged, both results `already_deleted` | **PENDING** |
| **G-5** | Workflow added with `workflow_dispatch` **only**, then run successfully | **PENDING** |
| **G-6** | Only after G-5: add the `schedule:` trigger | **PENDING** |
| **G-7** | Machine-verified source diff via Supabase CLI before 21.8B modifies the function | **PENDING** |

**G-4 detail — `already_deleted` is the expected status for both rows.** A result of `deleted` would mean a Storage object existed that this analysis concluded was absent, and must stop the phase for re-investigation.

---

## 7. Unresolved concerns

1. **Source fidelity is inspection-verified, not machine-verified** (§3.2). G-7 closes it.
2. **The floating `@supabase/supabase-js@2` import** in all three functions means a redeploy may silently change the SDK version. Deliberately not fixed here; belongs to 21.8B.
3. **`maintenance-auth.ts` is duplicated** across two functions and must be kept in sync by hand — the deployed code says so itself. Captured as-is.
4. **S-3 remains OPEN**, reclassified 2026-09-12 as a storage-lifecycle/cleanup finding rather than a security finding, on the evidence that the missing DELETE policy is fail-closed and documented as deliberate in Phase 20.7. The original finding text and evidence are preserved unchanged.
5. **S-4 remains OPEN** and is untouched.
6. **Repository CI is still none.** No workflow exists at the end of this phase, by design.

---

## 8. Summary

Seven Edge Function source files are now captured in the repository, hashed, and checked against the deployed source by the strongest method available in this environment — with the method's limitation stated plainly and a concrete way to close it before any modification.

**Eight repository-safety checks pass.** No workflow, no secret, no deployment, no invocation, no database change. `index.html` and all prior phase artifacts are untouched.

**Level 1 is satisfied for the preparation step.** Everything that touches production is gated behind G-1 to G-7, and G-3 — approval for the single first invocation — has not been given.
