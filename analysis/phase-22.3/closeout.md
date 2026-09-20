# Phase 22.3 — Closeout

**Phase:** 22.3 — Production Designation and Reproducible Backend Baseline
**Status:** **COMPLETE / PASS**
**Closed:** 2026-09-20, by product-owner decision.
**Merged work:** PR #26 (merge `86ba828`, phase commit `775f048`) and PR #27 (merge `209bd3e`, phase commit `cb2bb12`). `main` = `origin/main` = `209bd3e7beedb2966c11503fd15f470ee17351bc`.
**Closeout branch:** `phase-22.3-closeout`, from `main` @ `209bd3e`. Documentation only.

---

## 1. Closure statement

**Phase 22.3 is COMPLETE / PASS.**

**PASS means** the stated phase objective was achieved: the production backend is formally
designated, and its application-owned database state is reconstructable from repository
artifacts and verified as equivalent to production.

**PASS does NOT mean:**

- that the Supabase **service runtimes** (Auth/API/Realtime, Edge Functions, Storage API) were
  proven in a clean-room rebuild;
- that the **current production epoch** has been smoke-tested;
- that production-readiness hardening is complete (custom SMTP, backups, CAPTCHA, synthetic-data
  cleanup and the 2 broken `collaboration_assets` rows all remain open, in their own rows in
  `.apos/PROJECT_CONTEXT.md`);
- that production migration history was reconciled with the repository baseline. It was not, and
  that remains a separate, metadata-only, owner-approved operation.

### What the phase achieved

| # | Achievement | Evidence |
|---|---|---|
| 1 | Production backend of record formally designated: `kbnmkyvbwkuvcklywdhk` | Phase 22.2 Option A; labels cleaned in PR #27 |
| 2 | Canonical repository baseline `supabase/migrations/20260919120000_stagerz_baseline.sql` (SHA-256 `8c292ef4…`; substantive SQL `cd2fcf93…`, byte-identical to the verified draft `7ae91fd1…`) | `baseline-verification-record.md` §1 |
| 3 | **Two deterministic clean rebuilds** from empty databases, exit 0 both times; the two runs byte-identical across all categories | `baseline-verification-record.md` §4 |
| 4 | **20/20 exact fingerprint categories match production**, on both runs, with no expected value weakened | `baseline-verification-record.md` §4; `supabase/verify/expected-production.json` |
| 5 | Storage **database** contract proven (bucket, both policies, RLS state, ownership) | `baseline-verification-record.md` §4 (F) |
| 6 | Edge Function source parity captured, 10/10 | `phase-definition.md` §5 criterion 4 |
| 7 | Auth, Storage and Realtime configuration captured, with **no secrets and no user data** | `supabase/config/environment-inventory.md` §6; `auth-owner-capture-checklist.md` |
| 8 | Hostname-based production environment selection implemented, unknown hosts fail closed; 5/5 offline tests, 2 deliberate mutations caught | `index.html`; `tests/environment-selection.test.ts`; `frontend-environment-mapping.md` |
| 9 | Production-designation label cleanup merged; historical records untouched | `production-label-inventory.md`; PR #27 |
| 10 | **Production never mutated.** The baseline was never executed against `kbnmkyvbwkuvcklywdhk`; its migration history is unchanged (43 rows, latest `20260917143322`) and does not contain `20260919120000` | `baseline-verification-record.md`; read-only queries only |

---

## 2. Deferred gates — carried forward, explicitly NOT passed

These four gates are **open**. They must not be described as passed, and closing Phase 22.3 does
not close them. They are the proposed scope of **Phase 22.5**.

### D — Auth / API / Realtime runtime

**Status: OPEN — production historically proven, current epoch unproven; clean-room unproven.**

- Proven in production: Phase 21.2 **N-1…N-3** (magic-link sign-in, session restore across F5 and
  Ctrl+F5, sign-out, `onAuthStateChange`), **N-5** (Realtime `postgres_changes` + presence + clean
  teardown, 1 of the 5 subscribed tables), production **P-5 / P-6** (real magic-link sign-in on
  `stagerz.app`, 2026-08-21), Phase 21.4 **8/8** authenticated read paths plus a write persisted
  across reload (2026-08-23), and the Phase 21.3 anon-read-200 / base-table-401 `42501` check at
  HTTP level.
