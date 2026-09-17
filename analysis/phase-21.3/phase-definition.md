# Phase 21.3 — Capture the Backend Contract in the Repository

**Branch:** `phase-21.3-backend-contract`
**Base commit:** `ebfe536` (`main`, merge of PR #10 — Phase 21.2 documentation follow-up)
**Addresses:** Phase 20.7 register item **C-3** (Critical) — *the backend contract exists only inside Supabase* (`analysis/phase-20.7/codebase-assessment.md` §C-3, §A.8)
**Resumption note (2026-08-31):** this phase was **paused** after Step 1 so that finding **S-1**, discovered during its extraction, could be remediated separately as **Phase 21.4 / PR #11** (merge `968b501`). The paused artefacts were subsequently lost from volatile storage and **recovered hash-verified** from history; the branch now sits on `main` at `f4d1fa7`. **S-1 is remediated; S-2–S-5 remain open.** Current finding status and the historical-vs-current evidence split are in `backend-contract.md` §0.1–§0.2. The "Base commit: `ebfe536`" above is retained deliberately — it records when this document was authored, not where the branch points today.
**Status (2026-09-17):** **RESUMED — INCOMPLETE (one gate open).**
- **Step 1** (client-side audit) was completed and merged in PR #12.
- **Resume:** the six `.sql` snapshots are now **complete** for the current epoch `20260916215204`, extracted read-only on branch `phase-21.3-backend-contract-resume` from `main` @ `2fdef81` and fingerprint-verified against the live catalog.
- **Gates:** R-1–R-4, R-6–R-11 and S-1–S-6 pass. **R-5 fails on grant width** (W-1 to W-4); the phase closes only after a recorded owner decision on those items (`validation.md` §14, §17).
- **Scope:** no application source was modified.

The text below "Resumption note" and §1–§8 is the Step 1 record; the current-epoch outcome is §9.
**Validation level:** **Level 1** for this step — it adds documentation only and does not touch `index.html`. The extraction step that follows is also Level 1 by the same reasoning; Level 3 would only apply if a later phase changed application behaviour.

---

## 1. Objective

Capture the complete server-side contract of the active Supabase project into version-controlled, reviewable files, so the repository can describe the server it depends on.

Phase 20.7 ranked this Critical and identified it as the **root cause of two other problems**, not merely a documentation gap:

> Nothing here can reconstruct the server — this is also the root cause of "no staging environment" and "authenticated flows unverifiable pre-merge."

Phase 21.2 demonstrated both consequences concretely. Authenticated validation required a real magic link against the live production project because no other environment exists, and the effort to work around that (a `curl` token hand-off, a dedicated browser profile, a local CONNECT proxy) was substantial. None of it would have been necessary against a reconstructable backend.

**Pattern decision (`.apos/WORKFLOW.md`): Create.** No existing pattern covers this. `analysis/<phase>/` holds Markdown findings; this phase adds `.sql` extraction artifacts, a genuinely new artifact class for this repository. They are **descriptive snapshots, never migrations** — a distinction enforced by a header on every file and by validation check S-2.

---

## 2. Scope

**In scope — read-only capture of:** database schema (tables, views, columns, types, defaults, nullability, PK/FK/unique/check constraints, contract-relevant indexes); the 20 RPCs with full bodies, signatures, volatility, security mode and `search_path`; RLS enablement and every policy with both expressions; table-, column- and function-level grants; triggers including the signup hook; the `collaboration-assets` bucket and its object policies; the SQLSTATE contract; and observable auth/identity configuration.

**Explicitly out of scope:** any backend modification; any migration, or any framing of the captured SQL as one; secrets, tokens, service-role keys or connection strings; changes to `index.html`; a staging environment; and the code-duplication cleanups Phase 20.7 proposed separately.

---

## 3. What this step produced

A complete, exhaustive audit of the **client side** of the contract — the demand side that the extraction must be reconciled against. Full detail in `backend-contract.md`; headline figures:

| Dimension | Result |
|---|---|
| Tables/views referenced | **14** — matches Phase 20.7 exactly |
| RPCs called | **20** distinct, 20 call sites, all string literals, no dynamic dispatch |
| Direct REST writes | **7** sites across 5 relations — everything else goes through RPCs |
| Storage | 1 bucket, 4 operations, **no client-side size or MIME limit** |
| SQLSTATEs branched on | **4** — `23505`, `P0012`, `P0013`, `P0053` |
| Realtime | `postgres_changes` on **5** tables, plus presence |
| Auth entry points | 4 |

Two properties make the audit exhaustive rather than indicative, and both were verified explicitly: **all** backend access is funnelled through eight helpers, and **every** RPC name is a string literal.

---

## 4. Server side — access confirmed, snapshot awaiting delivery

When this step was written the Supabase MCP server was not connected and no introspection could run. **That blocker is now resolved:** verified read-only access to `kbnmkyvbwkuvcklywdhk` exists, headline counts and several specific facts are confirmed, and **no writes were performed**. The confirmed results are recorded in `backend-contract.md` §11.

The MCP tools remain unavailable *to this agent*, so the detailed extraction is being performed externally and will be transcribed verbatim into the `.sql` artifacts on delivery. Each artifact now carries its exact read-only query, the confirmed counts and facts relevant to it, and an `ACCESS CONFIRMED — SNAPSHOT AWAITING DELIVERY` status.

**Nothing is invented, and no placeholder stands in for anything that can now be read live.** Confirmed facts are recorded as confirmed; outstanding detail is named as outstanding.

**What the confirmed counts already establish:** the backend is *wider* than the client needs — 20 relations against 14 referenced, 34 functions against 20 called — so no deficit has been found in the direction that would break the app. Three findings landed immediately: the signup trigger is identified, the realtime publication matches exactly, and the `collaboration-assets` bucket turns out to have **no size or MIME limit at all**, which combined with the client-side audit means uploads are unbounded at every layer (`backend-contract.md` §11.2).

---

## 5. Deliverables

| Path | Contents | State |
|---|---|---|
| `phase-definition.md` | This document | Current (2026-09-17) |
| `backend-contract.md` | Client-side contract; reconciliation targets; known discrepancies; live results (§11); **current contract (§13)** | Complete for epoch `20260916215204` |
| `schema.sql` | Tables, views, columns, constraints, indexes, RLS state, view definition, Realtime publications, extensions, API roles, migration names | **Complete** — 17 tables, 1 view, 141 columns, 67 constraints, 40 indexes |
| `functions.sql` | All 34 functions with full definitions, attributes and EXECUTE grants; SQLSTATE contract | **Complete** — 34/34 byte-identical |
| `rls-policies.sql` | RLS state and every `public` policy | **Complete** — 25/25 |
| `grants.sql` | Schema, table, column, function and default privileges; effective API-role matrix | **Complete** |
| `triggers.sql` | `public`, `auth.users` and `storage` triggers; event triggers | **Complete** — 8 triggers |
| `storage-policies.sql` | Bucket configuration, storage RLS, object policies, storage grants, path contract | **Complete** — 1 bucket, 2 policies |
| `validation.md` | The checks that prove the capture is complete and safe | Current — R-5 open |

---

## 6. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | A captured artifact is later mistaken for a migration and executed | Low | **High** — could alter or destroy production | Header on every file; validation **S-2** asserts no bare DDL |
| R2 | A secret, token or connection string enters the repository | Low | **High** | Validation **S-4** scans every added line; only catalog metadata is captured, never row data |
| R3 | Extraction accidentally performs a write | Low | **High** | Only `SELECT` against catalog views; validation **S-5**; the phase brief forbids all DDL/DML |
| R4 | Capture is incomplete — a frontend dependency has no backend object | **Medium** | Medium | Reconciliation checks **R-1…R-6** fail the phase rather than warn |
| R5 | The snapshot ages silently as the backend drifts | **Certain over time** | Medium | Record the capture timestamp; propose a re-capture trigger. Same class as the unanswered **Q-5** from Phase 21.2 |
| R6 | Row data is captured alongside metadata | Low | **High** — could expose user data | Queries target catalog views only; no `SELECT` against an application table |

---

## 7. Unresolved questions

| # | Question | Why it matters |
|---|---|---|
| ~~**Q-1**~~ | ~~How is read-only backend access to be provided?~~ **ANSWERED** — verified read-only access to `kbnmkyvbwkuvcklywdhk` is in place; detailed extraction is being performed externally and delivered for transcription | Was blocking; no longer |
| **Q-2** | Is `kbnmkyvbwkuvcklywdhk` still the *"disposable test project"* the code calls it ([307-310](../../index.html#L307-L310), [1218-1225](../../index.html#L1218-L1225))? Phase 20.7 raised this and it is **still unanswered** | Determines whether production user data sits on a project not intended to persist — and how carefully this capture must be handled |
| ~~**Q-3**~~ | ~~Capture `auth` and `storage`, or only `public`?~~ **ANSWERED — yes, both are in scope.** Confirmed live: the signup trigger `on_auth_user_created` sits on `auth.users`, and the 2 object policies sit on `storage.objects`. A `public`-only capture would have missed both | Settled by evidence |
| **Q-4** | What keeps the snapshot current? | R5. Ties directly to Phase 21.2's unanswered Q-5. *Partly addressed 2026-09-17:* every object carries a server-side SHA-256 and the aggregates are listed in `validation.md` §13, so drift is detectable by re-running the read-only extractions. No owner or schedule is defined for re-capture yet |
| ~~**Q-5**~~ | ~~Record `supabase_realtime` membership?~~ **ANSWERED — captured.** Exactly the 5 tables the frontend subscribes to are members; check R-9 passes | Closed |

---

## 8. Summary

Phase 20.7 item **C-3** says the backend contract exists only inside Supabase and nothing in this repository can reconstruct it. This step establishes the **demand side** of that contract exhaustively and from the source: 14 relations, 20 RPCs, 7 direct writes, 1 bucket, 4 SQLSTATEs, 5 realtime tables and 4 auth entry points, each mapped to an exact line in `index.html`. Because all backend access is funnelled through eight helpers and every RPC name is a literal, that audit is complete rather than a sample.

The **supply side** is now partially captured. Verified read-only access exists, **no writes were performed**, and the confirmed results are in `backend-contract.md` §11: 19 tables, 1 view, 34 functions, 27 RLS policies, 2 storage policies, 3 `public` triggers, 1 `auth` trigger, 5 realtime tables. Per-object detail is being extracted externally and will be transcribed verbatim; nothing has been fabricated in the interim.

**Three results already stand.** The signup trigger the repository never recorded is identified — `on_auth_user_created AFTER INSERT ON auth.users → handle_new_auth_user()`, the mechanism behind the identity chain `getMyDomainId()` relies on. The realtime publication matches the frontend's five subscriptions exactly (check **R-9** passes). And the first of the four known discrepancies is **confirmed**: `public_profiles` is sourced from `public.users` and never reads `profiles.display_name`, the column Edit Profile writes.

**One finding worth flagging beyond the capture itself:** the `collaboration-assets` bucket has `file_size_limit = NULL` and `allowed_mime_types = NULL`, and the client-side audit already established the frontend imposes no restriction either — so asset uploads are **unbounded in size and type at every layer**. Pre-existing, out of scope to fix in a capture-only phase, recorded for a product decision.

---

## 9. Resume outcome — 2026-09-17

**Pause history.**
- Paused after Step 1 for S-1 (Phase 21.4).
- Paused again for S-2 to S-8 (Phases 21.5–21.9).
- Paused on 2026-09-15 for the backend integrity remediation (O-1/O-2/O-3), which this phase's own re-baseline found.

All of those are REMEDIATED.

**The resume captured the current post-remediation backend** (migration epoch `20260916215204`, 42 migrations):
- **How:** read-only extraction, deterministic rendering, and SHA-256 reconciliation of every captured definition against the live catalog (`validation.md` §11–§13).
- **Result:** the six snapshots are complete, with 34/34 function bodies, 25 + 2 policies with full expressions, 8 triggers, 67 constraints, 40 indexes, 141 columns, every privilege row and every default ACL.
- **Current contract:** summarised in `backend-contract.md` §13.

**Gate outcome.**
- **Pass:** R-1–R-4, R-6–R-11 and S-1–S-6.
- **Fail:** **R-5** records four grant-width items (W-1 `wanted_posts` INSERT `id`/`created_at`; W-2 extra `profiles` UPDATE columns; W-3 extra `users` UPDATE columns; W-4 unused `follows`/`likes` writes).
- **Scope of those items:** all are own-row-scoped by RLS, and none is a new security finding. Step 1's rule is still that a materially wider grant "is a finding, not a pass".

**Status:** **INCOMPLETE.** Phase 21.3 closes once each of W-1 to W-4 has a recorded decision (accept as design, or narrow in a separately approved change) and R-5 is re-evaluated.

**Carried open questions:**
- **Q-2** (is this the "disposable test project"?);
- **Q-4** (who re-captures the snapshot, and when);
- the unbounded-upload product decision;
- Auth settings that are not observable read-only (`backend-contract.md` §13.6).


---

## 10. Post-R-5 regeneration — 2026-09-17

**Status: Phase 21.3 is READY FOR DOCUMENTATION / CONTEXT CLOSURE.** All eleven reconciliation gates and the six phase-specific safety gates pass, and **R-5 now PASSES**.

**What happened between §9 and here.**
1. §9 closed with R-5 **FAIL** and four recorded width findings (W-1..W-4) awaiting an owner decision.
2. The product owner decided: narrow W-1, accept W-2, adopt a profile-centred model for W-3, and remove the unused write surface for W-4. The final display-name rule (option A) treats `'New Artist'` as a technical signup placeholder that is never shown.
3. The remediation was prepared, reviewed, applied once to the test project and validated: `analysis/phase-21.3-r5-remediation/` (migration `20260917143322 phase21_3_r5_w1_w3_w4`).
   - Catalog gates C-1..C-14 PASS.
   - Behavioural run 1 was 38/40 because of two defects in the test template; the corrected template then passed 40/40. Both runs were rollback-only and left zero residue.
4. This step regenerated the six snapshots from the live catalog at the new epoch and re-ran every gate (`validation.md` §18).

**Snapshot epoch now recorded in the six files:** `20260917143322 phase21_3_r5_w1_w3_w4`, 43 migrations, PostgreSQL 17.6.

**Contract deltas versus the `e5244a9` snapshot** — only these, all from R-5:
- **W-1:** `wanted_posts` client INSERT is column-level on the nine columns the frontend sends; `id` and `created_at` are no longer client-insertable.
- **W-2:** unchanged (`profiles` grants and policies byte-identical).
- **W-3:** `users` client UPDATE is `username` only; `public_profiles` derives `display_name` from `profiles.display_name` with the placeholder, username and `'STAGERZ Artist'` fallbacks, and keeps its seven columns, owner, ACL and accepted Phase 21.4 security behaviour.
- **W-4:** `follows` and `likes` have no client INSERT or DELETE, and their four write policies are gone; the tables, their rows and read access remain.

Functions, triggers, constraints, indexes, columns, function privileges, default ACLs, Storage and Realtime are byte-identical to the previous epoch.

**Remaining work (separate approvals):**
- update `.apos/PROJECT_CONTEXT.md` (deliberately untouched here);
- then decide on push, PR and merge. A merge to `main` is a production release.
