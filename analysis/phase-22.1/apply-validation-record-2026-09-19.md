# Phase 22.1 — Apply and Validation Record (2026-09-19)

**Target:** `edxicnafggnnvcdvxemk` ("stagerz-app", legacy Telegram-era project) — **only**.
**Authorization:** owner approval "PHASE 22.1 — OWNER APPROVAL TO APPLY DATABASE CONTAINMENT R-1 THROUGH R-4" (2026-09-19). It covers R-1 … R-4 and validation Parts A and B only.
**Checkpoint:** commit `b31bd26a8106d72663e195412de6b8cee9dd2ef6` on `phase-22.1-legacy-supabase-containment`, pushed to `origin` before the apply. `remediation.sql` as committed there has SHA-256 `b4bb0484593d8094cb5239188f011815f484de6de55467b2a803af18bd188f37` (257 lines).
**Result:**
- **R-1 … R-4 APPLIED.** Validation: Part A all expected values; Part B PASS=66 / FAIL=0 (§1 – §7).
- **N-1 and N-2 PERFORMED** by the owner in the dashboard (§8).
- Final read-only verification (§8.3) passed.
- **Phase 22.1 — COMPLETE / PASS** (§9).

---

## 1. Pre-apply gates (all PASS)

| Gate | Evidence | Result |
|---|---|---|
| Branch | `phase-22.1-legacy-supabase-containment` | PASS |
| Clean tree | `git status --porcelain` empty | PASS |
| Checkpoint is HEAD | HEAD = `origin/phase-22.1-legacy-supabase-containment` = `b31bd26…` | PASS |
| Target identity | `get_project`: ref `edxicnafggnnvcdvxemk`, name `stagerz-app`, `eu-north-1`, ACTIVE_HEALTHY, PG 17.6.1.155, created 2026-06-25 17:06:37 UTC | PASS |
| Pre-flight replica (`P221-PREAPPLY-GATE-v1`, read-only, 13:14:49 UTC) | 21 checks all `true`: role is postgres/postgres; not the Foundation v2 schema; 6 relations; `users.id` bigint; relacl, policy and default-ACL fingerprints; 24 / 0 default-ACL entries; function definition and ACL; containment not yet present; row counts 3/5/0/0/0/0; Auth users 2; Storage 0/0; column md5; storage relacl and function-ACL md5; untargeted default-ACL md5 | PASS — **no drift** from the approved baseline |
| Advisor (pre) | 3 WARN: `anon_security_definer_function_executable`, `authenticated_security_definer_function_executable` (both `rls_auto_enable`), `auth_leaked_password_protection` | recorded |
| Edge Functions (pre) | `[]` | recorded |

## 2. Application

| Item | Value |
|---|---|
| Mechanism | **One** `execute_sql` call (Supabase MCP, direct SQL execution as `postgres`) containing the committed `remediation.sql` verbatim: its comments and one `DO $p221$ … $p221$` block. O-1 stays commented out and was **not** executed |
| Not used | `apply_migration`. The project has no migration history; the migration tool would have created `supabase_migrations` as an extra change |
| Migration / version identifier | **None assigned.** `list_migrations` = `[]` after the apply; schema `supabase_migrations` still does not exist |
| Atomicity | One DO block = one transaction: pre-flight, R-1 … R-4, post-flight. Any failed assertion would have rolled back everything |
| Application time | **2026-09-19, between 13:14:49 UTC** (last pre-apply gate read) **and 13:17:16 UTC** (first post-apply read, Part A). The success NOTICE is not written to the platform log at the default log level, so a tighter bound is not available |
| Outcome | The call returned without error (`[]`), so every embedded post-flight assertion passed and the transaction **committed** |
| Ad-hoc changes | None. No statement was edited, added or re-run |

### Changes applied

| # | Statement(s) | Result |
|---|---|---|
| **R-1** | `REVOKE ALL ON TABLE public.follows, public.likes, public.notifications, public.profiles, public.users, public.wanted_posts FROM anon, authenticated;` | **APPLIED** |
| **R-2** | 6 × `CREATE POLICY p221_containment_deny_client … AS RESTRICTIVE FOR ALL TO anon, authenticated USING (false) WITH CHECK (false)`, plus `COMMENT ON POLICY` | **APPLIED** |
| **R-3** | 4 × `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA {public,storage} REVOKE ALL ON {TABLES,SEQUENCES} FROM anon, authenticated;` | **APPLIED** |
| **R-4** | `REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;` | **APPLIED** |

