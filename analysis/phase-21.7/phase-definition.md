# Phase 21.7 — Clean up the residual privileges (S-6, S-7)

**Branch:** `phase-21.7-s6-s7-privilege-cleanup`
**Base commit:** `452b12b` (`main`, merge of PR #14 — Phase 21.6 / S-5)
**Addresses:** findings **S-6** and **S-7** from `analysis/phase-21.3/backend-contract.md` §0.2
**Status:** **COMPLETE — S-6 and S-7 REMEDIATED.** Production mutation applied 2026-09-11 (UTC) under explicit approval; validation closed 2026-09-12. Pre-flight **21/21 PASS**, post-change **16/16 PASS**, smoke tests **A, B, C all PASS**. See §15.
**Validation level:** **Level 1** — documentation and a backend-only change; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)

Exactly one backend change was made: the seven approved `REVOKE` statements, in a single atomic call. No existing object definition, policy, trigger or row was modified, and no application source was touched. PR and merge still pending.

---

## 1. Objective

Remove two residual privilege grants that no application path uses and nobody deliberately created:

- **S-6** — `anon` and `authenticated` hold `MAINTAIN` on `public.users`.
- **S-7** — three trigger functions are executable by `PUBLIC`, and by explicit grant by `authenticated`.

Both were discovered during the Phase 21.6 analysis of S-5. Neither is reachable through the application, and neither was caused by Phase 21.6 — they are older residues that the S-5 investigation happened to surface.

**Pattern decision (`.apos/WORKFLOW.md`): Extend.** Phases 21.4, 21.5 and 21.6 established the shape: one phase, a minimal migration of exactly the approved statements, its own approval, pre-flight with hard stops, and post-change verification against captured baselines. This phase follows it, with one deviation stated up front: **it remediates two findings rather than one**, justified in §9.

---

## 2. S-6 — evidence

Captured read-only 2026-09-12 against `kbnmkyvbwkuvcklywdhk`, PostgreSQL **17.6**.

| Property | Value |
|---|---|
| relkind / owner | `r` / `postgres` |
| RLS enabled / forced | **true / false** |
| relacl | `{postgres=arwdDxtm/postgres,anon=m/postgres,authenticated=m/postgres,service_role=arwdDxtm/postgres}` |
| `anon` | **MAINTAIN only** |
| `authenticated` | **MAINTAIN only** |
| `service_role`, `postgres` | full `arwdDxtm` |
| Policies | 2 — `authenticated can read own row` (SELECT, `id = current_stagerz_user_id()`); `active users can update own row` (UPDATE, own-row USING + CHECK) |
| Triggers | **0** |
| Dependent views | **1** — `public.public_profiles` |
| Column grants | **7** — `authenticated`: `id=r`; `username, first_name, last_name, photo_url, bio, location = rw` |

**MAINTAIN is held at table level only, and directly.** It cannot exist as a column-level privilege. Neither role is a member of any other role, and no `PUBLIC` grant exists on the table, so nothing confers it indirectly.

---

## 3. S-6 — exact root cause

The table received `arwdDxtm` for both roles at `CREATE`, from the S-5 default privileges since closed in Phase 21.6. Five later statements revoked everything except `m`. **No migration in the project mentions `MAINTAIN` at all** — zero lines across all 41.

| Migration | Statement |
|---|---|
| `20260712100630` | `revoke select on public.users from anon, authenticated;` |
| `20260712100630` | `revoke update on public.users from authenticated;` |
| `20260712144816` | `revoke insert, references on public.users from authenticated;` |
| `20260712144900` | `revoke delete, truncate, trigger on public.users from authenticated;` |
| `20260712144926` | `revoke insert, update, delete, truncate, references, trigger on public.users from anon;` |

The arithmetic closes exactly:

- **`anon`:** `arwdDxtm` − `r` − `a,w,d,D,x,t` = **`m`**
- **`authenticated`:** `arwdDxtm` − `r` − `w` − `a,x` − `d,D,t` = **`m`**

Every one of those revokes enumerated privileges from the pre-PostgreSQL-17 set of seven. `MAINTAIN` did not exist in that vocabulary, so it was not omitted by choice — it was invisible to the person writing the list.

