# Phase 22.1 — Remediation Plan (legacy project `edxicnafggnnvcdvxemk`)

**Status:** **COMPLETE / PASS (2026-09-19).** R-1 … R-4 were applied and validated (Part B **PASS=66 / FAIL=0**). N-1 (legacy JWT-based API keys disabled; tool-verified) and N-2 (sign-ups OFF, anonymous sign-ins OFF; owner/dashboard-confirmed) were performed by the owner. The final verification passed. O-1 was skipped; LG-5 is accepted/deferred; historical-key HTTP testing was never performed; `rollback.sql` was never run. Evidence: `apply-validation-record-2026-09-19.md`. **Caveat:** PASS does not mean the legacy project was deleted, paused, archived or migrated; the disposition decision remains separate. The sections below are the plan as approved.
**Prepared:** 2026-09-19, on branch `phase-22.1-legacy-supabase-containment` from `main` @ `eb3c640`.

| File | Role |
|---|---|
| `remediation.sql` | Core changes R-1 … R-4 in one guarded DO block (pre-flight → changes → post-flight), plus optional O-1, commented out and **skipped by the owner** |
| `validation.sql` | Part A: read-only catalog checks. Part B: behavioural probes as `anon`/`authenticated`, always rolled back |
| `rollback.sql` | Section-selective inverse of R-1 … R-4, blocked unless an explicit approval flag is set in the same transaction |

---

## 1. Summary

The exposure has three layers:
1. a client credential that anyone can read in public git history;
2. database grants and `USING (true)` policies that give that credential full read and write access;
3. latent defaults that would expose future objects the same way.

**The fix is at layer 2 and layer 3, in the database.** After R-1 … R-4, no client credential — the historical anon JWT, the unpublished `sb_publishable_` key, or a signed-in user's JWT — can read or write any legacy table. The published key then gives nothing.

- Disabling the legacy key (N-1) is defence in depth that mainly closes the Auth-endpoint surface. It was approved in principle, then **performed by the owner on 2026-09-19** (§6; `apply-validation-record-2026-09-19.md` §8).
- Leaked-password protection (LG-5) **cannot be enabled on the current Free plan**. The owner has **accepted it as a deferred risk** (§6).
- O-1 (function default privileges) is **skipped for now** and recorded as optional residual hardening (§4.2).
- No data, user, table, column or legacy policy is removed.

---

## 2. Current-state evidence (read-only reconfirmation, 2026-09-19)

### 2.1 Results C-1 … C-16

