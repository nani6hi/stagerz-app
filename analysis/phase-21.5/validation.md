# Phase 21.5 — Validation Record

**Branch:** `phase-21.5-s2-test-table-removal`
**Base commit:** `4ed53b9`
**Validation level:** **1** — documentation and a prepared migration; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **APPLIED AND VALIDATED. S-2 is REMEDIATED.** Mutation approved and applied 2026-09-08; all 17 pre-flight requirements matched exactly and **all 11 post-mutation checks pass**. M-9 stood as PARTIAL until the browser half was manually confirmed against production; it is now complete (§4.1).

Exactly one backend write was performed: the two approved `DROP TABLE` statements. Every other statement issued in this phase was a `SELECT`.

---

## 1. What this record claims, and what it does not

**Claims:** the mutation was applied against a state that matched the reviewed state exactly, it removed precisely the two intended tables and their two owned sequences and nothing else, and the exposure is gone at both the catalog and the API layer.

**Does not claim:** that the browser-level smoke check was observed. **M-9** is satisfied at the server level only; the console-error half was not run and is marked as such rather than assumed. See §4.1.

The mutation is recorded in `migration.sql`, which now carries pre- and post-change evidence and the `APPLIED` marker.

> **Naming collision — read this.** The check ids `P-1…P-8` (repository safety) in §2 are **not** the security findings `S-1…S-5`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-08: security **S-1 REMEDIATED** (Phase 21.4) and **S-2 REMEDIATED** (this phase); **S-3, S-4 and S-5 remain OPEN**.

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — not in the diff; no application source touched |
| **P-2** | Phase 21.3 artifacts unmodified | **PASS** — `analysis/phase-21.3/` not in the diff |
| **P-3** | Phase 21.4 artifacts unmodified | **PASS** — `analysis/phase-21.4/` not in the diff |
| **P-4** | `.apos/PROJECT_CONTEXT.md` unmodified | **PASS** — updated only after successful remediation, not in anticipation |
| **P-5** | `migration.sql` contains exactly two executable statements, both `DROP TABLE`, no `CASCADE`, no `IF EXISTS` | **PASS** — see §2.1 |
| **P-6** | `migration.sql` is unambiguously marked as not yet applied | **PASS** — header reads `EXECUTABLE MIGRATION - NOT YET APPLIED`; `Applied: NOT APPLIED`; `Approved by: NOT APPROVED` |
| **P-7** | No secret, token, key or connection string added | **PASS** — see §2.2 |
| **P-8** | No backend write beyond the two approved statements | **PASS** — exactly two `DROP TABLE` statements were executed, both approved; every other statement in this phase was a `SELECT`. No `CREATE`, `ALTER`, `GRANT`, `REVOKE`, `INSERT`, `UPDATE`, `DELETE` or `TRUNCATE` was issued |

### 2.1 Statement counting — and the artefact it avoids

Both `.sql` files contain the words `DROP`, `CREATE`, `INSERT` and `GRANT` inside `--` comments. A raw `grep` therefore **over-counts**, the same class of counting artefact recorded for `haptic(` in Phase 20.5 and for `NOT A MIGRATION` in Phase 21.4.

Counts below are taken **after stripping comment lines**, and are the only figures this record treats as authoritative:

| File | Executable statements | Composition |
|---|---|---|
| `migration.sql` | **2** | `DROP TABLE public._test_results;` and `DROP TABLE public._test_run_log;` |
| `pre-drop-snapshot.sql` | **6** | 2 × `CREATE TABLE`, 2 × `INSERT` (4 + 24 = **28** value tuples), 2 × `setval` |

`CASCADE` occurrences in `migration.sql`: **3** in the whole file, all on comment lines 56, 58 and 61, inside the block explaining why it is omitted — **0** in any executable statement.
`IF EXISTS` occurrences in `migration.sql`: **3** in the whole file, likewise all on comment lines 56, 63 and 65 — **0** in any executable statement.

Those raw figures are recorded here precisely because they are the artefact: a reviewer grepping the file finds three hits for each and must not read them as three uses. The authoritative figure in both cases is the executable count, **0**.

### 2.2 Secret scan