---

## 4. S-6 — semantics and practical severity

In PostgreSQL 17, `MAINTAIN` permits `VACUUM`, `ANALYZE`, `CLUSTER`, `REINDEX` and `REFRESH MATERIALIZED VIEW`, and satisfies the privilege requirement for the stronger `LOCK TABLE` modes. **It confers no ability to read or write a single row.**

Reachability here is effectively nil. PostgREST issues only SELECT/INSERT/UPDATE/DELETE and function calls; no HTTP verb maps to a maintenance command. `anon` and `authenticated` cannot log in (`rolcanlogin = false`) and are reachable only through `authenticator` switching roles inside PostgREST, which exposes no SQL surface.

**Severity: very low — hygiene, not exposure.** It is worth removing because it was never intended, not because it can be used.

---

## 5. S-7 — evidence

All three functions are identical in every security-relevant respect.

| Property | Value |
|---|---|
| Signatures | `public.log_collaboration_asset_activity()`, `public.log_collaboration_credit_activity()`, `public.log_collaboration_message_activity()` |
| Owner / language | `postgres` / `plpgsql` |
| Security / volatility | **SECURITY DEFINER** / VOLATILE |
| Returns | `trigger` |
| `search_path` | `SET search_path TO ''` — correctly hardened |
| proacl | `{=X/postgres,postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |
| `PUBLIC` EXECUTE | **yes** — the leading `=X/postgres` |
| `anon` EXECUTE | **yes, via PUBLIC only** — no explicit grant |
| `authenticated` EXECUTE | **yes, explicit** |
| Triggers | one each, all **AFTER INSERT**: `trg_log_collaboration_asset_activity` on `collaboration_assets`; `…_credit_activity` on `collaboration_credits`; `…_message_activity` on `collaboration_messages` |
| Other dependencies | none — `pg_depend` shows only those three triggers |
| Frontend references | **0** in `index.html`; no `supaRpc` call names them |

Each body inserts one `collaboration_activity` row and fans notifications out to the other participants, reading `NEW.*` throughout — which is exactly why it cannot run outside trigger context.

In `public`, `anon` can execute exactly **3** functions, and **0** of them are non-trigger functions. S-7 is therefore the complete set.

---

## 6. S-7 — mechanism and practical severity

The exposure comes from PostgreSQL's built-in default that new functions are executable by `PUBLIC` — **not** from the `pg_default_acl` entries that caused S-5. Phase 21.6 could not have fixed it, and did not.

A direct call raises `0A000 — trigger functions can only be called as triggers`, and PL/pgSQL raises it **before executing any statement in the body**. The SECURITY DEFINER + `postgres`-owner combination would be serious if the body were reachable; the guard is what makes it not.

**One honest uncertainty.** The Supabase advisor asserts a route at `/rest/v1/rpc/log_collaboration_*`. PostgREST commonly excludes functions returning `trigger` from its schema cache, which would mean no route exists at all. **This was not tested**, deliberately — these functions are VOLATILE, so any probe would be a POST, and the analysis brief forbade invoking anything that could write. The remediation and its justification do not depend on which is true.

**Severity: low.** A latent misconfiguration with no demonstrated path to effect.

---

## 7. Why `authenticated` EXECUTE is included — deliberate, approved scope expansion

S-7 was originally worded as a `PUBLIC` exposure. Removing `authenticated`'s explicit grant goes beyond that wording. It is included on the following evidence, and **was explicitly approved for Phase 21.7**:

1. **`authenticated` holds explicit EXECUTE on all three functions** — visible in each proacl as `authenticated=X/postgres`, independent of the `PUBLIC` grant. Revoking `PUBLIC` alone would leave it in place.
2. **The frontend has zero RPC references to them.** `index.html` contains no occurrence of `log_collaboration`, and none of the 20 RPCs the app calls is one of these.
3. **They are trigger-only functions.** They return `trigger` and read `NEW.*`; there is no legitimate direct-call use for any role.
4. **Trigger execution does not require the DML caller to hold EXECUTE** (§8), so removing the grant cannot affect the collaboration flows that fire them.
5. **`handle_new_auth_user()` is the in-project control case** — same owner, same SECURITY DEFINER posture, `proacl {postgres=X/postgres,service_role=X/postgres}`, executable by neither `anon` nor `authenticated`, and its trigger fires on every signup.
6. **It aligns these three functions with the intended `postgres`/`service_role`-only execution posture** that every other trigger function in this project already has. After the change, their proacl is identical in shape to the control case.

The alternative — revoking only `PUBLIC` — would close the anonymous path but leave a signed-in user able to call a `postgres`-owned SECURITY DEFINER function directly. That call fails today because of the PL/pgSQL guard, which is a property of the function body rather than of the permission model. Relying on it is weaker than not granting the privilege.

---

## 8. Why the triggers keep working

**No compensating GRANT is required.** PostgreSQL does not check the invoking user's EXECUTE privilege when firing a trigger; the trigger function runs as part of the DML statement, not as a call made by that user.

Rather than rest on that assertion, this project already contains the control case:

| Function | proacl | `anon` / `authenticated` EXECUTE | Trigger | Fires? |
|---|---|---|---|---|
| `handle_new_auth_user()` | `{postgres=X/postgres,service_role=X/postgres}` — no `PUBLIC` | **false / false** | `on_auth_user_created` AFTER INSERT on `auth.users` | **Yes** — every signup, validated repeatedly with real magic-link sign-ins in Phase 21.2 |

That is precisely the configuration this migration moves the three log functions into. **Post-change check M-12 and smoke test C verify it empirically rather than by assertion.**

---

## 9. Scope — and why two findings in one phase

**In scope:** exactly seven statements — one `REVOKE MAINTAIN` for S-6, six `REVOKE EXECUTE` for S-7.

**One phase, one migration file, two labelled statement groups.** Both findings are existing-object grant revocations, verified by the identical method (ACL before/after against captured baselines), independent of each other, and small. Splitting them would double the approval and verification overhead without reducing risk — rollback is per-statement either way. This is a deliberate, reasoned deviation from the one-finding-per-phase precedent of Phases 21.4–21.6, not an oversight.

**Explicitly out of scope**, and recorded so a future audit does not misread them as missed:

| Item | Why excluded |
|---|---|
| `storage.buckets`, `storage.buckets_analytics`, `storage.objects` — `anon`/`authenticated` hold `arwdDxtm`, including `m` | **Not the same pattern.** Grantor is `supabase_storage_admin`; a deliberate platform grant, not a revoke residue. RLS-gated; `storage` is not PostgREST-exposed. Not alterable by this project |
| `storage.enforce_bucket_name_length()`, `storage.protect_delete()`, `storage.update_updated_at_column()` | PUBLIC-executable trigger functions owned by `supabase_storage_admin`, **SECURITY INVOKER** — no definer escalation. Platform-owned |
| `supabase_admin` / `public` TABLES default ACL (oid 16496) | Carried forward from Phase 21.6 as a latent, platform-owned twin |
| S-3, S-4 | Separate findings, untouched |
| `pg_default_acl` | S-5, closed in Phase 21.6 |
| `public_profiles`, RLS, policies, storage policies, auth settings, `index.html` | Untouched |

---

## 10. Expected post-state

**`public.users`**

```
{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
```

The `anon` and `authenticated` entries **disappear entirely**, because `MAINTAIN` was their only table-level privilege. That is the expected result, not over-revocation.

Unchanged: the **seven column grants**, RLS `enabled=true forced=false`, both policies, zero triggers, the single dependent view.

**Each of the three functions**

```
{postgres=X/postgres,service_role=X/postgres}
```

`PUBLIC` = false, `anon` = false, `authenticated` = false, `service_role` = true, `postgres` = true — identical in shape to `handle_new_auth_user()`.

Unchanged: ownership, SECURITY DEFINER, `search_path`, volatility, bodies, and all three triggers.

---

## 11. Rollback

Seven statements, recorded as comments in `migration.sql`, restore the exact prior privileges:

```sql
GRANT MAINTAIN ON TABLE public.users TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_collaboration_asset_activity()   TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_collaboration_asset_activity()   TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_collaboration_credit_activity()  TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_collaboration_credit_activity()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_collaboration_message_activity() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_collaboration_message_activity() TO authenticated;
```

Rollback touches only grants — never data, definitions, policies or triggers — and re-opens S-6 and S-7. It requires the same explicit approval as the change itself.

**No data snapshot is needed.** Nothing is destroyed; the complete prior state is the ACL strings recorded in `migration.sql` §PRE-CHANGE STATE, and the rollback restores them byte-exactly.

---

## 12. Hard-stop conditions

Any of these **stops the phase before mutation**. Report; do not proceed; do not improvise a variant.

| # | Condition |
|---|---|
| H-1 | `public.users` relacl differs from §2 |
| H-2 | The seven column grants are not exactly as listed in §2 |
| H-3 | `public.users` RLS state, policy count or trigger count differs |
| H-4 | Any of the three functions' proacl differs from §5 |
| H-5 | Any function's owner, SECURITY DEFINER flag, `search_path` or body differs |
| H-6 | Any of the three triggers is missing or points elsewhere |
| H-7 | `handle_new_auth_user()` proacl differs from §8 — the control case must hold |
| H-8 | The executing role is not `postgres`, or not a member of it |
| H-9 | Repository not clean on this branch, or `migration.sql` not committed and pushed before mutation |
| H-10 | Explicit production-mutation approval has not been given |

**During or after execution:**

| # | Condition |
|---|---|
| H-11 | Any statement errors |
| H-12 | Only some of the seven statements took effect |
| H-13 | **Any of the seven column grants on `public.users` is missing** — the highest-consequence failure mode; it would break profile editing |
| H-14 | Any unrelated relation, function or column ACL changed |
| H-15 | Any function body, owner, security setting or trigger changed |

---

## 13. Deliverables

| Path | Contents | State |
|---|---|---|
| `phase-definition.md` | This document | Complete |
| `migration.sql` | The 7 statements, with pre- and post-change evidence | **APPLIED** 2026-09-11 (UTC) |
| `validation.md` | Pre-flight, post-change checks and smoke tests | **21/21 pre-flight PASS; 16/16 post-change PASS; smoke A/B/C PASS** |

**Prior-phase artifacts.** `analysis/phase-21.4/*`, `analysis/phase-21.5/*` and `analysis/phase-21.6/*` are untouched. `analysis/phase-21.3/backend-contract.md` receives **current-status changes only** — §0.2 now records S-6 and S-7 as REMEDIATED, since that section is this project's single record of finding status. Its historical evidence sections are preserved exactly and are **not** rewritten to suggest the remediated state existed during Phase 21.3.

---

## 14. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | A column grant on `public.users` is lost, breaking profile editing | **Very low** | **High** | `REVOKE MAINTAIN` cannot touch column ACLs (§ rule 2); H-13; post-check M-3; smoke test A |
| R2 | A collaboration trigger stops firing | Very low | Medium | Trigger firing does not consult EXECUTE (§8), proven by the control case; H-7; smoke test C |
| R3 | Over-revocation removes `service_role` or `postgres` access | Very low | High | Neither role is named in any statement; post-checks M-2 and M-11 |
| R4 | Partial application of the seven statements | Low | Low | Single execution; M-1; H-12; rollback is exact |
| R5 | Advisor counts move for unrelated reasons, muddying evidence | Low | Low | Advisor treated as supporting evidence only; the catalog diff is the proof |
| R6 | Smoke test C cannot run because no collaboration exists | **Medium** | Low | Recorded NOT RUN rather than inferred; no data manufactured to satisfy it |

---

## 15. Production result — applied 2026-09-11 (UTC)

**S-6 and S-7 are REMEDIATED.**

The four stages are kept distinct below, because they are different kinds of claim.

### 15.1 The original findings

Both were discovered during the Phase 21.6 analysis of S-5, and neither was caused by it. **S-6:** `anon` and `authenticated` held `MAINTAIN` on `public.users`, the residue of five enumerated revokes written before PostgreSQL 17 gave that privilege a name (§3). **S-7:** three trigger functions were executable by `PUBLIC`, and explicitly by `authenticated`, from PostgreSQL's built-in default for new functions (§5–§6).

### 15.2 The approved remediation

Seven statements, no more: one `REVOKE MAINTAIN` for S-6 and six `REVOKE EXECUTE` for S-7. The `authenticated` revoke was explicitly approved scope expansion beyond S-7's original PUBLIC-only wording (§7).

### 15.3 The production result

Pre-flight was run as an approval gate and **re-run immediately before execution; all 21 requirements matched with zero drift.** The seven statements executed in a **single atomic call** as `postgres` (`current_user` = `session_user` = `postgres`), with **no SQL errors**. No rollback was run. No unapproved statement of any kind was issued.

| | Before | After |
|---|---|---|
| `public.users` relacl | `{postgres=arwdDxtm,anon=m,authenticated=m,service_role=arwdDxtm}` | **`{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}`** |
| `anon` / `authenticated` table privileges | MAINTAIN | **none of the eight** |
| Seven column grants | `id=r`; six × `rw` | **byte-identical** |
| RLS / policies / triggers / dependent view | `true/false` / 2 / 0 / 1 | **unchanged** |
| Each of the three functions | `{=X,postgres=X,authenticated=X,service_role=X}` | **`{postgres=X/postgres,service_role=X/postgres}`** |
| `PUBLIC` / `anon` / `authenticated` EXECUTE | true / true / true | **false / false / false** |
| Function bodies, security attrs, triggers | — | **byte-identical (md5-verified)** |
| `handle_new_auth_user()` control case | — | **byte-identical** |

### 15.4 The validation result

**Post-change 16/16 PASS.** Blast radius was proven rather than asserted: recomputing the `public` relation and function fingerprints with only the intended objects' pre-change ACLs substituted back reproduced `eb5f241e…` and `b573f7fd…` exactly — so among 18 relations only `users` changed, and among 34 functions only the three. Storage, column and policy fingerprints are unchanged. The Advisor moved **35 → 29** findings, `anon_security_definer_function_executable` **3 → 0**, `authenticated_security_definer_function_executable` **28 → 25**, with **zero new findings**. S-1, S-2 and S-5 all verified still remediated.

**Smoke tests A, B and C all PASS**, including the real collaboration message path — sent, displayed and deleted with no error, through the application UI, after the EXECUTE grants were removed. That is the empirical confirmation of the principle this phase relied on: trigger firing does not require the DML caller to hold EXECUTE. Predicted from the `handle_new_auth_user()` control case, now observed on the changed functions themselves. `validation.md` §5.1 states precisely what the user reported and what is inferred from it.

### 15.5 What remains open

**S-3 and S-4 are untouched and remain OPEN.** Nothing in this phase addresses them. Also unchanged, and outside this project's control: the platform-owned `storage` MAINTAIN grants, the three `storage` SECURITY INVOKER trigger functions, and the `supabase_admin`/`public` TABLES default ACL carried forward from Phase 21.6.

---

## 16. Summary

Two residual grants, both found during the Phase 21.6 analysis and neither caused by it. `anon` and `authenticated` held `MAINTAIN` on `public.users` — the remainder of five enumerated revokes written before PostgreSQL 17 gave that privilege a name. Three trigger functions were executable by `PUBLIC`, and explicitly by `authenticated`, from PostgreSQL's built-in default for new functions.

Neither was reachable in any useful way: `MAINTAIN` grants no row access and no HTTP verb maps to a maintenance command, and a direct call to a trigger function raises `0A000` before its body runs. Both were removed because they were never intended, not because they were exploitable.

Seven statements, applied in one atomic call. No existing object's definition, policy, trigger or data changed. The seven column grants that profile editing depends on were provably untouchable by the form of revoke chosen — and were verified byte-identical afterwards. The three functions now sit in exactly the posture `handle_new_auth_user()` already had, and a real message sent through the production UI confirmed their triggers still fire.

**S-6 REMEDIATED. S-7 REMEDIATED. S-3 and S-4 remain OPEN.** PR and merge pending.