| # | Check | Result | vs Phase 22.0 |
|---|---|---|---|
| C-1 | Identity / status | `stagerz-app`, `eu-north-1`, **ACTIVE_HEALTHY**, PostgreSQL 17.6.1.155, created 2026-06-25 17:06 UTC; org `STAGERZ` on **Free** plan | unchanged |
| C-2 | Public tables | 6 tables (`follows`, `likes`, `notifications`, `profiles`, `users`, `wanted_posts`), all owned by `postgres`; 0 views, 0 sequences; `users.id` is `bigint` (legacy v1 schema) | unchanged |
| C-3 | Table privileges | `anon` and `authenticated`: **`arwdDxtm`** (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN) on **all 6**; `service_role` same; `PUBLIC` none | unchanged |
| C-4 | Column privileges | No column grants beyond the table-level ones (0 extra) | new check |
| C-5 | RLS | Enabled on 6/6, forced on 0/6 | unchanged |
| C-6 | Policies | **18**, all `PERMISSIVE`, all `TO public`, every `USING` / `WITH CHECK` = **`true`**. `users`, `profiles`, `wanted_posts`, `notifications`: SELECT, INSERT, UPDATE (no DELETE policy). `follows`, `likes`: SELECT, INSERT, DELETE. Storage policies: 0 | unchanged |
| C-7 | Default privileges | 24 entries, 0 global. **`postgres`** in `public` and `storage` grants **ALL on TABLES, SEQUENCES, FUNCTIONS** to `anon`/`authenticated` (44 table/sequence privilege tuples). **`supabase_admin`** in `public`, `graphql`, `graphql_public` grants the same (platform-owned; `postgres` is **not** a member of `supabase_admin`, so it cannot alter these) | unchanged; platform entries newly noted |
| C-8 | `rls_auto_enable()` | `SECURITY DEFINER`, owner `postgres`, `search_path=pg_catalog`, returns `event_trigger`; used by event trigger **`ensure_rls`** (enabled, on CREATE TABLE / CREATE TABLE AS / SELECT INTO). ACL `{=X/postgres, postgres, anon, authenticated, service_role}`, so **`PUBLIC` also holds EXECUTE** | PUBLIC grant newly noted |
| C-9 | Client keys | 2 keys, **both enabled**: legacy `anon` JWT and one `sb_publishable_` key. The anon JWT in git history (**6** `index.html` commits) decodes to the same `ref`, `role`, `iat` 1782407197 (2026-06-25 17:06:37 UTC) and `exp` 2097983197 (2036-06-25) as the enabled key. It is the same, still-valid credential. The publishable key appears nowhere in the repository. **No key value recorded** | unchanged |
| C-10 | Auth aggregates | 2 users (1 confirmed), 2 identities, 2 sessions, 2 refresh tokens, 0 audit entries; last creation / sign-in / update all **2026-07-12** | unchanged |
| C-11 | Row counts | `users` 3, `wanted_posts` 5, `profiles` 0, `notifications` 0, `follows` 0, `likes` 0 | unchanged |
| C-12 | Storage | 0 buckets, 0 objects, 0 storage policies | unchanged |
| C-13 | Edge Functions | none; migration history: none | unchanged |
| C-14 | Security Advisor | 3 WARN: `anon_security_definer_function_executable` (`rls_auto_enable`), `authenticated_security_definer_function_executable` (same), `auth_leaked_password_protection`. The always-true policies are **not** flagged | unchanged |
| C-15 | Dormancy | Latest `public.users` write 2026-06-25; latest `wanted_posts` insert 2026-06-25; latest Auth activity 2026-07-12. `pg_stat_user_tables`: 0 inserts, updates and deletes on all 6 tables since the stats epoch. **Last 24 h gateway log (16 requests):** only platform probes (`/auth/v1/health` ×6, `/rest-admin/v1/ready` ×6, `/admin/v1/network-bans/retrieve` ×4); **0** requests to `/rest/v1`, `/graphql/v1` or user-facing `/auth/v1`. No other log source shows client activity | consistent — dormant |
| C-16 | Dependencies | Current tree: 0 references outside `analysis/` and `.apos/`. `.github/workflows/process-pending-asset-deletions.yml` targets `kbnmkyvbwkuvcklywdhk` only. `supabase/functions/*`: no reference. No `netlify.toml`, `_redirects` or `_headers`. Live HTML of `stagerz.app`, `www.stagerz.app` and `aquamarine-puppy-beccd9.netlify.app`: 0 legacy references, 1 reference to `kbnmkyvbwkuvcklywdhk` each. Netlify site `aquamarine-puppy-beccd9` current deploy is `ready`, with no build step and no Forms | unchanged — **no dependency** |

### 2.2 Queries run (all read-only)

- **Metadata:** `get_project`, `get_organization`, `list_edge_functions`, `list_migrations`, `get_advisors` (security), `get_publishable_keys` (state only; values not recorded).
- **Catalog SQL:**
  - `P221-PRECHANGE-CATALOG-v1`;
  - `P221-PRECHANGE-AGG-v1` (counts and timestamps only);
  - `P221-PRECHANGE-FINGERPRINT-v1`;
  - per-table `relacl`;
  - column names and types (no values);
  - a `pg_default_acl` breakdown.
- **Validation baseline:** `validation.sql` Part A (§7.3).
- **Logs:** two aggregate queries over the 24-hour log window, returning counts by source and by method/path/status. No IPs, headers or bodies were read.
- **Offline:** git-history claim decoding (header and payload only; no token printed); public HTTPS `GET` of the three live URLs; Netlify site metadata.

### 2.3 Pre-change fingerprints (embedded as guards in `remediation.sql`)

