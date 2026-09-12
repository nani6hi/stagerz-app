# Phase 21.7 — Validation Record

**Branch:** `phase-21.7-s6-s7-privilege-cleanup`
**Base commit:** `452b12b`
**Pre-mutation checkpoint:** `22efa74f72f49befe77d07489df3e703b158efc8`
**Validation level:** **1** — documentation and a backend-only change; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **APPLIED 2026-09-11 (UTC) — S-6 and S-7 REMEDIATED. VALIDATION COMPLETE.** Pre-flight **21/21 PASS**; post-change **16/16 PASS**; smoke tests **A, B and C all PASS**.

Exactly one backend change was made: the seven approved `REVOKE` statements, in a single call. Every other statement issued in this phase was a `SELECT` or catalog read.

---

## 1. What this record claims, and what it does not

**Claims:** the change was applied against a state that matched the reviewed baseline exactly; it altered precisely the intended grants on one table and three functions; every other permission in `public` and `storage` — table, function and column — is byte-identical before and after; and all three production smoke tests passed.

**Does not claim** more UI evidence than was actually reported. The user confirmed smoke A and smoke C in their own words (§5); those quotes are recorded verbatim and nothing is extrapolated beyond them. In particular, the user did **not** report inspecting the resulting `collaboration_activity` row or notification, so trigger firing is evidenced by the successful, error-free INSERT rather than by direct observation of the row it wrote (§5.1).

> **Naming collision — read this.** The check ids `P-1…P-8` in §2 are repository-safety checks and are **not** the security findings `S-1…S-7`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-12: **S-1, S-2, S-5, S-6 and S-7 REMEDIATED**; **S-3 and S-4 OPEN**.

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — not in the branch diff; no application source touched |
| **P-2** | Phase 21.4, 21.5 and 21.6 artifacts unmodified | **PASS** — none in the diff |
| **P-3** | Phase 21.3 historical evidence preserved | **PASS** — `backend-contract.md` receives only current-status changes in §0.2; §11 and all historical sections untouched |
| **P-4** | `migration.sql` contains exactly seven executable statements | **PASS** — see §2.1 |
| **P-5** | All seven are `REVOKE`; no `GRANT`, `ALTER`, `DROP`, `CREATE` or `CASCADE` in executable code | **PASS** |
| **P-6** | Exact object identities — one table, three zero-argument functions | **PASS** |
| **P-7** | `migration.sql` marked with its true state | **PASS** — `EXECUTABLE MIGRATION - APPLIED`, with timestamp, approval, checkpoint, executing identity, atomicity and error status |
| **P-8** | No backend write beyond the seven approved statements | **PASS** — one mutating call containing exactly those seven; everything else was a read |

### 2.1 Statement counting — and the artefact it avoids

`migration.sql` contains `GRANT`, `REVOKE`, `MAINTAIN`, `EXECUTE` and the three function names inside `--` comments — in the six rules, the pre/post state blocks, the rollback block and the out-of-scope list. A raw `grep` therefore **over-counts**, the same class of artefact recorded for `haptic(` in Phase 20.5, `NOT A MIGRATION` in Phase 21.4, `CASCADE` in Phase 21.5 and `GRANT` in Phase 21.6.

Counts are taken **after stripping comment lines** and splitting on `;`. Those are the only authoritative figures. The seven executable statements, unchanged from the approved and executed set:

```sql
REVOKE MAINTAIN ON TABLE public.users FROM anon, authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM authenticated
REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM PUBLIC
REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM authenticated
```

**The rollback block is commented out** and excluded by comment stripping. It is the only place `GRANT` appears.

---

## 3. Pre-flight — executed 2026-09-11, re-confirmed at 23:40:35+00

**All 21 requirements matched exactly. No hard-stop condition fired.** The full pre-flight ran once as the approval gate and was re-run immediately before execution; both runs were identical.

### 3.1 S-6 — `public.users`

