# Phase 21.6 — Close the default-privilege root cause (S-5)

**Branch:** `phase-21.6-s5-default-privileges`
**Base commit:** `168d068` (`main`, merge of PR #13 — Phase 21.5 / S-2)
**Addresses:** finding **S-5** from `analysis/phase-21.3/backend-contract.md` §0.2 — the root cause of S-1 and S-2
**Status:** **COMPLETE — S-5 REMEDIATED, production mutation applied 2026-09-11, validation closed 2026-09-12.** Pre-flight **14/14 PASS**; post-change **15/15 PASS**, including the authenticated browser write smoke test. See §16.
**Validation level:** **Level 1** — documentation and a backend-only change; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

Exactly one backend change was made: the four approved `ALTER DEFAULT PRIVILEGES` statements. No existing object was modified and no application source was touched. Not yet committed, not yet pushed.

---

## 1. Objective

Stop every future table, view and sequence created by `postgres` in `public` or `storage` from automatically granting `anon` and `authenticated` full privileges — including `TRUNCATE`.

S-1 and S-2 were fixed one object at a time. Both were symptoms of this one mechanism. Until it is changed, the next `CREATE TABLE` reproduces the same exposure, and safety depends on someone remembering to revoke it every single time.

**Pattern decision (`.apos/WORKFLOW.md`): Extend.** Phases 21.4 and 21.5 established the pattern: one finding, a minimal migration of exactly the approved statements, its own approval, pre-flight with hard stops, post-change verification. This phase follows it unchanged.

**Why this phase needs no data snapshot, unlike Phase 21.5.** Nothing is destroyed. The complete prior state is four ACL strings, recorded verbatim in `migration.sql`, and the rollback restores them byte-exactly. There is no data to preserve.

---

## 2. S-5 — exact evidence

Captured read-only on 2026-09-09 against `kbnmkyvbwkuvcklywdhk`. `pg_default_acl` holds **24 entries**:

| Grantor | Schemas | Entries |
|---|---|---|
| **`postgres`** | **`public`, `storage`** | **6** — TABLES, SEQUENCES, FUNCTIONS in each |
| `supabase_admin` | `extensions`, `graphql`, `graphql_public`, `public`, `realtime` | 15 |
| `supabase_auth_admin` | `auth` | 3 |

The four entries this phase changes:

| oid | Grantor | Schema | Object type | Current ACL |
|---|---|---|---|---|
| **16492** | `postgres` | `public` | TABLES | `{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| **16494** | `postgres` | `public` | SEQUENCES | `{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}` |
| **16548** | `postgres` | `storage` | TABLES | *identical to 16492* |
| **16550** | `postgres` | `storage` | SEQUENCES | *identical to 16494* |

`arwdDxtm` is INSERT, SELECT, UPDATE, DELETE, **TRUNCATE**, REFERENCES, TRIGGER and MAINTAIN. `rwU` is SELECT, UPDATE (`setval`) and USAGE (`nextval`).

**Origin: Supabase platform bootstrap, not a project migration.** None of the 41 migration records mentions `DEFAULT PRIVILEGES`. The `postgres`/`public` entries sit at oids **16492–16494** and the `supabase_admin`/`public` entries at **16495–16497** — six contiguous rows created together during database initialisation, before the first migration ran. No bootstrap SQL exists in this repository.

**A platform default is not the same thing as a safe default.** This one has already produced two ERROR-severity findings on this project, each of which needed its own remediation phase. Granting `anon` `TRUNCATE` on every future table is not defensible under any threat model, and Supabase's own Security Advisor flags the consequences.

---

## 3. Schema-scoped, not global

**Every one of the 24 entries has a non-zero `defaclnamespace`. No global entry exists.** The open question carried from Phase 21.5 is resolved: the dangerous `postgres` TABLES default is scoped to `public` — and separately to `storage` — not to every schema.

**Why it matters for the fix, not just the finding.** Postgres combines default privileges in layers: a schema-scoped entry is *added* to the role's global default, and a global default that does not exist falls back to the built-in rule (the owner gets everything, nobody else gets anything). So a `REVOKE` issued `IN SCHEMA` can only remove what that schema-scoped entry itself grants.

Here, that is exactly where the `anon` and `authenticated` grants live. With no global entry beneath them, revoking them `IN SCHEMA public` and `IN SCHEMA storage` removes them **completely**, with nothing left to inherit from underneath.

It also sets the trap `migration.sql` rule 2 warns about: omit `IN SCHEMA` and Postgres does not modify these entries — it creates a *new* global one.

---

## 4. Why current live exposure is zero

Surveyed 2026-09-09:

- **All 18 relations in `public` have been manually narrowed.** None carries the `arwdDxtm` signature for `anon`. None grants `anon` INSERT, UPDATE, DELETE or TRUNCATE.
- **`public` holds zero sequences.** The only two were dropped with the S-2 tables in Phase 21.5.
- **`postgres` owns no object in `storage`.** The `storage` entries have never fired.

The project's migrations follow a consistent pattern — create, inherit everything, then revoke and re-grant narrowly. **29 of 41 migrations contain a `REVOKE`.** That pattern is why the schema is clean today.

---

## 5. Why recurrence risk remains

The clean state is a product of discipline, not design, and the evidence shows the discipline has already failed three times:

| Occasion | What was missed | Result |
|---|---|---|
| `public_profiles` created | the revoke entirely | **S-1** — anonymous write path into `public.users` |
| `_test_results`, `_test_run_log` created | the revoke **and** RLS | **S-2** — world-writable, world-truncatable |
| `public.users` narrowed | `MAINTAIN`, from an enumerated revoke list | **S-6** — residue that survives to today |

Nothing prevents a fourth. The next table created in `public` receives `arwdDxtm` for `anon` the moment it exists, and whether it stays that way depends entirely on the next migration being written correctly.

---

## 6. Relationship to S-1 and S-2

**S-5 is the cause; S-1 and S-2 were its effects.**

- **S-1** — `public_profiles` is a view. Views are covered by `ALTER DEFAULT PRIVILEGES ... ON TABLES`, so it received `arwdDxtm`. Being auto-updatable, that became a write path into `public.users`. Remediated in Phase 21.4 by narrowing the one object.
- **S-2** — `_test_results` and `_test_run_log` received the same ACL at creation and were never narrowed. Remediated in Phase 21.5 by dropping them.

Both fixes were correct and both were local. Neither touched the mechanism, and both phase records said so explicitly. **This phase fixes the mechanism** so that the next occurrence does not need a phase of its own.

---

## 7. Scope

### 7.1 Why both `public` and `storage`

`public` is the live risk — every application table lives there, and PostgREST exposes it.

`storage` is the latent twin: an identical entry that has never fired because `postgres` has never created anything there. It is included because it is the same mechanism with the same grantor, costs one statement each for TABLES and SEQUENCES, and has nothing depending on it. Leaving it would mean fixing S-5 in the schema where it has bitten and keeping it in the schema where it has not yet.

### 7.2 Why TABLES and SEQUENCES are included

**TABLES** — the S-1 and S-2 vector. `ON TABLES` covers tables, views, materialized views and foreign tables. Views are the stronger case: S-1 was a view, and an auto-updatable view with write grants is a write path into whatever it selects from.

**SEQUENCES** — a separate entry (`S`), and `anon` would receive UPDATE, which permits `setval`: an anonymous caller could rewind a sequence and cause primary-key collisions. No legitimate browser flow needs that.

**One compatibility caveat, stated so it cannot surprise anyone.** A role inserting into a table with a `serial` column needs USAGE on the backing sequence. After this change, a future `serial`-keyed table written by `authenticated` would need an explicit `GRANT USAGE`. Risk is low: STAGERZ uses `uuid` primary keys throughout, `public` currently holds zero sequences, and `GENERATED ... AS IDENTITY` — the modern replacement for `serial` — needs no sequence privilege at all.

### 7.3 Why FUNCTIONS are excluded

The FUNCTIONS entries (oids 16493, 16549) grant EXECUTE to `anon`. Removing that would be defensible in isolation, but **it would not fix the only live function exposure on the project**, and presenting it as a fix would be misleading.

That exposure — finding **S-7** — belongs to the three `log_collaboration_*_activity` trigger functions, whose ACL reads `{=X/postgres, postgres=X, authenticated=X, service_role=X}`. **`anon` is not in it.** The leading `=X` is a grant to `PUBLIC`, from Postgres's built-in rule that new functions are executable by everyone. `anon` inherits it through `PUBLIC`. No change to `pg_default_acl` touches that path.

Meanwhile, every one of the 20 RPCs the frontend calls depends on EXECUTE grants. Changing the FUNCTIONS default would add explicit-grant burden to all future RPCs without closing the real exposure. Function privileges deserve their own analysis.

### 7.4 Why `supabase_admin` defaults are not modified

The 15 `supabase_admin` entries include **oid 16496** — `supabase_admin` / `public` / TABLES — which grants `arwdDxtm` to `anon` exactly like the finding. It is recorded as a latent twin, and deliberately left alone:

1. **It belongs to a platform role.** `FOR ROLE supabase_admin` requires acting as that role. Doing so would mean altering Supabase's own managed configuration, which a platform upgrade could silently reset.
2. **Evidence says it is not this project's creation path.** All 18 existing relations in `public` are owned by `postgres`, so tables here are created as `postgres`. Entry 16496 only fires for objects created *as* `supabase_admin`.

**Residual risk, stated plainly:** if some future tool creates tables in `public` while running as `supabase_admin`, entry 16496 still grants them `arwdDxtm`. The post-creation ACL check proposed in `validation.md` §6 is the control for that.

### 7.5 Explicitly out of scope

S-6, S-7, FUNCTIONS defaults, all `supabase_admin` and `supabase_auth_admin` defaults, S-3, S-4, `public_profiles`, RLS, policies, storage policies, auth settings, every existing object ACL, `index.html` and all application source.

---

## 8. Why S-6 and S-7 are deferred to Phase 21.7

Both were found during the S-5 analysis, and both are real:

| | Finding | Mechanism |
|---|---|---|
| **S-6** | `anon` and `authenticated` hold `MAINTAIN` on `public.users` | Static `relacl` residue — migration `20260712144926` enumerated six privileges and missed `MAINTAIN` |
| **S-7** | Three trigger functions executable by `PUBLIC`, and so by `anon` | Postgres's built-in `EXECUTE` to `PUBLIC` default |

They are deferred because:

- **Different mechanisms.** This phase changes `pg_default_acl`. S-6 is a live object's ACL; S-7 is the built-in `PUBLIC` rule. Three mechanisms, three fixes, three verification methods.
- **No atomicity requirement.** Default privileges affect only future objects. S-6 and S-7 are static and cannot be changed, worsened or fixed by this phase, and neither fix depends on the other.
- **Different risk profiles.** This phase modifies **nothing that exists** — its central safety check is that every existing ACL comes out byte-identical. S-6 and S-7 require modifying live objects, which needs its own before/after evidence and smoke tests.
- **Low urgency.** No PostgREST verb maps to `MAINTAIN`, and a direct RPC call to a trigger function raises `0A000`. Neither is a live exploit.
- **Precedent.** Phases 21.4 and 21.5 each remediated exactly one finding under its own approval.

Bundling would put a zero-existing-object change and a live-object change behind a single approval, and would muddy this phase's cleanest safety property.

---

## 9. Preferred remediation — rationale

Remove `anon` and `authenticated` from the `postgres` TABLES and SEQUENCES defaults in `public` and `storage`. Keep `postgres` and `service_role`. Leave FUNCTIONS alone.

1. **It fully closes S-5.** No future table, view, materialized view or sequence created by `postgres` in either schema grants anything to `anon` or `authenticated` automatically. No automatic anonymous write. No accidental `TRUNCATE`.
2. **It codifies what the project already does.** Every one of the 18 existing relations was manually narrowed. Removing the default eliminates a step from the workflow rather than adding one, and turns *"remember to revoke"* from a discipline into a property of the system.
3. **It changes nothing that exists.** Not one existing ACL moves. That is what makes it verifiable: a full `relacl`/`proacl` diff must come out empty.
4. **It makes public API surfaces explicit.** A new table becomes reachable over PostgREST only when someone writes a `GRANT` for it — which is when someone should be asking whether it has RLS.
5. **It is exactly reversible.** Four `GRANT ALL` statements restore the prior state byte-for-byte.

**The behavioural consequence to be clear about:** after this change, a new table in `public` is **invisible to the REST API** until explicitly granted. That is the intended secure behaviour, and it matches how every existing table is already managed — but anyone creating a table through the Supabase dashboard will notice it.

---

## 10. Fallback strategy

**If the preferred remediation is rejected, or must be rolled back: replace the TABLES default with SELECT-only** for `anon` and `authenticated`.

| | Preferred | Fallback |
|---|---|---|
| Automatic write / `TRUNCATE` | none | none |
| Automatic read | none | **every new table, world-readable at creation** |
| Would have prevented S-1 | yes | yes |
| Would have prevented S-2 | yes | the writes, not the reads |
| New tables invisible to the API until granted | yes | no |

The fallback is strictly weaker: a new table with RLS not yet enabled is world-readable the instant it exists. It is the right choice only if a future read path breaking is judged worse than a future table being briefly readable. It would be a separate, separately-approved change.

---

## 11. Rollback strategy

Four statements, recorded as comments in `migration.sql`, restore all four entries byte-exactly:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  GRANT ALL ON SEQUENCES TO anon, authenticated;
```

`ALL` on TABLES restores `arwdDxtm`; `ALL` on SEQUENCES restores `rwU`.

**Rollback is uniquely safe here.** Unlike Phase 21.5, where rollback meant recreating tables and re-acquiring an exposure, this rollback cannot touch any existing object — it is no more retroactive than the migration. The worst it can do is restore the pre-existing risk for *future* objects.

**Preconditions:** a confirmed regression attributable to this phase, and explicit production-mutation approval. No plausible regression mechanism is known: the change affects no existing object, and no existing application path depends on objects that do not yet exist.

---

## 12. Hard-stop conditions

Any of these **stops the phase before mutation**. Report; do not proceed; do not improvise a variant.

| # | Condition |
|---|---|
| H-1 | `pg_default_acl` does not hold exactly **24** entries |
| H-2 | Any of the four targeted ACLs differs from the strings in §2 |
| H-3 | **Any global entry exists** (`defaclnamespace = 0`) — the layering argument in §3 would no longer hold |
| H-4 | The executing role is neither `postgres` nor a member of it |
| H-5 | Any of the 18 existing `public` relation ACLs differs from the captured baseline |
| H-6 | `public_profiles` is not exactly `anon=r` / `authenticated=r` |
| H-7 | Repository not clean on this branch, or `migration.sql` not committed and pushed before mutation |
| H-8 | Explicit production-mutation approval has not been given for this specific change |

**And during or after execution:**

| # | Condition |
|---|---|
| H-9 | **Any statement errors.** Stop and report. Do not re-run a subset |
| H-10 | **Only some of the four entries changed.** A partial application is reported immediately, and either completed or rolled back under explicit approval — never left half-applied |
| H-11 | **Any existing `relacl` or `proacl` changed.** Something other than these four statements ran |
| H-12 | **The entry count moved off 24, or a global entry appeared.** The `IN SCHEMA` trap fired |

---

## 13. Execution notes

**Role.** The session must run as `postgres`, or as a role that is a member of `postgres`. Verified at pre-flight with `current_user`, `session_user` and `pg_has_role(current_user, 'postgres', 'MEMBER')`.

**Atomicity.** All four statements are sent in a single execution. A multi-statement query string sent in one call normally runs as one implicit transaction, so the four apply together or not at all. That is expected behaviour, not a guarantee this record relies on: **the guarantee is post-check M-1**, which verifies all four entries changed, backed by H-10.

**What the Security Advisor can and cannot confirm.** The Advisor has no lint for default privileges. **It cannot show this fix** — it will be unchanged before and after, which is the expected result. Only a direct `pg_default_acl` diff proves the remediation. The Advisor check exists solely to catch regression.

---

## 14. Deliverables

| Path | Contents | State |
|---|---|---|
| `phase-definition.md` | This document | Complete |
| `migration.sql` | The 4 `ALTER DEFAULT PRIVILEGES` statements, with pre- and post-change evidence | **APPLIED** 2026-09-11 |
| `validation.md` | Pre-flight and post-change checks | 14/14 pre-flight **PASS**; **15/15** post-change **PASS** (M-15 closed 2026-09-12 after a test-design correction) |

**Not updated in this phase, deliberately.** `analysis/phase-21.3/*`, `analysis/phase-21.4/*`, `analysis/phase-21.5/*` and `.apos/PROJECT_CONTEXT.md` are untouched. They record S-5 as OPEN, which is still true, and are updated only after a successful remediation.

---

## 15. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Statement runs as the wrong role and silently changes nothing | Medium without the check | Medium — S-5 appears fixed but is not | `FOR ROLE postgres` in every statement; H-4 role check; M-1 verifies the entries actually changed |
| R2 | `IN SCHEMA` omitted, creating a global entry | Low | Medium — dangerous entry untouched, confusing entry added | Present in all four; H-12; M-2 and M-3 count entries and global entries |
| R3 | A future `serial` insert by `authenticated` fails | Low | Low | §7.2 caveat; uuid and identity columns need no grant |
| R4 | A new table created via the dashboard is unexpectedly invisible to the API | **Medium** | Low | §9 documents it; the fix is an explicit `GRANT`, which is the intended workflow |
| R5 | A tool running as `supabase_admin` creates a table, hitting oid 16496 | Low | Medium | Out of scope (§7.4); `validation.md` §6 recommends a post-creation ACL check |
| R6 | Change is mistaken for having fixed S-6 or S-7 | Medium | Low | §8 and every validation record state explicitly that it does not |
| R7 | Partial application of the four statements | Low | Low | Single execution; M-1; H-10 |

---

## 16. Remediation result — applied 2026-09-11

**S-5 is REMEDIATED.**

The pre-flight was re-run at `21:24:38+00` and **all 14 requirements matched the reviewed baseline exactly**: 24 entries with none global; the four target ACLs and both FUNCTIONS ACLs byte-identical to §2; all 18 `public` relation ACLs as documented; `public_profiles` at `anon=r` / `authenticated=r`; the Advisor at 35 findings; the session running as `postgres` (`current_user` = `session_user` = `postgres`). Checkpoint `c06c675` was confirmed on `origin` with the committed `migration.sql` hash `bf5cb656…aab2d0` before anything ran. No hard-stop condition fired.

Exactly four statements ran, in one call, verbatim from `migration.sql`:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
```

All returned success. Post-change state, verified `21:26:04+00`:

| | Before | After |
|---|---|---|
| `postgres`/`public`/TABLES | `postgres`, `anon`, `authenticated`, `service_role` — all `arwdDxtm` | **`postgres`, `service_role` only** |
| `postgres`/`public`/SEQUENCES | all four roles `rwU` | **`postgres`, `service_role` only** |
| `postgres`/`storage`/TABLES | as `public` | **`postgres`, `service_role` only** |
| `postgres`/`storage`/SEQUENCES | as `public` | **`postgres`, `service_role` only** |
| `pg_default_acl` entries | 24 | **24** |
| Global entries | 0 | **0** |
| The other 20 entries | — | **fingerprint-identical** |
| `public` relations / functions ACLs | 18 / 34 | **byte-identical** |
| `storage` relations / functions ACLs | 8 / 17 | **byte-identical** |
| Migration records | 41 | **41** |
| Security Advisor | 5 lints / 35 findings | **5 lints / 35 findings** |

**The change landed in exactly the right place.** Each of the four targeted entries lost precisely its `anon` and `authenticated` elements and kept `postgres` and `service_role`. The count held at 24, because each row kept a non-empty ACL and was updated in place. No global entry appeared, so the `IN SCHEMA` trap in `migration.sql` rule 2 did not fire.

**The non-retroactivity claim held empirically.** Every existing ACL across 77 relations and functions in `public` and `storage` is byte-identical before and after. `public.users` still carries `anon=m` / `authenticated=m` — S-6, deferred — and its survival is part of that proof.

**No regression.** `public_profiles` is still SELECT-only for both roles; `public.users` grants neither role SELECT, INSERT, UPDATE, DELETE or TRUNCATE; the S-2 tables are still absent and their endpoints return 404; `GET /rest/v1/public_profiles` as `anon` still returns 200 with a row; the Advisor is unchanged in every lint's name, level and count.

**What the Advisor could not show.** It has no default-privilege lint, so it was never going to reflect this fix. The fix is proven by the `pg_default_acl` diff alone.

**Column-level grants were checked too, after a gap was found.** The fingerprints above cover table and function ACLs but not `attacl`. Since the application's real authenticated writes depend on column-level UPDATE grants, those were compared against the pre-Phase-21.6 baseline in `analysis/phase-21.3/backend-contract.md` §11.4: `users` **6** columns, `profiles` **9**, `notifications` **`read` only**, `wanted_posts` **7** — all matching exactly. **No column-level permission changed during Phase 21.6.** Detail and the limits of that instrument: `validation.md` §4.5.

**The authenticated write smoke test passed, after its design was corrected.** M-15 originally named "a like or follow". That action does not exist: no Like element in the app has a click handler, the counts come from a static `stageData` array, no Supabase write targets `likes` or `follows`, Phase 21.3 had already recorded both tables as unreferenced, and both hold 0 rows. **That is a test-design error of mine, not a product failure and not a regression** — `Like` and `Follow` are display-only in the current build, and this phase changed nothing about them. M-15 was replaced with **Profile → Edit Profile → Save with no values changed**, which exercises the same class of permission on a path the app genuinely uses: column-level UPDATE grants on `profiles` and `users.username`, own-row RLS UPDATE policies, and EXECUTE on the SECURITY DEFINER helper those policies call. Confirmed by the user on production `stagerz.app` on 2026-09-12: the save completed with no visible error and no unintended data change. **M-15 = PASS.**

**Final S-5 state: REMEDIATED for future objects.** No table, view, materialized view or sequence created by `postgres` in `public` or `storage` will be granted anything automatically to `anon` or `authenticated`. The mechanism that produced S-1 and S-2 is closed. What remains open is listed, not implied closed: S-6 and S-7 (Phase 21.7), the FUNCTIONS defaults, and the `supabase_admin` twin at oid 16496.

---

## 17. Summary

S-5 was a Supabase bootstrap default: `postgres` default privileges granted `anon` and `authenticated` everything — including `TRUNCATE` — on every future table, view and sequence in `public` and `storage`. It was schema-scoped rather than global, it predated every migration, and it had already caused two ERROR-severity findings.

Current live exposure from it was **zero** — every existing relation had been manually narrowed and `public` held no sequences — but that was discipline, not design, and the evidence showed the discipline failing three times.

**On 2026-09-11, under explicit approval, this phase removed `anon` and `authenticated` from exactly four `pg_default_acl` entries**, keeping `postgres` and `service_role`. **Pre-flight 14/14 PASS; post-change 15/15 PASS.** Exactly four statements ran. No existing object changed — table, function and column permissions are all byte-identical — and that was the design, not a happy accident.

The one check that could not be automated, a signed-in write on production, needed its wording corrected before it could run at all, and then passed. Every future public API surface is now an explicit decision rather than an automatic grant. The change is exactly reversible. FUNCTIONS defaults, platform-role defaults, and the two residues S-6 and S-7 are deliberately left for separate treatment.