| Fingerprint | Value |
|---|---|
| `public` relation ACLs (md5) | `ff81dd8ad8ae8264d531931a0cbd52f0` |
| `public` policies (md5, 18) | `a5ddf5ad03f8c5c333470e4af9e5d292` |
| `pg_default_acl` all 24 (md5) | `5a6e897e1a22110d8b9cefb7c128cfa6` |
| `pg_default_acl` untargeted 20 (md5) | `94a24e2550d616f304d33cc6f4b5d9a5` |
| `rls_auto_enable()` definition (md5) | `6998ea6b4c2480f5d2e34b5dcf3f8d36` |
| `public` columns (md5) | `e038cf2a45b7c033e4cb4a5e81bf0779` |
| `storage` relation ACLs / function ACLs (md5) | `04360dda0d641c7805b22e23d8c6e59b` / `c90dd3853e9865ba8ca26d33bade167f` |

---

## 3. Threat and containment analysis

| Layer | What it is | Current state | Controlled by | Containment |
|---|---|---|---|---|
| **A. Public credential exposure** | The legacy anon JWT is in public git history and still enabled | Exposed. **Permanent**: history is public and forked/cached copies may exist, so it cannot be recalled | Key state (N-1) | Treated as **public by design**. Rotating or disabling it is optional hardening (§6), not the primary control |
| **B. Database authorization** | What the `anon` / `authenticated` roles may do once the gateway admits a request | Full DML plus TRUNCATE on all 6 tables; every policy `true`, so RLS admits every row | Grants (R-1) and RLS policies (R-2) | **Primary control.** Two independent layers: no privileges at all, plus a restrictive deny-all policy |
| **C. Future-object exposure** | New tables, views or sequences created by `postgres` inherit ALL for client roles | Latent (no DDL since 2026-06-25) | Default ACL (R-3) | Revoke client roles from the `postgres` defaults in `public` and `storage` (the S-5 fix from Phase 21.6). Functions: optional O-1 |
| **D. Function exposure** | `rls_auto_enable()` is `SECURITY DEFINER` and executable by `PUBLIC`/`anon`/`authenticated` | Low: an event-trigger function cannot run its body via RPC. The Advisor still flags it | Function ACL (R-4) | Revoke EXECUTE from `PUBLIC`, `anon`, `authenticated`. The event trigger keeps firing (proven by validation B-7c) |
| **E. Auth hardening** | Leaked-password protection; sign-up and email endpoints reachable with the anon key | Protection disabled (not available on Free); sign-up setting UNKNOWN (not readable by tooling) | Auth configuration (N-2), key state (N-1), plan | Not changed now; see §6 |

**Why the database layer must be the primary control.**
- Any client key is by design embedded in shipped code, and the one at issue is already public.
- The publishable key is not a secret either.
- A signed-in user's JWT maps to `authenticated`, and currently that role has the same full access. So "rotate the key" alone would leave:
  - anyone holding the new key able to read and write everything;
  - any signed-in user able to do the same.
- Only B (and C for the future) removes the capability itself.

**Access paths after R-1 … R-4:**
- **PostgREST `/rest/v1`:** `42501` on every table, for both roles.
- **`/rest/v1/rpc/rls_auto_enable`:** `42501`.
- **pg_graphql `/graphql/v1`:** the schema reflects only granted objects, so it exposes nothing.
- **Storage:** nothing to reach (0 buckets, and no storage policies).
- **Realtime:** no publication membership.
- **Remaining client-reachable surface:** Auth endpoints (sign-up, sign-in, password recovery). They cannot reach table data, because `authenticated` holds nothing (§8).

---

## 4. Exact proposed changes

### 4.1 Core set — database (`remediation.sql`, one guarded transaction)

| # | Statement(s) | Why | Finding |
|---|---|---|---|
| **R-1** | `REVOKE ALL ON TABLE public.follows, public.likes, public.notifications, public.profiles, public.users, public.wanted_posts FROM anon, authenticated;` | Removes every client-role privilege, including TRUNCATE, REFERENCES, TRIGGER and MAINTAIN. `REVOKE ALL` rather than a list, so no privilege type is missed (the lesson of S-6). `service_role` and `postgres` are untouched | LG-1 (B), **LG-3** |
| **R-2** | For each of the 6 tables: `CREATE POLICY p221_containment_deny_client ON public.<t> AS RESTRICTIVE FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);` plus a `COMMENT` naming this phase | Defence in depth. Restrictive policies are AND-ed with permissive ones, so even if privileges were re-granted by mistake, the legacy `true` policies can no longer admit a row. **Additive:** the 18 legacy policies are kept, unchanged, as historical record. Lockdown semantics are explicit, and rollback is a simple `DROP POLICY` | LG-1 (B) |
| **R-3** | `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;` and the same for `public`/SEQUENCES, `storage`/TABLES and `storage`/SEQUENCES (4 statements) | Future tables, views and sequences created by `postgres` no longer auto-grant client roles. Identical to the Phase 21.6 S-5 fix applied on the live project (`FOR ROLE postgres` and `IN SCHEMA` are both mandatory) | **LG-2** (tables/sequences) |
| **R-4** | `REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;` | Clears both Advisor WARNs. `PUBLIC` must be included, or `anon` keeps EXECUTE through it. `service_role` and `postgres` are unchanged. Event-trigger firing does not check the caller's EXECUTE privilege, and B-7c verifies this behaviourally | **LG-4** |

