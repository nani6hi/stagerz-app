# Phase 21.3 — Validation Record

**Branch:** `phase-21.3-backend-contract` (Step 1, merged in PR #12); resumed on `phase-21.3-backend-contract-resume` from `main` @ `2fdef81`
**Base commit:** `ebfe536` (Step 1); `2fdef81b15cf58bb5594dc60ca0173942de5b341` (resume)
**Validation level:** **1** — documentation only; `index.html` is not touched (`.apos/VALIDATION_STANDARD.md` §2)
**Status (2026-09-17):** **Current-epoch snapshot CAPTURED and fingerprint-verified; Phase 21.3 INCOMPLETE on one gate.**
- The six `.sql` snapshots are complete for epoch `20260916215204`, and every definition reconciles with the live catalog (§13).
- R-1–R-4 and R-6–R-11 **PASS**, and repository-safety checks S-1–S-6 **PASS**.
- **R-5 FAILS on grant width:** some granted write columns and tables go beyond what the frontend uses (§14). A recorded owner decision is required before the phase can close (§17).

No backend write was performed at any point.

Sections 1–7 are the **Step 1 record (2026-08)**, preserved as written. Sections 8–17 are the current-epoch completion record.

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

> **Step 1 status (2026-08), superseded.** The results of these checks for the current epoch are in **§14**.

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

> **Step 1 concerns (2026-08).** Current state of each:
> - **0 — unbounded uploads:** still true, and recorded in `storage-policies.sql`.
> - **1 — extraction not delivered:** resolved (§11).
> - **2 — Q-2:** still unanswered.
> - **3 — snapshot staleness:** addressed by the fingerprints and the re-run method in §13.
> - **4 — scope boundary between schemas:** decided — `public`, `auth.users` triggers and `storage` are all captured.

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

---

## 8. Resume and current-epoch capture — 2026-09-17

- **Starting point:** `main` @ `2fdef81b15cf58bb5594dc60ca0173942de5b341` (after the O-1/O-2/O-3 closure), clean.
- **Branch:** `phase-21.3-backend-contract-resume`, created fresh from that commit. The old `phase-21.3-backend-contract` was not reused.
- **Read-only calls against `kbnmkyvbwkuvcklywdhk`:**
  - `get_project`;
  - five marked extraction queries (`P213-EPOCH-v1`, `P213-FUNCTIONS-v1`, `P213-SCHEMA-v1`, `P213-GRANTS-v1`, `P213-RLS-STORAGE-TRIGGERS-v1`), each a single `SELECT json_build_object(...)`;
  - a final read-only check after the commit (§17).
- **Not done:** no `apply_migration`, no DDL or DML, no Edge Function or Storage call, no secret access, no Advisor action.

## 9. Live epoch verification — PASS

| Check | Result |
|---|---|
| Target | `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk`, `ACTIVE_HEALTHY`, PostgreSQL 17.6 |
| Migration history | 42 rows; latest `20260916215204 backend_integrity_o1_o2_o3` |
| Inventory | 17 tables, 1 view, 34 functions (0 overloads), 25 policies, 3 `public` triggers + 1 `auth.users` trigger, 141 columns, 40 indexes, 30 FKs; 0 sequences, types or rules |
| O-1 / O-2 / O-3 | `authenticated` has no INSERT on `wanted_applications` and no DELETE on `wanted_posts`; the collaborations FK is `RESTRICT`; asset INSERT is limited to the 9 columns |
| Drift since the post-merge reconciliation of 2026-09-17 | **none** |

## 10. Artefact assessment

| File | Class | State before resume | State now |
|---|---|---|---|
| `schema.sql` | C — generated snapshot | stub (queries and counts only) | complete |
| `functions.sql` | C | stub (0 of 34 bodies) | complete, 34/34 |
| `grants.sql` | C | stub (queries only) | complete |
| `rls-policies.sql` | C | stub (count only) | complete, 25/25 |
| `storage-policies.sql` | C | stub (bucket facts) | complete |
| `triggers.sql` | C | stub (counts) | complete |
| `backend-contract.md` | A + B — current contract (§13) plus historical evidence (§11, §12) | client side complete; server side partial | §13 added; stale §11 sections carry banners; history unchanged |
| `phase-definition.md` | D | Step 1 status | status updated |
| `validation.md` | D | Step 1 checks | this record |

The stubs contained no evidence beyond their extraction queries and headline counts; those remain in git history (`2895367`).

## 11. Snapshot generation

**Method.** Each extraction returned one JSON document.
- The documents were decoded exactly from the session's tool results, with no manual transcription, and rendered by a deterministic generator (stable ordering, LF only).
- Every output line is an SQL comment. Verbatim definitions sit in `-- >>> BEGIN` / `-- <<< END` blocks, prefixed `-- | `, each carrying the server-side SHA-256 of the exact text.
- The generator refuses to write any non-comment line or any CR.

| File | Catalog sources | Objects |
|---|---|---|
| `schema.sql` | `pg_class`, `pg_attribute`, `pg_attrdef`, `pg_constraint`, `pg_index`, `information_schema.views`, `pg_get_viewdef`, `pg_publication(_tables)`, `pg_extension`, `pg_namespace`, `pg_roles`, `pg_db_role_setting`, `supabase_migrations.schema_migrations` (version and name only) | 17 tables, 1 view, 141 columns, 67 constraints, 40 indexes, 2 publications, 5 extensions, 42 migration names |
| `functions.sql` | `pg_proc`, `pg_language`, `pg_get_functiondef`, `aclexplode(proacl)` | 34 functions with full definitions, attributes and EXECUTE grants; 121 RAISE sites; 58 codes |
| `grants.sql` | `pg_namespace.nspacl`, `pg_class.relacl`, `pg_attribute.attacl`, `pg_proc.proacl`, `pg_default_acl`, `has_*_privilege` | 393 table-level, 39 column-level and 93 function privilege rows; 256 default-ACL rows (24 entries); effective matrix for `anon` / `authenticated` on 20 relations |
| `rls-policies.sql` | `pg_policy`, `pg_get_expr`, `pg_class` | 17 tables' RLS state, 25 policies |
| `storage-policies.sql` | `storage.buckets` (configuration columns, owner excluded), `pg_policy`, `pg_class`, relation ACLs | 1 bucket, 8 storage tables' RLS state, 2 policies |
| `triggers.sql` | `pg_trigger`, `pg_get_triggerdef`, `pg_event_trigger` | 8 triggers (1 auth, 3 public, 4 storage), 6 event triggers |

## 12. SQLSTATE reconciliation with Phase 21.9 — PASS

| Measure | Live (captured) | Phase 21.9 `error-codes.tsv` |
|---|---|---|
| RAISE EXCEPTION sites | 121 | 121 |
| Distinct custom codes | 58 | 58 |
| Tokens per code | identical for 58/58 | — |
| Raising functions per code | identical for 58/58 | — |
| Client-facing / admin-only | 53 / 5 — identical classification | 53 / 5 |
| Client-facing codes mapped by the frontend translator | 53/53 | — |

There is no unexplained difference.

## 13. Method and repository-to-live fingerprint reconciliation — PASS

**How the check works.** A verifier re-read the six written files (LF-normalized), rebuilt every definition from its `-- | ` lines, and recomputed SHA-256 locally.
- **Canonical texts:**
  - functions: `pg_get_functiondef()`;
  - views: `pg_get_viewdef(oid, true)`;
  - constraints: `pg_get_constraintdef()`;
  - indexes: `pg_get_indexdef()`;
  - triggers: `pg_get_triggerdef()`;
  - policies: schema, table, name, command, permissive, roles, USING and WITH CHECK joined by newlines, with `<null>` for an absent expression.
- **Aggregate hashes** are recomputed from the rendered rows in the order printed.

| Object set | Result | Aggregate SHA-256 |
|---|---|---|
| Functions | **34/34** byte-identical | `1abd299b5e3f39bd5919e522357f2d8e17522ff87421f4560c6bf79c03588d43` |
| View `public_profiles` | match (md5 `d86256ac1ad53a250c96c315ed69a52e` = Phase 21.4 baseline) | `f0651e4d89598ebcb4876a1267fefe5f8ca61c66f10ba1b46fb08aa45bf18706` |
| Constraints | **67/67** | `98350d5e1189c1588d566f6976f61a0f17f8f00f56e27100b181f4717da1f2ac` |
| Indexes | **40/40** | `85a1240403166bd7fc4afcdab2dd263e33b7ce30dc7577363f204020dab992bb` |
| Columns (parsed back from the tables) | **141**, aggregate match | `21c9b64ff9a598b8e37ae19d36adae8f84ac3eb0a5e6a219459495d462d0bf61` |
| `public` policies | **25/25** | `d16c3e415c8163fadce6fa91f0996baf41b9f6a80e3613ed407f9b7205311163` |
| `storage` policies | **2/2** | `eee0fad6695c94ba20688da0a3bcba6009a59760ab9008b8fe2d522c8810536d` |
| Triggers | **8/8** | `62f69d51ba813ccbc6743cfc9af1f9b79255c9c8a77c14af6f7585d1b50806eb` |
| Table privileges (393 rows) | aggregate match | `7b785fb172a68861f02ccdce9a7f1e82ede7a4054f4c9a08cd9493a9a00b0155` |
| Column privileges (39 rows) | aggregate match | `fc922a1f19525b146d72745f21437ae25193c50918963be72ffd1b5f12aadece` |
| Function privileges (93 rows) | aggregate match | `a357d8063de20cc086bddb6a9977d0ed10fc9cd329e714193b1825e9dd16d520` |
| Default ACLs (256 rows) | aggregate match | `d231ccfaa157897c13e9b66980ba8298de51e36637caddc37473e643480f4def` |

**Re-running later.** Re-execute the extraction queries summarised in §11 and compare these values; any difference is drift. The aggregate definitions are stated in each `.sql` file.

## 14. Reconciliation checks R-1 to R-11 — current epoch

Interpretation: the invariants are evaluated against epoch `20260916215204` and the current `index.html` (blob `9720134`), whose demand sets equal the Step 1 audit (`backend-contract.md` §13.2).

| # | Result | Evidence |
|---|---|---|
| **R-1** | **PASS** | All **20** frontend RPC names appear in `functions.sql` with complete bodies (byte-identical, §13); 0 missing |
| **R-2** | **PASS** | All **14** frontend relations (13 tables + `public_profiles`) are in `schema.sql` with columns, constraints and indexes |
| **R-3** | **PASS** | `23505` comes from constraints `wanted_applications_wanted_post_id_applicant_id_key` (applyToWanted) and `users_username_key` (saveProfile). `P0012` (`wanted_post_not_open`) and `P0013` (`cannot_apply_to_own_wanted`) are raised by `create_wanted_application`. `P0053` (`duplicate_credit`) is raised by `create_collaboration_credit` |
| **R-3b** | **PASS** | 58 codes are raised (the handled 3 plus 55 more). The surplus was finding S-4, **now REMEDIATED**: all 53 client-facing codes are mapped by the Phase 21.9 translator, and the 5 admin-only codes are unreachable because EXECUTE is limited to `postgres` / `service_role`. No unhandled client-facing code remains (§12) |
| **R-4** | **PASS** | All 20 RPCs have recorded EXECUTE grants (`authenticated`, `postgres`, `service_role`) in `functions.sql` and `grants.sql`; none is granted to `anon` or `PUBLIC` |
| **R-5** | **FAIL — width findings recorded** | *Mapping:* all 7 direct write sites map to a grant that permits them. *"No wider":* sites 1, 5, 6 and 7 are exact. The following are wider than the frontend uses (W-1 to W-4 below) |
| **R-6** | **PASS** | Relations 18 ≥ 14; functions 34 ≥ 20 RPCs; buckets 1 = 1; handled SQLSTATEs 4 traced; realtime 5 = 5. No shortfall |
| **R-7** | **PASS** | The capture read catalog and metadata only: `pg_catalog`, `information_schema`, `storage.buckets` (configuration, owner columns excluded), `pg_publication_tables`, `pg_db_role_setting`, `supabase_migrations.schema_migrations` (versions and names only). No application table was selected |
| **R-8** | **PASS** | RLS state recorded for all 17 tables, including the two zero-policy queues (`rls-policies.sql` §1) |
| **R-9** | **PASS** | `supabase_realtime` = exactly the five tables the frontend subscribes to |
| **R-10** | **PASS** | All four discrepancies resolved and re-verified at this epoch. (1) `public_profiles` depends only on `users` and never reads `profiles.display_name`: CONFIRMED. (2) The `users` UPDATE grant excludes `id`, `is_system`, `blocked`, `anonymized_at`, `created_at`, `updated_at`: CONFIRMED ENFORCED. (3) No CHECK on `collaboration_assets.asset_type`: still REFUTED (only `file_size > 0`). (4) `collaborations` is SELECT-only for `authenticated`, and status changes go through RPCs: CONFIRMED |
| **R-11** | **PASS** | Each of the six files records project ref, server version, migration epoch and UTC extraction timestamp (verified mechanically) |

**R-5 width findings** (all own-row-scoped by RLS; none reaches another user's row or an internal column):

| # | Grant | Beyond frontend use | Prior record |
|---|---|---|---|
| W-1 | `wanted_posts` INSERT (table-level) | client may set `id` and `created_at` (the frontend also sends `status: 'open'`, which the grant allows) | Recorded as an open, low follow-up in `analysis/backend-integrity-remediation/phase-definition.md` §8 |
| W-2 | `profiles` UPDATE columns | `available`, `category`, `country_flag`, `looking_for` (the frontend edits display_name, role, location, bio, skills) | §11.4 described these grants as intended ("scoped tightly") |
| W-3 | `users` UPDATE columns | `first_name`, `last_name`, `photo_url`, `bio`, `location` (the frontend writes `username` only). `first_name`/`last_name` take precedence in `public_profiles.display_name` | §11.4 (intended); Phase 21.1 raised the display-name precedence as an open question |
| W-4 | `follows`, `likes` INSERT / DELETE | no frontend write path exists | Phase 21.6 recorded it as a product gap |

The Step 1 definition says a grant materially wider than the frontend uses "is a finding, not a pass". R-5 is therefore reported as **FAIL**; it is not reinterpreted. None of W-1 to W-4 is raised as a new security finding here. They need a recorded owner decision: accept each as intended design, or narrow it.

## 15. Repository-safety checks S-1 to S-6 (Phase 21.3 namespace, not the security findings)

| # | Result | Evidence |
|---|---|---|
| **S-1** | **PASS** | `index.html` unchanged — not in the branch diff against `2fdef81` |
| **S-2** | **PASS** | Each of the six `.sql` files parses (PostgreSQL 17 parser, `libpg-query`) to **0 statements** and has **0** non-comment lines |
| **S-3** | **PASS** | Every `.sql` file begins with "DESCRIPTIVE SNAPSHOT -- NOT A MIGRATION." and states it must never be executed |
| **S-4** | **PASS** | Secret and identifier scan of all changed files: 0 JWT-shaped strings, 0 Supabase keys, 0 `sk_live`, 0 credential-bearing connection strings, 0 UUID literals, 0 email addresses, 0 password assignments. The project ref appears; it is public, as recorded in §3.1 |
| **S-5** | **PASS** | No backend write performed or attempted: every Supabase call was `get_project` or a read-only `SELECT` (§8) |
| **S-6** | **PASS** | Only documentation changed, all under `analysis/phase-21.3/`. `.apos/PROJECT_CONTEXT.md` is left unchanged because the phase is not complete |

## 16. Historical security reconciliation

- **S-1 to S-8 — all remain REMEDIATED; nothing in the capture contradicts any closure:**
  - `public_profiles` is SELECT-only;
  - no test tables exist;
  - the postgres default ACLs are narrowed;
  - no `public` MAINTAIN is held by an API role;
  - the `log_*` functions are limited to `postgres` / `service_role`;
  - the reaper and drainer paths are untouched;
  - the S-4 translator covers every code;
  - the queue is protected.
- **O-1 / O-2 / O-3 — REMEDIATED; the capture shows the remediated state** (§9, `grants.sql` §2, `rls-policies.sql`, `schema.sql`).
- **`public.public_profiles` Advisor item — the accepted Phase 21.4 design**, recorded in `schema.sql` §3; not remediated and not suppressed.
- **Latent platform twins (documented, outside project control):**
  - `anon` / `authenticated` MAINTAIN on `storage.objects` and `storage.buckets`;
  - the `supabase_admin` default ACLs.

## 17. Completeness decision — PHASE 21.3 INCOMPLETE

| Requirement | State |
|---|---|
| Six SQL stubs populated | done |
| 34/34 function definitions | done |
| Every policy with expressions (25 + 2) | done |
| Table, column and function grants; default ACLs | done |
| Triggers | done |
| `public_profiles` definition | done |
| Storage contract | done |
| Realtime contract | done |
| SQLSTATE contract reconciled | done |
| Observable Auth configuration recorded; unobservable settings marked NOT OBSERVABLE | done (`backend-contract.md` §13.6) |
| Migration epoch recorded | done |
| Per-object fingerprints reconcile | done |
| R-1 to R-11 evaluated | done — **R-5 FAIL** |
| S-1 to S-6 | done — all PASS |
| No secret, user or row data | done |
| No unexplained live/repository mismatch | done |

**Blocker:** R-5. The four grant-width items W-1 to W-4 need a recorded decision, per item, to either:
- accept it as intended design (R-5 then passes with documented exceptions); or
- narrow it in a separately approved remediation.

Until then, Phase 21.3 stays **INCOMPLETE**. The snapshot itself is complete and verified for epoch `20260916215204`.