Scanned every added line for JWT-shaped strings (`eyJ…`), `access_token` / `refresh_token` values, `service_role` secrets, `SUPABASE_SERVICE`, `sk_live`, `postgres://` / `postgresql://` connection strings, `password`, and the publishable key literal.

**Result: zero secret values.**

Benign pattern hits, recorded so a future run does not raise a false alarm:

| Pattern | Hits | What they actually are |
|---|---|---|
| `service_role` | several | The **Postgres role name**, in ACL strings and in the S-5 explanation — never a key |
| `password` | 1 | The name of the excluded `auth_leaked_password_protection` Advisor finding |

The project ref `kbnmkyvbwkuvcklywdhk` appears. It is not a secret: it is already committed in `index.html` and public in every deployed page.

**On the 28 preserved rows.** Phase 21.3's rule R-7 — *no query selects application row data* — was deliberately and explicitly set aside for this phase, under direct approval to read these two tables in full for exactly this purpose. All 28 rows were inspected. **No credential, token, password, personal information or production user content is present.** The longest string in either table is 57 characters; the only uuid identifies the test run, not a person; `Deleted User` is the backend's anonymisation sentinel literal. The snapshot is therefore safe to commit.

---

## 3. Pre-flight requirements — executed 2026-09-08 15:22:07+00

Run immediately before applying `migration.sql`. **All 17 matched exactly. No hard-stop condition fired.**

| # | Requirement | Expected | Observed | Status |
|---|---|---|---|---|
| **F-1** | `public._test_results` row count | exactly **4** | 4 | **PASS** |
| **F-2** | `public._test_run_log` row count | exactly **24** | 24 | **PASS** |
| **F-3** | Inbound foreign keys, both tables | **0** | 0 / 0 | **PASS** |
| **F-4** | Outbound foreign keys, both tables | **0** | 0 / 0 | **PASS** |
| **F-5** | Dependent views / materialized views | **0** | 0 / 0 | **PASS** |
| **F-6** | Functions referencing either table (`public`, `auth`, `storage`) | **0** | 0 / 0 | **PASS** |
| **F-7** | Triggers, both tables | **0** | 0 / 0 | **PASS** |
| **F-8** | Policies referencing either table | **0** | 0 / 0 | **PASS** |
| **F-9** | Publication memberships (incl. `supabase_realtime`) | **0** | 0 / 0 | **PASS** |
| **F-10** | Application references in `index.html` | **0** | 0 | **PASS** |
| **F-11** | ACL, both tables, byte-identical to the string below | unchanged | identical on both | **PASS** |
| **F-12** | RLS state, both tables | `enabled=false, forced=false, policies=0` | exactly that | **PASS** |
| **F-13** | Both relations present | 2 in `pg_class` | 2 | **PASS** |
| **F-14** | Both owned sequences present | 2 | 2 | **PASS** |
| **F-15** | Snapshot committed **and pushed** before mutation | on the remote | `origin/phase-21.5-s2-test-table-removal` = `d5417e9` = local; remote blob SHA-256 `adb374b7…0e7baa97` | **PASS** |
| **F-16** | Working tree clean on `phase-21.5-s2-test-table-removal` | clean | clean at `d5417e9` | **PASS** |
| **F-17** | Explicit production-mutation approval given for this change | given | **given** | **PASS** |

**No unexpected object had appeared.** The `public` schema held exactly 22 relations at pre-flight — 19 tables, 2 sequences, 1 view — matching the Phase 21.3 record. Both sequences were the two belonging to these tables.

**Expected ACL for F-11**, both tables:

```
{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,
 authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
```

F-11 was asserted on the string **and** on per-privilege `has_table_privilege` results for `anon` and `authenticated` across SELECT, INSERT, UPDATE, DELETE and TRUNCATE — **all 10 returned `true`**, confirming the exposure was still fully present at the moment of the drop.

### 3.1 Baseline captured before mutation

| Item | Value | Status |
|---|---|---|
| `public` table count | **19** | **CAPTURED** |
| `public` views / sequences / functions | 1 / 2 / 34 | **CAPTURED** |
| Policies (all schemas) / triggers (all schemas) | 29 / 9 | **CAPTURED** |
| Full sorted list of `public` relations with relkind | 22 entries, md5 `e443b9a6e19cba90340282fd557eca26` | **CAPTURED** |
| Full Security Advisor result set (`type=security`) | 6 lints, 37 findings — 3 ERROR, 32 WARN, 2 INFO | **CAPTURED** |
| `pg_default_acl` entries | 24, incl. `postgres/r/public = {…anon=arwdDxtm…}` | **CAPTURED** |
| `supabase_migrations.schema_migrations` records | 41 | **CAPTURED** |