**Guards built into the block:**
- **Pre-flight:**
  - runs as `postgres`;
  - wrong-project guard: aborts if `collaboration_assets` exists, which is present only on `kbnmkyvbwkuvcklywdhk`;
  - exactly 6 relations, and `users.id` is `bigint`;
  - every §2.3 fingerprint matches;
  - the `rls_auto_enable()` ACL matches;
  - containment is not already applied;
  - row, Auth and Storage counts match.
- **Post-flight:**
  - every table ACL is exactly `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`;
  - no table or column privilege remains for client roles;
  - 6 correct restrictive policies exist, 24 in total, and the 18 legacy policies are byte-identical;
  - no client role remains in the targeted default ACLs; still 24 entries and 0 global; the 20 untargeted entries are unchanged;
  - the function ACL is exactly `{postgres=X/postgres,service_role=X/postgres}`, its definition is unchanged, and `ensure_rls` is still enabled;
  - columns, storage ACLs, row counts, Auth count and Storage counts are unchanged.
- **Any mismatch raises**, and the entire block, changes included, rolls back.

**Execution method:** a direct `execute_sql`, **not** `apply_migration`. This project has no `supabase_migrations` schema; the migration tool would create one, which would be an extra, unapproved change. This is the same reasoning as Phases 21.5 and 21.6.

### 4.2 Optional O-1 — function default privileges (database; commented out in `remediation.sql`) — **SKIPPED by the owner (2026-09-19)**

> **Owner decision:** skip for now. It is broader than the concrete findings and not necessary to contain LG-1 … LG-4. It is recorded as an **optional residual hardening item (RR-4), not a Phase 22.1 blocker**. The statements stay commented out and will not be executed in this phase.

The statements are:
- `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;`
- the same for `storage`;
- plus the **global** `ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;`

Considerations:
- Without the global `PUBLIC` revoke, the per-schema revoke is cosmetic, because PostgreSQL's built-in default grants EXECUTE to `PUBLIC` anyway (Phase 21.6 rule 5).
- The global statement applies to every function `postgres` creates in any schema. On this dormant project it has no practical downside, but it goes beyond the recorded findings.
- **Result of skipping it:** LG-2 will be "resolved for tables and sequences; function defaults residual".

### 4.3 What is deliberately NOT changed

- The 18 legacy policies: kept and neutralised by R-2.
- RLS `FORCE`: `postgres` is the owner and the maintenance role; forcing adds nothing against clients.
- `USAGE` on schema `public` for `anon`/`authenticated`: this is the Supabase standard. Without any object privileges it grants nothing readable. Revoking it is possible but non-standard, and is not needed.
- `service_role` privileges: server-side only, and the `service_role` key is not public.
- The `supabase_admin` default ACLs: platform-owned and not alterable by `postgres`; see §8.
- All data, users, Storage, Edge Functions, event triggers, extensions and project settings.
- Anything on `kbnmkyvbwkuvcklywdhk`, the app and Netlify.

---

## 5. Order of operations and gates

