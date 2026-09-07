# Phase 21.3 — Validation Record

**Branch:** `phase-21.3-backend-contract`
**Base commit:** `ebfe536`
**Validation level:** **1** — documentation only; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status:** **Step 1 (client-side audit + extraction planning) validated. Live read-only access now confirmed; headline counts captured and 2 of 11 reconciliation checks already pass. Detailed snapshot awaiting delivery.**
No backend write performed at any point. Not committed. Not pushed.

---

## 1. What this step claims, and what it does not

**Claims:** the client side of the contract in `backend-contract.md` is exhaustive for `index.html` at `ebfe536`.

**Does not claim:** anything whatsoever about what the Supabase project contains. No introspection ran.

That distinction is enforced below: §2 checks are **executed**, §4 checks are **defined and pending**.

---

## 2. Executed checks — client-side audit

| # | Check | Method | Result |
|---|---|---|---|
| **C-1** | All backend access is funnelled through known helpers | Only literal REST path in the file is `/rest/v1/rpc/`; all table access goes through `supaSelect`/`supaSelectCount`/`supaInsert`/`supaUpsert`/`supaUpdate`/`supaUpdateMinimal` | **PASS** |
| **C-2** | Every RPC name is a string literal (no dynamic dispatch) | Searched for `supaRpc(<identifier>` — only the definition at 1286 matched | **PASS** — audit is exhaustive, not indicative |
| **C-3** | Distinct RPCs = call sites | 20 distinct names, 20 call sites | **PASS** |
| **C-4** | RPC inventory matches Phase 20.7 | 20 names, set-identical to `codebase-assessment.md` §217 | **PASS** |
| **C-5** | Relation inventory matches Phase 20.7 | 14 relations, set-identical to §218 | **PASS** |
| **C-6** | Every direct write is enumerated | 7 sites across 5 relations | **PASS** |
| **C-7** | Every handled SQLSTATE is enumerated with its call site | 4 codes, each mapped to line and function | **PASS** |
| **C-8** | Storage surface enumerated | 1 bucket, 4 operations, path format captured | **PASS** |
| **C-9** | No client-side size/MIME restriction exists | No `accept` attribute on the input at 802; no size check before upload | **PASS** — confirms any limit is server-side and contract-relevant |
| **C-10** | Realtime table membership enumerated | 5 tables + presence | **PASS** |

## 3. Executed checks — repository safety

