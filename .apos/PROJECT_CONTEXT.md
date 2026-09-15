# Project Context

Confirmed stable facts only. Anything not established is marked **unknown** rather than inferred.

---

## Identity

| Field | Value |
|---|---|
| Project name | STAGERZ |
| Process | APOS |
| Role of this project | STAGERZ is the APOS reference implementation |
| Current APOS phase of record | Phase 21.3 — Capture the Backend Contract in the Repository |
| Current phase status | **PAUSED for the Phase 21.5–21.8 security and reliability detours — 21.5, 21.6 and 21.7 merged (PRs #13, #14, #15); 21.8A complete, S-8 remediated (PRs #16, #17). Step 1 complete; extraction still in progress.** Phase 21.3's Step 1 discovered finding **S-1** (unauthenticated write path to `public.users` via the `public_profiles` view). The phase was **paused**, S-1 was remediated separately as **Phase 21.4 / PR #11** (merge `968b501`, now on `main` at `f4d1fa7`), and the paused Phase 21.3 artefacts — lost from volatile scratch storage — were **recovered hash-verified** from Claude file-history plus a deterministic re-run of the original generators (all 10 artefacts matched their recorded SHA-256). It then paused a second time for **Phase 21.5**, which remediated **S-2** (PR #13), and a third time for **Phase 21.6**, which remediated the root cause **S-5**. **Findings, live-verified 2026-09-12: S-1 REMEDIATED (21.4); S-2 REMEDIATED (21.5); S-5 REMEDIATED (21.6); S-6 and S-7 REMEDIATED (21.7); S-3, S-4 and S-8 remain OPEN** — **S-3 reclassified 2026-09-12** from a security finding to a **storage-lifecycle / cleanup** finding: `storage.objects` still has no DELETE policy, but the absence is **fail-closed and documented as deliberate** in Phase 20.7 (*"no DELETE policy by design"*), so the defect is that orphaned objects are never reclaimed, not that anything is exposed; **S-4** — **55** of 58 backend SQLSTATEs unhandled (corrected from 54 — `23505` is constraint-raised, not one of the 58); **S-8 (new, 2026-09-12)** — the pending asset-deletion pipeline has **no active automatic drainer**, a **reliability / data-lifecycle** defect of **MEDIUM** severity, not a security vulnerability: user-requested asset deletions are soft-deleted and enqueued, the UI reports success, and the Storage file is never removed because nothing invokes `process-pending-asset-deletions`. **S-5, the root cause of S-1 and S-2, is closed for future objects**: the `postgres` default privileges in `public` and `storage` no longer grant anything to `anon` or `authenticated`. **S-6 and S-7, the two residues that survived it, are now closed for existing objects**: `public.users` grants table-level privileges to `postgres`/`service_role` only, and the three `log_collaboration_*_activity` trigger functions are executable only by `postgres`/`service_role`. Latent twins remain outside this project's control — the `supabase_admin`/`public` TABLES default, the platform `storage` MAINTAIN grants, and three `storage` SECURITY INVOKER trigger functions. **Update 2026-09-13: S-3 REMEDIATED by Phase 21.8B** — see the Phase 21.8B status row; the S-3 clause above is its 2026-09-12 state. **Update 2026-09-15: S-8 REMEDIATED by Phase 21.8A / PRs #16 and #17** — see the Phase 21.8A status row; the S-8 clause above is its 2026-09-12 state. Contract detail below is the historical Step 1 record, with post-21.4 and post-21.5 state marked separately |
| Phase 21.8B status | **COMPLETE IN PRODUCTION — S-3 REMEDIATED. Operated and validated 2026-09-13 (UTC).** Implementation merged as **PR #18** (merge `4bdb426028e68f58e2b67480a38a74d0c35fa89f`): a new, separate Edge Function **`reap-orphaned-collaboration-assets`** — service role, maintenance-secret gated, **dry-run by default**, deletes only objects in `collaboration-assets` referenced by no live or soft-deleted `collaboration_assets` row and not queued, **48 h** grace, batch ≤ **25**, per-object re-check before removal, and delete mode needs both the confirmation token and the separately set `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` flag. **No client DELETE capability and no policy, schema or application change.** Deployed with `verify_jwt=false`, source byte-identical to `main`. One fingerprint-matched **dry-run**; a **private local backup** of the 13 stored objects (260 bytes, manifest-verified, never committed); the other 2 orphan rows proven to have **no stored file** (`NoSuchKey`); **one delete run** removed all 15: `storage.objects` 28 → **13**, orphans 15 → **0**, referenced objects and all 15 `collaboration_assets` rows fingerprint-identical. **Delete flag removed afterwards**; reaper ACTIVE **v4**, bundle `b0663090…9397` unchanged — versions v2–v4 are platform-side secret reloads, not deployments. No schedule exists. Out of scope: S-4; 2 live rows whose Storage objects are missing. Output: `analysis/phase-21.8b/` |
| Phase 21.8A status | **COMPLETE IN PRODUCTION — S-8 REMEDIATED (PRs #16 and #17), closed 2026-09-15.** **PR #16** (merge `026bace`) captured the deployed Edge Function source (`3fb81ae`) and added a manual-only workflow (`23c05b2`). Manual production drain validated 2026-09-13 (run #5, after runs #1–#4 failed with HTTP 401 before the maintenance secret was applied): queue 2 → 0, `collaboration_assets` 17 → 15, Storage unchanged because both objects were already absent. **PR #17** (head `fd018b8`, merge `03ece66`) added a daily schedule (`17 3 * * *`) as a separate approved change, keeping `workflow_dispatch` for recovery. Workflow **active**; scheduled runs **#6 (2026-09-14) and #7 (2026-09-15) succeeded**. Queue empty, no failed attempts, no soft-deleted asset left (read-only, 2026-09-15). **G-1 to G-7 all PASS.** Non-blocking follow-ups (25/day cap, no attempt cap, partial-failure handling, unpinned `@supabase/supabase-js@2`, possible schedule auto-disable in an inactive public repository) are in `analysis/phase-21.8a/validation.md` §10.7. *HISTORICAL preparation-time record, 2026-09-12/13, follows:* Branch `phase-21.8a-s8-deletion-drainer` from `main` @ `abefeb0`. Addresses **S-8** (pending asset-deletion pipeline has no active automatic drainer) — **reliability / data-lifecycle, MEDIUM**, not a security vulnerability. Root cause: `delete_collaboration_asset` soft-deletes the metadata row and enqueues to `pending_asset_deletions`, and the privileged `process-pending-asset-deletions` Edge Function is the only thing that can complete the Storage deletion — but **nothing invokes it**. No `pg_cron`, no `pg_net`, no database webhooks, no CI, and no `functions.invoke` anywhere in the frontend. Queue baseline (read-only): **2 rows, both `attempt_count = 0`, both `last_attempted_at` NULL, requested 2026-07-20/21**; both Storage objects already absent; both `collaboration_assets` rows soft-deleted. This phase **captures the deployed Edge Function source into version control for the first time** (7 files under `supabase/functions/`, fidelity-checked against the deployed source) and adds a `.gitignore`. Source capture committed as `3fb81ae`, pushed, **PR #16 open, not merged**. **A manual-only workflow (`.github/workflows/process-pending-asset-deletions.yml`, `workflow_dispatch` trigger only) is prepared but not yet committed and has never run.** **No schedule, no GitHub secret, no Edge Function change, no database change, no invocation, no Supabase mutation.** The first dispatch requires explicit approval and is predicted to drain the queue 2 → 0 and `collaboration_assets` 17 → 15, leaving `storage.objects` at 28, orphans at 15 and live assets at 15. The scheduler decision is GitHub Actions — chosen because the schedule becomes a diffable file in the repository rather than hidden service state, and because it needs no new database extensions and keeps the maintenance secret out of the database. **Supabase Pro is NOT required**; Free covers this entirely. Level 1; `index.html` untouched. Output: `analysis/phase-21.8a/` |
| Phase 21.7 status | **COMPLETE IN PRODUCTION — S-6 and S-7 REMEDIATED. Applied 2026-09-11 (UTC), validation closed 2026-09-12. Merged to `main` as PR #15 (merge commit `abefeb0b7e38d306a67bbfe61163c03416102f8e`).** Removed the two residues found during the Phase 21.6 analysis: **S-6** (`anon`/`authenticated` held `MAINTAIN` on `public.users`) and **S-7** (three `log_collaboration_*_activity` trigger functions executable by `PUBLIC`, and explicitly by `authenticated`). Root cause of S-6 traced exactly: five enumerated revokes across four migrations on 2026-07-12, written against the pre-PostgreSQL-17 set of seven privileges — the arithmetic leaves precisely `m`, and no migration mentions `MAINTAIN` anywhere. S-7 came from PostgreSQL's built-in `EXECUTE`-to-`PUBLIC` default, not from S-5. Both were very low / low severity: `MAINTAIN` grants no row access and no HTTP verb reaches a maintenance command, and a direct call to a trigger function raises `0A000` before its body runs. **Exactly 7 statements** executed in a single atomic call as `postgres`, zero SQL errors — 1 `REVOKE MAINTAIN`, 6 `REVOKE EXECUTE`. The `authenticated` revoke was **approved scope expansion** beyond S-7's original PUBLIC-only wording, so the three functions now match the `postgres`/`service_role`-only posture of `handle_new_auth_user()`. Post-state: `public.users` table ACL is `postgres`+`service_role` only while **all seven column grants, RLS, both policies and zero triggers are byte-identical**; the three functions are `PUBLIC`=false, `anon`=false, `authenticated`=false with bodies and trigger definitions unchanged. Blast radius proven by fingerprint substitution — among 18 public relations only `users` changed, among 34 functions only the three; storage, column and policy fingerprints unchanged. Advisor **35 → 29 findings**, `anon_security_definer_function_executable` **3 → 0**, `authenticated_security_definer_function_executable` **28 → 25**, zero new findings. Pre-flight **21/21 PASS**, post-change **16/16 PASS**, smoke **A/B/C all PASS** (profile save; anonymous `public_profiles` read HTTP 200; real collaboration message sent, displayed and deleted with no error — the end-to-end proof that trigger firing does not require caller EXECUTE). S-1/S-2/S-5 verified still remediated. Level 1; `index.html` untouched. Output: `analysis/phase-21.7/` |
| Phase 21.6 status | **COMPLETE IN PRODUCTION — S-5 REMEDIATED. Mutation applied 2026-09-11, validation closed 2026-09-12. Merged to `main` in PR #14 (`452b12b`).** Removed `anon` and `authenticated` from exactly four `postgres` default-privilege entries — TABLES and SEQUENCES in `public` and `storage` — keeping `postgres` and `service_role`. The defaults were a Supabase bootstrap default, schema-scoped (no global entry), absent from all 41 migrations, and the root cause of S-1 and S-2. Live exposure was already zero — every existing relation had been narrowed by hand — so the fix removes recurrence risk rather than a live hole. Pre-mutation checkpoint `c06c675` was committed and pushed first; **pre-flight 14/14 PASS**; four `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA … REVOKE ALL …` statements executed in one call, as `postgres`. Post-state: exactly those four entries changed, count still 24, no global entry, the other 20 fingerprint-identical; **every existing permission byte-identical** — 77 relations and functions across `public` and `storage`, plus every column-level grant (`users` 6, `profiles` 9, `notifications` `read` only, `wanted_posts` 7, all matching the pre-21.6 Phase 21.3 baseline); Advisor unchanged at 35 findings; anon `public_profiles` read still 200. **Post-change 15/15 PASS.** M-15 needed a test-design correction first: its original wording named a Like action the app does not implement (`likes`/`follows` have no UI write path and 0 rows — a pre-existing product gap, not a regression), so it was replaced with **Profile → Edit Profile → Save with no values changed**, which exercises column-level UPDATE grants, own-row RLS and the SECURITY DEFINER helper on existing objects. User-confirmed on production: save succeeded, no error. Deliberately out of scope: FUNCTIONS defaults, `supabase_admin` defaults, and the two residues found during analysis — **S-6** (`MAINTAIN` on `public.users`) and **S-7** (three `PUBLIC`-executable trigger functions) — **both remain OPEN, deferred to Phase 21.7**. Level 1; `index.html` untouched. Output: `analysis/phase-21.6/` |
| Phase 21.5 status | **COMPLETE — S-2 REMEDIATED. Merged to `main` in PR #13 (`168d068`).** Dropped `public._test_results` and `public._test_run_log` on **2026-09-08** under explicit approval. Both were abandoned test-harness tables: created outside all 41 migrations, written once each on the project's creation day, RLS disabled with 0 policies while `anon` and `authenticated` held all seven privileges **including TRUNCATE** — grants applied automatically by S-5, never deliberately. **Zero dependencies of every class and zero `index.html` references**, verified live twice. The 28 rows — a structured 24-case backend behaviour suite with real documentary value — were preserved in `analysis/phase-21.5/pre-drop-snapshot.sql`, **committed (`d5417e9`) and pushed to `origin` before the mutation ran**, deliberately avoiding the single-failure-domain mistake that lost the Phase 21.3 artefacts. All **17 pre-flight requirements matched exactly**; exactly two bare `DROP TABLE` statements executed (no `CASCADE`, no `IF EXISTS` — their success is itself proof nothing depended on them). Post-state: `public` tables **19 → 17**, both owned sequences gone, relation list lost exactly those four objects, views/functions/policies/triggers/default-ACLs/migration-records all unchanged. Advisor **ERROR findings 3 → 1**; the `rls_disabled_in_public` lint no longer appears; **zero new findings**. As `anon`, both REST endpoints now return **HTTP 404 `PGRST205`** while `public_profiles` still returns 200. Production smoke passed at both levels — server-side automated, and manually confirmed in a browser afterwards (Stage loads, navigation visible, a profile opens, no visible errors); the browser half was held open as NOT RUN until actually observed rather than inferred. Level 1; `index.html` untouched. Output: `analysis/phase-21.5/` |
| Phase 21.3 Step 1 record | **Step 1 — client-side audit COMPLETE; live access CONFIRMED; detailed snapshot awaiting delivery.** Addresses Phase 20.7 item **C-3**. The client side of the contract is captured exhaustively from `index.html` at `ebfe536`: **14 relations, 20 RPCs, 7 direct REST writes, 1 Storage bucket, 4 SQLSTATEs, 5 realtime tables, 4 auth entry points**. Live read-only access to `kbnmkyvbwkuvcklywdhk` is confirmed and **no writes were performed**: 19 tables, 1 view, 34 functions, 27 RLS policies, 2 storage policies, 3 public triggers, 1 auth trigger, 5 realtime tables. Backend is wider than the client needs (20 relations vs 14 referenced; 34 functions vs 20 called) -- **no deficit found**. Signup trigger identified (`on_auth_user_created` -> `handle_new_auth_user()`); realtime publication matches the frontend exactly (**R-9 PASS**); `public_profiles` confirmed sourced from `public.users`, **not** `profiles.display_name`. **Finding: the `collaboration-assets` bucket has no size or MIME limit, and neither does the frontend -- uploads are unbounded at every layer** (pre-existing; out of scope to fix here). Per-object detail is being extracted externally and will be transcribed verbatim; nothing fabricated. Level 1; documentation only, `index.html` untouched. Output: `analysis/phase-21.3/`. Not committed, not pushed |
| Phase 21.2 status | **COMPLETE — merged and production-validated; no open defects.** Merged to `main` in **PR #9** as merge commit **`968b501`** (phase commit `5a8d253`; `index.html` +138 / −17, including the approved **D-1 fix**). **Level 3 satisfied pre-merge and post-merge: 57/57 static invariants, 42/42 headless guard assertions, 48/48 in-browser harness assertions, 12/12 browser tests (Edge 151), 7/7 authenticated regressions against a real magic-link session, and 7/7 production checks on `stagerz.app` (5/5 applicable on the Netlify surface).** Risk R1 closed for 11 of the 12 `supabaseClient` call sites. Remaining gaps, none blocking: `storage.remove` (4836) uncovered, F2/F9/F10 reduced-not-closed per Q-4, and Q-5 unanswered. Output: `analysis/phase-21.2/{phase-definition,validation}.md`, `static-check.sh`, `startup-failure-harness.html` |

---

## APOS Phases

| # | Phase |
|---|---|
| 0 | Project Initialization |
| 1 | Requirements Analysis |
| 2 | Architecture Review |
| 3 | ADR |
| 4 | Technical Specification |
| 5 | Implementation Plan |
| 6 | Task Specification |
| 7 | Implementation |
| 8 | Documentation Update |
| 9 | Review Support |
| 10 | Release Preparation |
| 11 | Maintenance |

---

## Application

| Field | Value |
|---|---|
| Main application file | `index.html` |
| Architecture | Single-page application, contained primarily in `index.html` |

---

## Repository and Deployment

| Field | Value |
|---|---|
| Repository remote | https://github.com/nani6hi/stagerz-app.git |
| Deployment | **Two production surfaces, both serving `main`** — corrected by direct observation during Phase 21.2, see below |
| Production surface 1 | `https://stagerz.app` (`CNAME`) via **GitHub Pages** — responds `Server: GitHub.com`. The intended production domain |
| Production surface 2 | `https://aquamarine-puppy-beccd9.netlify.app` via **Netlify** — responds `Server: Netlify`. Observed serving `main` both before and after the Phase 21.2 merge, byte-identical to the primary surface each time. **Merging to `main` publishes to both.** There is no `netlify.toml` in the repository; Netlify is configured outside it |
| Repo-defined CI | **On `main`: one workflow** — `.github/workflows/process-pending-asset-deletions.yml` (Phase 21.8A, S-8 drainer; PRs #16 and #17). Triggers: **daily `schedule` (`17 3 * * *`, GitHub best-effort timing)** and **`workflow_dispatch`** for manual recovery; no `push` or `pull_request` trigger, so it adds no PR checks. `permissions: {}`, no checkout, no inputs, no in-run retries. Uses the repository secret `STAGERZ_MAINTENANCE_SECRET` (configured and aligned — proven by successful authenticated runs) and fails before any request if it is missing. Workflow **active**; scheduled runs on 2026-09-14 and 2026-09-15 succeeded. The only PR checks remain Netlify's |
| Pull-request previews | **Netlify PR deploy previews exist.** PR #9 had one at `https://deploy-preview-9--aquamarine-puppy-beccd9.netlify.app`, reported via the commit status `netlify/aquamarine-puppy-beccd9/deploy-preview` plus three Netlify check runs. Preview-equivalents of P-1…P-4 were run against it before merge. **This supersedes the earlier record that no per-PR preview environment exists.** Note the limit: a magic link always returns to `https://stagerz.app` ([`index.html:1329`](../index.html#L1329)), so authenticated flows still cannot be completed natively on a preview or on the Netlify surface |
| Production branch | `main` |
| Current development branch | `phase-21.3-backend-contract` — originally branched from `main` at `ebfe536`; fast-forwarded to `main` at `f4d1fa7` after PR #11 merged |
| Previous development branches | `phase-21.2-startup-resilience` — merged in PR #9 (`968b501`), **retained**; `phase-21.2-docs-followup` — merged in PR #10 (`ebfe536`); `phase-21.4-s1-anon-write-exposure` — merged in PR #11 (`f4d1fa7`) |

**Not established about surface 2, and deliberately not assumed:** whether it is intended to be user-facing, who owns its configuration, and whether it answers on any other domain. Verified only through public HTTP responses and read-only GitHub API calls; no Netlify configuration was inspected further or changed.

---

## Roles and Authority

| Actor | Responsibility |
|---|---|
| **ChatGPT** | Architecture, governance, reviews, implementation approval |
| **Claude Code** | Analysis and approved implementation |
| **User** | Final authority for source changes and commits |

---

## Directory Conventions

| Path | Contents |
|---|---|
| `analysis/<phase>/` | Analysis results |
| `.apos/` | Governance rules |

---

## Product Roadmap Decisions

Permanent product decisions. These constrain scope regardless of what the code currently contains.

### NACKL is excluded from the current full web app

**Decision:** NACKL does not belong in the current full STAGERZ web application.

NACKL was intended for a later, reduced **Light version**, after the real full app/web version is established. The NACKL implementation currently present in `index.html` is **premature** and creates unnecessary runtime errors, state, and maintenance burden inside the main app.

Consequences:

- Do **not** repair `nacklVal` as a standalone cosmetic fix.
- Do **not** expand NACKL.
- Do **not** integrate NACKL further into Profile or any other module.
- Complete removal of NACKL from the current full web app is scheduled as **Phase 20.4**.
- The NACKL product idea is **preserved as a deferred concept for a future Light version**.

**Removal from the full app does not mean deletion of the product idea.** It means the idea returns in the Light version, on purpose, rather than persisting here by accident.

### Telegram runtime integration is excluded from the current full web app

**Decision:** Telegram Mini App / Telegram-specific runtime integration does not belong in the current full STAGERZ web application.

Like NACKL, it is preserved as a concept for a future STAGERZ Light / Mini App version. Removal from the full app does **not** mean deletion of the product idea.

**Product-owner decision recorded 2026-07-28 (resolves the Phase 20.6 prerequisite gate):**

> STAGERZ is currently being developed as an **independent web application**. The current product must be built, tested, and completed **without any Telegram dependency or Telegram-specific runtime behavior**. A separate Telegram light version may be developed later, **only after** the main web application is technically complete, stable, and user-friendly. The existing Telegram Mini App configuration is **not part of the currently supported product scope and must not block this removal**.

Scope boundary: Phase 20.6 removes the Telegram runtime **from this repository only**. External BotFather / Telegram Mini App configuration is deliberately **not** inspected or modified by this phase.

Telegram removal is deliberately **not** bundled with NACKL removal. NACKL is fully repository-provable and isolated; Telegram's true impact depends on whether an external Mini App entry point exists — configuration outside this repository — and `haptic()` has 28 call sites. The sequence below separates the two so a zero-risk cleanup is not blocked behind an unverifiable one.

**Call-site count of record: 28.** Pre-20.5 documentation recorded `haptic(` as occurring 29 times (1 definition + 28 calls). Phase 20.5 added three explanatory comment mentions, so the current raw count in `index.html` is **32** = 28 call sites + 1 function definition + 3 comment mentions. The number of **executable call sites is unchanged at 28**.

### Locked removal sequence

| Phase | Title | Scope |
|---|---|---|
| **20.4** | **Remove Premature NACKL Integration** | **Completed** — merged in Pull Request #4 (`31dc073af588d1664d0991b98e6b0995d5174660`). All NACKL UI, CSS, and JavaScript removed; misleading NACKL feature claim removed; `nacklVal is not defined` ReferenceError eliminated |
| **20.5** | **Evaluate and Isolate Telegram Runtime** | **Completed** — merged in Pull Request #5 (`155b029cdfcd752104849f1d52f84c0aa645ce61`). Every Telegram runtime reference collapsed into one contiguous, marker-delimited compatibility block (`index.html` 962–1001); `tg` renamed to `telegramWebApp`; single detection point; `haptic()` given a documented platform-agnostic contract. No behavior change, no call site changed |
| **20.6** | **Remove Telegram Runtime from Full Web App** | **Completed** — merged in Pull Request #6 (`275caf3944f1194434ca4924272731c03111bbd1`). Complete Telegram runtime removal, including all 28 `haptic(...)` call sites: the Telegram SDK script tag (line 8), the compatibility block (962–1001) with `window.Telegram`, `telegramWebApp`, `ready()`, `expand()`, `HapticFeedback`, and the `haptic()` function, plus every `haptic(...)` call site and all Telegram-specific comments. Deletion only — no substitute (no `navigator.vibrate`, no sound, no animation). Authentication, sessions, identity, navigation, messaging, and all collaboration workflows preserved unchanged |

### Final intended full-app architecture

On completion of Phase 20.6, the current full STAGERZ web application will have:

- no NACKL runtime;
- no Telegram SDK;
- no Telegram initialization;
- no Telegram haptics;
- normal browser runtime only;
- Supabase-only authentication and session management.

NACKL and Telegram are preserved **only as future Light-version concepts**. The full web app must remain fully functional using normal browser and Supabase behavior alone.

**Achieved and merged to `main` (Pull Request #6, `275caf3`).** `index.html` on `main` contains **zero** occurrences of `telegram`, `window.Telegram`, `telegramWebApp`, `HapticFeedback`, `ready()`/`expand()` Telegram initialization, and `haptic` in any form — re-verified during Phase 20.7 (`grep -c -i "telegram\|haptic" index.html` → `0`). `index.html` is the only file in the repository containing executable code, so **the main web app is Telegram-independent.** Details in `analysis/phase-20.6/phase-definition.md` §14.

### Guardrail — a future Telegram Light version must not reintroduce coupling

**Any future Telegram light version must be implemented separately and must not silently reintroduce runtime coupling into the main web application.**

Binding rules:

1. **Separate delivery artifact** — its own entry point, build target, or repository. **Not** a conditional branch inside the main app's `index.html`.
2. **No conditional platform code in the main app** — no `if (window.Telegram)`, no platform sniffing, no "harmless" SDK script tag, no `haptic()`-style wrapper kept "just in case". A guard that is inert today is still coupling.
3. **No shared mutable runtime** — reusing Supabase schema and API contracts is fine; requiring the main app to carry Telegram-aware code is not.
4. **Sequencing is fixed** — Light-version work begins only after the main web application is technically complete, stable, and user-friendly.
5. **Explicit governance** — reintroducing any Telegram runtime into the main app requires a new APOS phase and a recorded reversal of this roadmap decision. It may not arrive as an incidental part of unrelated work.

Phases 20.4, 20.5, and 20.6 exist because Telegram and NACKL runtime code accumulated inside the main app without a boundary. The removed implementation is preserved in git history at `155b029cdfcd752104849f1d52f84c0aa645ce61` and documented in `analysis/phase-20.5/phase-definition.md`, so the Light version can recover it deliberately from a clean base.

### Phase history

| Phase | Title | Status |
|---|---|---|
| 20.1 | Optimistic Message Sending | Merged to `main` (PR #1) |
| 20.2 | Messaging Hardening | Merged to `main` (PR #2) |
| 20.3 | Message Load Failure Visibility | Merged to `main` (PR #3) |
| 20.4 | Remove Premature NACKL Integration | Merged to `main` (PR #4) |
| 20.5 | Evaluate and Isolate Telegram Runtime | Merged to `main` (PR #5) |
| 20.6 | Remove Telegram Runtime from Full Web App | Merged to `main` (PR #6, `275caf3`) — 69 lines deleted + 1 in-place edit in `index.html`; SDK script, compatibility block, and all 28 `haptic(...)` call sites removed. Deployed to production per product-owner report. *No post-deployment authenticated-validation record exists under `analysis/phase-20.6/`; the outcome is reported, not documented in this repository.* |
| 20.7 | Codebase Assessment & Roadmap | Merged to `main` (PR #7, `6789493`) — analysis only; no application code changed. Full assessment at `analysis/phase-20.7/codebase-assessment.md` |
| 21.1 | Complete Output Escaping | Merged to `main` (PR #8, `780d6f9`) — 18 HTML-text sinks escaped, 4 `photo_url` CSS-`url()` sinks removed from markup, 2 helpers added. Level 3 validated: 33/33 static invariants, 38/38 adversarial harness, B1–B11 + B13 PASS, B12 N/A, B14 PASS. `analysis/phase-21.1/` |
| 21.4 | S-1: Close the Unauthenticated Write Path to `public.users` | **Merged to `main` (PR #11, `f4d1fa7`)** — security remediation arising from a Phase 21.3 finding. Two-statement ACL change on `public.public_profiles` (`REVOKE ALL` from `anon`/`authenticated`, then `GRANT SELECT`). 8/8 backend requirements and 8/8 production UI checks EMPIRICAL PASS; no `index.html` change. `analysis/phase-21.4/` |
| 21.3 | Capture the Backend Contract in the Repository | **Current phase — RESUMED 2026-08-31** after the 21.4 detour. Addresses 20.7 item **C-3**. Step 1 (client-side audit + extraction planning) complete; live read-only extraction performed (19 tables, 1 view, 34 functions, 27 RLS policies, 2 storage policies, 4 triggers, 5 realtime tables). Discovered **S-1** (remediated by 21.4) plus **S-2–S-5, all still open**. Paused artefacts were lost from volatile storage and **recovered hash-verified**. Remaining work: transcribe verbatim function bodies into the SQL snapshots. **No backend write has ever been performed by this phase.** `analysis/phase-21.3/` |
| 21.2 | Startup Resilience & Dependency Pinning | **Merged to `main` (PR #9, `968b501`)** — SDK pinned to 2.112.1 with SRI and `crossorigin`, moved out of `<head>`; boot screen added; three top-level statements guarded. **Level 3 complete pre- and post-merge** (57/57 static, 42/42 headless, 48/48 harness, **12/12 browser**, **7/7 authenticated**, **7/7 production**). Defect **D-1 found, approved and fixed**. Branch retained, not deleted. `analysis/phase-21.2/` |

### Phase 21.1 — Complete Output Escaping (implementation)

Closes Phase 20.7 register item **C-1** (Critical) — incomplete output escaping / stored XSS.

**Changed in `index.html`** (119 insertions, 33 deletions):

- **18 HTML-text sinks** now escaped with the existing `escapeCollaborationHtml()`: Wanted feed (`title`, `location`, `compensation`, `category`, `role_needed`), Applicants and participant rows (`display_name`, `username`, `role`, `location`), collaboration titles in My Collaborations and the Workspace header, the linked Wanted title, and `collaboration_assets.asset_type`.
- **4 `photo_url` CSS-`url()` sinks** removed from generated markup entirely. The URL is no longer interpolated into any inline `style` attribute; it is applied after the node exists via the DOM style API.
- **Two helpers added:** `safeImageUrl(value)` — parses with the `URL` constructor, accepts only `http:`/`https:`, returns `null` for every rejection, never throws; and `applyAvatarImage(el, photoUrl)` — writes a single CSS property using `JSON.stringify()` for the quoted string.

**Three findings beyond the Phase 20.7 table**, all recorded in `analysis/phase-21.1/phase-definition.md`:

1. **`item.loc` in `renderWanted()`** carries `wanted_posts.location` and was a live stored-XSS vector on non-remote posts. It sits in a mixed-trust expression alongside `item.flag`, a developer-authored HTML entity pair, so only the user-controlled operand is escaped.
2. **`collaboration_assets.asset_type`** is written by the client via `supaInsert`, so it is attacker-influencable regardless of what the UI computes. Escaped defensively — whether a `CHECK` constraint exists is unknowable from this repository (item C-3).
3. **The demo datasets store HTML entities** in `wantedData.flag`/`badgeText` and `artistDB.role`. A blanket escape would render them literally. Trusted static presentation constants are explicitly excluded and documented.

**Standing rule established by this phase:** escape values that originate in the database; do not escape developer-authored presentation constants or values already escaped upstream. Within database values, columns the **client** can write are escaped; columns only a **server RPC** writes (e.g. `collaborations.status`) are documented as safe rather than escaped.

**Verification artefacts:** `analysis/phase-21.1/static-check.sh` (33 source invariants, no browser or network needed — **33/33 pass**) and `analysis/phase-21.1/xss-verification.html` (runtime adversarial harness that extracts the helpers from the live `index.html` — **38/38 pass**).

**Level 3 validated in the live app** against `kbnmkyvbwkuvcklywdhk` with a real session. B1–B11 and B13 PASS; B12 **N/A** (no `photo_url` exists in the dataset); **B14 PASS** — a stored `<img src=x onerror=alert(1)>` rendered as inert literal text in a participant meta line, no alert, no HTML parsing. B14 was **retargeted from `display_name` to `profiles.location`** because of the reachability finding below. Full record: `analysis/phase-21.1/validation.md` §6.

**Findings surfaced during validation — none a Phase 21.1 regression, all pre-existing:**

1. **`public_profiles.display_name` does not reflect `profiles.display_name` — CONFIRMED.** All six `innerHTML` display-name sinks read the view; Edit Profile writes the table. Confirmed by querying the active project (`pg_get_viewdef('public.public_profiles')`): the view is sourced from **`public.users`** and resolves `display_name` as `'Deleted User'` for anonymized users → trimmed `first_name` + `last_name` when either exists → `users.username` → `'STAGERZ Artist'`. **It never reads `profiles.display_name`.**

   Consequence: through the UI, no HTML metacharacter can reach that column — the app writes only `users.username`, which `saveProfile()` constrains to `^[a-z0-9_.]+$`, and never writes `first_name`/`last_name`. That lowers the practical severity of six of the eighteen corrected sinks. **Escaping is retained** because both the username restriction and any write protection on `first_name`/`last_name` are **client-side or unrecorded server-side grants** (item C-3) — a direct REST `PATCH` would bypass the client check. This is a **confirmed pre-existing data-model inconsistency, not a Phase 21.1 regression**, and `profiles.display_name` is currently written by the UI and read by nothing. Reconciling the two columns and capturing the `users` grants belongs to backend-contract capture.
2. **Notification → Applicants routing does not fire.** `wanted.application.created` maps to `navigateToWantedPostApplicants`, but tapping such notifications does not open the view. Pre-existing Phase 13.2 behaviour.
3. **Applicants reachable only via an unlabeled 8px `<div>`** in Profile → My WANTED. Aligns with item B.9.

**Not addressed, recorded:** no Content-Security-Policy exists; `collaborations.status` remains unescaped by decision; demo-content presentation (item H-2) is untouched.

### Phase 21.2 — Startup Resilience and Dependency Pinning (implementation)

Addresses Phase 20.7 register item **C-2** (Critical) — unpinned CDN dependency with no failure path — plus **M-12** (cold-start blank screen) and risk **R-2**.

**Approved 2026-08-06 and implemented.** `index.html` modified: 138 insertions, 17 deletions across five edits plus the approved D-1 fix. Applied in the binding order — boot screen first, guards second, pin and hash last — so a wrong hash could only have surfaced as a readable failure screen, never as the blank page the phase exists to remove. **Not committed, not pushed.**

**Startup path established (at `780d6f9`).** The inline script contains exactly **three** top-level executable statements — `supabase.createClient()` at `index.html:964`, `onAuthStateChange` at 1312, and the `DOMContentLoaded` registration at 5020. **None is guarded.** The vendor UMD bundle binds `var supabase`, so a CDN failure leaves the identifier undeclared and line 964 raises a `ReferenceError` that aborts the single ~4,000-line script before any function is defined. **Zero** of the 20 `.screen` elements carry `active` in the static markup, `.screen{display:none}` is the default (line 17), and the first `active` is added by `goTo()` (1331) — which never runs. Confirmed outcome: a permanently black page, no message, no recovery. No `try/catch`, no `onerror`, and no global error handler exists anywhere on the startup path.

**Measured finding — the dependency is non-deterministic across users, not merely unpinned.** Measured 2026-08-05:

| Source | Version |
|---|---|
| jsDelivr resolver API for `@2` | 2.112.1 |
| npm `latest` | 2.112.1 |
| **Bytes actually served by the `@2` URL** (Frankfurt edge, `x-cache: HIT`, `age: 34115`) | **2.112.0** |
| Bundle observed during Phase 21.1 validation, 2026-08-04 | **2.111.0** |

Three versions inside two days, **two live simultaneously**, and the version served depends on edge-cache state rather than on the URL. Two consequences: Subresource Integrity is **impossible** on the floating URL by construction, and the Phase 20.7 instruction *"pin to the version currently resolved in production"* is **unsatisfiable as written** — recorded as open question **Q-1**.

**Implemented:** the SDK is pinned to **2.112.1** with SHA-384 `integrity` and the mandatory `crossorigin='anonymous'`, and **moved out of `<head>`** to sit after the boot markup and immediately above the application script — with neither `defer` nor `async`, which would invert execution order and break `createClient()` on every load. A 21st `.screen` (`#screen-boot`) carries `active` in the static markup and is deactivated automatically by the existing `goTo()`, which is **byte-identical to base**. `createClient()` is guarded behind a `typeof` check and a `try/catch` setting an explicit `startupFailure` code; the `onAuthStateChange` registration and the `DOMContentLoaded` body are guarded. **One** fixed message is written via `textContent` with a single **Reload** control. Retry-initialization was evaluated and **rejected** — a script that never loaded leaves a global that will never appear.

**Hash recomputed at implementation time (Q-2), not copied:** SHA-384 `0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV`, SHA-256 `ed01c1c20daec4e06a08dbbf4fdc7d4a613091f7032a408faee2d6df45acad58`, 210,842 bytes, verified from two byte-identical independent downloads and confirmed by both the embedded `supabase-js/2.112.1` constant and the `x-jsd-version: 2.112.1` header.

**Failure coverage: 8 of the 11 enumerated paths fully closed** (F1, F3, F4, F5, F6, F7, F8, F11), each confirmed in a browser. **F2, F9 and F10 are reduced from a permanently black page to a branded "Starting…" splash but are not closed** — the accepted consequence of **Q-4 excluding the watchdog**. That is now the phase's only residual startup gap.

**DEFECT D-1 — found by browser validation, approved, FIXED, re-verified.** `if(supabaseClient){…}` guarded only against a *null* client. If the client was created successfully but `supabaseClient.auth.onAuthStateChange(…)` **threw** — the shape an incompatible or partial SDK build produces — the uncaught `TypeError` aborted the rest of the inline script, the `DOMContentLoaded` listener was never registered, and the user was stranded on `#screen-boot` showing "Starting…" with no message and no Reload control. It was **reported rather than improvised**, because the implemented code matched approved design §6.4 exactly and the fix changes an approved decision (`.apos/WORKFLOW.md` stop-and-report rule). **Approved as in-scope and fixed with six lines:** the registration call alone is wrapped in a `try/catch` that logs to the console and sets `startupFailure = 'client-init-failed'` — the code the `createClient`-throws path already uses. No new failure code, no new message, no new DOM node, no watchdog, no retry, no change to the callback body or normal-path auth. Re-verified in the same simulation that exposed it: `startupFailure='client-init-failed'`, fixed message shown, Reload visible, **zero uncaught errors**, and the screen renders identically to every other failure state (4.60 % non-background pixels, versus 0.87 % when stuck). New static invariant **S-23b** prevents a silent regression.

**Invariant change recorded by D-1:** `supabaseClient` can now be non-null while `startupFailure` is set. The rule "a failed startup never leaves the boot screen" is therefore carried by `startupFailure` alone, not by the client being null.

**Validation status.** `analysis/phase-21.2/static-check.sh` — **57/57 pass**, including byte-identical comparison of `goTo()`, `checkSessionAndStart()`, `enterApp()` and the `onAuthStateChange` callback body against `780d6f9`, plus machine-checked assertions that the excluded scope (watchdog, `window.onerror`, CSP, service worker) was not crossed. Headless guard suite against code extracted from the live source — **42/42 pass**. In-browser harness — **48/48 pass**.

**Browser validation executed 2026-08-06 in Microsoft Edge (Chromium) 151.0.4129.59**, headless, against a local `System.Net.HttpListener` server (no Node or Python is available on this machine), and **fully re-run after the D-1 fix**. **B-1, B-3, B-4, B-5, B-6, B-8, B-9, B-10, B-11, B-12 PASS; B-2 partial** (session branch reached `screen-stage` via a stubbed client, not a real session); **B-7 not runnable**. Blocked-CDN and normal-load cases ran against the **unmodified working-tree `index.html`** using `--host-resolver-rules`; everything needing modified source used scratchpad copies, and `git diff --numstat index.html` stayed `127 18` throughout. **No tested failure state produced a black screen**, and a scan of all 19 captured DOM dumps found **zero** leaked secrets, URLs, error messages, stacks or machine codes — including a case where the thrown `Error` deliberately carried the publishable key and project URL. A navigation sweep activated **20/20** screens with **0** uncaught errors.

**M-12 / F11 closed, measured.** First Contentful Paint against an 8-second-delayed SDK: **224 ms** with the shipped layout versus **8,064 ms** with the SDK returned to `<head>`. The Q-3 script-position change moves first paint ahead of the SDK download by 7.8 seconds.

**Authenticated regression N-1…N-7 executed 2026-08-17 — all seven PASS**, against a genuine magic-link session on the live project `kbnmkyvbwkuvcklywdhk`, driven manually by the product owner and recorded only from observed output. Coverage: sign-in, session restore across both reload types, sign-out, authenticated REST read and write, Storage upload with a **byte-identical** download round-trip plus inline preview, realtime `postgres_changes` delivered to a second tab in 1–2 s, presence, and clean channel teardown. Phase 21.1 escaping re-confirmed at the real `innerHTML` sink — a stored `<img src=x onerror=alert(1)>` rendered as inert text, zero `img` nodes in the participant list. **No behavioural difference from the 2.111.0 baseline was found, so risk R1 is closed for 11 of the 12 `supabaseClient` call sites.** The twelfth, `storage.remove` (index.html:4836), is an error-cleanup path that runs only when a metadata insert fails after a successful upload; it was not manufactured and is recorded as uncovered.

**Constraint discovered, relevant to all future local authenticated testing:** `emailRedirectTo` is hardcoded to `https://stagerz.app` (index.html:1329), so a magic link returns to production, not to a local build. Changing it is a source edit and allow-listing localhost is a backend change — both out of scope. Resolved instead with a `curl` hand-off that reads the tokens from the `302 Location` fragment of Supabase's verify endpoint and launches the local build in one motion (~600 ms), staying inside the token lifetime.

**Environmental finding, not a regression:** auth-js probes `localStorage` with a write test and, on failure, **silently** falls back to in-memory storage. An Edge profile that denies `localStorage` therefore signs in successfully but loses the session on every reload, with no error. Identical behaviour in 2.111.0. Re-run in a dedicated default-settings profile, session restore passed. **Product observation for a future phase:** any STAGERZ user who blocks site data silently cannot stay signed in, and the app neither detects nor explains it.

**B-7 PASS (2026-08-19) — the final pre-merge item.** With a real session live, the SDK request was failed on demand and then restored **without restarting the browser**, so the page's own RELOAD control remained the thing under test. This Edge build has no DevTools "Network request blocking" panel, so the failure was induced with a local HTTP **CONNECT proxy** (`scratchpad/proxy.ps1`) that Edge routes through, with localhost bypassed and QUIC disabled. It is a raw byte relay, so TLS stayed end-to-end and **SRI still validated** — verified before use: in `allow` mode the relayed bytes hashed to the pinned SHA-384 exactly; in `block` mode only `*jsdelivr*` got 502 while Google Fonts still returned 200. Observed: during the failure the session key remained in `localStorage` while `supabaseClient` was `null` and `startupFailure` was `sdk-unavailable`, the fixed message and Reload were shown, the leak scan was CLEAN, and there was no black screen; after unblocking, the page's RELOAD control returned the user to **Stage** with the nav bar and **no re-login**. No source was modified — `index.html` was served unchanged from the working tree throughout.

**PRODUCTION VALIDATION EXECUTED 2026-08-21, after merge as `968b501`.** Both live surfaces were checked. **`stagerz.app`: P-1…P-7 all PASS. Netlify production: P-1…P-4 and P-7 PASS**; **P-5/P-6 are n/a natively** there, because `emailRedirectTo` is hardcoded to `https://stagerz.app` so a magic link never returns to that surface. Both serve HTML **byte-identical to the merged commit blob**, and the Netlify deploy-preview badge is preview-only and absent from production.

**P-7 is the result that demonstrates the objective.** Two independent warm jsDelivr edges (`x-cache: HIT`, age ~1.34 M s) both returned **2.112.1**, 210,842 bytes, SHA-384 matching the deployed `integrity` attribute. Phase 21.2 §4.2 had measured the floating `@2` serving a stale **2.112.0** from a warm edge while the resolver reported 2.112.1 — that non-determinism no longer reproduces. P-6 signed in through a real magic link to Stage; P-5 confirmed the session survives reload (`storage in use: localStorage`, session key present, no re-login).

**LEVEL 3 IS COMPLETE, PRE-MERGE AND POST-MERGE:** 57/57 static invariants, 42/42 headless guard assertions, 48/48 in-browser harness assertions, **12/12 browser tests**, **7/7 authenticated regressions**, **7/7 production checks** on the primary surface. Full record: `analysis/phase-21.2/validation.md`.

**Counting artefact, Phase 20.5 precedent, recorded to prevent a false alarm:** the comments this phase added mention identifiers, so raw greps now over-count. `crossorigin='anonymous'` appears **2** times (1 attribute + 1 comment) and `supabaseClient.` appears **14** times (**12 executable call sites** + 2 comment mentions). **The executable counts are unchanged from base.** `static-check.sh` matches the executable forms only.

**Standing rule established by this phase:** validation must not edit the repository working tree. SDK failure is simulated by **DevTools request blocking**; any test needing modified source operates on a copy held outside the repository. This deliberately avoids the temporary-source-edit hazard that Phase 21.1 had to contain with a `pre-commit` marker hook and SHA-256 verification.

**Q-5 remains open:** pinning converts silent drift into a standing maintenance obligation this repository has no process for — no lockfile, no CI, no dependency-update process. The pin will silently age.

### Phase 20.6 prerequisite — RESOLVED

Phase 20.6 carried one gate that this repository could not answer:

> Does a live external Telegram Bot / Mini App entry point exist that points at STAGERZ, and do real users currently open the app inside Telegram?

**Resolved by the product-owner decision recorded above (2026-07-28):** the existing Telegram Mini App configuration is outside the currently supported product scope and does not block removal. Implementation proceeded on that basis. Full record at `analysis/phase-20.6/phase-definition.md` §13.1.

### Phase 20.7 — Codebase Assessment (recommendations, **not** decisions)

Phase 20.7 was an analysis-only evaluation of the application after Telegram removal. It changed no application code and recorded no roadmap decision. Full document: `analysis/phase-20.7/codebase-assessment.md`.

**Nothing in that document is binding.** Its roadmap is a *proposal* for ChatGPT review under `.apos/WORKFLOW.md`. Phase numbering (21.1–21.10) is suggested, not assigned.

**Baseline measured (at `275caf3`):** `index.html` is 4,942 lines / ~265 KB — CSS 9–286, markup 288–958, JavaScript 960–4940. 20 screens, all reachable via `goTo()`. 139 functions, 47 module-level `var`s, 194 `getElementById` calls, 81 `.innerHTML` assignments. Backend surface: 20 RPCs and 14 tables/views across one Supabase project. Zero `@media` queries, zero `aria-*` attributes, zero tests/lint/CI.

**Three findings ranked Critical:**

1. **Incomplete output escaping.** `escapeCollaborationHtml()` exists and is applied at 32 sites, but 10 sites interpolate user-controlled values (`display_name`, `username`, `role`, `location`, Wanted `title`, collaboration `title`) unescaped into `innerHTML`, plus 4 `photo_url` injections into inline `style` attributes. Stored-XSS class.
2. **Unpinned CDN dependency with no failure path.** `@supabase/supabase-js@2` floats across all v2 releases with no SRI and no lockfile. Because no screen carries `active` in the static markup, a CDN failure makes the whole inline script throw at `supabase.createClient()` and the user sees a permanently blank page.
3. **The backend contract exists only inside Supabase.** 20 RPCs, 14 tables/views, RLS policies, column grants, the signup trigger, and Storage bucket policies have no representation in this repository. Nothing here can reconstruct the server — this is also the root cause of "no staging environment" and "authenticated flows unverifiable pre-merge."

**Open question raised for the product owner (recorded, not answered):** `index.html` describes the Supabase project at `kbnmkyvbwkuvcklywdhk.supabase.co` as a *"disposable test project"* and the auth flow as *"TEST ONLY"* (lines 307–310, 1218–1225). Whether that is still accurate — and therefore whether production user data currently sits on a project not intended to persist — is **unknown from this repository and must be confirmed rather than assumed.**

**Architecture verdict:** the single-file architecture is sound and is recommended for retention. No build step, bundler, framework, module system, or file split is proposed. The assessment found no compelling technical reason to change it.

---

## Governance Gates

- Source changes require explicit approval.
- Commits require successful validation **and** explicit user approval.
- Validation procedure is defined in `.apos/VALIDATION_STANDARD.md`.

---

## Unknown

The following are **not** established and must not be assumed:

- APOS acronym expansion — unknown.
- Release procedure beyond "deployed via GitHub Pages from `main`" — unknown.
- Branching and merge policy (how development branches reach `main`) — unknown.
- Definitions of the individual APOS phase deliverables — unknown.
- Whether the Supabase project at `kbnmkyvbwkuvcklywdhk.supabase.co` is still the "disposable test project" the code describes, or is now the intended production data store — **unknown**; raised by Phase 20.7, not yet answered.
- The full backend contract (RPC bodies, RLS policies, column grants, triggers, Storage policies) — **not recorded anywhere in this repository.** Phase 20.7 enumerated the 20 RPCs and 14 tables/views the client calls, but their definitions exist only inside the Supabase project.

Previously listed as unknown, now established by Phase 20.7 (`analysis/phase-20.7/codebase-assessment.md`):

- **Runtime dependencies and third-party integrations.** Exactly one runtime dependency: `@supabase/supabase-js@2`, loaded from jsDelivr at `index.html:8` (unpinned within v2, no SRI, no `crossorigin`, render-blocking, no failure path). Plus Google Fonts via a CSS `@import`. No other third-party code. **Refined by Phase 21.2 (measured 2026-08-05):** the floating `@2` URL was not merely unpinned but **non-deterministic across users** — the resolver reported 2.112.1 while the Frankfurt edge served 2.112.0, and Phase 21.1 validated against 2.111.0 the day before. The version a user received depended on edge-cache state, so SRI was impossible on that URL as written. **Resolved by Phase 21.2 (implemented, not yet merged):** the dependency is now pinned to exactly **2.112.1** with SHA-384 Subresource Integrity and `crossorigin='anonymous'`, loaded from `<body>` above the application script rather than from `<head>`.
- **Backend services.** One Supabase project providing PostgREST, Auth (email magic link), Realtime (`postgres_changes` + presence), and Storage (bucket `collaboration-assets`).

---

## Summary

STAGERZ is the APOS reference implementation: a single-page application contained primarily in `index.html`, deployed from the `main` branch to **two production surfaces** — `stagerz.app` via GitHub Pages and `aquamarine-puppy-beccd9.netlify.app` via Netlify, the second established by direct observation during Phase 21.2. Phases 20.4–20.6 removed NACKL and the Telegram runtime; Phase 20.7 assessed the resulting codebase and proposed a roadmap, changing no application code; Phase 21.1 closed the stored-XSS and CSS-injection surfaces that assessment identified and merged in Pull Request #8; Phase 21.2 pinned the CDN dependency to an integrity-checked 2.112.1 and removed the permanently-blank-page startup failure, **merged in Pull Request #9 (`968b501`) with Level 3 complete pre- and post-merge** — defect D-1 found and fixed, 12/12 browser tests, 7/7 authenticated regressions against a real session, and 7/7 production checks confirming the CDN drift no longer reproduces. ChatGPT owns architecture, governance, reviews, and approval; Claude Code performs analysis and approved implementation; the user is the final authority for source changes and commits. Analysis output lives under `analysis/<phase>/` and governance rules under `.apos/`. Items listed under **Unknown** above are deliberately unrecorded rather than inferred.