---

## 4. Post-mutation checks — executed 2026-09-08 15:23:46+00

| # | Check | Passes when | Observed | Status |
|---|---|---|---|---|
| **M-1** | `public._test_results` absent | not in `pg_class` | absent | **PASS** |
| **M-2** | `public._test_run_log` absent | not in `pg_class` | absent | **PASS** |
| **M-3** | `_test_results_id_seq` absent | dropped with its table | absent | **PASS** |
| **M-4** | `_test_run_log_id_seq` absent | dropped with its table | absent | **PASS** |
| **M-5** | `public` table count | **19 → 17** | 17 | **PASS** |
| **M-6** | All unrelated relations unchanged | baseline minus exactly these four objects | 22 → 18; the 4 removed are exactly `r:_test_results`, `r:_test_run_log`, `S:_test_results_id_seq`, `S:_test_run_log_id_seq`; remaining 18 identical | **PASS** |
| **M-7** | S-2 Advisor findings gone | both `rls_disabled_in_public` ERRORs absent | the lint no longer appears at all | **PASS** |
| **M-8** | No new Advisor finding introduced | baseline minus exactly those two, zero additions | 6 lints → 5; 37 findings → 35; every remaining lint identical in name, level and count | **PASS** |
| **M-9** | Production Stage smoke check | `stagerz.app` loads, Stage renders, nav bar present, no console error | HTTP 200, 271,474 bytes, SDK tag and SRI hash intact, 0 `_test_` references; **browser session confirmed Stage loads, navigation visible, a profile opens, no visible errors** | **PASS** — see §4.1 |
| **M-10** | Production profile-read smoke check | a profile read through `public_profiles` succeeds | `GET /rest/v1/public_profiles` as `anon` → HTTP 200, one row with `display_name` | **PASS** |
| **M-11** | Statement count actually executed | exactly **2**, both `DROP TABLE` | exactly 2, verbatim from `migration.sql` | **PASS** |

### 4.1 M-9 — both halves now observed

**Server level, automated.** `https://stagerz.app` returns HTTP 200 with the expected 271,474-byte page, the pinned `supabase-js@2.112.1` script tag and its SRI hash are intact, and the served page contains zero references to either dropped table.

**Browser level, manually confirmed by the user against production `stagerz.app` after the mutation:**

| Observation | Result |
|---|---|
| Stage loads | **normally** |
| Navigation visible | **yes** |
| A profile opens | **successfully** |
| Visible errors | **none observed** |

M-9 was recorded as **PARTIAL** until this confirmation arrived, and it is upgraded to **PASS** on the strength of the observation, not on the inference. The distinction is kept in this record on purpose: zero application references and a passing M-10 were always a good *argument* that nothing could regress, but an argument is not an observation. The profile opening is the more informative half — it exercises the `public_profiles` read path end to end through the UI, which is the path Phase 21.4 touched and the one Test 16 of the dropped suite had covered.

### 4.2 Two results worth stating beyond the check list

**The absence of `CASCADE` produced positive evidence.** Both `DROP TABLE` statements succeeded. A bare `DROP` fails if anything depends on the table, so success is empirical proof that nothing did — independently confirming the catalog evidence in `phase-definition.md` §5, which had been established only by reading `pg_depend`, `pg_constraint`, `pg_rewrite`, `pg_proc`, `pg_trigger`, `pg_policy` and `pg_publication_rel`.

**The exposure is gone at the API layer, not merely the catalog.** As `anon`, `GET /rest/v1/_test_results` and `GET /rest/v1/_test_run_log` now both return **HTTP 404 `PGRST205`**. Before the drop, the same role held SELECT, INSERT, UPDATE, DELETE and TRUNCATE on both. This is the check that matters most: PostgREST is the path an attacker would have used.

### 4.3 What was verified as unchanged

