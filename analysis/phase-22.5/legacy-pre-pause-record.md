# Legacy Supabase Project — Final Pre-Pause Verification Record

**Inspection date:** 2026-09-20. **Nature:** read-only. Every database query was a `SELECT`;
nothing was modified, paused, deleted or created.
**Repository base:** `main` @ `784f068a4f72015cadcea272e87870e6ce92e5cb`.

**Legacy project:** `edxicnafggnnvcdvxemk` ("stagerz-app"), the former Telegram-era backend,
contained by Phase 22.1. **State at inspection: `ACTIVE_HEALTHY`**, region `eu-north-1`,
PostgreSQL 17.6.1.155, created 2026-06-25.

**Production backend of record:** `kbnmkyvbwkuvcklywdhk` ("stagerz-foundation-v2-test"),
designated by Phase 22.2 (Option A).

**Purpose:** preserve, immediately before any pause, the evidence that the legacy project can be
paused without losing anything the current STAGERZ application needs.

No tester personal data, e-mail address, API key, JWT, secret value or Auth record content is
recorded here — aggregates and dates only.

---

## 1. Aggregate inventory (re-verified live, 2026-09-20)

| Item | Value |
|---|---|
| `public` tables | **6** — `follows`, `likes`, `notifications`, `profiles`, `users`, `wanted_posts` |
| `public` views / materialised views | 0 / 0 |
| `public` functions | 1 — `rls_auto_enable()` |
| Triggers (`public` / `auth`) | 0 / 0 |
| Sequences (`public`) | 0 |
| Schemas | 9 — `auth`, `extensions`, `graphql`, `graphql_public`, `pgbouncer`, `public`, `realtime`, `storage`, `vault` |
| Extensions | 5 — `pg_stat_statements`, `pgcrypto`, `plpgsql`, `supabase_vault`, `uuid-ossp` |
| **Row counts** | `users` **3**, `wanted_posts` **5**, `follows` **0**, `likes` **0**, `notifications` **0**, `profiles` **0** |
| **Auth users** | **2** (2 identities; 1 has ever signed in) |
| Auth activity | Last sign-in and last account creation both **2026-07-12** — dormant since |
| **Storage** | **0 buckets, 0 objects** |
| **Edge Functions** | **0** |
| **Migration history** | **None.** The `supabase_migrations` schema does not exist — a query against `supabase_migrations.schema_migrations` returned `relation does not exist` |
| **Realtime member tables** | **0.** The `supabase_realtime` publication exists with no members |
| RLS | Enabled on all 6 tables; forced on none |
| Policies | 24 in `public` (4 per table); 0 in `storage` |
| Security Advisor | **1 WARN** — `auth_leaked_password_protection` only (LG-5, accepted) |

These figures match the Phase 22.1 record exactly.

---

## 2. Phase 22.1 containment invariants — all re-verified PASS

| Gate | Expected | Observed 2026-09-20 | Verdict |
|---|---|---|---|
| **R-1** — all client table privileges revoked | none | `role_table_grants` for `anon`/`authenticated` = **0**; column privileges = **0** | **PASS** |
| **R-2** — six restrictive deny-all policies | 6 restrictive + 18 original permissive | **6 RESTRICTIVE**, each named `p221_containment_deny_client`, one per table, roles `anon+authenticated`; **18 PERMISSIVE**; 24 total | **PASS** |
| **R-3** — client roles removed from the 4 `postgres` TABLE/SEQUENCE default ACLs | absent | `postgres` TABLE and SEQUENCE defaults in **both** `public` and `storage`: client roles absent, 4 of 4 | **PASS** |
| **R-4** — `EXECUTE` on `rls_auto_enable()` revoked from client roles | not executable | `has_function_privilege` → `anon` **false**, `authenticated` **false** | **PASS** |

**Containment is intact and unchanged since it was applied on 2026-09-19.**

### The two already-accepted residuals (both expected; neither is a regression)

1. **Skipped O-1 — the `postgres` FUNCTION default ACLs** in `public` and `storage` still mention
   client roles. O-1 was **deliberately SKIPPED** by owner decision in Phase 22.1 as optional
   residual hardening, not a blocker.
2. **Platform-owned `supabase_admin` default ACLs** (`public` TABLE, SEQUENCE and FUNCTION) mention
   client roles. These are **managed by the platform**, were explicitly recorded in Phase 22.1 as an
   expected residual, and are not STAGERZ-owned.

---

## 3. Repository references — zero executable dependency

Verified at `main` @ `784f068`.

**Executable / runtime references: ZERO.** Checked individually, 0 occurrences each:
`index.html`, `.github/workflows/process-pending-asset-deletions.yml`,
`tests/environment-selection.test.ts`, `supabase/verify/fingerprint.sql`,
`supabase/verify/expected-production.json`, `supabase/seed/showcase.sql`,
`supabase/seed/fixtures.sql`, `CNAME`. No `edxicnafggnnvcdvxemk.supabase.co` URL appears anywhere
in the repository except one historical narrative sentence in
`analysis/phase-22.0/investigation-report.md`.