| Step | Action | Gate to proceed |
|---|---|---|
| 0 | **Owner review** of this plan. Decide R-1 … R-4 (core), O-1, N-1 and N-2 | **DONE 2026-09-19** (§11) |
| 1 | Commit and push this plan (analysis files + context) as a checkpoint **before** any change, as in Phase 21.6 | **Approved 2026-09-19**; this checkpoint commit |
| 2 | Re-run the read-only pre-flight: validation Part A, which must reproduce the §7.3 baseline exactly | Identical baseline, otherwise stop and re-plan |
| 3 | **Apply `remediation.sql`** (one execution) | Block returns the `P221 containment applied … PASS` notice. On any exception nothing changed: stop and report |
| 4 | Run validation Part A (post) | All V-1 … V-10 values as bracketed |
| 5 | Run validation Part B (rolled back) | `VALIDATION RESULTS (rolled back): PASS=66 FAIL=0` |
| 6 | Security Advisor, Edge Functions, key state, 24-hour log aggregate | V-10 / V-12 as expected |
| 7 | V-11: the live app is unaffected | Live sites unchanged: 200, `kbnmkyvbwkuvcklywdhk` only |
| 8 | ~~Apply O-1~~ — **skipped by the owner**; not executed in this phase | — |
| 9 | N-1 (approved in principle): disable the legacy API keys in the dashboard, only after steps 3–7 pass and with the owner's go-ahead for that action | Key list (state only) shows the legacy anon key `disabled: true`, and the publishable key unchanged |
| 10 | N-2 (approved in principle): record the current sign-up setting first (the owner reads it in the dashboard, because the tooling cannot), then disable sign-ups, with the owner's go-ahead for that action | Setting recorded before and after |
| 11 | Document the results, update `PROJECT_CONTEXT.md`, commit, push, open a PR | Owner review |

**Stop rule:** any unexpected result at any gate stops the sequence. There is no improvisation and no partial retries; the finding is reported to the owner.

---

## 6. Non-database actions — proposed, not applied

### N-1 — Disable the legacy JWT API keys. **APPROVED IN PRINCIPLE (2026-09-19) — NOT YET EXECUTED.** It is performed only after the database lockdown is validated (§5, step 9).

**What it does:**
- Dashboard → Project Settings → API Keys → "Legacy API keys" → **Disable**.
- This disables the legacy `anon` **and** legacy `service_role` JWTs **together** (per Supabase docs, "Disable or re-enable JWT based legacy (anon, service_role) API keys").
- It is reversible: they can be re-enabled.
- The `sb_publishable_` key keeps working, and it is not published anywhere.

**What it adds beyond the database lockdown:**
1. The **published credential stops working at the gateway** for every API, including those the database lockdown does not cover:
   - Auth sign-up and sign-in;
   - password-recovery and OTP emails to the 2 tester addresses;
   - sign-up spam, if sign-ups are enabled.
2. It removes the legacy `service_role` JWT as well. That key is secret and unused (no Edge Functions, no workflows), so disabling it reduces the blast radius if it ever leaked.
3. It makes LG-1's layer A **moot** rather than merely harmless.

**What it does not do:**
- It does **not** protect the data by itself: the publishable key and any user JWT would still reach the database without R-1 … R-4.
- It is therefore **not a substitute** for the database changes.

**Impact:**
- nothing depends on this project (C-16);
- `kbnmkyvbwkuvcklywdhk` is a different project with its own keys and is unaffected.

**Verdict:** **Not necessary for data containment** (V-13 holds without it); cheap, reversible defence in depth. **Owner decision: approved in principle, not yet executed.**

### N-2 — Disable new-user sign-ups. **APPROVED IN PRINCIPLE (2026-09-19) — NOT YET EXECUTED.** The current setting must be confirmed first, if possible (§5, step 10).

- The current value is **UNKNOWN**: Auth configuration is not readable with the available read-only tooling. The owner can check it under Dashboard → Authentication → Sign In / Providers → "Allow new users to sign up".
- After R-1 … R-4, a new sign-up gets an `authenticated` session that can reach no data. The residual concerns are:
  - junk `auth.users` rows;
  - use of the project's mailer.
- N-1 already blocks sign-up with the published key. N-2 closes it for the publishable key too.

**Recommendation:** disable, if the owner confirms that no tester needs to sign up. Record the prior value first.

### LG-5 — Leaked-password protection. **ACCEPTED / DEFERRED — accepted risk, not remediated (owner decision 2026-09-19).**

- Per Supabase docs, it is **available on the Pro plan and above**. The organisation is on **Free** (C-1), so it **cannot be enabled** without a plan change. That is out of scope.
- **Relevance while Auth stays intact is minimal:**
  - it checks passwords only when they are set or changed;
  - the 2 dormant tester accounts have existing passwords;
  - with N-1 and/or N-2 there is no new sign-up path;
  - the accounts can reach no data after R-1.
