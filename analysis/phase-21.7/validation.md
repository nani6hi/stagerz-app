# Phase 21.7 — Validation Record

**Branch:** `phase-21.7-s6-s7-privilege-cleanup`
**Base commit:** `452b12b`
**Validation level:** **1** — documentation and a prepared backend-only migration; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **Preparation validated. Mutation NOT APPROVED and NOT APPLIED. All mutation-dependent results are PENDING.**

No backend write has been performed or attempted at any point in this phase.

---

## 1. What this record claims, and what it does not

**Claims:** the three files in `analysis/phase-21.7/` are internally consistent, safe to hold in the repository unexecuted, and faithful to the live state captured read-only on 2026-09-12.

**Does not claim:** anything about the outcome of the mutation. It has not run. Every entry in §3–§6 reads **PENDING** and must not be reported otherwise until the mutation is approved, applied and checked.

> **Naming collision — read this.** The check ids `P-1…P-8` in §2 are repository-safety checks and are **not** the security findings `S-1…S-7`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of this writing: **S-1, S-2 and S-5 REMEDIATED**; **S-3, S-4, S-6 and S-7 OPEN**.

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — not in the diff; no application source touched |
| **P-2** | Phases 21.3, 21.4, 21.5 and 21.6 artifacts unmodified | **PASS** — none in the diff. `backend-contract.md` §0.2 still records S-6 and S-7 as OPEN, which remains true until this phase is applied |
| **P-3** | `.apos/PROJECT_CONTEXT.md` records preparation state only | **PASS** — a Phase 21.7 row marked PREPARATION ONLY; no finding is marked remediated |
| **P-4** | `migration.sql` contains exactly seven executable statements | **PASS** — see §2.1 |
| **P-5** | All seven are `REVOKE`; no `GRANT`, `ALTER`, `DROP`, `CREATE` or `CASCADE` in executable code | **PASS** — see §2.1 |
| **P-6** | Exact object identities used — one table, three zero-argument functions | **PASS** — see §2.1 |
| **P-7** | `migration.sql` is unambiguously marked as not yet applied | **PASS** — `EXECUTABLE MIGRATION - NOT YET APPLIED`; `Applied: NOT APPLIED`; `Approved by: NOT APPROVED - preparation only` |
| **P-8** | No backend write performed or attempted | **PASS** — no SQL of any kind was issued during preparation |

### 2.1 Statement counting — and the artefact it avoids

`migration.sql` contains `GRANT`, `REVOKE`, `MAINTAIN`, `EXECUTE` and the three function names inside `--` comments — in the six rules, the pre-change state, the expected post-state, the rollback block and the out-of-scope list. A raw `grep` therefore **over-counts**, the same class of artefact recorded for `haptic(` in Phase 20.5, `NOT A MIGRATION` in Phase 21.4, `CASCADE` in Phase 21.5 and `GRANT` in Phase 21.6.

Counts are taken **after stripping comment lines** and splitting on `;`. Those are the only authoritative figures. The seven executable statements are:

```sql
REVOKE MAINTAIN ON TABLE public.users FROM anon, authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM authenticated
```

**The rollback block is commented out** and is excluded by comment stripping. It is the only place `GRANT` appears.

---

## 3. Pre-flight requirements — HARD STOP ON MISMATCH

Re-run **immediately before** applying `migration.sql`, not earlier.

### 3.1 S-6 — `public.users`

| # | Requirement | Expected | Status |
|---|---|---|---|
| **F-1** | relacl, byte-exact | `{postgres=arwdDxtm/postgres,anon=m/postgres,authenticated=m/postgres,service_role=arwdDxtm/postgres}` | **PENDING** |
| **F-2** | `anon` effective privileges | MAINTAIN **true**; SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER all **false** | **PENDING** |
| **F-3** | `authenticated` effective privileges | identical to F-2 | **PENDING** |
| **F-4** | `service_role` / `postgres` | full `arwdDxtm` | **PENDING** |
| **F-5** | **Column grants — exactly seven** | `authenticated`: `id=r`; `username, first_name, last_name, photo_url, bio, location = rw` | **PENDING** |
| **F-6** | RLS state | `enabled=true, forced=false` | **PENDING** |
| **F-7** | Policies — exactly two | `authenticated can read own row` (SELECT); `active users can update own row` (UPDATE) — expressions captured verbatim | **PENDING** |
| **F-8** | Triggers | **0** | **PENDING** |
| **F-9** | No indirect path to MAINTAIN | `anon` and `authenticated` are members of no role; no `PUBLIC` grant on the table | **PENDING** |

### 3.2 S-7 — the three functions

