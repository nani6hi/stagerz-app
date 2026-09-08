# Phase 21.5 — Validation Record

**Branch:** `phase-21.5-s2-test-table-removal`
**Base commit:** `4ed53b9`
**Validation level:** **1** — documentation and a prepared migration; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **Preparation validated. Mutation NOT APPROVED and NOT APPLIED. All post-mutation results are PENDING.**

No backend write has been performed or attempted at any point in this phase. Not committed, not pushed.

---

## 1. What this record claims, and what it does not

**Claims:** the four files in `analysis/phase-21.5/` are internally consistent, safe to hold in the repository unexecuted, and faithful to the live state verified read-only on 2026-09-08.

**Does not claim:** anything about the outcome of the DROP. It has not run. Every entry in §4 and §5 reads **PENDING** and must not be reported otherwise until the mutation is approved, applied and checked.

That distinction is enforced below: §2 checks are **executed**, §3–§5 are **defined and pending**.

> **Naming collision — read this.** The check ids `P-1…P-8` (repository safety) in §2 are **not** the security findings `S-1…S-5`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of this writing: security **S-1 REMEDIATED**; **S-2, S-3, S-4, S-5 remain OPEN**. S-2 stays OPEN until this phase's mutation is applied and §4 passes.

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
| **P-8** | No backend write performed or attempted | **PASS** — every statement issued this phase was a `SELECT`; no `CREATE`/`ALTER`/`DROP`/`GRANT`/`REVOKE`/`INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` was executed |

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

## 3. Pre-flight requirements — HARD STOP ON MISMATCH

Re-run **immediately before** applying `migration.sql`, not earlier. Any deviation stops the phase; report it and do not proceed.

| # | Requirement | Expected | Status |
|---|---|---|---|
| **F-1** | `public._test_results` row count | exactly **4** | **PENDING** |
| **F-2** | `public._test_run_log` row count | exactly **24** | **PENDING** |
| **F-3** | Inbound foreign keys, both tables | **0** | **PENDING** |
| **F-4** | Outbound foreign keys, both tables | **0** | **PENDING** |
| **F-5** | Dependent views / materialized views | **0** | **PENDING** |
| **F-6** | Functions referencing either table (`public`, `auth`, `storage`) | **0** | **PENDING** |
| **F-7** | Triggers, both tables | **0** | **PENDING** |
| **F-8** | Policies referencing either table | **0** | **PENDING** |
| **F-9** | Publication memberships (incl. `supabase_realtime`) | **0** | **PENDING** |
| **F-10** | Application references in `index.html` | **0** | **PENDING** |
| **F-11** | ACL, both tables, byte-identical to the string below | unchanged | **PENDING** |
| **F-12** | RLS state, both tables | `enabled=false, forced=false, policies=0` | **PENDING** |
| **F-13** | Both relations present | `_test_results`, `_test_run_log` in `pg_class` | **PENDING** |
| **F-14** | Both owned sequences present | `_test_results_id_seq`, `_test_run_log_id_seq` | **PENDING** |
| **F-15** | Snapshot committed **and pushed** before mutation | `pre-drop-snapshot.sql` on the remote | **PENDING** |
| **F-16** | Working tree clean on `phase-21.5-s2-test-table-removal` | clean | **PENDING** |
| **F-17** | Explicit production-mutation approval given for this change | given | **PENDING — NOT GIVEN** |

**Expected ACL for F-11**, both tables:

```
{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,
 authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
```

F-11 is asserted on the string **and** on per-privilege `has_table_privilege` results for `anon` and `authenticated` across SELECT, INSERT, UPDATE, DELETE and TRUNCATE — all expected `true`. A narrower ACL would mean someone else changed the tables since verification, which is a stop condition even though it points the safe way.

### 3.1 Baseline to capture before mutation

Needed by §4, and only obtainable beforehand:

| Item | Expected value | Status |
|---|---|---|
| `public` table count | **19** | **PENDING** |
| Full sorted list of `public` relations with relkind | captured verbatim | **PENDING** |
| Full Security Advisor result set (`type=security`) | captured verbatim | **PENDING** |

---

## 4. Post-mutation checks — ALL PENDING

**No result below has been observed. The mutation has not run.**

