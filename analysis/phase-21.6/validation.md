# Phase 21.6 — Validation Record

**Branch:** `phase-21.6-s5-default-privileges`
**Base commit:** `168d068`
**Pre-mutation checkpoint:** `c06c6758b7a804a0d866e5fbc2d282105a40f64e`
**Validation level:** **1** — documentation and a backend-only change; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **APPLIED 2026-09-11 — S-5 REMEDIATED. VALIDATION COMPLETE.** All 14 pre-flight requirements matched exactly. **All 15 post-change checks pass**, M-15 closed 2026-09-12 by a manual authenticated write smoke test (§4.3).

Exactly one backend change was made: the four approved `ALTER DEFAULT PRIVILEGES` statements. Every other statement issued in this phase was a `SELECT`.

---

## 1. What this record claims, and what it does not

**Claims:** the change was applied against a state that matched the reviewed baseline exactly; it altered precisely the four intended `pg_default_acl` entries and nothing else; every existing object ACL in `public` and `storage` is byte-identical before and after, column-level grants included; and a signed-in write through existing-object permissions has been observed working after the change.

**Does not claim:** that a newly created table now receives no `anon` grants. That is the goal, and it is proven through Postgres's documented default-privilege semantics from M-1 to M-3, not by creating a test object — which this phase deliberately did not do (§4.4).

> **Naming collision — read this.** The check ids `P-1…P-8` in §2 are repository-safety checks and are **not** the security findings `S-1…S-7`. Security-finding status is maintained in one place only: `analysis/phase-21.3/backend-contract.md` §0.2. As of 2026-09-12: **S-1, S-2 and S-5 REMEDIATED**; **S-3, S-4, S-6 and S-7 OPEN**.

---

## 2. Executed checks — repository safety

| # | Check | Result |
|---|---|---|
| **P-1** | `index.html` unmodified | **PASS** — not in the diff; no application source touched |
| **P-2** | Phase 21.3 historical evidence, 21.4 and 21.5 artifacts unmodified | **PASS** — `analysis/phase-21.4/` and `analysis/phase-21.5/` untouched; `analysis/phase-21.3/backend-contract.md` receives only a current-status update to §0.2, the designated single status record (§5, D-4) |
| **P-3** | `.apos/PROJECT_CONTEXT.md` updated only after successful remediation | **PASS** — edited after §4 passed, not before |
| **P-4** | `migration.sql` contains exactly four executable statements, all `ALTER DEFAULT PRIVILEGES` | **PASS** — see §2.1 |
| **P-5** | Every statement carries `FOR ROLE postgres`, a correct `IN SCHEMA`, and `REVOKE ALL` | **PASS** — see §2.1 |
| **P-6** | No statement touches FUNCTIONS, `service_role`, `postgres`, or any existing object | **PASS** — see §2.1 |
| **P-7** | `migration.sql` marked with its true state | **PASS** — `EXECUTABLE MIGRATION - APPLIED`, with timestamp, approval, checkpoint commit, executing role and final validation status |
| **P-8** | No backend write beyond the four approved statements | **PASS** — exactly four `ALTER DEFAULT PRIVILEGES` statements, in one execution. No `GRANT`, `REVOKE`, `CREATE`, `ALTER TABLE`, `DROP`, `INSERT`, `UPDATE` or `DELETE` was issued by this phase. Migration records still **41** |

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