| # | Requirement | Expected | Status |
|---|---|---|---|
| **F-10** | Exact identities | `public.log_collaboration_asset_activity()`, `…_credit_activity()`, `…_message_activity()` — all zero-argument | **PENDING** |
| **F-11** | proacl, byte-exact, all three | `{=X/postgres,postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | **PENDING** |
| **F-12** | Execution state | `PUBLIC` **true**, `anon` **true** (via PUBLIC only), `authenticated` **true**, `service_role` **true** | **PENDING** |
| **F-13** | Definitions | owner `postgres`, `plpgsql`, SECURITY DEFINER, VOLATILE, returns `trigger`, `search_path = ''`; bodies captured verbatim for later comparison | **PENDING** |
| **F-14** | Triggers | `trg_log_collaboration_asset_activity` AFTER INSERT on `collaboration_assets`; `…_credit_activity` on `collaboration_credits`; `…_message_activity` on `collaboration_messages` | **PENDING** |
| **F-15** | No other dependencies | `pg_depend` shows only those three triggers | **PENDING** |

### 3.3 Control case and environment

| # | Requirement | Expected | Status |
|---|---|---|---|
| **F-16** | `handle_new_auth_user()` proacl | `{postgres=X/postgres,service_role=X/postgres}`; `anon`=false, `authenticated`=false; trigger `on_auth_user_created` on `auth.users` | **PENDING** |
| **F-17** | ACL fingerprints captured | `public` relations, `public` functions, `storage` relations, `storage` functions, **and all `public` column grants** | **PENDING** |
| **F-18** | Security Advisor baseline | 5 lints / 35 findings — 1 ERROR, 32 WARN, 2 INFO | **PENDING** |
| **F-19** | **Executing DB role is `postgres`** | `current_user` = `session_user` = `postgres`, or a member of it | **PENDING** |
| **F-20** | Repository clean on this branch, `migration.sql` committed and pushed | clean, on `origin` | **PENDING** |
| **F-21** | Explicit production-mutation approval | given | **PENDING — NOT GIVEN** |

**F-17 closes the gap found in Phase 21.6**, whose fingerprints covered table and function ACLs but not column ACLs. Column grants are fingerprinted here from the start, because F-5 is the highest-consequence check in this phase.

---

## 4. Post-change checks — ALL PENDING

**No result below has been observed. The mutation has not run.**

| # | Check | Passes when | Status |
|---|---|---|---|
| **M-1** | All seven statements applied | each targeted grant is gone; no partial application | **PENDING** |
| **M-2** | `public.users` relacl | exactly `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` — `anon` and `authenticated` entries absent entirely | **PENDING** |
| **M-3** | **Seven column grants byte-identical** | all seven present and unchanged vs F-5 — **the highest-consequence check in this phase** | **PENDING** |
| **M-4** | `public.users` RLS byte-identical | `enabled=true, forced=false`; both policies unchanged in name, command and expression | **PENDING** |
| **M-5** | `public.users` triggers | still **0** | **PENDING** |
| **M-6** | MAINTAIN removed **only** | `anon`/`authenticated` hold no table-level privilege; `service_role` and `postgres` keep full `arwdDxtm` | **PENDING** |
| **M-7** | All three functions' proacl | exactly `{postgres=X/postgres,service_role=X/postgres}` | **PENDING** |
| **M-8** | Execution state | `PUBLIC`=false, `anon`=false, `authenticated`=false, `service_role`=true, `postgres`=true, all three | **PENDING** |
| **M-9** | Function definitions byte-identical | owner, SECURITY DEFINER, volatility, `search_path` and **bodies** unchanged vs F-13 | **PENDING** |
| **M-10** | Triggers byte-identical | all three present, same names, timing, events and tables vs F-14 | **PENDING** |
| **M-11** | Unrelated ACLs unchanged | all five fingerprints from F-17 identical — relations, functions and column grants across `public` and `storage` | **PENDING** |
| **M-12** | `handle_new_auth_user()` unchanged | identical to F-16 — the control case must still hold | **PENDING** |
| **M-13** | S-1 and S-2 remain remediated | `public_profiles` still `anon=r`/`authenticated=r` with no write privileges; `_test_results`/`_test_run_log` still absent; no relation carries `anon=arwdDxtm` | **PENDING** |
| **M-14** | S-5 remains remediated | the four `postgres` default-privilege entries still exclude `anon` and `authenticated`; `pg_default_acl` still 24 entries, 0 global | **PENDING** |
| **M-15** | Security Advisor improves, with no new findings | see §4.1 | **PENDING** |
| **M-16** | Smoke tests | §5 | **PENDING** |

### 4.1 Expected Security Advisor movement

| Lint | Before | Expected after |
|---|---|---|
| `anon_security_definer_function_executable` (WARN) | 3 | **0 — lint disappears** |
| `authenticated_security_definer_function_executable` (WARN) | 28 | **25** |
| `security_definer_view` (ERROR) | 1 | 1 |
| `rls_enabled_no_policy` (INFO) | 2 | 2 |
| `auth_leaked_password_protection` (WARN) | 1 | 1 |
| **Totals** | **5 lints / 35 findings** | **4 lints / 29 findings** |

**Treated as supporting evidence, not as proof**, and only valid if no unrelated advisor state changes in the interim. The catalog diff in M-2, M-7 and M-8 is the proof.

Unlike Phase 21.6 — where the Advisor had no lint capable of showing the fix — here it can independently confirm the S-7 half. A **zero** on the `anon` lint is the outcome to look for; any *increase* anywhere is a failure of M-15.

---

## 5. Smoke-test plan — ALL PENDING

| # | Test | Exercises | Status |
|---|---|---|---|
| **A** | **Profile → Edit Profile → Save with no values changed** | The S-6 path: the seven column-level UPDATE grants, the own-row RLS UPDATE policy, and the SECURITY DEFINER helper the policy calls. Idempotent; creates no data. The procedure validated in Phase 21.6 | **PENDING** |
| **B** | **Anonymous `GET /rest/v1/public_profiles`** | The unauthenticated read path is unaffected; confirms S-1 stays remediated at the API | **PENDING** |
| **C** | **Post a message in an existing collaboration, then delete it** | The S-7 path end to end: the INSERT fires `trg_log_collaboration_message_activity`, which must still write one `collaboration_activity` row and notify the other participants. Reversible via the existing `delete_collaboration_message` RPC | **PENDING** |
| **D** | — | **No collaboration data may be manufactured to satisfy test C.** If no suitable collaboration already exists, C is recorded **NOT RUN**, and the trigger claim rests on M-7/M-8/M-12 plus the §8 control case | **Standing constraint** |

**Test C is the one that matters for S-7**, because it is the only check that observes a trigger firing after its EXECUTE grants were removed. Verification for C is not merely "no error": the new `collaboration_activity` row and the resulting notification must be confirmed, otherwise a silently skipped trigger would pass unnoticed.

**On test selection.** Each of these is a path the application actually invokes, verified against the enumerated write call sites in `backend-contract.md` §5. That check is here because Phase 21.6's M-15 originally named a Like action the app does not implement; a smoke test must be chosen from real code paths, not assumed features.

---

## 6. Post-change documentation updates — ALL PENDING

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql`: `NOT YET APPLIED` → `APPLIED`, with timestamp, approval, checkpoint commit, executing role and pre/post evidence | **PENDING** |
| **D-2** | This record: §3–§5 results filled in | **PENDING** |
| **D-3** | `phase-definition.md`: remediation result and final S-6/S-7 state | **PENDING** |
| **D-4** | `analysis/phase-21.3/backend-contract.md` §0.2: S-6 and S-7 `OPEN` → `REMEDIATED`, current-status rows only | **PENDING** |
| **D-5** | `.apos/PROJECT_CONTEXT.md`: Phase 21.7 completion | **PENDING** |
| **D-6** | Commit, push, PR, review, merge | **PENDING** |