| # | Check | Passes when | Status |
|---|---|---|---|
| **M-1** | `public._test_results` absent | not in `pg_class` for schema `public` | **PENDING** |
| **M-2** | `public._test_run_log` absent | not in `pg_class` for schema `public` | **PENDING** |
| **M-3** | `_test_results_id_seq` absent | owned sequence dropped with its table | **PENDING** |
| **M-4** | `_test_run_log_id_seq` absent | owned sequence dropped with its table | **PENDING** |
| **M-5** | `public` table count | **19 → 17** | **PENDING** |
| **M-6** | All unrelated relations unchanged | post-change relation list equals the §3.1 baseline **minus exactly these two tables** — no other relation added, removed, or changed in relkind | **PENDING** |
| **M-7** | S-2 Advisor findings gone | **both** `rls_disabled_in_public` ERROR findings naming `public._test_results` and `public._test_run_log` no longer appear | **PENDING** |
| **M-8** | No new Advisor finding introduced | post-change Advisor set equals the §3.1 baseline minus exactly the two findings in M-7 — **zero** additions at any severity | **PENDING** |
| **M-9** | Production Stage smoke check | `stagerz.app` loads, the Stage screen renders, the nav bar is present, no console error | **PENDING** |
| **M-10** | Production profile-read smoke check | a profile read through `public_profiles` returns the expected display name; the Edit Profile screen loads populated | **PENDING** |
| **M-11** | Statement count actually executed | exactly **2**, both `DROP TABLE`, matching `migration.sql` verbatim | **PENDING** |

**On M-9 and M-10.** With zero application references, neither can plausibly regress. They are run anyway: they cost little, they follow the Phase 21.4 precedent, and "no reference exists" is an argument, whereas a loaded page is an observation. They also guard against the failure mode M-6 is designed to catch — a DROP that removed more than intended.

**On M-8.** The check is equality against a captured baseline, not "no ERRORs". A new WARN or INFO finding is a failure of this check too, because it would mean the mutation changed something beyond the two tables.

---

## 5. Post-mutation documentation updates — ALL PENDING

Performed **only after** §4 passes. Not done in advance.

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql` header: `NOT APPLIED` → applied, with date and approval attribution | **PENDING** |
| **D-2** | `analysis/phase-21.3/backend-contract.md` §0.2: S-2 `OPEN` → `REMEDIATED` | **PENDING** |
| **D-3** | `.apos/PROJECT_CONTEXT.md:15`: S-2 status and phase register | **PENDING** |
| **D-4** | This record: §4 results filled in, `PENDING` markers cleared | **PENDING** |
| **D-5** | PR opened, reviewed, merged | **PENDING** |

---

## 6. Unresolved concerns

1. **S-5 remains open, and it is the cause of S-2.** Dropping these tables makes them permanently immune to it, but every future table created by `postgres` in `public` will still be granted ALL to `anon` at creation. This phase does not address that, deliberately (`phase-definition.md` §8). It should not be left indefinitely.
2. **Rollback re-opens the finding.** While S-5 stands, restoring `pre-drop-snapshot.sql` re-acquires the broad grants. Documented in the snapshot and in `phase-definition.md` §9; noted here so it is not discovered at the moment it matters.
3. **The harness is unrecoverable.** The 28 rows are preserved, but the suite that produced them was never in this repository. Only the results survive, not the ability to re-run them.
4. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it. The rows are evidence bearing on it (`phase-definition.md` §7) but do not settle it.

---

## 7. Summary

Four artifacts are prepared and statically verified. **Eight repository-safety checks pass**, including a secret scan with zero hits, confirmation that `index.html` and the Phase 21.3 and 21.4 artifacts are untouched, and confirmation that `migration.sql` contains exactly two executable statements — both bare `DROP TABLE`, no `CASCADE`, no `IF EXISTS`.

**No backend write has been performed or attempted.** Every statement issued during this phase was a `SELECT`.

Seventeen pre-flight requirements and eleven post-mutation checks are defined and ready to run. All of them are **PENDING**, and F-17 — explicit production-mutation approval — has **not been given**.

**Level 1 is satisfied for the preparation step.** The mutation step remains outstanding and is blocked solely on that approval.