- The same WARN exists on `kbnmkyvbwkuvcklywdhk`, and a plan decision would cover both projects.

**Owner decision:** LG-5 is recorded as **DEFERRED / ACCEPTED RISK, not remediated**. The reasons: the project is on Free and the feature needs a higher plan; the project is dormant; only tester accounts exist; and containment plus sign-up and key disabling materially reduce its relevance. Notes:
- It is to be revisited in the later disposition decision.
- It disappears if the project is paused or deleted.
- It would also be settled by any plan upgrade taken for the live project.

---

## 7. Validation plan

### 7.1 Checks

| # | Check | How | Expected after |
|---|---|---|---|
| V-1 | `anon` has no effective SELECT | Part A: `has_table_privilege` + deny-policy presence. Part B: B-1 `SELECT` as `anon` on 6 tables | 0 tables; 6 deny policies; B-1 `42501` ×6 |
| V-2 | `anon` has no INSERT/UPDATE/DELETE | Part A. Part B: B-2/B-3/B-4 as `anon` | 0; `42501` ×18 |
| V-3 | `authenticated` has no broad access | Part A (table + column). Part B: B-1 … B-5 as `authenticated` | 0; `42501` ×30 |
| V-4 | No TRUNCATE for client roles | Part A `V4_truncate_etc_tables`. Part B: B-5 for both roles | 0; `42501` ×12 |
| V-5 | Defaults no longer auto-grant | Part A `V5_client_defacl_priv_tuples`. Part B: B-8, a new table created by `postgres` in the rolled-back block | 0 (was 44); B-8 PASS |
| V-6 | `rls_auto_enable()` not client-executable; event trigger still works | Part A `V6_*`. Part B: B-7a/b (call as `anon`/`authenticated`); B-7c (new table has RLS on) | false/false, ACL `{postgres=X/postgres,service_role=X/postgres}`; `42501` ×2; B-7c PASS |
| V-7 | Tester row counts unchanged | Part A `V7_rows`, plus pre/post-flight in `remediation.sql` | 3 / 5 / 0 / 0 / 0 / 0 |
| V-8 | Auth user count unchanged | Part A `V8_*` | 2 users, 2 identities |
| V-9 | Storage unchanged | Part A `V9_*` | 0 / 0 / 0 |
| V-10 | No Edge Functions added or changed | `list_edge_functions` | `[]` |
| V-11 | No current-app dependency broken | Re-fetch the 3 live URLs (HTTP 200, only the `kbnmkyvbwkuvcklywdhk` reference); workflow and Netlify unchanged. The app never calls this project | unchanged |
| V-12 | Security Advisor reconciled | `get_advisors` (security) | The two `*_security_definer_function_executable` WARNs are **gone**. `auth_leaked_password_protection` **remains** (LG-5, accepted/deferred). No new lint |
| V-13 | The historical key is no longer security-relevant | Composite of V-1 … V-6, plus Part B **B-6**: inside the rolled-back block, SELECT and INSERT are re-granted to `anon` on `wanted_posts` to simulate a future mistake. Rows visible must be 0, and INSERT must fail with `42501` (RLS) | B-6a/b PASS. The data is unreachable by any client role even with the key valid, and even after an accidental re-grant |
| V-14 | If the key is disabled (N-1), document the gain | After step 9: `get_publishable_keys` (state only), plus a 24-hour log aggregate of gateway `401`s on legacy-key use | §6 N-1 items 1–3 recorded as observed |

**V-13b — HTTP probe with the historical key: NOT APPROVED (owner decision 2026-09-19), removed from the plan.**
- The historical credential must not be actively exercised, at any step.
- V-13 rests entirely on catalog checks, role checks and the rollback-only Part B probes. Part B exercises the same role that PostgREST switches to (`authenticator` → `anon`) without using any client key.
- V-14 likewise uses only key **state** (`disabled` flag) and aggregate gateway logs, never a request made with the key.

### 7.2 Behavioural test design (Part B)