---

## 7. Unresolved concerns

1. **Platform-owned siblings remain**, by design: the `storage` MAINTAIN grants and the three `storage` SECURITY INVOKER trigger functions, plus the `supabase_admin`/`public` TABLES default ACL carried forward from Phase 21.6. None is alterable by this project.
2. **S-3 and S-4 remain open** and are untouched here.
3. **PostgREST exposure of trigger functions is unverified.** Whether `/rest/v1/rpc/log_collaboration_*` routes exist at all was deliberately not tested, because probing a VOLATILE function requires a POST. The remediation does not depend on the answer.
4. **Smoke test C may be unrunnable** if no collaboration exists. That is an accepted limitation, recorded as NOT RUN rather than inferred.
5. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it.

---

## 8. Summary

Three artifacts are prepared and statically verified. **Eight repository-safety checks pass**, including confirmation that `index.html` and all prior phase artifacts are untouched, and that `migration.sql` contains exactly seven executable statements — all `REVOKE`, with no `GRANT`, `ALTER`, `DROP`, `CREATE` or `CASCADE` outside comments.

**No backend write has been performed or attempted.**

Twenty-one pre-flight requirements, sixteen post-change checks and three smoke tests are defined. All are **PENDING**, and F-21 — explicit production-mutation approval — has **not been given**.

**Level 1 is satisfied for the preparation step.** The mutation step remains outstanding and is blocked solely on that approval.