## 3. Before / after catalog evidence

| Aspect | Before | After |
|---|---|---|
| Table ACL (each of the 6 tables) | `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| `public` relacl md5 | `ff81dd8ad8ae8264d531931a0cbd52f0` | `c719d0752a9b549c50f23f6173420f1c` (expected change) |
| Client column privileges | table-level only | none |
| Policies | 18 (all PERMISSIVE, `TO public`, `true`) | **24** = 18 legacy PERMISSIVE (md5 `a5ddf5ad03f8c5c333470e4af9e5d292`, **byte-identical**) + 6 RESTRICTIVE `p221_containment_deny_client` |
| RLS enabled | 6/6 | 6/6 |
| `postgres` default ACL public/TABLES | `{postgres,anon,authenticated,service_role = arwdDxtm}` | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| `postgres` default ACL public/SEQUENCES | `{postgres,anon,authenticated,service_role = rwU}` | `{postgres=rwU/postgres,service_role=rwU/postgres}` |
| `postgres` default ACL storage/TABLES | as public/TABLES | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| `postgres` default ACL storage/SEQUENCES | as public/SEQUENCES | `{postgres=rwU/postgres,service_role=rwU/postgres}` |
| Client privilege tuples in those 4 entries | 44 | **0** |
| Default-ACL entries / global | 24 / 0 | 24 / 0 (no `IN SCHEMA` trap) |
| Untargeted 20 default-ACL entries (md5) | `94a24e2550d616f304d33cc6f4b5d9a5` | `94a24e2550d616f304d33cc6f4b5d9a5` (unchanged) |
| `rls_auto_enable()` ACL | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | `{postgres=X/postgres,service_role=X/postgres}` |
| `rls_auto_enable()` EXECUTE anon / authenticated | true / true | **false / false** |
| `rls_auto_enable()` definition md5 | `6998ea6b4c2480f5d2e34b5dcf3f8d36` | unchanged |
| Event trigger `ensure_rls` | enabled | enabled; **fires** (log 13:17:51.749 "rls_auto_enable: enabled RLS on public.p221_probe", inside the rolled-back Part B) |
| `public` column md5 | `e038cf2a45b7c033e4cb4a5e81bf0779` | unchanged |
| `storage` relation / function ACL md5 | `04360dda0d641c7805b22e23d8c6e59b` / `c90dd3853e9865ba8ca26d33bade167f` | unchanged |

## 4. Validation results

### 4.1 Part A (read-only, 13:17:16 UTC) — all as expected

| Key | Pre | Post | Expected | |
|---|---|---|---|---|
| `V1_anon_select_tables` | 6 | **0** | 0 | ✅ |
| `V2_anon_dml_tables` | 6 | **0** | 0 | ✅ |
| `V3_authenticated_any_tables` | 6 | **0** | 0 | ✅ |
| `V3_column_priv_tables` | 6 | **0** | 0 | ✅ |
| `V4_truncate_etc_tables` | 6 | **0** | 0 | ✅ |
| `V1_deny_policy_tables` | 0 | **6** | 6 | ✅ |
| `V1_rls_enabled_tables` | 6 | 6 | 6 | ✅ |
| `V1_policies_total` | 18 | **24** | 24 | ✅ |
| `V5_client_defacl_priv_tuples` | 44 | **0** | 0 | ✅ |
| `V5_defacl_entries` / `global` | 24 / 0 | 24 / 0 | 24 / 0 (O-1 skipped) | ✅ |
| `V5_platform_defacl_tuples` | 24 | 24 | 24 (residual) | ✅ |
| `V6_rls_auto_enable_anon` / `_auth` | true / true | **false / false** | false / false | ✅ |
| `V6_rls_auto_enable_acl` | 5 grantees incl. PUBLIC | `{postgres=X/postgres,service_role=X/postgres}` | same | ✅ |
| `V6_event_trigger_enabled` | true | true | true | ✅ |
| `V7_rows` | 3/5/0/0/0/0 | 3/5/0/0/0/0 | unchanged | ✅ |
| `V8_auth_users` / `identities` | 2 / 2 | 2 / 2 | unchanged | ✅ |
| `V9_storage_buckets` / `objects` / `policies` | 0 / 0 / 0 | 0 / 0 / 0 | unchanged | ✅ |
| `fp_col_md5`, `fp_fn_def_md5` | baseline | unchanged | unchanged | ✅ |
| `max_activity` | ≤ 2026-07-12 | ≤ 2026-07-12 | ≤ 2026-07-12 | ✅ |

### 4.2 Part B (behavioural, rolled back, 13:17:51 UTC)

Executed verbatim from `validation.sql`. Result, as returned by the database (the intentional final exception):

```
VALIDATION RESULTS (rolled back): PASS=66 FAIL=0 (expected 66/0)
```

| Probe group | Count | Result |
|---|---|---|
| B-1 … B-5: SELECT / INSERT / UPDATE / DELETE / TRUNCATE × 6 tables × {`anon`, `authenticated`} → `42501` | 60 | 60 PASS |
| B-6a: simulated accidental re-grant of SELECT to `anon` on `wanted_posts` → 0 rows visible (restrictive policy alone) | 1 | PASS |
| B-6b: same re-grant of INSERT → `42501` (RLS, before NOT NULL) | 1 | PASS |
| B-7a / B-7b: `anon` / `authenticated` call `rls_auto_enable()` → `42501` | 2 | 2 PASS |
| B-7c: new table created by `postgres` gets RLS from `ensure_rls` after the EXECUTE revoke | 1 | PASS |
| B-8: new table created by `postgres` has no client-role privilege (R-3 effective) | 1 | PASS |

**Rollback of Part B confirmed** (13:18:11 UTC, read-only): `public.p221_probe` does not exist; `anon` has no SELECT on `wanted_posts` (the simulated re-grant is gone); row counts are unchanged; `pg_stat_user_tables` shows 0 committed inserts, updates and deletes on all 6 tables.

### 4.3 V-1 … V-14

| # | Check | Result |
|---|---|---|
| V-1 | `anon` effective SELECT = none | **PASS** (A: 0 tables; B-1: 6 × `42501`) |
| V-2 | `anon` effective INSERT/UPDATE/DELETE = none | **PASS** (A: 0; B-2/3/4: 18 × `42501`) |
| V-3 | `authenticated` has no unintended broad access | **PASS** (A: 0 table, 0 column; B-1 … B-5: 30 × `42501`) |
| V-4 | No TRUNCATE for client roles | **PASS** (A: 0; B-5: 12 × `42501`) |
| V-5 | `postgres` defaults no longer auto-grant tables/sequences | **PASS** (A: 44 → 0; B-8 PASS). Platform-owned `supabase_admin` defaults remain; see §5 |
| V-6 | `rls_auto_enable()` not client-executable | **PASS** (A: false/false; B-7a/b `42501`; the trigger still fires, B-7c) |
| V-7 | Row counts unchanged | **PASS** (3/5/0/0/0/0) |
| V-8 | Auth users and identities unchanged | **PASS** (2 / 2) |
| V-9 | Storage unchanged | **PASS** (0 buckets / 0 objects / 0 policies) |
| V-10 | No Edge Functions added or changed | **PASS** (`[]` before and after) |
| V-11 | Live STAGERZ app untouched | **PASS**: `stagerz.app`, `www.stagerz.app` and `aquamarine-puppy-beccd9.netlify.app` return HTTP 200, with 0 legacy and 1 `kbnmkyvbwkuvcklywdhk` reference each. The repository had no changes to `index.html`, `.github` or `supabase/`. No Netlify call was made |
| V-12 | Security Advisor reconciled | **PASS**: 3 WARN → **1 WARN**. Both `*_security_definer_function_executable` findings are cleared; `auth_leaked_password_protection` remains (LG-5, accepted/deferred). No new lint |
| V-13 | LG-1 database exposure contained although the historical credential still exists | **PASS**: no client role can read or write any legacy table (V-1 … V-4), and even a simulated accidental re-grant is denied by the restrictive policy (B-6). Established without using any client key; the historical key stays enabled and was not exercised |
| V-14 | N-1's role | Recorded: the database data protection holds **without** N-1. N-1 remains defence in depth: it would stop the published credential at the gateway for Auth endpoints (sign-up, sign-in, recovery emails), and would also disable the unused legacy `service_role` JWT. The key state after the apply is unchanged: legacy `anon` and the publishable key are both `disabled: false`, as N-1 was not performed |

## 5. Residual state (expected; not failures)

- **Platform-owned default privileges.** `supabase_admin` default ACLs in `public` still grant `anon`/`authenticated` on TABLES (`arwdDxtm`), SEQUENCES (`rwU`) and FUNCTIONS (`X`), 24 privilege tuples.
  - `postgres` is not a member of `supabase_admin` and cannot change them.
  - They apply only to objects created **by `supabase_admin`**.
  - They do **not** restore access to the 6 contained tables: those tables' ACLs are explicit (V-1 … V-4, B-1 … B-5).
  - They do **not** affect new `postgres`-created objects (B-8).
  - The same state exists on the live project.
- **`postgres` FUNCTIONS default entries** (`public/f`, `storage/f`) still grant EXECUTE to `anon`/`authenticated`. O-1 was **skipped** by the owner and stays an optional residual hardening item. The built-in EXECUTE-to-PUBLIC default applies regardless.
- **Historical anon JWT** remains in public git history and remains **enabled**. It can no longer reach any legacy table data; the Auth-endpoint surface remains until N-1 / N-2.
- **Tester data** (3 `users` rows, 5 `wanted_posts`, 2 Auth accounts) is intact and awaits the later disposition decision.
- **The 18 legacy `USING (true)` policies** remain, neutralised. Re-exposure would require undoing **both** R-1 and R-2.

## 6. Finding status after validation

| Finding | Status |
|---|---|
| **LG-1** | **CONTAINED at the database-authorization layer**, pending the N-1 defence-in-depth action (approved in principle, not executed). Not "fully resolved": the credential is still valid at the gateway for Auth endpoints |
| **LG-2** | **REMEDIATED for the `postgres`-owned TABLE/SEQUENCE default privileges in `public` and `storage` covered by R-3.** Residual, recorded separately: the platform-owned `supabase_admin` defaults (not alterable), and the `postgres` FUNCTIONS defaults (O-1 skipped) |
| **LG-3** | **REMEDIATED** (no client TRUNCATE on any legacy table) |
| **LG-4** | **REMEDIATED** (`rls_auto_enable()` not executable by `PUBLIC`/`anon`/`authenticated`; the Advisor WARNs are cleared; the event trigger still works) |
| **LG-5** | **ACCEPTED / DEFERRED — not remediated** (owner decision; Free-plan limitation) |

## 7. What was NOT done

- **Not done in this step:**
  - O-1;
  - N-1 (keys unchanged, both enabled);
  - N-2 (Auth settings not touched);
  - any LG-5 change;
  - any HTTP request using the historical key;
  - any data export, cleanup or deletion;
  - any change to Auth users, tester rows, Storage, Edge Functions, project status, plan, or pause/delete settings.
- **Not run:** `rollback.sql`. There was no regression, and no automatic rollback was authorized.
- **Not touched:** `kbnmkyvbwkuvcklywdhk`, Netlify, `index.html`, application code and GitHub workflows.
- **Read-only calls after the apply:**
  - `get_advisors`;
  - `list_edge_functions`;
  - `list_migrations`;
  - `get_publishable_keys` (state only; values not recorded);
  - a 5-minute Postgres-log read (timestamps and message prefixes only).

> §6 and §7 above record the state **after R-1 … R-4, before N-1 / N-2**. The final state is in §8 and §9.

---

## 8. N-1 / N-2 — owner manual actions and final verification

**Authorization:** owner approval "PHASE 22.1 — OWNER APPROVAL FOR N-1 / N-2 AND FINAL VALIDATION" (2026-09-19).

**Why the actions were manual:**
- The available Supabase tooling can read key state, but it can neither disable keys nor read or change Auth settings.
- The Supabase CLI had no access token, and its only Auth-config path (a whole-config push) was judged unsafe.
- Claude therefore performed neither action. The owner performed both in the Supabase dashboard.

### 8.1 N-1 — legacy JWT-based API keys disabled

| Item | Value |
|---|---|
| Mechanism | **Owner, Supabase dashboard:** Project Settings → API Keys → Legacy API Keys → **Disable JWT-based API keys**, on `edxicnafggnnvcdvxemk` / `stagerz-app` |
| Owner-stated boundaries | No key rotated or regenerated; the JWT secret was not changed; no publishable or secret API key was modified |
| **Tool-verified** (`get_publishable_keys`, state only, values not recorded) | Legacy `anon` key: **`disabled: true`** (was `false` at every earlier read). Publishable key: **unchanged** (same key id, `disabled: false`) |
| Legacy `service_role` key | **Not listed** by the available tooling, which returns publishable keys only, so it is not tool-verifiable here. Per Supabase documentation, legacy `anon` and `service_role` are disabled and re-enabled **together**, and the owner used that single control. Recorded as **disabled: owner-confirmed / documentation-consistent, not tool-verified** |
| Reversibility | Re-enable on the same dashboard page (see `rollback.sql`, non-database section). Not needed |

### 8.2 N-2 — new sign-ups disabled

| Setting (Authentication → Sign In / Providers) | State | Evidence level |
|---|---|---|
| Allow new users to sign up | **OFF** | **Owner / dashboard-confirmed** (not tool-verified; the tooling cannot read Auth settings) |
| Allow anonymous sign-ins | **OFF** | Owner / dashboard-confirmed |
| Confirm email | ON | Owner / dashboard-confirmed; unchanged |
| Providers, SMTP, URL settings, rate limits, users | Not intentionally changed | Owner statement |

- The **prior** value of "Allow new users to sign up" was not captured before the change, because the tooling could not read it. The owner changed only this setting.
- Consistency check (tool-verified): Auth users are still **2** and identities still **2**. The latest Auth user creation, sign-in and update are all still 2026-07-12. No account was created or changed.

### 8.3 Final read-only verification (`P221-FINAL-VERIFY-v1`, 2026-09-19 13:47:48 UTC)

| # | Check | Result |
|---|---|---|
| 1 | Target identity | `edxicnafggnnvcdvxemk` / `stagerz-app`, `eu-north-1`, ACTIVE_HEALTHY (not paused) — **PASS** |
| 2 | N-1: legacy anon key disabled | `disabled: true` — **PASS (tool-verified)**; `service_role`: owner-confirmed (§8.1) |
| 3 | Publishable key unchanged | same id, `disabled: false` — **PASS** |
| 4 | N-2 | sign-ups OFF, anonymous sign-ins OFF — **owner / dashboard-confirmed** |
| 5a | `anon` SELECT on the 6 tables | 0 — **PASS** |
| 5b | `anon` INSERT/UPDATE/DELETE | 0 — **PASS** |
| 5c | `authenticated` table / column access | 0 / 0 — **PASS** |
| 5d | Client TRUNCATE (and REFERENCES, TRIGGER, MAINTAIN) | 0 — **PASS** |
| 5e | Restrictive deny-all policies | 6/6 — **PASS** |
| 5f | Total policies | 24; the 18 legacy policies are byte-identical (md5 `a5ddf5ad03f8c5c333470e4af9e5d292`) — **PASS** |
| 5g | Table ACLs | md5 `c719d0752a9b549c50f23f6173420f1c`, identical to the post-apply state — **PASS** |
| 5h | Targeted `postgres` defaults: client privilege tuples | 0; entries 24 / global 0; the untargeted 20 unchanged (md5 `94a24e2550d616f304d33cc6f4b5d9a5`) — **PASS** |
| 5i | `rls_auto_enable()` | `{postgres=X/postgres,service_role=X/postgres}`; no PUBLIC grant; `anon`/`authenticated` false/false; definition md5 unchanged — **PASS** |
| 5j | Event trigger `ensure_rls` | enabled, bound to `rls_auto_enable()` — **PASS** |
| 5k | Tester rows | 3 / 5 / 0 / 0 / 0 / 0; 0 committed inserts, updates and deletes in `pg_stat_user_tables` — **PASS** |
| 5l | Auth | 2 users / 2 identities — **PASS** |
| 5m | Storage | 0 buckets / 0 objects / 0 policies; storage ACL md5s unchanged — **PASS** |
| 5n | Edge Functions | `[]` — **PASS** |
| 5o | Security Advisor | exactly 1 WARN: `auth_leaked_password_protection` (LG-5, accepted) — **PASS** |
| 5p | Migration history | `list_migrations` = `[]`; schema `supabase_migrations` absent — **PASS** |
| 5q | Test residue | `p221_probe` absent; exactly 6 relations in `public`; no leftover `anon` grant — **PASS** |
| 5r | Dependencies | Repository: 0 references outside `analysis/` and `.apos/`. `stagerz.app`, `www.stagerz.app` and `aquamarine-puppy-beccd9.netlify.app`: HTTP 200, 0 legacy references, 1 `kbnmkyvbwkuvcklywdhk` reference each — **PASS** |
| 6 | `kbnmkyvbwkuvcklywdhk` not modified | ACTIVE_HEALTHY; migration history 43 entries, latest `20260917143322 phase21_3_r5_w1_w3_w4`, as at the Phase 21.3 close. No write call was ever made to it in Phase 22.1 — **PASS** |
| 7 | Netlify and application code not modified | Netlify current deploy is still `6aae826b812cd80009b27a46` (ready). `index.html`, `.github`, `supabase/` and `CNAME` are unchanged versus `main` @ `eb3c640` and in the working tree — **PASS** |

## 9. Final status and closeout

| Finding | Final status |
|---|---|
| **LG-1** | **REMEDIATED / CONTAINED IN DEPTH.** Database access removed (R-1); restrictive deny-all policies active (R-2); legacy JWT-based API keys disabled (N-1); new sign-ups disabled and anonymous sign-ins OFF (N-2). The historical key stays visible in git history, but it is disabled and would reach no data even if it were not |
| **LG-2** | **REMEDIATED** for the scoped `postgres`-owned TABLE/SEQUENCE default privileges in `public` and `storage` (R-3). **Residual, documented separately:** the platform-owned `supabase_admin` defaults (24 privilege tuples; not alterable by `postgres`; they affect only objects created by `supabase_admin`, and not the contained tables or new `postgres` objects, per B-8), and the `postgres` FUNCTIONS defaults (O-1) |
| **LG-3** | **REMEDIATED** |
| **LG-4** | **REMEDIATED** |
| **LG-5** | **ACCEPTED / DEFERRED — not remediated** (Free plan; the feature needs a higher plan; the project is dormant; tester accounts only; its relevance is further reduced by N-1 and N-2) |
| **O-1** | **SKIPPED / OPTIONAL HARDENING**; not a Phase 22.1 blocker |

**Phase 22.1 — COMPLETE / PASS (2026-09-19).**

**Caveat:** PASS means the approved legacy containment objective was achieved. It does **not** mean that `edxicnafggnnvcdvxemk` has been deleted, paused, archived or migrated. The project remains ACTIVE with its tester data stored (3 `users` rows, 5 `wanted_posts`, 2 Auth accounts). **No current STAGERZ dependency exists** on it. The later **disposition decision** (keep locked down / pause / private export then delete) remains a **separate owner decision**. Future **Telegram integration** remains a separate product decision and is **not prohibited** by this phase.

**Remaining residual risks (all low):**
- The historical key stays in public git history. It is disabled and harmless.
- The platform-owned `supabase_admin` default privileges remain.
- The `postgres` FUNCTIONS defaults remain (O-1 skipped).
- Tester personal data is still stored, pending the disposition decision.
- The 18 legacy `true` policies remain, neutralised.
- LG-5 is accepted.
- The unpublished publishable key still reaches the gateway. It can reach no data, and sign-ups are off.
- The prior sign-up setting value was not captured.

`rollback.sql` was never run.
