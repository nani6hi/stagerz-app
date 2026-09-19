# Phase 22.3 — Production Designation and Reproducible Backend Baseline

**Branch:** `phase-22.3-production-designation-reproducible-backend-baseline`, from `main` @ `7ae06c17be0b1341fd00db6195809107a0176e5e` (the PR #25 merge of Phase 22.2). A remote branch of the same name already existed at the same commit; nothing has been pushed.
**Assigned:** 2026-09-19 by the product owner, following Phase 22.2 (Option A approved).
**Production backend of record:** `kbnmkyvbwkuvcklywdhk`.
**Status:** **ACTIVE — BASELINE VERIFIED AND PROMOTED TO CANONICAL (2026-09-20); AUTH CAPTURE COMPLETE; RUNTIME VALIDATION (Auth/API/Realtime, Edge Functions, Storage API) STILL OPEN. No production mutation has occurred.** See §6 and `baseline-verification-record.md`.

---

## 1. Objective

Establish a production-grade, repository-backed and reproducible definition of the current STAGERZ backend. The production backend must be reconstructable in principle from repository artifacts and documented configuration, without depending on undocumented state that exists only inside Supabase.

## 2. Scope

**In scope:**
- read-only inventory of production (database, migration history, Edge Functions, Storage, Auth — what tooling can read);
- baseline strategy;
- a draft executable baseline;
- a verification/fingerprint gate;
- config and secret-name inventory;
- the owner Auth capture checklist;
- the production-label inventory;
- frontend environment-targeting design;
- test-environment strategy;
- the scope boundary.

**Later in this phase, each only with separate approval:**
- designation cleanup edits;
- recording the Auth capture;
- proving the baseline on a non-production environment;
- adopting B1.

**Out of scope:**
- custom SMTP, backups or plan upgrade;
- synthetic-data cleanup;
- the 2 missing Storage objects;
- CSP;
- UI and product work (frontend environment targeting was brought **into** scope by owner decision 4 on 2026-09-19);
- the legacy-project disposition.

## 3. Safety boundary (this step)

Not permitted:
- any Supabase mutation, project rename, Auth or SMTP change, API-key change, Storage change, or Edge Function deploy;
- creating a test project or branch;
- Netlify, DNS or workflow changes;
- production data changes;
- changing `index.html` runtime behaviour (first step; owner decision 4 then approved exactly the environment-selection change, with known production hosts unchanged);
- deleting synthetic data;
- commit or push.

**Read-only queries only.** No secrets, e-mails or user-identifying data are recorded.

## 4. Deliverables (this step)

| File | Content |
|---|---|
| `analysis/phase-22.3/baseline-inventory.md` | A (database), B (migration history), C (Edge Functions), D (Storage), with a generated object inventory |
| `analysis/phase-22.3/reproducibility-design.md` | Baseline strategy B1/B2/B3, repo structure, verification gate, frontend targeting, scope boundary, owner decisions |
| `analysis/phase-22.3/auth-owner-capture-checklist.md` | Owner dashboard capture of Auth configuration (no secrets, no user data) |
| `analysis/phase-22.3/production-label-inventory.md` | Stale test/production wording, classified F1–F4 |
| `analysis/phase-22.3/test-environment-options.md` | T1 / T2 / T3 evaluation |
| `supabase/migrations/20260919120000_stagerz_baseline.sql` | **Canonical baseline** (promoted 2026-09-20 from the verified DRAFT; substantive SQL byte-identical). Verified by two clean rebuilds, 20/20 fingerprint categories; never executed on production |
| `supabase/verify/fingerprint.sql`, `supabase/verify/expected-production.json` | Reproducibility gate and production fingerprint |
| `supabase/config/environment-inventory.md`, `supabase/seed/README.md`, `supabase/README.md` | Config and secrets-by-name inventory, seed strategy, rebuild runbook |

## 5. Acceptance criteria (for the whole phase)

1. An inventory of all application-owned database state, with platform-managed state separated. **Draft done.**
2. The baseline strategy decided by the owner.
3. An executable baseline that, applied to an empty non-production project, **passes the fingerprint gate** against `expected-production.json`.
4. Edge Function source and config (`verify_jwt`, secret names) reproducible from the repository. **Parity verified 10/10.**
5. Storage and Realtime setup in the baseline. **Draft done.**
6. Auth configuration captured by the owner and recorded, with no secrets.
7. Production-designation cleanup applied to current code comments and docs (historical records untouched).
8. A test-environment strategy decided. Creation of the environment happens only with owner cost confirmation.
9. No production mutation other than separately approved, metadata-only steps (for example recording the baseline as applied under B1); no secrets or personal data in the repository.
10. `PROJECT_CONTEXT.md` updated at closeout.

## 6. Owner decisions (2026-09-19) and implementation status

| # | Decision | Implementation status |
|---|---|---|
| 1 | **B1** canonical baseline + incremental migrations; history not the rebuild path (an optional archive may come later) | **DONE.** Verified by two clean rebuilds (20/20 fingerprint categories, byte-identical runs) and **promoted 2026-09-20** to `supabase/migrations/20260919120000_stagerz_baseline.sql` (substantive SQL byte-identical to the verified DRAFT `7ae91fd1…`). Convention in `supabase/MIGRATIONS.md`. Production history deliberately not reconciled |
| 2 | **T1** local stack first; no cloud project or branch | **PARTIAL.** Docker and WSL 2 installed by the owner. The full CLI stack is blocked by `storage-api:v1.72.1` exit 139, so the **database gate was completed by running the database image directly** (PASS). Auth/API/Realtime and Edge Function runtimes remain untested locally |
| 3 | Project rename **deferred** | Not renamed |
| 4 | Hostname-based frontend environment config **now**; unknown hosts fail closed | **IMPLEMENTED** in `index.html`. Mapping documented first (`frontend-environment-mapping.md`). 5/5 offline tests pass (`tests/environment-selection.test.ts`); 2 deliberate mutations are caught; a stubbed start-up run confirms the known production hosts are unchanged and that unknown or preview hosts create no client |
| 5 | Synthetic **showcase + test fixtures** | **Showcase PASS** (applied to the rebuilt database, idempotent). **Fixture scenario PASS** database-side via the real sign-up trigger. **Auth-account creation NOT RUNTIME-PROVEN** (needs GoTrue) |
| 6 | Owner Auth capture now; no Auth change | **COMPLETE** (2026-09-19, two submissions). All required values recorded in `supabase/config/environment-inventory.md` §6; no setting changed |
