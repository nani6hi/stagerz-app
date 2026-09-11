# Phase 21.6 — Validation Record

**Branch:** `phase-21.6-s5-default-privileges`
**Base commit:** `168d068`
**Validation level:** **1** — documentation and a prepared backend-only migration; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **Preparation validated. Mutation NOT APPROVED and NOT APPLIED. All mutation-dependent results are PENDING.**

No backend write has been performed or attempted at any point in this phase. Not committed, not pushed.

---

## 1. What this record claims, and what it does not

**Claims:** the three files in `analysis/phase-21.6/` are internally consistent, safe to hold in the repository unexecuted, and faithful to the live state captured read-only on 2026-09-09.

**Does not claim:** anything about the outcome of the mutation. It has not run. Every entry in §3–§5 reads **PENDING** and must not be reported otherwise until the mutation is approved, applied and checked.

> **Naming collision — read this.** The check ids `P-1…P-8` in §2 are repository-safety checks and are **not** the security findings `S-1…S-7`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of this writing: **S-1 and S-2 REMEDIATED**; **S-3, S-4, S-5 OPEN**; **S-6 and S-7 identified in the Phase 21.6 analysis, not yet recorded there, deferred to Phase 21.7.**

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — not in the diff; no application source touched |
| **P-2** | Phase 21.3, 21.4 and 21.5 artifacts unmodified | **PASS** — none in the diff |
| **P-3** | `.apos/PROJECT_CONTEXT.md` unmodified | **PASS** — updated only after successful remediation |
| **P-4** | `migration.sql` contains exactly four executable statements, all `ALTER DEFAULT PRIVILEGES` | **PASS** — see §2.1 |
| **P-5** | Every statement carries `FOR ROLE postgres`, a correct `IN SCHEMA`, and `REVOKE ALL` | **PASS** — see §2.1 |
| **P-6** | No statement touches FUNCTIONS, `service_role`, `postgres`, or any existing object | **PASS** — see §2.1 |
| **P-7** | `migration.sql` is unambiguously marked as not yet applied | **PASS** — `EXECUTABLE MIGRATION - NOT YET APPLIED`; `Applied: NOT APPLIED`; `Approved by: NOT APPROVED - preparation only` |
| **P-8** | No backend write performed or attempted | **PASS** — no SQL of any kind was issued during preparation |

### 2.1 Statement counting — and the artefact it avoids

`migration.sql` contains the words `GRANT`, `FUNCTIONS`, `service_role` and `ALTER DEFAULT PRIVILEGES` inside `--` comments — in the six rules, the rollback block and the out-of-scope list. A raw `grep` therefore **over-counts**, the same class of artefact recorded for `haptic(` in Phase 20.5, `NOT A MIGRATION` in Phase 21.4, and `CASCADE` in Phase 21.5.

Counts below are taken **after stripping comment lines**, joining lines and splitting on `;` — each statement spans two lines, so a per-line count would be wrong too. These are the only figures this record treats as authoritative:

| Property | Executable count |
|---|---|
| Statements | **4** |
| `ALTER DEFAULT PRIVILEGES` | **4** — and **0** statements of any other kind |
| `FOR ROLE postgres` | **4 of 4** |
| `IN SCHEMA public` / `IN SCHEMA storage` | **2 / 2** |
| `REVOKE ALL ON` | **4 of 4** — no enumerated privilege list |
| `ON TABLES` / `ON SEQUENCES` | **2 / 2** |
| `FROM anon, authenticated` as the exact statement tail | **4 of 4** |
| `FUNCTIONS` | **0** |
| `service_role` | **0** — never revoked |
| `GRANT` | **0** |
| `ON TABLE <name>` (existing-object form) | **0** |