> **Naming collision — read this.** The check IDs `S-1`…`S-6` in this section are **repository-safety checks** and have **nothing to do** with the security findings `S-1`…`S-5` recorded in `backend-contract.md`. "S-1 PASS" below means *`index.html` was not modified* — it does **not** refer to the `public_profiles` write exposure.
>
> Security-finding status is maintained in one place only: **`backend-contract.md` §0.2**. As of 2026-08-31: security **S-1 REMEDIATED** (Phase 21.4 / PR #11); **S-2, S-3, S-4, S-5 remain OPEN**.

| # | Check | Result |
|---|---|---|
| **S-1** | `index.html` unmodified | **PASS** — not in the diff |
| **S-2** | No SQL artifact contains executable DDL/DML | **PASS** — every statement is inside a `--` comment; each file carries a "NOT A MIGRATION" header |
| **S-3** | No artifact presents itself as a migration or as instructions to apply | **PASS** — explicit header on all six |
| **S-4** | No secret, token, key or connection string added | **PASS** — see §3.1 |
| **S-5** | No backend write performed or attempted | **PASS** — no connection was made at all; no CREATE/ALTER/DROP/GRANT/REVOKE/INSERT/UPDATE/DELETE/TRUNCATE issued |
| **S-6** | Only documentation added | **PASS** — all additions under `analysis/phase-21.3/`, plus `.apos/PROJECT_CONTEXT.md` |

### 3.1 Secret scan

Scanned all added lines for: JWT-shaped strings (`eyJ…`), `access_token`/`refresh_token` values, `service_role`, `SUPABASE_SERVICE`, `sk_live`, `postgres://`/`postgresql://` connection strings, `password`, and the publishable key literal.

**Result: zero secret values.**

Four pattern hits occurred and all four are benign — recorded here so a future run does not raise a false alarm, the same way Phase 20.5's `haptic(` counting artefact was recorded:

| Pattern | Hits | What they actually are |
|---|---|---|
| `service_role` | 2 | Once a **Postgres role name** inside the `grants.sql` extraction query (`grantee IN ('anon','authenticated','service_role','PUBLIC')`); once in the scan list on this page |
| `SUPABASE_SERVICE` | 1 | This page's scan list only |
| `sk_live` | 1 | This page's scan list only |
| `postgres://` | 1 | This page's scan list only |

**The scanner matches its own scan list.** Any future secret check on this directory should exclude `validation.md` §3.1 or expect exactly these.

The project ref `kbnmkyvbwkuvcklywdhk` also appears. It is not a secret: it is already committed in `index.html` at `HEAD` and is public in every deployed page.

**Structural reason no secret can enter:** every extraction query targets **catalog views only** (`information_schema.*`, `pg_catalog.*`, `storage.buckets`, `pg_policies`). None selects from an application table, so no row data — and therefore no user data or credential — is in scope. This is checked as **R-7** below rather than left to inspection.

---

## 4. Reconciliation checks — 2 of 11 already pass

Each fails the phase rather than warning, and each is expressed against the client-side inventory in `backend-contract.md` §10. Live results so far are in `backend-contract.md` §11.

| # | Check | Passes when | Status |
|---|---|---|---|
| **R-1** | Every frontend RPC has a captured backend definition | All **20** names in §3 appear in `functions.sql` with a full body. **0 missing** | **Pending** — 34 functions exist vs 20 called, so the count reconciles in the safe direction, but **name-level matching is unproven** |
| **R-2** | Every frontend relation exists in the captured contract | All **14** in §2 appear in `schema.sql` | **Pending** — 20 relations exist vs 14 referenced; same caveat, counts are not names |
| **R-3** | Every frontend-handled SQLSTATE is documented | `23505`, `P0012`, `P0013`, `P0053` each traced to an emitting function and condition | **Pending** — needs function bodies |
| **R-3b** | Every SQLSTATE the backend raises is documented, including unhandled ones | Codes in `functions.sql` ⊇ the 4 handled. **Any surplus is a finding** — an unhandled custom code reaches the user as a raw Postgres message | **Pending** |
| **R-4** | Every RPC has a recorded EXECUTE grant | 20 functions each with grantees listed | **Pending** |
| **R-5** | Every direct write is permitted by a recorded grant, and no wider | Each of the 7 sites in §5 maps to a grant. A grant materially wider than the frontend uses is a finding, not a pass | **Pending** |
| **R-6** | Object counts reconcile | Captured counts ≥ client-side expectations; every shortfall itemised | **PARTIAL PASS** — every count so far exceeds or equals demand; **no deficit found** |
| **R-7** | No query selected application row data | Every query targets a catalog view only | **PASS** — all queries in the six artifacts target `information_schema.*`, `pg_catalog.*`, `pg_policies` or `storage.buckets` |
| **R-8** | RLS state recorded for every captured table | Including tables with RLS enabled and **zero** policies | **Pending** — 27 policies exist; distribution across 19 tables unknown |
| **R-9** | Realtime publication membership captured | The 5 tables in §8 confirmed as members | **PASS** — exact match, no surplus, no shortfall |
| **R-10** | The 4 known discrepancies are confirmed or refuted | §9 items 1–4 each resolved | **1 of 4 done** — item 1 **CONFIRMED**; 2–4 need grants and constraints |
| **R-11** | Capture is timestamped and attributed to a project ref | Each file records ref and capture time | **Pending** — ref recorded; capture timestamp to be stamped on delivery |

**A caution that matters for R-1 and R-2.** Counts reconciling in the safe direction is encouraging but is *not* the check. 34 ≥ 20 and 20 ≥ 14 only prove the backend is not obviously too small. They do not prove the specific 20 RPCs and 14 relations the frontend needs are the ones that exist. Those two checks stay **Pending** until name-level lists arrive, and should not be reported as passing before then.

### 4.1 Suggested mechanisation

A `static-check.sh` in the Phase 21.1/21.2 house style can assert **R-1, R-2, R-3, R-7** and **S-2** purely from repository contents, with no backend access — by cross-referencing the names in `backend-contract.md` against the captured SQL. Deferred until there is a snapshot to check; writing it now would only assert against empty files.

---

## 5. Discrepancies already known, pending confirmation

Carried from `backend-contract.md` §9. Recorded here so they are not lost.

1. **`public_profiles` never reads `profiles.display_name`** — **CONFIRMED against the live catalog.** The view is sourced from `public.users`. The Edit Profile screen at [2213](../../index.html#L2213) therefore writes a column the view never reads, so that write cannot affect any display name the app renders. Independently corroborates the Phase 21.1 finding.
2. **`users.username` write narrowness unverified** — enforced by comment ([2222](../../index.html#L2222)), possibly not by grant.
3. **`collaboration_assets.asset_type` is client-written** — a `CHECK` may or may not constrain it.
4. **`collaborations.status` assumed RPC-written only** — Phase 21.1 left it unescaped on that basis, which rests on grants nobody has read.

---

## 6. Unresolved concerns

0. **FINDING — collaboration asset uploads are unbounded at every layer.** Confirmed live: the `collaboration-assets` bucket has `file_size_limit = NULL` and `allowed_mime_types = NULL`, and the frontend imposes no restriction either (check **C-9**). Any authenticated participant can upload a file of any size and any type. Pre-existing, **not introduced by this phase, and out of scope to fix here** — Phase 21.3 captures the contract, it does not change it. Recorded for a product decision. The bucket being private is correct and consistent with the frontend's use of `.download()`.
1. **The detailed extraction has not been delivered.** Access is confirmed and headline counts are captured, but per-object detail is outstanding, so 9 of 11 reconciliation checks remain pending.
2. **Q-2 is still unanswered from Phase 20.7** — whether the project is still the *"disposable test project"* the code calls it. It bears directly on how this capture should be handled and how much confidence the contract deserves.
3. **Snapshot staleness has no owner** (R5 / Q-4), the same class of gap as Phase 21.2's unanswered Q-5.
4. **Scope boundary between `public`, `auth` and `storage` is undecided** (Q-3). A `public`-only capture would silently omit the signup trigger and the bucket policies — two of the most consequential objects.

---

## 7. Summary

The client side of the backend contract is captured exhaustively and validated: **10 audit checks and 6 repository-safety checks pass**, including a secret scan with zero hits and confirmation that **no backend connection was made at all**, let alone a write.

The server side is not captured, because no read-only connection was available. Nothing was invented to hide that; each SQL artifact carries its exact extraction query and an explicit pending marker. **11 reconciliation checks are defined and ready to run** the moment access exists.

**Level 1 is satisfied for this step.** The extraction step remains outstanding and is blocked solely on **Q-1**.