| Class | Where |
|---|---|
| **Executable / runtime** | **none** |
| **Safety / documentation** — names it only to forbid targeting it | `supabase/README.md`; the header **comment block** of `supabase/migrations/20260919120000_stagerz_baseline.sql` (its `NEVER execute against…` warning); `.apos/PROJECT_CONTEXT.md` |
| **Historical evidence** | `analysis/phase-22.0/`, `analysis/phase-22.1/` (all mentions in `remediation.sql`, `rollback.sql` and `validation.sql` are SQL **comments**, never identifiers), `analysis/phase-22.2/`, `analysis/phase-21.3-r5-remediation/`, `analysis/phase-22.3/test-environment-options.md` |

---

## 4. Production is Foundation v2 — **not** a 1:1 clone of legacy

| Dimension | Legacy `edxicnafggnnvcdvxemk` | Production `kbnmkyvbwkuvcklywdhk` |
|---|---|---|
| Tables / views | 6 / 0 | **17 / 1** |
| Functions | 1 | **34 `SECURITY DEFINER`, `search_path=''`** |
| Triggers | 0 | 4 (including `on_auth_user_created`) |
| Storage | 0 buckets | 1 private bucket + 2 object policies |
| Realtime | 0 member tables | 5 collaboration tables |
| Edge Functions | 0 | 4 |
| Migration history | none | 43, latest `20260917143322` |
| Domain | Telegram-era **v1**: users, profiles, posts, follows, likes, notifications | **Foundation v2**: adds the entire collaboration domain — applications, collaborations, participants, messages, tasks, assets, credits, activity, deletion queues |

**Production was never intended to be a 1:1 copy of legacy.** It is a deliberate re-architecture,
created 2026-07-12 on a schema incompatible with legacy v1. Legacy became detached by **drift** on
2026-07-12/13 and was formally superseded by the Phase 22.2 Option A designation. **Legacy is a
superseded predecessor, not a source of truth.**

Nothing in legacy "should have been migrated but was not": its entire content is owner-created
tester data (Phase 22.0 owner testimony O-6; no known external users in either project), and Phase
22.2 explicitly decided **not** to migrate Auth users — the owner recreates test accounts by
signing in.

---

## 5. Conclusions

**No current STAGERZ runtime dependency, and no required production data, would be lost by pausing
the legacy project.** There is zero executable reference to it; it holds no Edge Functions, no
Storage, no Realtime members and no migration history; its client roles have no privileges and are
denied by restrictive policy; and it has been dormant since 2026-07-12.

**No database dump is required before PAUSE.** The schema, the containment design and its
validation are already committed durably in `analysis/phase-22.0/` and `analysis/phase-22.1/`
(including `remediation.sql` with its apply window, `validation.sql`, and the recorded Part B
result **PASS 66 / FAIL 0**), and this record adds a fresh live re-verification. The only content a
dump would uniquely preserve is 8 rows of owner tester data plus 2 Auth records on a superseded v1
schema that production was never meant to copy — nothing in STAGERZ needs them, and unpausing
recovers them. Taking a dump would also move personal tester data out of a contained project into a
less-controlled artifact, which is a net privacy negative.

### Scope of approval

- **PAUSE is approved as technically safe by this evidence.**
- **DELETE is NOT approved.** Deletion is irreversible and would permanently destroy the in-place
  containment evidence and the ability to re-verify R-1 … R-4 against the live project. Nothing in
  this record supports deletion.

---

## 6. Free-plan slot — owner-observed dashboard evidence

The product owner observed, in the Supabase dashboard, that the **free-project limit is 2**, and
that before another free project can be created **one or more projects must be deleted, paused, or
upgraded**.

This is recorded as **owner-observed dashboard evidence**, not as an inferred or remembered pricing
claim. No pricing or plan-limit figure in this document is derived from anything other than that
observation.

---

## 7. Explicitly not established

- **The exact retention / restore window for a paused Supabase project has NOT been established**
  and **must not be guessed**. It requires its own verification against current Supabase
  documentation or the dashboard before anyone relies on a specific duration.
- GoTrue sign-up / anonymous-sign-in state and legacy API-key status were **not** re-verified in
  this inspection: neither is readable through SQL, and no key-returning endpoint was called, to
  avoid surfacing key material. Both remain as recorded in Phase 22.1 (N-1 legacy `anon` disabled,
  tool-verified; N-2 sign-ups and anonymous sign-ins OFF, owner/dashboard-confirmed). Pausing does
  not depend on re-confirming either.

---

## 8. State at the time of recording

**No project had been paused at the time this evidence was recorded.** Both
`edxicnafggnnvcdvxemk` and `kbnmkyvbwkuvcklywdhk` were `ACTIVE_HEALTHY`. No Supabase project was
created, paused, deleted, renamed or otherwise modified; no T2 test environment existed; and no
Auth, key, secret or configuration value was changed anywhere.