| Object class | Before | After |
|---|---|---|
| `public` views | 1 | **1** |
| `public` functions | 34 | **34** |
| Policies, all schemas | 29 | **29** |
| Triggers, all schemas | 9 | **9** |
| `pg_default_acl` entries | 24 | **24** |
| `supabase_migrations.schema_migrations` | 41 | **41** |

**S-5 was re-read after the drop and is unchanged — it remains OPEN, deliberately.** The default ACL for `postgres` / TABLES / `public` is still `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`. Nothing in this phase touched it, and the next table created by `postgres` in `public` will still be granted ALL to `anon`.

The migration-record count is unchanged because the two statements were executed directly rather than through the migration tool. That was deliberate: the approval named exactly two statements, and recording a migration would have written a third change.

---

## 5. Post-mutation documentation updates

Performed only after §4 passed.

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql`: `NOT YET APPLIED` → `APPLIED`, with timestamp, approval attribution, checkpoint commit and full post-change evidence | **DONE** |
| **D-2** | `analysis/phase-21.3/backend-contract.md` §0.2: S-2 `OPEN` → `REMEDIATED`; §11.1 given a HISTORICAL (pre-21.5) banner; the epoch table extended to three epochs | **DONE** |
| **D-3** | `.apos/PROJECT_CONTEXT.md`: Phase 21.5 completion and S-2 REMEDIATED | **DONE** |
| **D-4** | `phase-definition.md`: remediation result and final S-2 state | **DONE** |
| **D-5** | This record: §3 and §4 results filled in, `PENDING` markers cleared | **DONE** |
| **D-6** | Commit, push, PR, review, merge | **PENDING** — awaiting approval |

**Historical evidence was preserved, not rewritten.** `backend-contract.md` §11.1 still describes the exposure exactly as it was found; it now carries a banner marking it as pre-21.5 state. The finding is not erased, in the same way Phase 21.4 preserved the S-1 evidence in §11.0 and §12.

---

## 6. Unresolved concerns

1. **S-5 remains open, and it is the cause of S-2.** Dropping these tables makes them permanently immune to it, but every future table created by `postgres` in `public` will still be granted ALL to `anon` at creation. This phase does not address that, deliberately (`phase-definition.md` §8). It should not be left indefinitely.
2. **Rollback re-opens the finding.** While S-5 stands, restoring `pre-drop-snapshot.sql` re-acquires the broad grants. Documented in the snapshot and in `phase-definition.md` §9; noted here so it is not discovered at the moment it matters.
3. **The harness is unrecoverable.** The 28 rows are preserved, but the suite that produced them was never in this repository. Only the results survive, not the ability to re-run them.
4. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it. The rows are evidence bearing on it (`phase-definition.md` §7) but do not settle it.

---

## 7. Summary

**S-2 is REMEDIATED.**

All **17 pre-flight requirements matched exactly** — row counts 4 and 24, every one of nine dependency classes at zero, zero application references, and an ACL byte-identical to the reviewed state with all ten `has_table_privilege` probes still returning `true`. No hard-stop condition fired.

Exactly two statements were executed: `DROP TABLE public._test_results;` and `DROP TABLE public._test_run_log;` — bare, no `CASCADE`, no `IF EXISTS`, nothing else. Both succeeded, which without `CASCADE` is itself proof that nothing depended on either table.

**All eleven post-mutation checks pass.** M-9 was held at PARTIAL until its browser half was observed rather than inferred, and closed on manual confirmation against production: Stage loads, navigation visible, a profile opens, no visible errors. Both tables and both owned sequences are gone, `public` went 19 → 17 tables, the relation list lost exactly those four objects and nothing else, and views, functions, policies, triggers, default ACLs and migration records are all unchanged. The Security Advisor's `rls_disabled_in_public` lint no longer appears — ERROR-level findings dropped 3 → 1 — with zero new findings at any severity. As `anon`, both REST endpoints now return HTTP 404 `PGRST205`, while `public_profiles` still returns HTTP 200 with a row.

The 28 rows are preserved in `pre-drop-snapshot.sql`, committed and pushed to `origin` before the mutation ran, verified by SHA-256 on the remote.

**Level 1 is satisfied.** Commit, push and PR remain outstanding and are blocked solely on approval.
