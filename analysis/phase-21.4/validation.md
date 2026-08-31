# Phase 21.4 — Validation Record (S-1 remediation)

**Branch:** `phase-21.4-s1-anon-write-exposure`
**Base commit:** `ebfe536` (`origin/main`)
**Project:** `kbnmkyvbwkuvcklywdhk`
**Applied:** 2026-08-23
**Validation level:** 1 for the repository (documentation only; `index.html` untouched). The backend change is a production mutation and was validated directly against the live project.
**Status:** **COMPLETE — migration applied, backend validation and live UI regression validation both pass.** 8/8 backend requirements and 8/8 production UI checks are **EMPIRICAL PASS** (§9, §10). No console errors observed. Evidence tiering in §9. Not committed, not pushed.

---

## 0. Three distinct activities — do not conflate them

This phase involved three different kinds of action against production. They are recorded separately because they carry very different risk:

| # | Activity | Mutating? | Where recorded |
|---|---|---|---|
| **1** | **The approved production ACL mutation** — two `REVOKE`/`GRANT` statements against `public.public_profiles` | **YES — the only write of the entire phase** | `migration.sql`, explicitly headed as an executable migration; §1–§3 here |
| **2** | **Non-executing security verification** — `EXPLAIN` **without** `ANALYZE` as `SET ROLE anon`, before and after | **No.** Plans and permission-checks only; zero rows touched | §4 here, and `analysis/phase-21.3/backend-contract.md` §12 for the pre-fix evidence |
| **3** | **Live UI regression validation** — eight authenticated checks on `https://stagerz.app` | No backend change; ordinary application use, one reversible Location edit that was restored | §10 here |

Activity 2 is what *confirmed* S-1 and later confirmed it closed. Activity 3 is what proved the fix caused no user-visible regression. Only activity 1 changed anything.

## 1. Change applied

Exactly two statements, the only approved production mutation:

```sql
REVOKE ALL ON TABLE public.public_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO anon, authenticated;
```

Executed via `execute_sql` rather than `apply_migration`, deliberately: `apply_migration` would additionally write a migration-history row, and the approval was scoped to *only* these two statements.

## 2. Pre-change state (captured before applying)

```
relacl: postgres=arwdDxtm/postgres | anon=arwdDxtm/postgres
      | authenticated=arwdDxtm/postgres | service_role=arwdDxtm/postgres
```

| Role | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `anon` | true | **true** | **true** | **true** |
| `authenticated` | true | **true** | **true** | **true** |
| `service_role` | true | true | true | true |

View owner `postgres`; `reloptions (none)`; viewdef md5 `d86256ac1ad53a250c96c315ed69a52e`; `users` RLS enabled=true forced=false, 2 policies. Baselines: 348 table-grant rows, 1542 column-grant rows in `public`.

**This matched the reviewed plan exactly — no discrepancy, so the change proceeded.**

## 3. Post-change state

```
relacl: postgres=arwdDxtm/postgres | service_role=arwdDxtm/postgres
      | anon=r/postgres | authenticated=r/postgres
```

| Role | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `anon` | **true** | **false** | **false** | **false** |
| `authenticated` | **true** | **false** | **false** | **false** |
| `service_role` | true | true | true | true — **untouched** |

## 4. Required verification — all pass