The four statements, normalised:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON TABLES    FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON SEQUENCES FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON TABLES    FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON SEQUENCES FROM anon, authenticated
```

**The raw whole-file figures, recorded because they are the artefact.** A reviewer grepping `migration.sql` finds `GRANT` **4**, `FUNCTIONS` **5**, `service_role` **9** and `ALTER DEFAULT PRIVILEGES` **9**. Every surplus hit is on a comment line: the four `GRANT`s are the commented rollback, the `FUNCTIONS` and `service_role` hits are the rules and the out-of-scope list. None may be read as a use. The authoritative figures are the executable ones above.

---

## 3. Pre-flight requirements — HARD STOP ON MISMATCH

Re-run **immediately before** applying `migration.sql`. Any deviation stops the phase (`phase-definition.md` §12).

| # | Requirement | Expected | Status |
|---|---|---|---|
| **F-1** | Full `pg_default_acl` capture | exactly **24** entries, all captured verbatim | **PENDING** |
| **F-2** | Global entries (`defaclnamespace = 0`) | **0** | **PENDING** |
| **F-3** | `postgres` / `public` / TABLES (oid 16492) | `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` | **PENDING** |
| **F-4** | `postgres` / `public` / SEQUENCES (oid 16494) | `{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}` | **PENDING** |
| **F-5** | `postgres` / `storage` / TABLES (oid 16548) | identical to F-3 | **PENDING** |
| **F-6** | `postgres` / `storage` / SEQUENCES (oid 16550) | identical to F-4 | **PENDING** |
| **F-7** | `postgres` / `public` + `storage` / FUNCTIONS (oids 16493, 16549) | `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` — captured to prove they do not change | **PENDING** |
| **F-8** | Executing role | `current_user` is `postgres`, or `pg_has_role(current_user,'postgres','MEMBER')` is true | **PENDING** |
| **F-9** | All `public` relation ACLs captured verbatim | 18 relations, matching §3.1 | **PENDING** |
| **F-10** | All `public` function ACLs captured verbatim | 34 functions | **PENDING** |
| **F-11** | `public_profiles` | `anon=r/postgres`, `authenticated=r/postgres` | **PENDING** |
| **F-12** | Security Advisor baseline | 5 lints / 35 findings — 1 ERROR, 32 WARN, 2 INFO | **PENDING** |
| **F-13** | Repository clean on `phase-21.6-s5-default-privileges`, with `migration.sql` committed and pushed | clean, on `origin` | **PENDING** |
| **F-14** | Explicit production-mutation approval for this change | given | **PENDING — NOT GIVEN** |

### 3.1 Expected `public` relation ACLs (captured 2026-09-09)

All owned by `postgres`. Every one also holds `postgres=arwdDxtm/postgres` and `service_role=arwdDxtm/postgres`; only the application-role elements are listed.

| Relation | `anon` | `authenticated` |
|---|---|---|
| `collaboration_activity` | — | `r` |
| `collaboration_assets` | — | `ar` |
| `collaboration_credits` | — | `r` |
| `collaboration_messages` | — | `r` |
| `collaboration_participants` | — | `r` |
| `collaboration_tasks` | — | `r` |
| `collaborations` | — | `r` |
| `follows` | `r` | `ard` |
| `likes` | `r` | `ard` |
| `notifications` | — | `r` |
| `pending_asset_deletions` | — | — |
| `pending_auth_deletions` | — | — |
| `profiles` | `r` | `r` |
| `user_auth_accounts` | — | `r` |
| `users` | `m` | `m` — finding **S-6**, deferred |
| `wanted_applications` | — | `ar` |
| `wanted_posts` | `r` | `ard` |
| `public_profiles` (view) | `r` | `r` |

**`users` carries `m` for both roles, and this phase must leave it that way.** S-6 is deferred to Phase 21.7. Its `m` surviving unchanged is part of what F-9 → M-8 proves: that this phase touched no existing object.

---

## 4. Post-change checks — ALL PENDING

**No result below has been observed. The mutation has not run.**

| # | Check | Passes when | Status |
|---|---|---|---|
| **M-1** | Exactly 4 default-ACL entries changed | the full `pg_default_acl` diff against F-1 shows changes to **exactly** `postgres`/`public`/TABLES, `postgres`/`public`/SEQUENCES, `postgres`/`storage`/TABLES, `postgres`/`storage`/SEQUENCES — no more, no fewer | **PENDING** |
| **M-2** | `anon` and `authenticated` absent from those 4 | neither role appears in any of the four ACLs | **PENDING** |
| **M-3** | `postgres` and `service_role` retained | TABLES entries read `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`; SEQUENCES entries read `{postgres=rwU/postgres,service_role=rwU/postgres}` | **PENDING** |
| **M-4** | Entry count unchanged | still **24** | **PENDING** |
| **M-5** | No new global entry | `defaclnamespace = 0` count still **0** — the `IN SCHEMA` trap did not fire | **PENDING** |
| **M-6** | FUNCTIONS defaults unchanged | oids 16493, 16549 byte-identical to F-7 | **PENDING** |
| **M-7** | Platform-role entries unchanged | all 15 `supabase_admin` and 3 `supabase_auth_admin` entries byte-identical to F-1 | **PENDING** |
| **M-8** | Every existing `public` relation ACL byte-identical | all 18 match F-9 exactly — **including `users` still holding `m`** | **PENDING** |
| **M-9** | `public_profiles` unchanged | still `anon=r`, `authenticated=r` | **PENDING** |
| **M-10** | No S-1 reintroduction | `anon` and `authenticated` hold no INSERT, UPDATE or DELETE on `public_profiles` or `public.users` | **PENDING** |
| **M-11** | No S-2 reintroduction | no relation in `public` carries the `arwdDxtm` signature for `anon`; no relation grants `anon` TRUNCATE | **PENDING** |
| **M-12** | Full `relacl` / `proacl` diff empty | every relation and function ACL in `public` byte-identical to F-9 and F-10 | **PENDING** |
| **M-13** | Security Advisor does not regress | equal to F-12 — 5 lints, 35 findings, zero additions at any severity | **PENDING** |
| **M-14** | Anon read path intact | `GET /rest/v1/public_profiles` as `anon` → HTTP 200 with a row | **PENDING** |
| **M-15** | Authenticated end-to-end write path intact | a signed-in browser session on `stagerz.app` completes a write (e.g. a like or follow) and sees the result | **PENDING** |

### 4.1 Which checks carry the safety argument

**M-8 and M-12.** This phase's entire safety claim is that `ALTER DEFAULT PRIVILEGES` is not retroactive — that it cannot touch any existing object. Those two checks verify that claim empirically rather than trusting the documentation. They are *expected* to pass; if either fails, something other than these four statements ran, and that is hard stop **H-11**.

**M-1 through M-5** prove the change happened, and happened in the right place. They matter because every failure mode of this statement is silent: the wrong role, or a missing `IN SCHEMA`, produces a statement that succeeds and fixes nothing. Success of the SQL is not evidence of success of the remediation.

**M-13 cannot confirm the fix.** The Security Advisor has no default-privilege lint. It is expected to be unchanged, and exists only to catch regression. The fix itself is proven by M-1 to M-5 alone.

### 4.2 What is not verifiable at mutation time

The actual goal — *a newly created table no longer grants anything to `anon`* — cannot be tested without creating an object, which this phase does not do. It is proven by M-1 to M-3 through Postgres's documented default-privilege semantics, and confirmed empirically the next time a legitimate migration creates a table (§6).

---

## 5. Post-change documentation updates — ALL PENDING

Performed **only after** §4 passes.

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql`: `NOT YET APPLIED` → `APPLIED`, with timestamp, approval attribution and pre/post evidence | **PENDING** |
| **D-2** | This record: §3 and §4 results filled in | **PENDING** |
| **D-3** | `phase-definition.md`: remediation result and final S-5 state | **PENDING** |
| **D-4** | `analysis/phase-21.3/backend-contract.md` §0.2: S-5 `OPEN` → `REMEDIATED`, historical evidence preserved; S-6 and S-7 recorded as OPEN | **PENDING** |
| **D-5** | `.apos/PROJECT_CONTEXT.md`: Phase 21.6 completion, S-5 status, S-6/S-7 carried to 21.7 | **PENDING** |
| **D-6** | Commit, push, PR, review, merge | **PENDING** |