- It runs as `postgres` and switches role with `SET LOCAL ROLE` to `anon` and then `authenticated`. That is the same role switch PostgREST performs. Verified read-only: `postgres` is a member of both roles, and `authenticator` is a member of `anon`.
- **Total: 66 probes:**
  - 60 (2 roles × 6 tables × 5 operations);
  - 2 (B-6 re-grant);
  - 3 (B-7a, B-7b, B-7c);
  - 1 (B-8).
- Each probe passes only on the exact expected outcome. For B-7a/b, SQLSTATE `0A000` (trigger-function call) would mean the EXECUTE check was passed, so it counts as a FAIL.
- Probes use `DEFAULT VALUES`, `WHERE false` and `count(*)`, so no row content is ever returned.
- The block **refuses to run before remediation**: it checks that the deny policy exists, so pre-change write probes can never execute. It **always** ends in `RAISE EXCEPTION 'VALIDATION RESULTS (rolled back): …'`, so the probe table, the simulated re-grant and every attempt are discarded.

### 7.3 Pre-change baseline (Part A, run read-only 2026-09-19)

| Key | Pre-change | Expected post |
|---|---|---|
| `V1_anon_select_tables` | **6** | 0 |
| `V2_anon_dml_tables` | **6** | 0 |
| `V3_authenticated_any_tables` | **6** | 0 |
| `V3_column_priv_tables` | **6** | 0 |
| `V4_truncate_etc_tables` | **6** | 0 |
| `V1_deny_policy_tables` | 0 | **6** |
| `V1_rls_enabled_tables` | 6 | 6 |
| `V1_policies_total` | 18 | **24** |
| `V5_client_defacl_priv_tuples` | **44** | 0 |
| `V5_defacl_entries` / `V5_defacl_global` | 24 / 0 | 24 / 0 (O-1 skipped) |
| `V5_platform_defacl_tuples` | 24 | 24 (residual, §8) |
| `V6_rls_auto_enable_anon` / `_auth` | **true / true** | false / false |
| `V6_rls_auto_enable_acl` | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | `{postgres=X/postgres,service_role=X/postgres}` |
| `V6_event_trigger_enabled` | true | true |
| `V7_rows` | 3 / 5 / 0 / 0 / 0 / 0 | unchanged |
| `V8_auth_users` / `V8_auth_identities` | 2 / 2 | unchanged |
| `V9_storage_*` | 0 / 0 / 0 | unchanged |
| `fp_col_md5` / `fp_fn_def_md5` | `e038cf2a…0779` / `6998ea6b…8d36` | unchanged |
| `max_activity` | ≤ 2026-07-12 | ≤ 2026-07-12 |

---

## 8. Rollback plan

`rollback.sql` restores **only** what R-1 … R-4 changed. Each section can be rolled back on its own:

| Section | Undoes |
|---|---|
| R-1 | `GRANT ALL` on the 6 tables to `anon`, `authenticated` |
| R-2 | `DROP POLICY` on the 6 containment policies |
| R-3 | `GRANT ALL` on the 4 default-ACL entries |
| R-4 | `GRANT EXECUTE` to `PUBLIC`, `anon`, `authenticated` |

- **O-1 and the non-database actions:** their inverses are documented at the end of the file. For N-1: re-enable the legacy keys. For N-2: restore the recorded sign-up value.
- **Accidental-execution guard:** the block raises and changes nothing unless the **same transaction** first runs `SET LOCAL p221.rollback_approved = '<sections>'`. The flag expires at commit, so an approval cannot carry over into a later run. Unknown section names are rejected.
- **Semantic restoration:** GRANT appends ACL items, so ACL text order differs from the original while the privilege set is identical. Verification is set-based.
- **Consequence:** a full rollback **re-opens LG-1 … LG-4**. It is for a confirmed regression only, and none is anticipated because nothing depends on this project. **It must never run without separate owner approval.**
- **Selective use case:** if `ensure_rls` ever failed to fire after R-4 (B-7c guards against this), R-4 alone can be rolled back while everything else stays in place.

---

## 9. Residual risks after the core remediation