- **The gap:** the newest app-runtime evidence is the Phase 21.7 smoke of **2026-09-12**. Since
  then the schema advanced through migrations `20260916215204` and `20260917143322` (which rebuilt
  `public_profiles` as a join, narrowed `users` UPDATE and revoked `follows` / `likes` writes), and
  `index.html` changed twice (Phase 21.9 error contract, Phase 22.3 environment selection).
  **Nothing validates the current combined epoch.** Every earlier privilege change was followed by
  its own smoke; that chain breaks on 2026-09-12.
- Clean-room: never run in any non-production environment.

### E — Edge Functions runtime

**Status: OPEN — 2 of 4 proven in production, 2 never exercised anywhere.**

| Function | Runtime evidence |
|---|---|
| `process-pending-asset-deletions` | **PROVEN** — manual run 2026-09-13 plus scheduled GitHub Actions runs on 2026-09-14 and 2026-09-15; the maintenance secret is proven. The *present-object* branch was never exercised, and no run is recorded after 2026-09-15 |
| `reap-orphaned-collaboration-assets` | **PROVEN** — dry-run and a real delete of 15 objects, 2026-09-13, with before/after fingerprints |
| `delete-account` | **NEVER EXECUTED.** It is deployed and maintained, but `index.html` contains **zero** `functions.invoke` / `functions/v1` / `delete-account` references, so **account deletion is unreachable in the current UI**. This is a product gap as well as a test gap, and may matter for data-deletion obligations before real users |
| `process-pending-deletions` | **NEVER EXECUTED** |

- Clean-room: never run locally (the CLI stack could not be started).

### G — Storage API runtime

**Status: OPEN for clean-room; production historically proven.**

- Proven in production: Phase 21.2 **N-4** (upload, byte-identical download verified by SHA-256,
  preview); Phase 21.8B (the delete path at API level, 15 objects). `storage.remove` from the
  application was never exercised, and the 2 missing objects were empirically diagnosed
  (`NoSuchKey` twice, 2026-09-13) but not remediated.
- **Clean-room BLOCKED:** `storage-api:v1.72.1` exits 139 (segfault) on this machine, reproducibly,
  on a freshly booted host with over 5 GB RAM free, and even when excluded from `supabase start`
  (the CLI still spawns it during schema initialisation). Postgres and Realtime containers exit
  cleanly, so the fault is specific to that vendor image. **Not a STAGERZ defect, and deliberately
  not worked around.**

### C3 — Full Auth-account fixture

**Status: OPEN — clean-room only.**

- The direct-Postgres image ships a **2021-era `auth.users` stub** that lacks `email_confirmed_at`
  and other GoTrue-managed columns, so `supabase/seed/fixtures.sql` could not insert Auth accounts.
  **This was reported as NOT TESTED and was not faked.**
- The scenario *was* validated database-side (C2 PASS): three accounts created through the **real**
  `on_auth_user_created` trigger produced the expected user rows, mappings and profiles, and the
  fixture file's own statements then produced the full collaboration scenario — executed inside a
  transaction and rolled back.
- Closing C3 needs a real GoTrue, that is, a working local stack or T2.

---

## 3. Netlify deployment-surface finding (new, 2026-09-20)

**Finding:** the public `stagerz.app` and `www.stagerz.app` surfaces serve the **current**
Phase 22.3 build, byte-identical to `origin/main` @ `209bd3e`. The **Netlify** surface does not:
both `aquamarine-puppy-beccd9.netlify.app` (274,832 bytes) and
`main--aquamarine-puppy-beccd9.netlify.app` (274,296 bytes) serve a **pre-Phase-22.3 build** with
no environment-selection block.