---

## 6. Unresolved concerns

1. **S-6 and S-7 remain open after this phase**, by design. Fixing the default does not touch `public.users`' `MAINTAIN` residue or the three `PUBLIC`-executable trigger functions. Both are deferred to Phase 21.7, and neither should be reported as addressed by this one.
2. **The `supabase_admin` twin (oid 16496) remains.** Any object created in `public` *as* `supabase_admin` still receives `arwdDxtm` for `anon`. All 18 existing relations are owned by `postgres`, which is evidence this is not the project's creation path — evidence, not proof.
3. **Proposed standing control — not part of this phase.** Every future migration that creates a table in `public` should end with an ACL assertion: the new relation's `relacl` contains no `anon` or `authenticated` element other than the ones it deliberately grants. That would catch the `supabase_admin` path, a rollback of this phase, or a platform upgrade resetting the defaults. The first table created after this phase is the natural moment to confirm the fix empirically.
4. **Dashboard behaviour changes.** A table created through the Supabase dashboard will be invisible to the REST API until explicitly granted. That is the intended behaviour, but anyone unaware of it will read it as a bug.
5. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it.

---

## 7. Summary

Three artifacts are prepared and statically verified. **Eight repository-safety checks pass**, including confirmation that `index.html` and the Phase 21.3, 21.4 and 21.5 artifacts are untouched, and that `migration.sql` contains exactly four executable statements — each `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA …  REVOKE ALL …  FROM anon, authenticated`.

**No backend write has been performed or attempted.**

Fourteen pre-flight requirements and fifteen post-change checks are defined. All of them are **PENDING**, and F-14 — explicit production-mutation approval — has **not been given**.

**Level 1 is satisfied for the preparation step.** The mutation step remains outstanding and is blocked solely on that approval.