| # | Requirement | Observed | Status |
|---|---|---|---|
| **F-1** | relacl byte-exact | `{postgres=arwdDxtm/postgres,anon=m/postgres,authenticated=m/postgres,service_role=arwdDxtm/postgres}` | **PASS** |
| **F-2** | `anon` — MAINTAIN true, all others false | exactly that | **PASS** |
| **F-3** | `authenticated` — MAINTAIN true, all others false | exactly that | **PASS** |
| **F-4** | `service_role` / `postgres` full `arwdDxtm` | confirmed | **PASS** |
| **F-5** | **Column grants — exactly seven** | `id:SELECT`; `username, first_name, last_name, photo_url, bio, location: SELECT+UPDATE` | **PASS** |
| **F-6** | RLS `enabled=true, forced=false` | `true/false` | **PASS** |
| **F-7** | Exactly two policies | 2, md5 `b784b66a3c906019478dfebccbd3c7b0` | **PASS** |
| **F-8** | Triggers = 0 | 0 | **PASS** |
| **F-9** | No indirect path to MAINTAIN | both roles member of `(none)`, not superuser/bypassrls, `pg_has_role(pg_maintain)`=false, no PUBLIC grant — held **directly only** | **PASS** |

### 3.2 S-7 — the three functions

| # | Requirement | Observed | Status |
|---|---|---|---|
| **F-10** | Exact identities, zero-argument | all three confirmed | **PASS** |
| **F-11** | proacl byte-exact, all three | `{=X/postgres,postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | **PASS** |
| **F-12** | `PUBLIC` true, `anon` true (via PUBLIC only), `authenticated` true, `service_role` true | exactly that | **PASS** |
| **F-13** | Definitions captured | owner `postgres`, plpgsql, SECURITY DEFINER, VOLATILE, returns `trigger`, `search_path=''`; body md5 `696efad0…`, `a6b00afd…`, `278d7269…` | **PASS** |
| **F-14** | Triggers | three AFTER INSERT triggers, md5 `c6b6071e…`, `3047edc2…`, `96bd81ad…` | **PASS** |
| **F-15** | No other dependencies | `pg_depend` shows only those three triggers | **PASS** |

### 3.3 Control case and environment

| # | Requirement | Observed | Status |
|---|---|---|---|
| **F-16** | `handle_new_auth_user()` control case | proacl `{postgres=X/postgres,service_role=X/postgres}`; anon/authenticated false; trigger `on_auth_user_created` present; body md5 `47c47604…` | **PASS** |
| **F-17** | ACL fingerprints captured, **including column ACLs** | see §3.4 | **PASS** |
| **F-18** | Security Advisor baseline | 5 lints / 35 findings — 1 ERROR, 32 WARN, 2 INFO | **PASS** |
| **F-19** | **Executing DB role is `postgres`** | `current_user` = `session_user` = `postgres`, database `postgres` | **PASS** |
| **F-20** | Repository clean, `migration.sql` committed and pushed | HEAD = origin = `22efa74f…`; artifact SHA-256 `f20123fe…81abd2` verified from the origin ref | **PASS** |
| **F-21** | Explicit production-mutation approval | **given**, naming the seven statements | **PASS** |

**F-17 closed the gap found in Phase 21.6**, whose fingerprints covered table and function ACLs but not column ACLs. Column grants were fingerprinted here from the start, because F-5 was the highest-consequence check in this phase.

### 3.4 Pre-change fingerprints

| Object set | Count | md5 |
|---|---|---|
| `public` relation ACLs | 18 | `eb5f241e4fc2107e9b063e0d105f9080` |
| `public` function ACLs | 34 | `b573f7fd22d2ce5a2c810b78318b47a3` |
| `storage` relation ACLs | 8 | `219b3af9ad84bd4396b5002d61bff025` |
| `storage` function ACLs | 17 | `9004d75ecb8885e8796438e688236ef6` |
| Column ACLs (`public` + `storage`) | 24 | `6f12d81ec431e4b5890b4f23485fb17e` |
| `public.users` policies | 2 | `b784b66a3c906019478dfebccbd3c7b0` |

---

## 4. Post-change checks — executed 2026-09-11 23:42:02+00

**All 16 pass.**

| # | Check | Observed | Status |
|---|---|---|---|
| **M-1** | All seven statements applied, no partial application | all seven took effect; single atomic call; zero SQL errors | **PASS** |
| **M-2** | `public.users` relacl | **`{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`** — `anon` and `authenticated` entries absent entirely | **PASS** |
| **M-3** | **Seven column grants byte-identical** | all seven present, identical string to F-5 | **PASS** |
| **M-4** | `public.users` RLS byte-identical | `true/false`; both policies unchanged, md5 `b784b66a…` | **PASS** |
| **M-5** | `public.users` triggers | still 0 | **PASS** |
| **M-6** | MAINTAIN removed **only** | `anon`/`authenticated` hold **none** of the eight table-level privileges; `service_role` and `postgres` keep full `arwdDxtm` | **PASS** |
| **M-7** | All three functions' proacl | **`{postgres=X/postgres,service_role=X/postgres}`** | **PASS** |
| **M-8** | Execution state | `PUBLIC`=false, `anon`=false, `authenticated`=false, `service_role`=true, `postgres`=true — all three | **PASS** |
| **M-9** | Function definitions byte-identical | owner, language, SECURITY DEFINER, volatility, return type, `search_path` and **body md5** all unchanged | **PASS** |
| **M-10** | Triggers byte-identical | all three trigger md5s unchanged; same tables and events | **PASS** |
| **M-11** | Unrelated ACLs unchanged | see §4.1 | **PASS** |
| **M-12** | `handle_new_auth_user()` unchanged | proacl, body md5 `47c47604…`, trigger md5 `8173a871…` all identical | **PASS** |
| **M-13** | S-1 and S-2 remain remediated | §4.3 | **PASS** |
| **M-14** | S-5 remains remediated | §4.3 | **PASS** |
| **M-15** | Security Advisor improves, no new findings | §4.2 | **PASS** |
| **M-16** | Smoke tests | §5 — A, B, C all PASS | **PASS** |

### 4.1 Blast-radius proof

The aggregate `public` fingerprints necessarily changed, because the intended objects live inside them. To prove that *only* the four intended objects moved, each aggregate was recomputed with the intended objects' pre-change ACL strings substituted back in:

| Fingerprint | Pre | Actual after | Recomputed with intended objects restored |
|---|---|---|---|
| `public` relations (18) | `eb5f241e…` | `f7b5763f76cebe3521dbdf96ee3003e1` | **`eb5f241e4fc2107e9b063e0d105f9080` — exact match** |
| `public` functions (34) | `b573f7fd…` | `1d68816858fe4e4e7683f167adefd1f3` | **`b573f7fd22d2ce5a2c810b78318b47a3` — exact match** |

That is positive proof: among 18 `public` relations only `users` changed, and among 34 `public` functions only the three changed.

| Must be identical | Pre | After |
|---|---|---|
| `storage` relation ACLs | `219b3af9…` | **`219b3af9…`** ✅ |
| `storage` function ACLs | `9004d75e…` | **`9004d75e…`** ✅ |
| Column ACLs (24) | `6f12d81e…` | **`6f12d81e…`** ✅ |
| `public.users` policies | `b784b66a…` | **`b784b66a…`** ✅ |

**No unrelated ACL mutation occurred.**

### 4.2 Security Advisor

| | Before | After |
|---|---|---|
| Lints | 5 | **4** |
| Total findings | 35 | **29** |
| ERROR / WARN / INFO | 1 / 32 / 2 | **1 / 26 / 2** |
| `anon_security_definer_function_executable` | **3** | **0 — lint gone entirely** |
| `authenticated_security_definer_function_executable` | 28 | **25** |
| `security_definer_view` (ERROR) | 1 | 1 |
| `rls_enabled_no_policy` (INFO) | 2 | 2 |
| `auth_leaked_password_protection` (WARN) | 1 | 1 |

Exactly the predicted movement, with **zero new findings** at any severity and no unrelated advisor drift to explain. Unlike Phase 21.6 — where no lint could reflect the fix — the Advisor independently confirms the S-7 half here.

### 4.3 Regression guards

- **S-1 remains remediated.** `public_profiles` = `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}`; no INSERT/UPDATE/DELETE/TRUNCATE for either role.
- **S-2 remains remediated.** `_test_results` and `_test_run_log` absent; 0 relations carry the `anon=arwdDxtm` signature; both REST endpoints return **HTTP 404**.
- **S-5 remains remediated.** `pg_default_acl` still 24 entries, 0 global; the `postgres` TABLE/SEQUENCE defaults in `public` and `storage` contain **no** `anon` or `authenticated`.

---

## 5. Smoke tests — all PASS

| # | Test | Result |
|---|---|---|
| **A** | Profile → Edit Profile → Save with no values changed | **PASS** |
| **B** | Anonymous `GET /rest/v1/public_profiles` | **PASS** — HTTP **200**, one row with `display_name`; `stagerz.app` HTTP 200, 271,474 bytes |
| **C** | Existing collaboration: send a message, confirm it appears, delete it | **PASS** |

**Smoke A — user-reported evidence, verbatim:**

> *"Profil speichern funktioniert, keine Fehlermeldung."*

Exercises the S-6 path: the seven column-level grants on `public.users`, the own-row RLS UPDATE policy, and the SECURITY DEFINER helper that policy calls. Idempotent; no data manufactured.

**Smoke C — user-reported evidence, verbatim:**

> *"Nachricht senden funktioniert, Nachricht erscheint und gelöscht, keine Fehlermeldung."*

Exercises the S-7 path through the real application UI, after `PUBLIC` and `authenticated` EXECUTE were removed from the three trigger functions: a message was sent, displayed, and deleted, with no visible error. Performed against an **existing** collaboration — no collaboration data was manufactured for the test, and no synthetic SQL substitute was used.

### 5.1 What smoke C proves, stated precisely

The user reported that sending, displaying and deleting a message worked with no error. They did **not** report inspecting the resulting `collaboration_activity` row or the participant notifications, and this record does not claim they did.

The trigger conclusion nevertheless follows from what was observed, and it is worth stating why rather than asserting it. `trg_log_collaboration_message_activity` is an **AFTER INSERT** trigger in the same transaction as the INSERT. Had it failed — including on a permission error — the exception would have aborted the transaction and the message would neither have been stored nor appeared in the UI. A message that was successfully created and then displayed is therefore evidence that the trigger ran to completion after its EXECUTE grants were removed.

That is the empirical confirmation of the principle this phase relied on: **trigger firing does not require the DML caller to hold EXECUTE on the trigger function.** It was predicted from the `handle_new_auth_user()` control case and is now observed on the changed functions themselves.

---

## 6. Documentation updates

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql`: `NOT YET APPLIED` → `APPLIED`, with timestamp, approval, checkpoint, executing identity, atomicity, error status, and full pre/post evidence | **DONE** |
| **D-2** | This record: §3–§5 closed with actual evidence | **DONE** |
| **D-3** | `phase-definition.md`: production result and final S-6/S-7 state | **DONE** |
| **D-4** | `analysis/phase-21.3/backend-contract.md` §0.2: S-6 and S-7 `OPEN` → `REMEDIATED`, **current-status rows only**; historical evidence untouched | **DONE** |
| **D-5** | `.apos/PROJECT_CONTEXT.md`: Phase 21.7 applied and validated | **DONE** |
| **D-6** | Commit and push | **DONE** — PR and merge still pending |