| # | Residual | Severity after | Mitigation / owner |
|---|---|---|---|
| RR-1 | The historical anon JWT stays in public git history permanently | **None** for data (V-13). Low for Auth-endpoint abuse until N-1 | N-1. A history rewrite is not proposed: it is ineffective for already-public data, and disruptive |
| RR-2 | Auth endpoints reachable with any client key (sign-up, sign-in, recovery emails) | Low | N-1 (published key) and N-2 (all keys) |
| RR-3 | `supabase_admin`-owned default ACLs in `public` still grant `anon`/`authenticated` (24 privilege tuples) for objects **created by `supabase_admin`** | Low, latent. The platform does not create application tables in `public`; the same state exists on the live project | Not alterable by `postgres`. Accepted as platform-owned |
| RR-4 | Function defaults (`postgres` per-schema FUNCTIONS entries, plus the built-in `PUBLIC` EXECUTE) | Low, latent. No function DDL expected | O-1, **skipped by the owner**. Kept as an optional residual hardening item, not a Phase 22.1 blocker |
| RR-5 | Tester personal data still stored (3 `users` rows including one Telegram-range profile, 2 Auth emails) | Low once unreachable by clients | Later disposition decision (keep / pause / export+delete); out of scope here |
| RR-6 | The 18 legacy `USING (true)` policies still exist | None while R-1 **or** R-2 holds. Both must be undone to re-expose | Kept deliberately as record. Can be dropped in the disposition phase |
| RR-7 | `service_role` / `postgres` retain full access | By design; secret or server-side only | N-1 disables the legacy `service_role` JWT too |
| RR-8 | LG-5 leaked-password protection unavailable on Free | Low | **Accepted risk / deferred** by the owner (§6) |
| RR-9 | Free-plan platform behaviour (for example an inactivity pause) could change project state independently | Informational | Owner awareness. A pause would reduce exposure further |

---

## 10. Expected end status of LG-1 … LG-5

Expected, given the owner decisions (O-1 skipped; N-1 and N-2 approved in principle):

| Finding | Core R-1 … R-4 (approved) | + N-1 (approved in principle) | + N-2 (approved in principle) |
|---|---|---|---|
| **LG-1** | **Resolved for data** (no client read or write; layers B and C closed); credential exposure A remains, harmless for data | **Fully resolved** (credential dead at the gateway) | Auth surface closed for all keys |
| **LG-2** | **Largely resolved** (tables and sequences in `public`/`storage`). Function defaults residual (O-1 skipped, RR-4); platform defaults residual (RR-3) | — | — |
| **LG-3** | **Resolved** | — | — |
| **LG-4** | **Resolved** (Advisor WARNs ×2 cleared) | — | — |
| **LG-5** | **ACCEPTED / DEFERRED — accepted risk, not remediated** (owner decision) | Relevance reduced | Relevance reduced |

## 11. Owner decisions — recorded 2026-09-19

| # | Item | Decision | Execution status |
|---|---|---|---|
| 1 | Core R-1 … R-4 | **APPROVED** | **APPLIED 2026-09-19 and validated (66/0)**; see `apply-validation-record-2026-09-19.md` |
| 2 | O-1, function default privileges | **SKIPPED for now**: broader than the findings and not needed for LG-1 … LG-4 | Optional residual hardening item (RR-4); not a blocker |
| 3 | N-1, disable the legacy API keys | **APPROVED IN PRINCIPLE**, then authorized | **PERFORMED** (owner, dashboard); tool-verified `disabled: true` |
| 4 | N-2, disable sign-ups | **APPROVED IN PRINCIPLE**, then authorized | **PERFORMED** (owner, dashboard): sign-ups OFF, anonymous OFF; owner-confirmed |
| 5 | LG-5 | **ACCEPTED / DEFERRED — accepted risk, not remediated** | — |
| 6 | V-13b HTTP probe with the historical key | **NOT APPROVED**; the historical credential is not to be exercised | Removed from validation |
| 7 | Pre-change checkpoint (commit and push this plan) | **APPROVED** | Done: `b31bd26`, pushed |

**Observed result (2026-09-19), replacing the "expected" wording of §10:**
- **LG-1:** contained at the database-authorization layer, pending N-1.
- **LG-2:** remediated for the `postgres` TABLE/SEQUENCE defaults (R-3). Platform-owned `supabase_admin` defaults and the `postgres` FUNCTIONS defaults are residual.
- **LG-3:** remediated.
- **LG-4:** remediated.
- **LG-5:** accepted/deferred.

Details: `apply-validation-record-2026-09-19.md` §6.
