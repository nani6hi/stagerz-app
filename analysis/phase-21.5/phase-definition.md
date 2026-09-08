# Phase 21.5 — Remove the abandoned test-harness tables (S-2)

**Branch:** `phase-21.5-s2-test-table-removal`
**Base commit:** `4ed53b9` (`main`, merge of PR #12 — Phase 21.3 backend contract)
**Addresses:** finding **S-2** from `analysis/phase-21.3/backend-contract.md` §0.2
**Status:** **COMPLETE — S-2 REMEDIATED.** Both tables dropped 2026-09-08 under explicit approval; all pre-flight requirements matched and all post-mutation checks pass. See §13.
**Validation level:** **Level 1** — documentation and a backend-only migration; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

Exactly one backend change was made: the two approved `DROP TABLE` statements. No application source was modified. Not yet committed, not yet pushed.

---

## 1. Objective

Remove `public._test_results` and `public._test_run_log` — two abandoned test-harness tables that sit in the PostgREST-exposed `public` schema with RLS disabled and full write privileges granted to `anon`.

**Pattern decision (`.apos/WORKFLOW.md`): Extend.** Phase 21.4 established the pattern for a minimal, approval-gated, single-purpose security migration — `migration.sql` + `phase-definition.md` + `validation.md`, exactly the approved statements and nothing else. This phase follows it, adding one artifact class it did not need: a data snapshot taken before an irreversible change.

---

## 2. S-2 — the finding

Live read-only verification, `2026-09-08 12:32:35+00`, project `kbnmkyvbwkuvcklywdhk`:

| Property | `_test_results` | `_test_run_log` |
|---|---|---|
| relkind / owner | table / `postgres` | table / `postgres` |
| **RLS enabled / forced** | **false / false** | **false / false** |
| **Policies** | **0** | **0** |
| Rows | 4 | 24 |
| Size | 32 kB | 32 kB |
| Comment | none | none |

Both carry an identical ACL:

```
{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,
 authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
```

Confirmed individually with `has_table_privilege`, `anon` and `authenticated` each hold **SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER** on both tables.

**Why this is a finding rather than an oddity.** These tables sit in `public`, which PostgREST exposes. Anyone holding the publishable key — which is embedded in every deployed page — can read, rewrite or **truncate** them. The Supabase Security Advisor reports both as `rls_disabled_in_public` at **ERROR** severity ([lint 0013](https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public)).

**One nuance that rules out the obvious partial fix.** RLS does not apply to `TRUNCATE`. Enabling RLS on these tables would clear the Advisor ERROR while leaving `anon` able to truncate both. Any fix that keeps the tables must revoke privileges, not merely enable RLS.

---

## 3. Complete semantic summary of the 28 rows

All 28 rows were read under explicit approval on 2026-09-08. **No credential, token, password, personal information or production user content was found**, so nothing is withheld below.

### 3.1 `_test_results` — 4 rows

| id | message | logged_at |
|---|---|---|
| 1 | `PASS Test 1` | `2026-07-12 10:18:41.799185+00` |
| 3 | `PASS Test 3a` | *(identical)* |
| 4 | `PASS Test 3b` | *(identical)* |
| 5 | `PASS Test 4` | *(identical)* |

`id = 2` is absent while the sequence stands at 5 — a row was inserted and later removed. A scratch pad, overwritten while being written.

### 3.2 `_test_run_log` — 24 rows

One `run_id` (`d098113c-397d-4d93-a444-5d7f6bc9e485`), one instant (`2026-07-12 15:11:12.495837+00`), `status = PASS` on all 24. Ids run **39–62** contiguously; ids 1–38 were cleared, so this is the surviving final run after at least one discarded attempt.

| Test | `details` | What it exercised |
|---|---|---|
| 1 | `mapping count = 1` | identity mapping created on signup |
| 2 | `expected 23505, got 23505` | unique violation |
| 3a | `expected 42501, got 42501` | privilege denial |
| 3b | `blocked=true confirmed under service_role` | block flag |
| 4 | `resolved id matched expected` | id resolver |
| 5a | `expected 42501, got 42501` | privilege denial |
| 5b | `resolver returned NULL as expected` | resolver miss path |
| 6 | `expected P0001, got P0001` | custom raise |
| 7 | `rows affected = 0` | write correctly refused |
| 8 | `rows affected = 0` | write correctly refused |
| 8b | `rows affected = 0` | write correctly refused |
| 8c | `anonymized_at unchanged on repeat call` | anonymisation idempotency |
| 9 | `expected 42501, got 42501` | privilege denial |
| 10 | `expected 23502, got 23502` | NOT NULL violation |
| 11 | `insert with null from_user_id succeeded` | nullable FK path |
| 12 | `status transitioned to closed` | collaboration status transition |
| 12b | `expected P0008, got P0008` | custom raise |
| 13 | `expected 42501, got 42501` | privilege denial |
| 14 | `expected 42501, got 42501` | privilege denial |
| 15 | `blocked/anonymized_at absent from view` | view column exposure |
| 16 | `resolved via public_profiles, display_name = Deleted User` | anonymisation sentinel |
| 17 | `1 row, attempt_count = 1` | attempt counter |
| 17b | `record cleared` | counter reset |
| 18 | `oldest row returned first` | queue ordering |

**On `Deleted User`:** this is the anonymisation **sentinel literal** the backend substitutes for a removed account, not a real display name. The only uuid present identifies the test run, not a person. The longest string in either table is 57 characters — too short to hold a token, JWT, email or URL of consequence.

---

## 4. Why these are abandoned test-harness artefacts

Each point below is independently verified, and they agree:

1. **Naming.** `_test_results` and `_test_run_log` are the only underscore-prefixed tables in `public`.
2. **Created outside the migration system.** 41 migration records exist (`20260712100630` → `20260721122606`) and **none mentions either table**. The first `_test_results` rows were written 12 minutes after the first migration ran.
3. **Written once, never since.** Every row in each table carries an identical timestamp — a single instant per table, both on 2026-07-12, the project's creation day. Nothing has touched them in the ~8 weeks since.
4. **Already superseded twice.** The missing `id = 2` and the missing ids 1–38 show earlier attempts were cleared. This is scratch output, treated as disposable by its own author.
5. **Content is entirely self-referential.** Every row describes the outcome of a test. No row is application state.
6. **The harness itself does not exist here.** No SQL, script or runner in this repository writes to either table. These are the orphaned output of a process that is gone.
7. **Nothing depends on them** (§5) and **no application code references them** (§6).

---

## 5. Zero dependencies

Verified live, `2026-09-08 12:32:35+00`, for both tables:

| Dependency class | Count |
|---|---|
| Inbound foreign keys | **0** |
| Outbound foreign keys | **0** |
| Dependent views / materialized views | **0** |
| Functions referencing them (all of `public`, `auth`, `storage`) | **0** |
| Triggers | **0** |
| RLS policies referencing them | **0** |
| Publication memberships (incl. `supabase_realtime`) | **0** |
| Owned sequences (dropped with the table) | 1 each |

A bare `DROP TABLE` therefore must succeed. That property is why `migration.sql` deliberately omits `CASCADE` — a failure would mean the verified state had changed, which is a signal the phase wants, not one it should suppress.

---

## 6. Zero application references

`git grep` across the tracked tree for `_test_results` and `_test_run_log`:

- **`index.html`: 0 matches.** The application has never referenced either table.
- 7 matches in total, all in this project's own findings documentation: `.apos/PROJECT_CONTEXT.md:15`, `analysis/phase-21.3/backend-contract.md:49,299,300`, `analysis/phase-21.4/phase-definition.md:41,55`, `analysis/phase-21.4/validation.md:105`.

Git history shows 2 commits touching each name — the Phase 21.3 and Phase 21.4 documentation commits. No application commit has ever mentioned them.

---

## 7. Why the historical results are still worth preserving

The initial read-only assessment estimated the content was probably worthless, from column shapes alone. Reading it corrected that: **the rows are useful historical test evidence**, and the snapshot in `pre-drop-snapshot.sql` exists because of it.

This is a deliberate, structured 24-case backend behaviour suite — SQLSTATE assertions, privilege-denial checks, anonymisation idempotency, view column exposure, queue ordering. Three specific reasons to keep it:

1. **It is prior evidence about objects this project is still investigating.** Tests 15 and 16 concern `public_profiles`, the subject of finding S-1 remediated in Phase 21.4.
2. **It records backend error codes.** The suite observed `P0001` and `P0008` among others, which is corroborating material for the SQLSTATE contract Phase 21.3 was capturing.
3. **It bears on the still-open Phase 21.3 question Q-2** — whether `kbnmkyvbwkuvcklywdhk` is still the *"disposable test project"* the code calls it. Somebody ran a formal security suite against it, which is not how a purely disposable project gets treated.

None of that requires the tables to keep existing. A committed snapshot preserves the evidence; the DROP removes the exposure. The two goals do not conflict.

**Durability, and the reason it is stated explicitly.** The Phase 21.3 artefacts were lost because both backup copies lived in volatile scratch storage — one failure domain wearing the appearance of two. `pre-drop-snapshot.sql` is therefore a **git-tracked repository file, committed and pushed before the DROP runs**: working tree, local git objects and the GitHub remote are three genuinely independent domains.

---

## 8. Relationship to S-5, and why S-5 stays out of scope

**S-5** is `ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES TO anon, authenticated, service_role`, still in force on this project.

**S-5 is the cause of S-2.** Nobody deliberately granted `anon` the right to truncate a test table. The ACL on both tables is byte-identical to the `pg_default_acl` entry, so the grants were applied automatically at `CREATE TABLE`. The same mechanism produced S-1, remediated in Phase 21.4.

**They are nonetheless separable, and separating them is the right call:**

- Default privileges apply **at CREATE time only**. They never retroactively re-grant on an existing table, so S-5 cannot re-open S-2 while these tables merely sit there.
- Dropping the tables makes them **permanently immune** to S-5 — there is no object left for any future default to attach to.
- No atomicity requirement exists in either direction. Neither fix depends on the other having run.
- S-5 has a far wider blast radius — every future table, view and function in `public`, and every role the default names. It deserves its own analysis of what legitimately depends on those defaults, which is a materially larger question than two abandoned tables.

Bundling them would make a low-risk, zero-dependency cleanup wait on a high-blast-radius investigation, and would put both behind a single approval. Phase 21.4 set the precedent of remediating one finding at a time under its own explicit approval; this phase follows it.

**S-5 is untouched by this phase.** So are S-3, S-4, the `security_definer_view` Advisor finding, the SECURITY DEFINER function Advisor findings, and the leaked-password-protection Advisor finding.

**One consequence to carry forward:** while S-5 stands, restoring the snapshot re-acquires the broad grants. `pre-drop-snapshot.sql` carries that warning prominently, and §9 repeats it.

---

## 9. Rollback strategy

`analysis/phase-21.5/pre-drop-snapshot.sql` recreates both tables, all 28 rows with their original ids and timestamps, and both sequence positions (`setval` to 5 and 62). It reproduces the captured state faithfully, including the `id = 2` and ids 1–38 gaps.

**Preconditions before any rollback:**

1. A **confirmed** regression attributable to this phase. Given zero dependencies and zero application references, no plausible mechanism for one is known — which is itself part of the case for the DROP.
2. **Explicit production-mutation approval**, the same standard as the DROP itself.
3. Acknowledgement of the S-5 consequence: **recreating the tables re-acquires the default grants and can reintroduce S-2 in full.** The resulting ACL must be inspected immediately after restore, and the exposure either accepted deliberately or revoked as a follow-up.

Rollback is a recovery path, never a routine one. This mirrors the framing of the Phase 21.4 rollback note, which likewise re-opened the finding it reversed.

---

## 10. Hard-stop conditions

Any of the following **stops the phase before mutation**. Report, do not proceed, do not improvise a variant.

| # | Condition |
|---|---|
| H-1 | Row counts are not exactly **4** (`_test_results`) and **24** (`_test_run_log`) |
| H-2 | Any dependency count in §5 is **non-zero** |
| H-3 | `index.html` contains **any** reference to either table |
| H-4 | The ACL on either table differs from the string recorded in §2 |
| H-5 | Either table or either owned sequence is **already absent** |
| H-6 | RLS state has changed from `enabled=false, forced=false, policies=0` |
| H-7 | Repository state is not this branch, clean, with the snapshot **committed and pushed** |
| H-8 | Explicit production-mutation approval has not been given for this specific change |
| H-9 | `DROP TABLE` fails for any reason — in particular a dependency error, which means something was created after verification |

**These apply during execution as well as before it.** H-9 in particular is the reason `CASCADE` is omitted: the phase would rather fail loudly than destroy an unknown dependent object silently.

---

## 11. Deliverables

| Path | Contents | State |
|---|---|---|
| `phase-definition.md` | This document | Complete |
| `pre-drop-snapshot.sql` | Recovery snapshot: 2 `CREATE TABLE`, 28 rows, 2 `setval` | Captured — **not executed** |
| `migration.sql` | The 2 intended `DROP TABLE` statements | Prepared — **NOT APPLIED** |
| `validation.md` | Pre-flight and post-mutation checks | Pre-flight defined; post-mutation results **PENDING** |

**Not updated in this phase, deliberately.** `analysis/phase-21.3/*`, `analysis/phase-21.4/*` and `.apos/PROJECT_CONTEXT.md` are untouched. They record S-2 as OPEN, which is still true. They are updated only after a successful remediation, not in anticipation of one.

---

## 12. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | `migration.sql` is executed before approval | Low | **High** — irreversible without the snapshot | Header states NOT YET APPLIED; validation gate H-8; snapshot committed first |
| R2 | The snapshot is lost, as the Phase 21.3 artefacts were | Low | **High** — the data becomes unrecoverable | Committed and pushed before mutation: three independent failure domains (§7) |
| R3 | Something depends on the tables after all | **Very low** | Medium | Nine dependency classes verified at zero; no `CASCADE`, so a dependency causes a clean failure (H-9) |
| R4 | The DROP removes more than intended | Low | **High** | Exactly two statements, no `CASCADE`; post-check asserts all unrelated relations unchanged |
| R5 | Rollback silently reintroduces S-2 | **Certain if rolled back** | Medium | Prominent warning in the snapshot; §9 preconditions; ACL inspection required after any restore |
| R6 | Verified state drifts between verification and execution | Low | Medium | Full pre-flight re-run immediately before applying, HARD STOP ON MISMATCH (`validation.md` §3) |

---

## 13. Remediation result — applied 2026-09-08

**S-2 is REMEDIATED.**

The pre-flight was re-run at `15:22:07+00` and **all 17 requirements matched the reviewed state exactly** — row counts 4 and 24, all nine dependency classes at zero, zero `index.html` references, and a byte-identical ACL with all ten `has_table_privilege` probes still `true`. No hard-stop condition fired. The snapshot commit `d5417e9` was confirmed present on `origin` with the expected blob SHA-256 before anything was executed.

Exactly two statements ran, verbatim from `migration.sql`:

```sql
DROP TABLE public._test_results;
DROP TABLE public._test_run_log;
```

Both succeeded. **Because neither carried `CASCADE`, that success is itself proof that nothing depended on either table** — the empirical confirmation of the catalog evidence in §5, which until then rested entirely on reading system catalogs.

**Post-mutation state, verified `15:23:46+00`:**

| | Before | After |
|---|---|---|
| `public` tables | 19 | **17** |
| `public` sequences | 2 | **0** |
| `public` relations (all kinds) | 22 | **18** |
| `public` views / functions | 1 / 34 | **1 / 34** |
| Policies / triggers, all schemas | 29 / 9 | **29 / 9** |
| `pg_default_acl` entries | 24 | **24** |
| Migration records | 41 | **41** |
| Advisor lints / findings | 6 / 37 | **5 / 35** |
| Advisor ERROR-level findings | 3 | **1** |

The relation list lost **exactly four objects** — the two tables and their two owned sequences — and the remaining 18 are identical. The `rls_disabled_in_public` lint no longer appears at all, and **no new Advisor finding was introduced at any severity**.

**The exposure is closed at the API layer, which is the layer that mattered.** As `anon`, `GET /rest/v1/_test_results` and `GET /rest/v1/_test_run_log` now return **HTTP 404 `PGRST205`**. The same role previously held SELECT, INSERT, UPDATE, DELETE and TRUNCATE on both. `GET /rest/v1/public_profiles` still returns HTTP 200 with a row, so the read path is intact.

**Final S-2 state: REMEDIATED, permanently and without residue.** The tables no longer exist, so no future application of the S-5 default privileges can reach them. The 28 rows survive in `pre-drop-snapshot.sql`, committed and pushed before the drop.

**S-5 was re-read after the mutation and is unchanged. It remains OPEN**, deliberately and in scope-conformance: the default ACL still grants ALL on new `public` tables to `anon`. S-2 was one of its two visible symptoms; the mechanism is untouched.

**Production smoke passed at both levels.** At the server level, `stagerz.app` returns HTTP 200 with the expected page, SDK tag and SRI hash intact, and the `public_profiles` read succeeded. At the browser level, manually confirmed against production after the mutation: **Stage loads normally, navigation is visible, a profile opens successfully, and no visible errors were observed.** The browser half was held open as NOT RUN until it was actually observed rather than inferred from the server response — `validation.md` §4.1 records why that distinction was kept.

---

## 14. Summary

Two tables in the PostgREST-exposed `public` schema had RLS disabled, zero policies, and granted `anon` and `authenticated` every table privilege including `TRUNCATE`. The Security Advisor flagged both at ERROR severity. The grants were never deliberate — they were applied automatically by the still-open finding S-5 at `CREATE TABLE` time.

The tables were abandoned test-harness output: created outside all 41 migrations, written once each on the project's creation day, already cleared twice by their own author, untouched for eight weeks, referenced by no function, view, policy, publication or line of `index.html`, and depended on by nothing.

Their 28 rows do carry real documentary value — a structured 24-case backend behaviour suite — so they were preserved in a snapshot committed and pushed **before** the mutation, rather than discarded. That preserved the evidence while removing the exposure; the two goals did not conflict.

**Both tables were dropped on 2026-09-08 under explicit approval.** All 17 pre-flight requirements matched exactly, exactly two bare `DROP TABLE` statements were executed, and **all 11 post-mutation checks pass**, including a manually confirmed production browser check. **S-2 is REMEDIATED** — permanently, since the tables no longer exist for the S-5 defaults to reach.

**S-5 itself is untouched and still OPEN.** It is the mechanism that produced both S-1 and S-2, and until it is addressed the next table created in `public` will reproduce the same exposure.