The four statements, normalised — byte-identical to those in checkpoint `c06c675`:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON TABLES    FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON SEQUENCES FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON TABLES    FROM anon, authenticated
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON SEQUENCES FROM anon, authenticated
```

**The raw whole-file figures are the artefact.** A reviewer grepping `migration.sql` finds far more hits for `GRANT`, `FUNCTIONS`, `service_role` and `ALTER DEFAULT PRIVILEGES` than the table above. Every surplus hit is on a comment line. None may be read as a use.

---

## 3. Pre-flight requirements — executed 2026-09-11 21:24:38+00

Run immediately before the change. **All 14 matched exactly. No hard-stop condition fired.**

| # | Requirement | Expected | Observed | Status |
|---|---|---|---|---|
| **F-1** | Full `pg_default_acl` capture | exactly **24** entries, captured verbatim | 24, captured | **PASS** |
| **F-2** | Global entries (`defaclnamespace = 0`) | **0** | 0 | **PASS** |
| **F-3** | `postgres` / `public` / TABLES (oid 16492) | `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` | identical | **PASS** |
| **F-4** | `postgres` / `public` / SEQUENCES (oid 16494) | `{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}` | identical | **PASS** |
| **F-5** | `postgres` / `storage` / TABLES (oid 16548) | identical to F-3 | identical | **PASS** |
| **F-6** | `postgres` / `storage` / SEQUENCES (oid 16550) | identical to F-4 | identical | **PASS** |
| **F-7** | `postgres` / `public` + `storage` / FUNCTIONS (oids 16493, 16549) | `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | identical, both | **PASS** |
| **F-8** | Executing role | `postgres`, or a member of it | `current_user` = `session_user` = `postgres`; member of `postgres`; not superuser | **PASS** |
| **F-9** | All `public` relation ACLs captured verbatim | 18 relations, matching §3.2 | 18, identical to §3.2 | **PASS** |
| **F-10** | All `public` function ACLs captured | 34 functions | 34, fingerprinted (§3.1) | **PASS** |
| **F-11** | `public_profiles` | `anon=r/postgres`, `authenticated=r/postgres` | exactly that | **PASS** |
| **F-12** | Security Advisor baseline | 5 lints / 35 findings — 1 ERROR, 32 WARN, 2 INFO | exactly that | **PASS** |
| **F-13** | Repository clean on this branch, `migration.sql` committed and pushed | clean, on `origin` | HEAD `c06c675` = `origin`; tree clean; committed SHA-256 `bf5cb656…aab2d0` | **PASS** |
| **F-14** | Explicit production-mutation approval for this change | given | **given** | **PASS** |

**Additional pre-flight observations, all as expected:** `public` holds **0** sequences; `_test_results` and `_test_run_log` are **absent**; **0** relations in `public` carry `anon=arwdDxtm`; `index.html` has **0** references to the S-2 tables.

### 3.1 Baseline fingerprints

Each fingerprint is the md5 of the ordered, newline-joined `name=acl` text for that object set. They are used for equality only.

| Object set | Count | Pre-flight fingerprint |
|---|---|---|
| The 20 **non-targeted** `pg_default_acl` entries | 20 | `214c7692b94b0410bd43ed623d5f0b40` |
| `public` relations | 18 | `eb5f241e4fc2107e9b063e0d105f9080` |
| `public` functions | 34 | `b573f7fd22d2ce5a2c810b78318b47a3` |
| `storage` relations | 8 | `219b3af9ad84bd4396b5002d61bff025` |
| `storage` functions | 17 | `9004d75ecb8885e8796438e688236ef6` |

`storage` is fingerprinted as well as `public` because the change touched `storage` defaults too — so `storage`'s existing objects needed the same proof of non-retroactivity.

**These fingerprints cover table (`relacl`) and function (`proacl`) grants only. They do not cover column-level grants (`attacl`)** — a gap found during the M-15 diagnosis and closed separately in §4.5.

### 3.2 `public` relation ACLs — identical at pre-flight and post-change

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

**`users` still carries `m` for both roles, and it was supposed to.** S-6 is deferred to Phase 21.7. Its `m` surviving unchanged is part of what proves this phase touched no existing object.

Plus the view `public_profiles`: `anon=r`, `authenticated=r`.

---

## 4. Post-change checks — executed 2026-09-11 21:26:04+00; M-15 closed 2026-09-12