---

## 7. Unresolved concerns

1. **S-3 and S-4 remain OPEN** and were untouched by this phase. Nothing here should be read as addressing them.
2. **Platform-owned siblings remain**, by design and outside this project's control: the `storage` MAINTAIN grants (`buckets`, `buckets_analytics`, `objects`, granted by `supabase_storage_admin`), the three `storage` SECURITY INVOKER trigger functions, and the `supabase_admin`/`public` TABLES default ACL carried forward from Phase 21.6.
3. **PostgREST exposure of trigger functions was never tested**, deliberately — probing a VOLATILE function requires a POST. Now moot for `anon` and `authenticated`, who can no longer execute them at all.
4. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it.

---

## 8. Summary

**S-6 and S-7 are REMEDIATED.**

All **21 pre-flight requirements matched exactly**, re-confirmed immediately before execution with zero drift. Seven statements were executed in a **single atomic call** as `postgres`, with **no SQL errors**.

**All 16 post-change checks pass.** `public.users` now grants table-level privileges to `postgres` and `service_role` only, while all seven column grants, RLS, both policies, zero triggers and the single dependent view are byte-identical. The three trigger functions are executable only by `postgres` and `service_role` — `PUBLIC`, `anon` and `authenticated` all false — with bodies, security attributes and trigger definitions untouched, matching the `handle_new_auth_user()` control case exactly.

**Only the four intended objects changed**, proven by fingerprint substitution rather than assertion. Storage, column and policy fingerprints are unchanged. The Advisor moved 35 → 29 findings with the `anon` lint eliminated and zero new findings. S-1, S-2 and S-5 all remain remediated.

**All three production smoke tests pass**, including the collaboration message path that exercises a changed trigger function end to end.

**Level 1 is satisfied.** Outstanding: PR and merge.