| # | Requirement | Method | Result |
|---|---|---|---|
| 1 | anon SELECT still works | `GET /rest/v1/public_profiles?select=…&limit=0` ×3 shapes, incl. the app's search projection | **PASS** — HTTP 200 `[]` |
| 2 | authenticated SELECT still works | `has_table_privilege` = true; same view, same grant | **PASS** |
| 3 | anon UPDATE rejected | `SET ROLE anon; EXPLAIN UPDATE …` | **PASS** — `42501: permission denied for view public_profiles` |
| 4a | anon INSERT rejected | `SET ROLE anon; EXPLAIN INSERT …` | **PASS** — `42501` |
| 4b | anon DELETE rejected | `SET ROLE anon; EXPLAIN DELETE …` | **PASS** — `42501` |
| 5 | authenticated writes restricted | `has_table_privilege` INSERT/UPDATE/DELETE | **PASS** — all `false` |
| 6 | Edit Profile paths intact | writes target base tables `profiles` / `users` via their own column grants; neither touched | **PASS** — see §5 |
| 7 | `users` RLS unchanged | `relrowsecurity` / `relforcerowsecurity` / policy count | **PASS** — `true` / `false` / `2`, identical to pre-change |
| 8 | No Stage/profile regression | read path verified at SQL and HTTP layers; `index.html` unmodified | **PASS** — see §5 |

All write checks used `EXPLAIN` **without** `ANALYZE`. **No write was executed for testing.** `RESET ROLE` confirmed afterwards (`current_user = postgres`, 0 idle-in-transaction sessions).

### Read path, planner level

```
SET ROLE anon;
EXPLAIN SELECT id, username, display_name FROM public.public_profiles WHERE id = '000…'::uuid;
--> Seq Scan on users  (cost=0.00..1.12 rows=1 width=55)
--> Filter: (id = '00000000-0000-0000-0000-000000000000'::uuid)
```

The definer read gateway still functions exactly as designed.

### Before / after, same statement

| | Before | After |
|---|---|---|
| `EXPLAIN UPDATE … public_profiles` as `anon` | `Update on users` (**no RLS predicate**) | **`42501` permission denied for view** |

## 5. Blast-radius confirmation — the change is confined

| Evidence | Result |
|---|---|
| Table-grant rows in `public` | 348 → **336** (Δ 12 = 2 roles × 6 revoked privileges) |
| Column-grant rows in `public` | 1542 → **1500** (Δ 42 = 2 roles × 7 columns × 3 privileges) |
| Grant rows for relations **other than** `public_profiles` | **320** — accounts for all of 336 minus this view's 16 |
| Relations still granting TRUNCATE to `anon` | `_test_results, _test_run_log` — `public_profiles` removed, **S-2 untouched as instructed** |
| View owner / `reloptions` / viewdef md5 | **all unchanged** (`d86256ac1ad53a250c96c315ed69a52e`) |
| `users` RLS + policies | **unchanged** |

Both deltas are exactly and arithmetically accounted for by this one view. **No other relation, role or privilege was affected.**

Requirements 6 and 8 follow from this: `profiles` and `users` column grants are untouched, so Edit Profile writes are unaffected; and `index.html` was never modified, so rendering cannot have regressed. **Both were subsequently confirmed empirically in the live application — see §10.**

## 6. Rollback

```sql
GRANT ALL ON TABLE public.public_profiles TO anon, authenticated;
```

Restores the exact prior ACL (`arwdDxtm` for both roles). **It also re-opens S-1**, so it must not be run except to recover from a confirmed regression, under the same approval as any production change.

## 7. Deliberately not changed

`security_invoker` (would break every profile read — see `phase-definition.md` §3) · `public.users` RLS · `ALTER DEFAULT PRIVILEGES` (**S-5**, the root cause) · `service_role` privileges · **S-2**, **S-3**, **S-4** · `index.html` · Phase 21.3, which remains paused.

## 8. Outstanding

1. **S-5 remains open and is the root cause.** Default privileges still grant ALL on every *new* object in `public` to `anon`, so this class of exposure will recur until addressed.
2. **Phase 21.3's grant snapshot is now stale** — it records the pre-fix ACL. It must be re-captured when 21.3 resumes, or the repository will document the vulnerable state as current.

---

## 9. Evidence tiers

Every claim in this record is classified. The distinction matters: a structural pass reasons from configuration and unchanged inputs, and is strong but is *not* the same as watching the application work.