| # | Check | Passes when | Observed | Status |
|---|---|---|---|---|
| **M-1** | Exactly 4 default-ACL entries changed | only `postgres`/`public`/TABLES, `postgres`/`public`/SEQUENCES, `postgres`/`storage`/TABLES, `postgres`/`storage`/SEQUENCES | exactly those four; the other 20 fingerprint-identical (`214c7692…`) | **PASS** |
| **M-2** | `anon` and `authenticated` absent from those 4 | neither role in any of the four ACLs | absent from all four | **PASS** |
| **M-3** | `postgres` and `service_role` retained | TABLES `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`; SEQUENCES `{postgres=rwU/postgres,service_role=rwU/postgres}` | exactly those strings, all four | **PASS** |
| **M-4** | Entry count unchanged | **24** | 24 — same oids, updated in place | **PASS** |
| **M-5** | No new global entry | `defaclnamespace = 0` count **0** | 0 | **PASS** |
| **M-6** | FUNCTIONS defaults unchanged | oids 16493, 16549 identical to F-7 | identical | **PASS** |
| **M-7** | Platform-role entries unchanged | all 15 `supabase_admin` + 3 `supabase_auth_admin` identical | identical (within the 20-entry fingerprint) | **PASS** |
| **M-8** | Every existing `public` relation ACL byte-identical | all 18 match F-9 — including `users` still holding `m` | fingerprint `eb5f241e…` before and after; verbatim list identical | **PASS** |
| **M-9** | `public_profiles` unchanged | `anon=r`, `authenticated=r` | unchanged | **PASS** |
| **M-10** | No S-1 reintroduction | no INSERT/UPDATE/DELETE for `anon`/`authenticated` on `public_profiles` or `public.users` | `public_profiles`: SELECT only for both. `public.users`: none of SELECT/INSERT/UPDATE/DELETE/TRUNCATE for either | **PASS** |
| **M-11** | No S-2 reintroduction | S-2 tables absent; no `anon=arwdDxtm`; no `anon` TRUNCATE | tables absent; 0 relations with `anon=arwdDxtm`; REST endpoints both **HTTP 404** | **PASS** |
| **M-12** | Full `relacl` / `proacl` diff empty | all four fingerprints identical | `public` relations, `public` functions, `storage` relations, `storage` functions — **all identical**. Column grants checked separately, §4.5 | **PASS** |
| **M-13** | Security Advisor does not regress | equal to F-12 | 5 lints, 35 findings — 1 ERROR, 32 WARN, 2 INFO. Every lint identical in name, level and count. Zero additions | **PASS** |
| **M-14** | Anon read path intact | `GET /rest/v1/public_profiles` as `anon` → 200 with a row | HTTP **200**, one row with `display_name`. `stagerz.app` HTTP 200, 271,474 bytes, SDK tag and SRI hash intact | **PASS** |
| **M-15** | Authenticated existing-object write path intact | a signed-in session on `stagerz.app` completes a write through existing-object permissions, with no visible error and no unintended data change | **Profile → Edit Profile → Save with no values changed**: save completed successfully, no visible error, existing profile data unchanged | **PASS** — 2026-09-12, §4.3 |

### 4.1 The default-privilege diff

Only these four rows changed. Each lost exactly its `anon` and `authenticated` elements:

| oid | Entry | Before | After |
|---|---|---|---|
| 16492 | `postgres` / `public` / TABLES | `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| 16494 | `postgres` / `public` / SEQUENCES | `{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}` | `{postgres=rwU/postgres,service_role=rwU/postgres}` |
| 16548 | `postgres` / `storage` / TABLES | *as 16492* | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| 16550 | `postgres` / `storage` / SEQUENCES | *as 16494* | `{postgres=rwU/postgres,service_role=rwU/postgres}` |

The four oids are unchanged: Postgres updated each row in place, because each retained a non-empty ACL. That is why the entry count stays at 24 instead of dropping.

### 4.2 Which checks carry the safety argument

**M-8, M-12 and §4.5.** This phase's safety claim was that `ALTER DEFAULT PRIVILEGES` is not retroactive. That is verified empirically across all 18 `public` relations, 34 `public` functions, 8 `storage` relations, 17 `storage` functions and every column-level grant in `public`: **not one existing permission moved.**

**M-1 through M-5** prove the change happened, and happened in the right place. They mattered because every failure mode of this statement is silent: running as the wrong role, or omitting `IN SCHEMA`, produces SQL that succeeds and fixes nothing. The SQL's success was not evidence the fix had worked; these checks are.

**M-13 could not confirm the fix and was never meant to.** The Security Advisor has no default-privilege lint. It was unchanged, as expected, and served only to rule out regression.

### 4.3 M-15 — test-design correction, then PASS

**The original M-15 instruction was invalid and was replaced, not failed.**

As first written, M-15 asked for "a like or follow" on `stagerz.app`. When that was attempted, liking proved impossible. A read-only diagnosis established why, and the cause is neither a Phase 21.6 regression nor a product defect introduced here:

- **No handler exists.** No Like element in the app has a click handler — not the content viewer ([index.html:872-876](../../index.html#L872-L876), where the neighbouring Share and Recreate actions *do* have one), not the feed card ([1522](../../index.html#L1522)), not the short ([1535](../../index.html#L1535)).
- **The counts are static.** They come from the hard-coded `stageData` array ([1471](../../index.html#L1471)), which is declared once and only ever read ([1488](../../index.html#L1488)). It is never populated from the backend.
- **No write path.** Of every Supabase write in the application — 6 direct table writes and 20 RPCs — **none targets `likes` or `follows`.**
- **Already on record.** Phase 21.3 listed both tables as unreferenced by the frontend (`backend-contract.md` §11.5), captured 2026-08-22/23, weeks before this phase.
- **Never used.** Both tables hold **0 rows**, and always have.
- **Untouched by this phase.** `likes` still reads `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}`, identical to pre-flight, inside the unchanged `eb5f241e…` fingerprint. Default privileges apply only at `CREATE`, and `likes` was created in July 2026.

**This is recorded as a test-design correction: my error in writing M-15, not a product failure.** `Like` and `Follow` are display-only in the current build; that is a pre-existing product gap, noted in §6, and outside Phase 21.6.

**The replacement test, and why it is equivalent for this phase.** M-15 exists to observe that a signed-in write through **existing-object permissions** still works. `Profile → Edit Profile → Save` does exactly that, on a path the application genuinely uses:

- a signed-in session and JWT → PostgREST `PATCH`
- **column-level UPDATE grants** on `profiles` (5 columns) and `users.username`
- **own-row RLS UPDATE policies** on both tables
- **EXECUTE on the SECURITY DEFINER helper** `current_active_stagerz_user_id()` that those policies call

Saving with nothing changed rewrites identical values, and neither table has a trigger, so the test is idempotent and creates no data — consistent with the standing instruction not to manufacture application data to satisfy a test. A Like would have exercised a table-level INSERT grant; this exercises column-level UPDATE grants, RLS and the helper function. Both belong to the same class — permissions on objects that already existed — which is the only class Phase 21.6 could conceivably have disturbed.

**Result, manually confirmed by the user on production `stagerz.app`, 2026-09-12:** signed in, opened Profile → Edit Profile, changed nothing, clicked Save; the profile save completed successfully with no visible error.

> Evidence, verbatim as reported: *"Profil speichern funktioniert, keine Fehlermeldung."*

**M-15 = PASS.**

### 4.4 What remains unverifiable at mutation time

The actual goal — *a newly created table no longer grants anything to `anon`* — cannot be tested without creating an object, which this phase deliberately does not do. It follows from M-1 to M-3 through Postgres's documented default-privilege semantics, and will be confirmed empirically the first time a legitimate migration creates a table (§6).

### 4.5 Column-level permissions — gap found, checked, unchanged

The M-15 diagnosis surfaced a gap in this record's own evidence: the §3.1 fingerprints cover `relacl` and `proacl` but **not `attacl`**, the column-level grants. That matters, because the application's real authenticated writes — profile, username, notifications, wanted posts — depend on column-level UPDATE grants rather than table-level ones.

The live column grants were therefore compared against the **pre-Phase-21.6 baseline** recorded in `analysis/phase-21.3/backend-contract.md` §11.4, captured 2026-08-22/23 and re-verified 2026-08-31 after Phase 21.4 — in both cases well before this phase.

| Relation | Baseline: `authenticated` column UPDATE | Live after Phase 21.6 | Match |
|---|---|---|---|
| `users` | `bio, first_name, last_name, location, photo_url, username` — **6** | same 6 | ✅ |
| `profiles` | `available, bio, category, country_flag, display_name, location, looking_for, role, skills` — **9** | same 9 | ✅ |
| `notifications` | **`read` only** | `read` only | ✅ |
| `wanted_posts` | `category, compensation, description, location, remote, role_needed, title` — **7** | same 7 | ✅ |

**No column-level permission changed during Phase 21.6.** The narrow grants Phase 21.3 relied on — notably `users` excluding `anonymized_at`, `is_system` and `id`, and `wanted_posts` excluding `status` and `user_id` — are all intact.

This is a comparison against a documented pre-change baseline rather than a live before/after snapshot taken minutes apart, which is a weaker instrument than the §3.1 fingerprints. It is stated that way deliberately. It is nonetheless conclusive for this phase, because `ALTER DEFAULT PRIVILEGES` has no mechanism to alter column grants at all: default privileges are consulted only at `CREATE`, and they do not express column-level grants in the first place.

---

## 5. Post-change documentation updates

Performed after §4 passed.

| # | Update | Status |
|---|---|---|
| **D-1** | `migration.sql`: `NOT YET APPLIED` → `APPLIED`, with timestamp, approval, checkpoint commit, executing role, full pre/post evidence, and final validation status | **DONE** |
| **D-2** | This record: §3 and §4 results filled in; M-15 corrected and closed; §4.5 added | **DONE** |
| **D-3** | `phase-definition.md`: remediation result and final S-5 state | **DONE** |
| **D-4** | `analysis/phase-21.3/backend-contract.md` §0.2: S-5 `OPEN` → `REMEDIATED`; S-6 and S-7 recorded as OPEN. **Current-status rows only** — §0.2 is this project's designated single record of finding status, so leaving S-5 marked OPEN there would contradict this record. No historical evidence is rewritten | **DONE** |
| **D-5** | `.apos/PROJECT_CONTEXT.md`: Phase 21.6 complete, S-5 REMEDIATED, S-6/S-7 carried to 21.7 | **DONE** |
| **D-6** | Commit, push, PR, review, merge | **PENDING** |

---

## 6. Unresolved concerns

1. **S-6 and S-7 remain open**, by design. This change does not touch `public.users`' `MAINTAIN` residue or the three `PUBLIC`-executable trigger functions — the untouched `m` in §3.2 is proof of that, not an oversight. Both are deferred to Phase 21.7.
2. **The `supabase_admin` twin (oid 16496) remains.** Any object created in `public` *as* `supabase_admin` still receives `arwdDxtm` for `anon`. All 18 existing relations are owned by `postgres`, which is evidence this is not the project's creation path — evidence, not proof.
3. **Proposed standing control — not part of this phase.** Every future migration that creates a table in `public` should end with an ACL assertion: the new relation's `relacl` contains no `anon` or `authenticated` element other than those it deliberately grants. That would catch the `supabase_admin` path, an accidental rollback of this phase, or a platform upgrade resetting the defaults. The first table created after this phase is the natural moment to confirm the fix empirically (§4.4).
4. **Dashboard behaviour has changed.** A table created through the Supabase dashboard will now be invisible to the REST API until explicitly granted. That is the intended behaviour, but anyone unaware of it will read it as a bug.
5. **Product gap, pre-existing and out of scope: `Like` and `Follow` are display-only.** The hearts carry `cursor:pointer` styling ([index.html:67](../../index.html#L67), [208](../../index.html#L208)) so they look interactive, but no handler exists and nothing is persisted; `.ap-follow` is orphaned CSS with no element using it. Meanwhile the `likes` and `follows` tables exist with full RLS policies and grants — backend ahead of frontend. Worth logging as a product item; **not** a Phase 21.6 defect and **not** something this phase changed.
6. **Validation-design lesson.** M-15 named a UI action that had never been verified to exist. A smoke test must be chosen from paths the application actually invokes — the enumerated write call sites in `backend-contract.md` §5 are the reliable source for that.
7. **Phase 21.3's Q-2 is still unanswered** — whether this project is still the *"disposable test project"* the code calls it.

---

## 7. Summary

**S-5 is REMEDIATED and Phase 21.6 validation is complete.**

All **14 pre-flight requirements matched exactly** — 24 default-privilege entries with none global, all four target ACLs and both FUNCTIONS ACLs byte-identical to the reviewed baseline, all 18 `public` relation ACLs as documented, the session running as `postgres`, and the checkpoint committed and pushed. No hard-stop condition fired.

Exactly four statements were executed, in one call: `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA {public, storage} REVOKE ALL ON {TABLES, SEQUENCES} FROM anon, authenticated`. All returned success.

**All 15 post-change checks pass.** Exactly the four targeted entries changed, each losing only `anon` and `authenticated` while keeping `postgres` and `service_role`. The entry count stayed at 24, no global entry appeared, and the other 20 entries are fingerprint-identical. **Every existing permission is byte-identical** — 77 relations and functions across `public` and `storage`, plus every column-level grant. The Advisor is unchanged at 35 findings, the anon read path returns 200, neither S-1 nor S-2 has been reintroduced, and a signed-in write through existing-object permissions has been observed working on production.

M-15 required a corrected test design before it could be run at all: the original instruction named a Like action the application does not implement. It was replaced with `Profile → Edit Profile → Save`, which exercises the same class of permission on a path the app genuinely uses, and it passed.

No future table, view or sequence created by `postgres` in `public` or `storage` will be granted anything automatically to `anon` or `authenticated` — so the mechanism that produced S-1 and S-2 is closed.

**Level 1 is satisfied.** Outstanding: commit, push and PR.
