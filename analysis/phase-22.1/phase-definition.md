# Phase 22.1 — Legacy Supabase Containment

**Branch:** `phase-22.1-legacy-supabase-containment`, created from `main` @ `eb3c64074f17f0713a9da4e8db47e233b4ae9d23` (the PR #23 merge of Phase 22.0; `main` = `origin/main`).
**Assigned:** 2026-09-19 by the product owner, as the follow-up recommended by Phase 22.0 (`analysis/phase-22.0/investigation-report.md` §8.5).
**Target:** Supabase project **`edxicnafggnnvcdvxemk`** ("stagerz-app") **only**.
**Status:** **COMPLETE / PASS (2026-09-19).** PASS means the approved legacy containment objective was achieved. It does **not** mean that `edxicnafggnnvcdvxemk` has been deleted, paused, archived or migrated; the later disposition decision remains separate.
- The pre-change checkpoint was committed and pushed (`b31bd26`).
- R-1 … R-4 were applied as one atomic execution (2026-09-19, 13:14:49–13:17:16 UTC). Validation Part A matched all expected values; Part B returned **PASS=66 / FAIL=0**.
- **N-1** (legacy JWT-based API keys disabled) and **N-2** (new sign-ups OFF; anonymous sign-ins OFF) were performed by the owner in the Supabase dashboard. N-1 is tool-verified (legacy `anon` `disabled: true`); N-2 is owner/dashboard-confirmed. The final read-only verification passed (`apply-validation-record-2026-09-19.md` §8.3).
- **Final status:** LG-1 REMEDIATED / CONTAINED IN DEPTH; LG-2 REMEDIATED for the scoped `postgres` TABLE/SEQUENCE defaults (platform-owned `supabase_admin` defaults documented as residual); LG-3 and LG-4 REMEDIATED; LG-5 ACCEPTED / DEFERRED; O-1 SKIPPED (optional hardening). Tester data remains stored; no current dependency exists; future Telegram integration remains a separate product decision and is not prohibited. `rollback.sql` was never run.

---

## 1. Objective

1. Establish an evidence-backed containment plan for the legacy project.
2. Make it **no longer publicly readable or writable** through the historical public client credential — and through any other client credential.
3. Remove unnecessary legacy privilege exposure.
4. Validate the containment.
5. Preserve enough evidence and data for a later owner decision: keep locked down, pause, private export then data deletion, or project deletion.

**Design principle:** public client keys are **not secrets**. Containment must hold at the database-authorization layer, so it does not depend on hiding, rotating or disabling a client key.

## 2. Product-history guard

STAGERZ began as a Telegram Mini App, and `edxicnafggnnvcdvxemk` belongs to that period. Telegram was removed from active development **for the time being**. This phase concerns the legacy project's exposure only. It is **not** a decision against future Telegram integration.

## 3. Findings targeted

| ID | Finding (from Phase 22.0) | Severity |
|---|---|---|
| **LG-1** | Publicly readable and writable through a still-valid anon key published in public git history | Medium |
| **LG-2** | `postgres` default privileges grant broad privileges to `anon`/`authenticated` | Low (latent) |
| **LG-3** | `TRUNCATE` granted to `anon`/`authenticated` | Low (latent) |
| **LG-4** | `rls_auto_enable()` executable by `anon`/`authenticated` (and `PUBLIC`) | Low |
| **LG-5** | Leaked-password protection disabled | Low |

## 4. Scope

**In scope:**
- `edxicnafggnnvcdvxemk` only;
- LG-1 … LG-5;
- read-only inspection needed to design the fix;
- draft remediation SQL, configuration actions, validation and rollback;
- documentation under `analysis/phase-22.1/`;
- `.apos/PROJECT_CONTEXT.md` updates appropriate to the phase.

**Out of scope:**
- `kbnmkyvbwkuvcklywdhk`;
- the live standalone app and `index.html`;
- Netlify;
- the production/test designation decision;
- the 2 `collaboration_assets` rows with missing Storage objects;
- feature work and future Telegram integration;
- deletion of tester rows or Auth users;
- deletion, pausing or archiving of the legacy project;
- migration to another project;
- rewriting git history.

## 5. Safety boundaries

**This step is PLAN / PRE-CHANGE REVIEW ONLY.** It is limited to read-only metadata, catalog and aggregate queries, plus read-only log aggregates. Not permitted in this step:
- revoking grants or altering RLS or policies;
- changing keys, JWT settings or Auth configuration;
- deleting rows or users;
- pausing or deleting the project;
- exporting personal data;
- touching Edge Functions or Storage;
- changing the app or Netlify;
- committing, pushing or opening a PR.

**Later steps:**
- Each needs separate, explicit owner approval.
- `remediation.sql` may run only after approval of the plan.
- `rollback.sql` may run only after its own approval.
- A key-disable action needs its own approval.

**Privacy:** analysis files record counts, catalog metadata, timestamps and fingerprints only. They contain no emails, user IDs, names, row content, tokens or keys.

## 6. Acceptance criteria

Phase 22.1 is complete when **all** of these hold:

1. The pre-change state is reconfirmed (C-1 … C-16, `remediation-plan.md` §2).
2. The owner has approved the containment plan, and has made a decision on each optional item (O-1 function defaults, N-1 legacy-key disable, N-2 sign-up setting). **Met 2026-09-19 (§8).**
3. The approved remediation is applied exactly as reviewed, in one guarded transaction whose pre-flight and post-flight both pass.
4. Validation V-1 … V-14 passes (`remediation-plan.md` §7), including the rolled-back behavioural tests. Validation never uses the historical client key (§8, decision 6).
5. Tester data, Auth users, Storage and Edge Functions are unchanged (V-7 … V-10).
6. The live STAGERZ app is unaffected (V-11).
7. LG-1 … LG-5 each carry a recorded end status: resolved, partly resolved with named residual, or accepted/deferred with a reason.
8. No secret or personal data was recorded, and no out-of-scope system was mutated.
9. `PROJECT_CONTEXT.md` records the outcome, and the later disposition decision (keep / pause / export+delete) is left open for the owner.

**Outcome (2026-09-19): criteria 1–9 all MET.** Evidence: `apply-validation-record-2026-09-19.md` §1–§4 and §8.3 (criteria 3–6), §9 (criterion 7), the privacy scans (criterion 8) and `PROJECT_CONTEXT.md` (criterion 9). One nuance on criterion 5: N-2 is owner/dashboard-confirmed rather than tool-verified, and the Auth counts are unchanged.

## 7. Non-goals

- No schema destruction: no table, column or legacy policy is dropped.
- No data or user deletion, and no export.
- No project pause or delete.
- No git history rewrite; the historical key stays in history, and the design makes that irrelevant.
- No change to `kbnmkyvbwkuvcklywdhk`, the live app or Netlify.
- No decision about Telegram as a product direction.

## 8. Owner decisions — 2026-09-19 (pre-change checkpoint)

| # | Item | Decision | Status |
|---|---|---|---|
| 1 | **R-1 … R-4** (core database containment, `remediation.sql`) | **APPROVED** | **APPLIED** 2026-09-19 and validated (66/0) |
| 2 | **O-1** (function default privileges) | **SKIPPED for now.** It is broader than the concrete findings and not needed to contain LG-1 … LG-4 | Optional residual hardening item; **not** a Phase 22.1 blocker |
| 3 | **N-1** (disable the legacy JWT API keys) | **APPROVED IN PRINCIPLE**, then **authorized** (2026-09-19) | **PERFORMED** by the owner in the dashboard; legacy `anon` key `disabled: true` (tool-verified) |
| 4 | **N-2** (disable new sign-ups) | **APPROVED IN PRINCIPLE**, then **authorized** (2026-09-19) | **PERFORMED** by the owner: sign-ups OFF, anonymous sign-ins OFF (owner/dashboard-confirmed; the prior value was not captured) |
| 5 | **LG-5** (leaked-password protection) | **ACCEPTED / DEFERRED — accepted risk, not remediated.** Reasons: the project is on Free and the feature needs a higher plan; the project is dormant; only tester accounts exist; containment plus N-1/N-2 materially reduce its relevance | Closed for Phase 22.1 as accepted risk |
| 6 | Optional HTTP test with the historical key (V-13b) | **NOT APPROVED.** The historical credential must not be exercised. Validation uses catalog, role and database checks, and rollback-only probes | Removed from the validation plan |
| 7 | Pre-change checkpoint: commit and push this plan before any Supabase change | **APPROVED** | Done: `b31bd26`, pushed |
| 8 | Apply R-1 … R-4, then validation Parts A and B | **APPROVED** (separate authorization, 2026-09-19) | **APPLIED and VALIDATED** (66/0). See `apply-validation-record-2026-09-19.md` |