| Tier | Meaning |
|---|---|
| **EMPIRICAL** | Directly observed — a request was made, a plan was produced, or a screen was seen |
| **STRUCTURAL** | Follows necessarily from verified configuration and unchanged inputs, but not directly observed |
| **NOT RUN** | Neither — explicitly not claimed |

### 9.1 Backend (§4) reclassified

| # | Requirement | Tier | Basis |
|---|---|---|---|
| 1 | anon SELECT works | **EMPIRICAL** | HTTP 200 `[]` against the production project, 4 projections including the app's exact search shape |
| 2 | authenticated SELECT works | **EMPIRICAL** | `has_table_privilege` = true, and confirmed in the live UI: six authenticated screens read the view successfully (§10 checks 2-7) |
| 3 | anon UPDATE rejected | **EMPIRICAL** | `EXPLAIN` → `42501` |
| 4 | anon INSERT / DELETE rejected | **EMPIRICAL** | `EXPLAIN` → `42501` each |
| 5 | authenticated writes restricted | **EMPIRICAL** | `has_table_privilege` = false ×3 |
| 6 | Edit Profile paths intact | **EMPIRICAL** | Live save of Location persisted across reload, original restored (§10 check 8). Column grants also verified untouched |
| 7 | `users` RLS unchanged | **EMPIRICAL** | catalog read, identical to pre-change |
| 8 | No Stage/profile regression | **EMPIRICAL** | Stage and Profile observed rendering correctly post-change (§10 checks 1-2); `index.html` unmodified; read path also verified at SQL and HTTP layers |

### 9.2 Production checks performed without a session

| Check | Tier | Result |
|---|---|---|
| Production artifact unchanged | **EMPIRICAL** | `stagerz.app/index.html` SHA-256 identical to `ebfe536` — no deploy occurred, so any behavioural change could only originate in the backend grant |
| Anon read path, production project, post-fix | **EMPIRICAL** | HTTP 200 on all 4 projections, including `username=ilike.*` (the search shape at [index.html:3293](../../index.html#L3293)) |
| Unauthenticated cold load of `stagerz.app` | **EMPIRICAL** | `screen-authemail` active, boot screen cleared, `bootMessage` untouched. **Zero** occurrences of `42501`, `permission denied`, `public_profiles`, `Uncaught`, `TypeError`, `ReferenceError`, `integrity` |

---

## 10. Authenticated UI validation — EXECUTED, 8/8 EMPIRICAL PASS

Performed against the live primary production surface `https://stagerz.app` with a real authenticated session, driven and observed by the product owner, 2026-08-23. **Post-ACL-change.**

| # | Check | Result |
|---|---|---|
| 1 | Stage loads after sign-in | **PASS** — Stage renders, bottom nav present |
| 2 | Own Profile renders | **PASS** — renders completely |
| 3 | Another user's profile via normal UI | **PASS** — renders completely |
| 4 | Applicant-list profile rendering | **PASS** — via Profile → My WANTED → My Collaborations → Collaboration → Applicants |
| 5 | Collaboration participant rendering | **PASS** — renders correctly |
| 6 | Message sender identities | **PASS** — render correctly |
| 7 | User search via `public_profiles` | **PASS** — returns and renders results |
| 8 | Edit Profile save + persistence | **PASS** — Location saved, persisted across `F5`, original value restored afterwards |

**Console: clean on every one of the eight checks.** Specifically **no** `42501`, **no** `permission denied`, **no** `public_profiles` error, and no other application console error observed.

**Username was not changed** at any point, as instructed. No application data was manufactured to satisfy a test; every check ran against pre-existing data.

**Coverage significance.** Checks 3–7 each read `public_profiles` — the exact relation whose privileges were altered — through five distinct code paths (`openArtistProfile`, `openApplicants`, `openCollaboration` participants, `loadCollaborationMessages`, user search). Together they exercise every one of the frontend's read sites against that view under an authenticated session. Check 8 exercises the Edit Profile write path against the untouched base-table grants.

**Conclusion: the ACL change caused no user-visible regression, observed rather than inferred.**