**Method:** read-only public HTTP GETs only, with a cache-buster query string and
`Cache-Control: no-cache`; the responses carried `Age: 0`, so this is **not a CDN cache artifact**.
Netlify read-only project metadata reports the current deploy as `ready`.

**Consequence:** the previously recorded assumption **"merging to `main` publishes to both"
no longer holds** and must not be relied on.

**Severity:** not an outage. The stale build carries the hard-coded production Supabase URL and
still functions. It does, however, mean two public surfaces are serving divergent builds, and the
stale one predates the fail-closed environment selection.

**Disposition:** **cause not established; not investigated further; deliberately NOT fixed and NOT
redeployed in this task.** Assigned to Phase 22.4.

---

## 4. Acceptance criteria — final outcome

Against `phase-definition.md` §5:

| # | Criterion | Outcome |
|---|---|---|
| 1 | Inventory of application-owned database state, platform state separated | **MET** |
| 2 | Baseline strategy decided by the owner | **MET** — B1 |
| 3 | Executable baseline passing the fingerprint gate on an empty non-production database | **MET** — 20/20, twice |
| 4 | Edge Function source and config reproducible from the repository | **MET** — parity 10/10 for source and config; *not* runtime, which is gate E |
| 5 | Storage and Realtime setup in the baseline | **MET** for the database contract; the Storage API runtime is gate G |
| 6 | Auth configuration captured, no secrets | **MET** |
| 7 | Production-designation cleanup applied to current code comments and docs | **MET** — PR #27; historical records untouched |
| 8 | Test-environment strategy decided | **MET as a strategy** — T1 first, T2 as the standing environment. **T1 proved only the database gate**; no environment was created, and T2 remains unapproved |
| 9 | No production mutation; no secrets or personal data in the repository | **MET** |
| 10 | `PROJECT_CONTEXT.md` updated at closeout | **MET** — this closeout |

---

## 5. Next Foundation phase

**Phase 22.4 — Current-Epoch Production Smoke & Deployment Surface Reconciliation.**
**DEFINED — NOT STARTED.** Deliberately **small**. It is **not** the D/E/G clean-room rebuild phase.

**Purpose:**

1. Smoke-test the **current** production epoch (`index.html` @ `209bd3e` against schema epoch
   `20260917143322`) — the highest-value open risk, because the last app-runtime evidence is
   2026-09-12 and both the schema and the frontend changed afterwards.
2. Verify the scheduled maintenance workflow `process-pending-asset-deletions.yml` is still
   healthy (no run recorded after 2026-09-15).
3. Investigate and reconcile the stale Netlify deployment surface (§3).
4. Decide the intended role of the Netlify surface.
5. Record the evidence before any clean-room runtime validation.

**Out of scope for 22.4:** gates D, E, G and C3 themselves; T2 creation; legacy-project pause or
delete; a Supabase Pro upgrade; migration-history reconciliation; project rename; SMTP, API-key or
CAPTCHA changes; synthetic-data cleanup.

**Then, proposed — Phase 22.5 — Runtime Rebuild & Test Environment Validation.** Potential scope:
a T2 cloud test environment; gate D clean-room Auth/API/Realtime; gate E all four Edge Functions;
gate G Storage API; gate C3 full Auth fixture; and the first controlled runtime exercise of
`delete-account` and `process-pending-deletions`.

**Explicitly NOT approved:** T2 creation, legacy-project pause or delete, and a Supabase Pro
upgrade. Note that on the Free plan a T2 slot is **coupled** to the legacy-project disposition
(2 active projects is the Free limit; paused projects do not count).

---

## 6. Docker / WSL disposition

Docker Desktop and WSL 2 remain installed and healthy; both test containers and both volumes were
removed (0 remaining) and the cached images were kept. **No unique evidence lives on that machine:**
the scratch workspace holds only logs, the two fingerprint JSON files and the extracted vendor
Storage migrations, and every artifact hash and result is recorded in
`baseline-verification-record.md`. They can therefore be removed without evidence loss, and
reinstalled later from `local-rebuild-plan.md`. Nothing was uninstalled in this phase.
