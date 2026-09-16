# STAGERZ — Backend Contract

**Phase:** 21.3 — Capture the Backend Contract in the Repository
**Branch:** `phase-21.3-backend-contract`
**Base commit:** `ebfe536`
**Project ref:** `kbnmkyvbwkuvcklywdhk`

---

## 0. Status — read this first

This document has **two halves.**

| Half | Source | Status |
|---|---|---|
| **Client side** — what `index.html` demands of the server | Static audit of the working tree at `ebfe536`, re-derived 2026-09-17 against the current `index.html` | **COMPLETE and authoritative.** The same 14 relations, 20 RPCs and 7 direct write sites; only line numbers moved (§13.2) |
| **Server side** — what the Supabase project actually provides | Live read-only introspection | **CAPTURED 2026-09-17 for the current epoch** (migration `20260916215204`). The six `.sql` snapshots hold every table, column, constraint, index, function body, policy, grant, default ACL, trigger and the bucket configuration, each fingerprinted against the live catalog (§13) |

> **Update 2026-09-17.** The per-object snapshot that the 2026-08 text below describes as "awaiting delivery" has now been extracted mechanically from the live catalog and is in the `.sql` files. **§13 is the current server-side contract.** §11 is the 2026-08 extraction record, kept for its evidence; where its counts differ from §13, §13 is current.

*Step 1 text (2026-08):* Read-only access to `kbnmkyvbwkuvcklywdhk` has been verified and the confirmed results so far are recorded in **§11**. The per-object detail — column lists, constraint definitions, function bodies, policy expressions, grant rows — is being extracted externally and will be transcribed verbatim into the `.sql` artifacts when it arrives.

**Nothing is invented, and no placeholder stands in for data that can now be read live.** Where a fact is confirmed it is stated as confirmed; where detail is still outstanding that is stated plainly rather than filled with a guess.

The client half is not a placeholder either. It is the **demand side of the contract**, derived by exhaustive audit, and it is what the extraction is reconciled against. Every reconciliation check in `validation.md` is expressed against it.

**No backend write of any kind has been performed or attempted at any point in this phase.**

---

### 0.1 Reconciliation notice — read before §11 and §12

> **This document was written BEFORE Phase 21.4. Its S-1 evidence is HISTORICAL.**
>
> **S-1 is REMEDIATED.** Phase 21.4 (PR #11, merge `968b501`, now on `main` at `f4d1fa7`) revoked the write privileges. **`anon` and `authenticated` now hold `SELECT` only** on `public.public_profiles`. Re-verified live on 2026-08-31.
>
> §11.0 and §12 are **preserved deliberately and unedited in substance** — they are the evidence that found and proved the exposure, and erasing them would erase the finding. Read them as *"what was true before Phase 21.4"*, not as current state. Each carries its own banner.

> **A second remediation has since landed. S-2 is also HISTORICAL.**
>
> **S-2 is REMEDIATED.** Phase 21.5 dropped `public._test_results` and `public._test_run_log` on **2026-09-08**. Both tables and both owned sequences are gone; the two `rls_disabled_in_public` Security Advisor ERRORs they produced no longer appear. §11.1 is preserved unedited as the evidence that found the exposure, and carries its own banner.
>
> The 28 rows those tables held are preserved in `analysis/phase-21.5/pre-drop-snapshot.sql`, committed before the drop. Their content is summarised in `analysis/phase-21.5/phase-definition.md` §3.

> **A third remediation has since landed. S-3's §11.2 evidence is HISTORICAL in consequence, not in fact.**
>
> **S-3 is REMEDIATED.** Phase 21.8B (implementation merged as PR #18, merge `4bdb426`) deployed a dedicated server-side orphan reaper, `reap-orphaned-collaboration-assets`. On **2026-09-13** one production dry-run and one controlled delete run reclaimed all **15** orphaned objects: `storage.objects` **28 → 13**, orphans **15 → 0**, with every referenced object and every `collaboration_assets` row verified unchanged. Delete capability was disabled again immediately afterwards.
>
> §11.2's facts are **still true**: `storage.objects` still has only SELECT + INSERT policies, and the frontend's best-effort `remove()` is still denied. That absence is deliberate and fail-closed; what S-3 recorded as the defect — orphans that could never be reclaimed — is what Phase 21.8B closed. §11.2 is preserved unedited and carries its own banner. Detail: `analysis/phase-21.8b/`.

> **A fourth remediation has since landed. S-4's §11.3 evidence is HISTORICAL (pre-21.9).**
>
> **S-4 is REMEDIATED.** Phase 21.9 (PR #20, merge commit `2df2734247f5f1cccf0ae689d6e121775dea652b`) added a frontend-only backend error contract to `index.html`: every backend failure the UI displays is translated to fixed, safe copy, so raw tokens, constraint names, JSON and `message` / `details` / `hint` text no longer reach the user. No database function, SQLSTATE, constraint, policy, Edge Function, workflow or secret changed. On **2026-09-15** the exact merged `main` passed post-merge validation: static **41/41**, offline browser harness **55/55**, real-application Level 3 **50/50**, with **0** successful external requests and **0 / 0** Supabase requests attempted / sent.
>
> That validation was **deliberately network-isolated**; live Supabase was not exercised. §11.3 is preserved unedited as the evidence that found the finding, and carries its own banner. Detail: `analysis/phase-21.9/`.

> **S-8 was found after this document's §11 evidence was written, and it is also REMEDIATED.**
>
> **S-8** — the pending asset-deletion pipeline had no active automatic drainer — is a **reliability / data-lifecycle** finding (MEDIUM), **not a security vulnerability**. It has no §11 section; its evidence lives in `analysis/phase-21.8a/`. Phase 21.8A added a manual-only caller (PR #16), validated a production drain on 2026-09-13, and then added a daily schedule as a separate change (PR #17). The workflow is active and its first two scheduled runs succeeded (2026-09-14, 2026-09-15).

**Seven evidence epochs are used throughout this document:**

| Label | Meaning |
|---|---|
| **HISTORICAL (pre-21.4)** | Captured 2026-08-22/23, before the ACL was fixed. §11.0, §11.4's first paragraph, all of §12 |
| **HISTORICAL (pre-21.5)** | Captured 2026-08-22/23 and re-confirmed 2026-08-31, before the test tables were dropped. §11.1 |
| **CURRENT (post-21.5)** | Re-verified live 2026-09-08 against `kbnmkyvbwkuvcklywdhk`. §0.2. The post-21.4 re-verification of 2026-08-31 stands for §11.4's current-state block and §12.7, neither of which Phase 21.5 touched |
| **CURRENT (post-21.8B)** | Re-verified live 2026-09-13 against `kbnmkyvbwkuvcklywdhk`, after the Phase 21.8B delete run and delete disablement. The S-3 row of §0.2 and the banner on §11.2 |
| **CURRENT (post-21.9)** | Validated 2026-09-15 on merged `main` at `2df2734`, network-isolated; a frontend validation, not a live backend read. The S-4 row of §0.2 and the closure banner on §11.3 |
| **CURRENT (S-8 closure)** | Revalidated 2026-09-15: repository, GitHub Actions run history and state (read-only API), and an aggregate read-only queue query against `kbnmkyvbwkuvcklywdhk`. The S-8 row of §0.2 |
| **CURRENT (contract snapshot, epoch `20260916215204`)** | Extracted 2026-09-17 (UTC) from the live catalog of `kbnmkyvbwkuvcklywdhk` after the O-1/O-2/O-3 remediation. §13 and the six `.sql` snapshots. This is the authoritative current server-side contract |

### 0.2 Current status of all findings — S-8 row revalidated 2026-09-15 (post-remediation); S-4 row validated 2026-09-15 on merged `main` (post-remediation, network-isolated); S-3 row live-verified 2026-09-13 (post-remediation); S-6 and S-7 rows 2026-09-11 (post-remediation); S-5 row 2026-09-11; S-2 row 2026-09-08; all others 2026-08-31

| ID | Finding | Status |
|---|---|---|
| **S-1** | `anon` write path to `public.users` via `public_profiles` | ✅ **REMEDIATED — Phase 21.4 / PR #11.** ACL now `anon=r`, `authenticated=r` |
| **S-2** | `_test_results` / `_test_run_log` world-writable by `anon` | ✅ **REMEDIATED — Phase 21.5.** Both tables dropped 2026-09-08. `public` table count 19 → 17; both owned sequences gone; both Advisor ERRORs cleared; the REST endpoints now return 404. 28 rows preserved in `analysis/phase-21.5/pre-drop-snapshot.sql` |
| **S-3** | No DELETE policy on `storage.objects` — orphaned objects in `collaboration-assets` were never reclaimed (reclassified 2026-09-12 as storage-lifecycle / cleanup, not security) | ✅ **REMEDIATED — Phase 21.8B / PR #18.** 2026-09-13: no client DELETE capability was added — `storage.objects` still has only SELECT + INSERT policies, deliberately. Orphans are reclaimed server-side by `reap-orphaned-collaboration-assets` (service role, maintenance-secret gated): **dry-run by default**; deletes only objects referenced by **no** live or soft-deleted `collaboration_assets` row and not queued; **48 h** grace period; batch ≤ **25**; exact-match re-check of both tables immediately before each removal; delete mode needs the explicit confirmation token **and** the separately set `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` flag. Production dry-run and **one** controlled delete run validated: `storage.objects` 28 → **13**, orphans **15 → 0**, referenced objects and all 15 `collaboration_assets` rows fingerprint-identical before and after. **Delete flag removed afterwards** — the reaper is back to dry-run only. Runs are operator-initiated; nothing schedules them |
| **S-4** | Unhandled backend SQLSTATEs — raw backend error text reaches the user | ✅ **REMEDIATED — Phase 21.9 / PR #20.** Merged into `main` as merge commit `2df2734247f5f1cccf0ae689d6e121775dea652b` (PR head `24252a6`, product commit `ab3a46d`). Re-derived 2026-09-14: **121** RAISE sites, **58** custom codes (**53** client-facing, **5** admin-only); the historical "55 unhandled" overstated the gap because every RPC site already had a fallback. The real flaw was that the fallback **displayed** the raw token, constraint or JSON: **34** reachable codes, about 12 user-facing conditions. The fix is a frontend-only translation layer (no backend change) covering all 20 RPC fallbacks, the 5 direct-write fallbacks, the Storage and Auth display sites, and a zero-byte upload guard, plus 5000 / 300-character edit-length checks. Independent pre-commit review completed (two corrections applied). Pre-merge: static check **41/41**, offline browser harness **55/55**, real-application Level 3 **50/50**. **Post-merge validation, 2026-09-15, on the exact merged `main`:** `index.html` byte-identical to the reviewed state; static **41/41**, harness **55/55**, Level 3 **50/50**; **0** successful external requests, **0 / 0** Supabase requests attempted / sent; no uncaught exception; repository unchanged. Validation was deliberately network-isolated — live Supabase was not exercised. Detail: `analysis/phase-21.9/` |
| **S-5** | Default privileges grant ALL on new objects to `anon` | ✅ **REMEDIATED — Phase 21.6.** 2026-09-11: `anon` and `authenticated` removed from the `postgres` TABLES and SEQUENCES defaults in `public` and `storage`; `postgres` and `service_role` retained. Every existing object ACL byte-identical. FUNCTIONS and `supabase_admin` defaults deliberately unchanged |
| **S-6** | `anon` / `authenticated` hold `MAINTAIN` on `public.users` | ✅ **REMEDIATED — Phase 21.7.** 2026-09-11: `REVOKE MAINTAIN … FROM anon, authenticated`. `public.users` now grants table-level privileges to `postgres` and `service_role` only; neither app role holds any of the eight. **All seven column grants, RLS, both policies and zero triggers verified byte-identical.** Root cause was five enumerated revokes on 2026-07-12 written before PostgreSQL 17 named the privilege |
| **S-7** | Three `log_collaboration_*_activity` trigger functions executable by `PUBLIC`, and so by `anon` | ✅ **REMEDIATED — Phase 21.7.** 2026-09-11: `EXECUTE` revoked from `PUBLIC` and from `authenticated` on all three. Now `{postgres=X/postgres,service_role=X/postgres}` — `PUBLIC`, `anon` and `authenticated` all false — matching the `handle_new_auth_user()` posture. Bodies, security attributes and trigger definitions unchanged; Advisor lint `anon_security_definer_function_executable` 3 → 0 |
| **S-8** | Pending asset-deletion pipeline had no active automatic drainer (reliability / data-lifecycle, MEDIUM — **not a security vulnerability**) | ✅ **REMEDIATED — Phase 21.8A / PRs #16 and #17.** PR #16 (merge `026bace`) captured the deployed Edge Function source and added a manual-only GitHub Actions caller of `process-pending-asset-deletions` (maintenance-secret gated, `permissions: {}`, batch ≤ **25**, oldest first). Production drain validated 2026-09-13 (run #5): queue **2 → 0**, `collaboration_assets` **17 → 15**, Storage unchanged because both objects were already absent. PR #17 (merge `03ece66`) then added a daily schedule (`17 3 * * *`) as a separate approved change, keeping manual dispatch. Workflow **active**; scheduled runs on **2026-09-14** and **2026-09-15** both succeeded. Queue empty on 2026-09-15, with no failed attempts. Gates G-1 to G-7 PASS. Non-blocking reliability follow-ups are listed in `analysis/phase-21.8a/validation.md` §10.7 |

**All eight findings in this table — S-1 to S-8 — are now remediated, each by its own approved phase: S-1 by Phase 21.4, S-2 by Phase 21.5, S-5 by Phase 21.6, S-6 and S-7 by Phase 21.7, S-8 by Phase 21.8A, S-3 by Phase 21.8B, S-4 by Phase 21.9.** S-3 and S-8 are storage-lifecycle and reliability findings rather than security vulnerabilities.

**S-8's remediation is a scheduled caller, not a change to the drainer.** The drainer's source in this repository has not changed since G-7 proved the deployed copy byte-identical to it on 2026-09-13; the deployed metadata was not re-read at closure. The only production run that processed rows handled objects that were already absent, so the branch where an object is present and removed has not yet run in production. Throughput is one batch of at most 25 per day, and the listed hardening items remain open as non-blocking follow-ups. Detail: `analysis/phase-21.8a/`.

**S-4's remediation is a display contract, not a backend change.** The backend still raises the same 58 codes with the same HTTP mapping; the frontend no longer shows their raw text. The inventory is a 2026-09-14 snapshot, so a new backend code must be added to the translator (until then it fails safe to the action's fallback copy). Backend taxonomy items (HTTP 500 for P0002–P0059, P0001's collision with the PL/pgSQL default, duplicate codes, unlocked check-then-act races) and the pre-existing `supaInsert REQUEST` console log remain out of scope. Detail: `analysis/phase-21.9/phase-definition.md` §10.

**Backend integrity observations O-1, O-2 and O-3 are also REMEDIATED** (not S-numbered). They were found by this phase's re-baseline on 2026-09-15 and fixed as migration `20260916215204 backend_integrity_o1_o2_o3` (PR #21, merge `e7fd4ac`), validated before merge and reconciled after it. The detail is in `analysis/backend-integrity-remediation/`.
- **O-1:** direct `wanted_applications` INSERT is revoked; `create_wanted_application` is the only creation path.
- **O-2:** direct `wanted_posts` DELETE is revoked, and `collaborations_wanted_post_id_fkey` is `ON DELETE RESTRICT`.
- **O-3:** `collaboration_assets` INSERT is limited to nine columns, with `deleted_at IS NULL` and a folder binding.

The `security_definer_view` Security Advisor ERROR on `public.public_profiles` remains the **accepted Phase 21.4 design** (§13.6).

**S-3's remediation is a reclaim path, not a permission change.** It removed the existing orphans and provides a validated, bounded way to remove future ones. It does **not** stop new orphans from being created — the upload-then-insert failure path still leaves one behind — and it does **not** address the separate observation of live `collaboration_assets` rows whose Storage objects are missing (2 at 2026-09-13), which the reaper by design never touches. Detail: `analysis/phase-21.8b/`.

**S-5 was the root cause of S-1 and S-2, and it is now closed for future objects.** Until 2026-09-11, the `postgres` default privileges in `public` and `storage` granted ALL — including TRUNCATE — to `anon` and `authenticated` on every new table, view and sequence. Phase 21.6 removed both roles from those four entries, keeping `postgres` and `service_role`. That fix was deliberately not retroactive: no existing object's ACL changed, which is why two residues on existing objects survived it — **S-6** on `public.users` and **S-7** on the three trigger functions. **Phase 21.7 closed both**, on 2026-09-11, with seven `REVOKE` statements applied in a single atomic call; every other permission in `public` and `storage` was verified byte-identical afterwards. Latent twins outside this project's control remain: the `supabase_admin` / `public` TABLES default, which applies only to objects created *as* `supabase_admin`; the platform `storage` MAINTAIN grants; and three `storage` SECURITY INVOKER trigger functions. Detail: `analysis/phase-21.6/` and `analysis/phase-21.7/`.

---

## 1. Method

Every figure below comes from a static audit of `index.html` at `ebfe536`, cross-checked against `analysis/phase-20.7/codebase-assessment.md`. All access is funnelled through a small set of helpers, which is what makes an exhaustive audit possible:

| Helper | Line | Role |
|---|---|---|
| `supaHeaders(extra)` | [1061](../../index.html#L1061) | Attaches the live session token, falling back to the publishable key |
| `supaSelect(table, filters, columns)` | [1070](../../index.html#L1070) | All reads |
| `supaSelectCount(table, filters)` | [1101](../../index.html#L1101) | Count-only reads |
| `supaInsert(table, data)` | [1125](../../index.html#L1125) | Direct inserts |
| `supaUpsert(table, data, conflictCol)` | [1151](../../index.html#L1151) | Upserts |
| `supaUpdate(table, filters, data)` | [1177](../../index.html#L1177) | Direct updates |
| `supaUpdateMinimal(table, filters, data)` | [1236](../../index.html#L1236) | Narrow-column updates |
| `supaRpc(fnName, params)` | [1286](../../index.html#L1286) | All RPC calls |

**There is no other path to the backend.** The only literal REST path in the file is `/rest/v1/rpc/`; every table access goes through the helpers above, and every RPC name is a **string literal** — there is no dynamic or computed dispatch. That was verified explicitly, and it is what makes the counts below exhaustive rather than indicative.

---

## 2. Tables and views the frontend references — 14

Matches the Phase 20.7 inventory exactly.

| # | Relation | Referenced | Notes |
|---|---|---|---|
| 1 | `wanted_posts` | 7 | Read + insert + update |
| 2 | `profiles` | 6 | Read + update |
| 3 | `public_profiles` | 5 | **View.** Read only |
| 4 | `wanted_applications` | 3 | Read only (writes go via RPC) |
| 5 | `notifications` | 3 | Read + update (`read` flag only) |
| 6 | `collaboration_participants` | 3 | Read only |
| 7 | `users` | 2 | Read + update (`username` only) |
| 8 | `collaborations` | 2 | Read only |
| 9 | `collaboration_tasks` | 2 | Read only |
| 10 | `collaboration_assets` | 2 | Read + insert |
| 11 | `user_auth_accounts` | 1 | Read only — auth→domain identity mapping |
| 12 | `collaboration_messages` | 1 | Read only |
| 13 | `collaboration_credits` | 1 | Read only |
| 14 | `collaboration_activity` | 1 | Read only |

### 2.1 Column projections the frontend depends on

These are explicit `select=` lists. Each is a column-level dependency: if a column disappears or is revoked, the corresponding screen breaks.

| Relation | Columns requested |
|---|---|
| `users` | `id, username, first_name, last_name, photo_url, bio, location` |
| `profiles` | `role, location, bio, rating, followers_count, collab_count, project_count` |
| `public_profiles` | filtered by `id` — projection not narrowed (`*`) |
| `collaborations` | `id, title, status, wanted_post_id, created_at` |
| `collaboration_participants` | `user_id, participant_type, created_at`; also `collaboration_id, participant_type` |
| `collaboration_messages` | `created_at` (latest-message probe) |
| `collaboration_tasks` | `id, status`; also `id` filtered `status=eq.todo` |
| `collaboration_assets` | `id, file_size, created_at` |
| `collaboration_credits` | `id, user_id` |
| `collaboration_activity` | `id, actor_user_id, activity_type, reference_id, metadata, created_at` |
| `wanted_posts` | `title`; plus unnarrowed reads filtered by `status`/`user_id` |
| `wanted_applications` | `wanted_post_id`; also `id, applicant_id, status, created_at` |
| `notifications` | `id` filtered `read=eq.false` |
| `user_auth_accounts` | filtered by `auth_user_id` |

---

## 3. RPCs the frontend calls — 20

**20 distinct functions, 20 call sites, one call site each.** All names are string literals.

| # | Function | Line | Calling function |
|---|---|---|---|
| 1 | `close_own_wanted_post` | [2035](../../index.html#L2035) | `closeWantedPost()` |
| 2 | `create_wanted_application` | [2070](../../index.html#L2070) | `applyToWanted()` |
| 3 | `respond_to_wanted_application` | [2457](../../index.html#L2457) | `respondToApplication()` |
| 4 | `change_collaboration_status` | [3212](../../index.html#L3212) | `changeCollaborationStatus()` |
| 5 | `invite_collaboration_participant` | [3349](../../index.html#L3349) | `performCollaborationInvite()` |
| 6 | `remove_collaboration_participant` | [3368](../../index.html#L3368) | `removeParticipant()` |
| 7 | `transfer_collaboration_ownership` | [3387](../../index.html#L3387) | `transferOwnership()` |
| 8 | `leave_collaboration` | [3407](../../index.html#L3407) | `promptLeaveCollaboration()` |
| 9 | `edit_collaboration_message` | [3674](../../index.html#L3674) | `saveMessageEdit()` |
| 10 | `delete_collaboration_message` | [3693](../../index.html#L3693) | `deleteMessagePrompt()` |
| 11 | `create_collaboration_message` | [3738](../../index.html#L3738) | `sendCollaborationMessage()` |
| 12 | `edit_collaboration_task` | [3932](../../index.html#L3932) | `saveCollaborationTaskTitle()` |
| 13 | `delete_collaboration_task` | [3951](../../index.html#L3951) | `deleteCollaborationTaskPrompt()` |
| 14 | `create_collaboration_task` | [3974](../../index.html#L3974) | `createCollaborationTask()` |
| 15 | `complete_collaboration_task` | [4000](../../index.html#L4000) | `completeCollaborationTask()` |
| 16 | `edit_collaboration_asset` | [4620](../../index.html#L4620) | `saveCollaborationAssetEdit()` |
| 17 | `delete_collaboration_asset` | [4643](../../index.html#L4643) | `deleteCollaborationAssetPrompt()` |
| 18 | `edit_collaboration_credit` | [5011](../../index.html#L5011) | `saveCollaborationCreditEdit()` |
| 19 | `delete_collaboration_credit` | [5030](../../index.html#L5030) | `deleteCollaborationCreditPrompt()` |
| 20 | `create_collaboration_credit` | [5053](../../index.html#L5053) | `createCollaborationCredit()` |

Each requires a captured definition in `functions.sql` and an EXECUTE grant recorded in `grants.sql`.

---

## 4. Read surface

All reads go through `supaSelect` / `supaSelectCount`, authenticated by `supaHeaders()` ([1061](../../index.html#L1061)), which attaches the live session access token when one exists and otherwise falls back to the publishable key. **Both `anon` and `authenticated` read paths are therefore live and must both be captured** — several screens render before a session is confirmed.

---

## 5. Write surface — only 7 direct writes

This is the most contract-critical section. Almost every mutation goes through an RPC; only these seven touch tables directly, so **the grants that permit exactly these and no more are the enforcement boundary.**

| # | Line | Operation | Relation | Payload scope |
|---|---|---|---|---|
| 1 | [2137](../../index.html#L2137) | `UPDATE` | `wanted_posts` | Edit own post, filtered `id=eq.<editingWantedId>` |
| 2 | [2153](../../index.html#L2153) | `INSERT` | `wanted_posts` | New post; `user_id` supplied by the client |
| 3 | [2213](../../index.html#L2213) | `UPDATE` | `profiles` | `display_name, role, location, bio, skills…`, filtered `user_id=eq.<myId>` |
| 4 | [2223](../../index.html#L2223) | `UPDATE` | `users` | **`username` only**, filtered `id=eq.<myId>` |
| 5 | [2626](../../index.html#L2626) | `UPDATE` | `notifications` | `{read:true}`, single row |
| 6 | [2634](../../index.html#L2634) | `UPDATE` | `notifications` | `{read:true}`, all own unread |
| 7 | [4810](../../index.html#L4810) | `INSERT` | `collaboration_assets` | Metadata after a successful Storage upload |

Site 4 is deliberately narrow: [index.html:2222](../../index.html#L2222) carries a comment stating the payload must not include `anonymized_at`, `is_system`, `id` or other internal fields. **Whether that narrowness is actually enforced server-side by a column grant, or is only a client-side convention, is exactly the kind of question this phase must answer.** Phase 21.1 already flagged the same concern: a direct REST `PATCH` would bypass any client-side check.

---

## 6. Storage

Bucket **`collaboration-assets`**, four operations:

| Line | Operation |
|---|---|
| [4691](../../index.html#L4691) | `download` — in-app preview |
| [4800](../../index.html#L4800) | `upload` |
| [4836](../../index.html#L4836) | `remove` — error cleanup after a failed metadata insert |
| [4855](../../index.html#L4855) | `download` — explicit download |

Object path is built at [4795-4797](../../index.html#L4795-L4797) as:

```
<collaboration_id>/<epoch_ms>-<rand6>-<sanitized_filename>
```

`contentType` is `file.type || 'application/octet-stream'` ([4798](../../index.html#L4798)).

**The frontend imposes no size or MIME restriction whatsoever** — no `accept` attribute on the file input ([802](../../index.html#L802)), no size check before upload. Any limit is purely server-side, which makes `file_size_limit` and `allowed_mime_types` on the bucket part of the contract rather than an implementation detail.

---

## 7. Error-code contract

> **Phase 21.9 note — merged 2026-09-15, S-4 REMEDIATED.** This section describes the frontend at `ebfe536` and is preserved as captured. On `main` since PR #20 (merge commit `2df2734`), every displayed backend failure is routed through a single translator (`backendErrorMessage()` in `index.html`). The four handlers below keep their behaviour; the full code-to-category map is recorded in `analysis/phase-21.9/`.

Four SQLSTATEs are branched on. Each maps to a specific user-visible outcome, so a change to any of them silently degrades the UI into a generic error.

| SQLSTATE | Emitting RPC | Frontend site | Condition (inferred from UI copy) | User sees |
|---|---|---|---|---|
| `23505` | `create_wanted_application` | [2081](../../index.html#L2081) `applyToWanted()` | Unique violation — duplicate application | "You already applied." Button → `APPLIED`, disabled |
| `P0012` | `create_wanted_application` | [2087](../../index.html#L2087) `applyToWanted()` | Target post is not open | "This Wanted is no longer open." |
| `P0013` | `create_wanted_application` | [2092](../../index.html#L2092) `applyToWanted()` | Applicant owns the post — server backstop for a client-side check | "You cannot apply to your own Wanted." |
| `P0053` | `create_collaboration_credit` | [5070](../../index.html#L5070) `createCollaborationCredit()` | Participant already credited | "This participant already has a credit for this collaboration." |

Anything else falls through to a generic path that logs the real error and shows `message` / `hint` / `details` ([2099-2100](../../index.html#L2099-L2100)).

**The conditions above are inferred from UI copy, not read from function bodies.** Confirming them — and finding any *additional* SQLSTATE the backend raises that the frontend does **not** handle — is a required output of the extraction. An unhandled custom code surfaces to the user as a raw Postgres message, which is both a UX and an information-disclosure concern.

---

## 8. Auth, identity and realtime

**Auth surface** — four SDK entry points: `getSession` ×4, `signInWithOtp` ×1, `signOut` ×1, `onAuthStateChange` ×1.

**Flow assumptions baked into `index.html`:**

- Implicit flow with `detectSessionInUrl` (client created with no options, [1037](../../index.html#L1037)); confirmed against the 2.112.1 bundle defaults during Phase 21.2.
- `emailRedirectTo` hardcoded to `https://stagerz.app` ([1329](../../index.html#L1329)).
- Email magic link, not numeric OTP — the comment at [1309-1316](../../index.html#L1309-L1316) records that the hosted template sends `{{ .ConfirmationURL }}` and cannot be changed without custom SMTP.
- Session persisted in `localStorage` under `sb-kbnmkyvbwkuvcklywdhk-auth-token`.

**Identity chain** — `auth.users.id` → `user_auth_accounts.auth_user_id` → `public.users.id` (the "domain identity"), resolved by `getMyDomainId()` ([1358](../../index.html#L1358)), which notes it mirrors the server-side `current_stagerz_user_id()`. **Both that function and whatever populates `user_auth_accounts` at signup must be captured.**

**Realtime** — one channel per collaboration, `collaboration-<id>`, with `postgres_changes` on **five** tables — `collaboration_messages`, `collaboration_tasks`, `collaboration_assets`, `collaboration_credits`, `collaboration_activity` — plus presence keyed by domain user id. **Those five tables must be members of the `supabase_realtime` publication**; publication membership is part of the contract and is easy to overlook.

---

## 9. Known repository-vs-backend discrepancies

Carried forward from earlier phases; each needs confirming or refuting against the live catalog.

1. **`public_profiles` does not read `profiles`.** Phase 21.1 confirmed via `pg_get_viewdef` that the view is sourced from `public.users`, resolving `display_name` as `'Deleted User'` → trimmed `first_name`+`last_name` → `users.username` → `'STAGERZ Artist'`. Meanwhile the UI writes `profiles.display_name` ([2213](../../index.html#L2213)) — **a column the view never reads.** The captured view definition must state this plainly.
2. **`users.username` write narrowness is unverified.** See §5, site 4.
3. **`collaboration_assets.asset_type` is client-written**, so attacker-influencable regardless of UI logic; Phase 21.1 escaped it defensively. Whether a `CHECK` constrains it is unknown — that is Phase 20.7 item **C-3**.
4. **`collaborations.status` is documented as server-RPC-written only** and was deliberately left unescaped by Phase 21.1. That assumption rests on grants that have never been read.

---

## 10. Reconciliation targets

The extraction is complete when every count below is matched by captured objects:

| Object | Expected from client audit |
|---|---|
| Tables/views referenced | **14** |
| RPCs called | **20** |
| Direct write sites | **7**, across 5 relations |
| Storage buckets | **1** (`collaboration-assets`) |
| Handled SQLSTATEs | **4** |
| Realtime publication members | **≥5** |

A captured object the frontend never uses is **not** an error — the backend may legitimately be wider. It is recorded as surplus. The reverse — a frontend dependency with no captured backend object — **is** an error, and blocks the phase.

---

## 11. Live extraction — results

Read-only introspection of `kbnmkyvbwkuvcklywdhk` (`stagerz-foundation-v2-test`, Postgres 17.6.1.141, eu-north-1, `ACTIVE_HEALTHY`). **Every statement below is a `SELECT` against catalog views. No write was performed or attempted.**

### 11.0 FINDING S-1 — ✅ REMEDIATED by Phase 21.4 / PR #11 — *historical evidence below*

> **STATUS: REMEDIATED.** The exposure described in this section **no longer exists**. Phase 21.4 revoked the write privileges; `anon` and `authenticated` now hold `SELECT` only. Confirmed live 2026-08-31 — see §0.2 and §12.7.
>
> **Everything below this banner is HISTORICAL evidence, captured 2026-08-22/23 before the fix.** It is preserved verbatim and deliberately: it is how the exposure was discovered and proved, and it is the justification for the Phase 21.4 change. Read it in the past tense. It does **not** describe the current state.

**Original finding, as recorded pre-remediation:**

This was not previously known and is the most serious result of the phase.

**The privilege chain, every link verified from the catalog:**

| # | Fact | Value |
|---|---|---|
| 1 | `public_profiles` is a **view** | `relkind = 'v'` |
| 2 | Owned by | `postgres` — also the owner of `public.users` |
| 3 | `reloptions` | **`(none)`** → `security_invoker` is **not** set, so the view executes with **owner** privileges |
| 4 | `users` RLS | `relrowsecurity = true`, **`relforcerowsecurity = false`** → the owner **bypasses RLS** |
| 5 | View is auto-updatable | `is_updatable = YES`, `is_insertable_into = YES`, **0** INSTEAD OF triggers, no `WITH CHECK OPTION` |
| 6 | Grants to **`anon`** | `INSERT` and `UPDATE` on 7 columns |
| 7 | Columns actually writable | `id`, `username`, `photo_url`, `is_system`, `created_at` (all `is_updatable = YES`) |

**Consequence.** An **unauthenticated** caller appears able to `PATCH /rest/v1/public_profiles?id=eq.<uuid>` and have the write land in `public.users`, bypassing both the `users` UPDATE policy (`id = current_active_stagerz_user_id()`) and the carefully scoped column grants described in §11.4. The exposed columns include **`username`** — the identifier the UI renders and Phase 21.1 assumed only the owner could change — and **`is_system`**.

`display_name` and `is_deleted` are **not** writable, because both are computed expressions in the view. That limits the blast radius but does not remove it.

**Verification boundary — stated precisely.** This is established from **configuration only**. It was **not** tested, because testing requires a write, which this phase forbids and which would modify production data. Two things could still defuse it in practice and have not been checked: whether PostgREST is configured to expose the view for writes, and whether any gateway rule intercepts such a request. **Treat this as a finding requiring urgent review, not as a confirmed exploit.**

**Not fixed here.** Phase 21.3 captures the contract; it does not change it. Remediation is a separate, approved change.

### 11.1 FINDING S-2 — two test tables are world-writable by `anon`

> **HISTORICAL (pre-21.5) — this describes state that no longer exists.** Both tables were dropped by Phase 21.5 on 2026-09-08 and S-2 is **REMEDIATED** (§0.2). This section is preserved unedited because it is the evidence that found the exposure; erasing it would erase the finding. Read it as *"what was true before Phase 21.5"*.

| Table | RLS | Policies | `anon` privileges |
|---|---|---|---|
| `_test_results` | **disabled** | 0 | `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` |
| `_test_run_log` | **disabled** | 0 | `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` |

Unauthenticated callers can read, write and **truncate** both. They are evidently test scaffolding, and neither is referenced by `index.html`. Combined with the project being named `stagerz-foundation-v2-test`, this is direct evidence for the long-open **Q-2**.

### 11.2 FINDING S-3 — the frontend's Storage `remove()` cannot succeed

> **HISTORICAL (pre-21.8B) in consequence — the facts below are still true.** `storage.objects` still has exactly these two policies and no DELETE policy, and the frontend's `remove()` is still denied; that is deliberate and fail-closed. What changed is the consequence: orphaned objects are now reclaimable server-side. Phase 21.8B reclaimed all 15 on 2026-09-13 and S-3 is **REMEDIATED** (§0.2). This section is preserved unedited as the evidence that found the finding.

`storage.objects` has RLS **enabled** with exactly **two** policies — `SELECT` and `INSERT`, both `authenticated`, both scoped by path prefix:

```
bucket_id = 'collaboration-assets'
AND is_collaboration_participant(((storage.foldername(name))[1])::uuid)
```

**There is no DELETE policy.** The frontend calls `.remove()` at [4836](../../index.html#L4836) — the cleanup path that runs when an asset uploads successfully but its metadata insert then fails. Under this configuration that cleanup **will be denied**, orphaning the uploaded object.

This is precisely the call site Phase 21.2 recorded as *"not covered"* by its testing, so it has never been exercised.

The policies also confirm §6's coupling note: authorisation depends on the first path segment being the collaboration UUID, exactly the format [4795-4797](../../index.html#L4795-L4797) builds.

### 11.3 FINDING S-4 — 55 of 58 backend error codes are unhandled, and surface as raw tokens

> **HISTORICAL (pre-21.9) — the raw-text display described below no longer exists on `main`.** Phase 21.9 (PR #20, merge commit `2df2734`) translated every displayed backend failure into safe copy, and S-4 is **REMEDIATED** (§0.2), validated post-merge on 2026-09-15. The two banners below record the state on their own dates — the 2026-09-14 re-derivation, before merge, and the 2026-08-31 correction. This section is preserved unedited as the evidence that found the finding.

> **Phase 21.9 re-derivation (2026-09-14) — S-4 still OPEN; remediation locally validated, not yet merged.** The **58** figure is confirmed exactly (121 RAISE sites; 53 client-facing codes, 5 admin-only). The **55 unhandled** reading is superseded: all 20 RPC call sites had a generic fallback, but that fallback **displayed** raw tokens, constraint names or JSON. By reachability: 36 codes reachable (5 direct, 31 via stale or concurrent state), 17 defensive, 5 admin-only, 0 dead. Of the reachable codes, 34 showed raw text. See `analysis/phase-21.9/phase-definition.md` §2–§3. The evidence below is preserved unedited.

> **CORRECTION (2026-08-31), not a staleness fix.** This section originally said **54**. That was an arithmetic error on my part: I subtracted all 4 handled codes from 58, but only **3** of them (`P0012`, `P0013`, `P0053`) are among the 58 backend-`RAISE`d codes. The fourth, `23505`, is produced by the UNIQUE constraint `wanted_applications_wanted_post_id_applicant_id_key`, not by any `RAISE`, so it was never in that set. The correct figure is **58 − 3 = 55**. Re-verified live: 58 distinct backend SQLSTATEs, all three handled RAISE codes still present, and the `23505` constraint still in place. S-4 remains **OPEN** and is one code worse than recorded.

The backend raises **58 distinct SQLSTATEs**. The frontend branches on **4**, only **3** of which are backend-raised.

The messages are **machine tokens, not sentences** — `no_active_stagerz_identity`, `collaboration_not_active`, `not_a_participant`, `only_owner_may_transfer`, `title_too_long`, `body_empty`. The generic fallback at [2099-2100](../../index.html#L2099-L2100) renders `error.message` directly, so **any of the 55 unhandled codes reaches the user as a snake_case identifier**.

Selected inventory (full list in `functions.sql`):

| Code | Message | Raised by |
|---|---|---|
| `P0001` | `no_active_stagerz_identity` | **all 20** frontend RPCs — the auth guard |
| `P0008` | `post_not_found_or_not_open_or_not_owned` | `close_own_wanted_post` |
| `P0011` | `wanted_post_not_found` | `create_wanted_application` |
| **`P0012`** | `wanted_post_not_open` | `create_wanted_application` — **handled** |
| **`P0013`** | `cannot_apply_to_own_wanted` | `create_wanted_application` — **handled** |
| `P0014` | `collaboration_not_active` | 16 functions |
| `P0015` | `not_a_participant` | 8 functions |
| `P0016` | `collaboration_not_found` | 10 functions |
| `P0022` | `only_owner_may_change_status` | `change_collaboration_status` |
| **`P0053`** | `duplicate_credit` | `create_collaboration_credit` — **handled** |
| `P0054`–`P0059` | message CRUD guards | message functions |

`23505` — the fourth handled code — is raised by no function body. It comes from the constraint `wanted_applications_wanted_post_id_applicant_id_key UNIQUE (wanted_post_id, applicant_id)`. **R-3 resolved.**

`P0014`, `P0015` and `P0016` alone cover 34 raise sites across the collaboration surface and are all unhandled.

### 11.4 Grants — the split is real, and precisely engineered

> **Superseded for current state (2026-09-17).** The totals and the three-`log_*`-functions note below predate Phases 21.5–21.7 and the O-1/O-2/O-3 remediation. The current grants are in `grants.sql` and §13.4. The column-grant analysis below is still accurate for `users`, `profiles`, `notifications` and `wanted_posts` UPDATE.

> **CURRENT (post-21.4), live-verified 2026-08-31 — one grant in this section changed.**
>
> **`public.public_profiles` now grants `SELECT` only** to `anon` and `authenticated`:
> ```
> postgres=arwdDxtm/postgres | service_role=arwdDxtm/postgres | anon=r/postgres | authenticated=r/postgres
> ```
> Effective privileges (`has_table_privilege`, SELECT/INSERT/UPDATE/DELETE): `anon` **true/false/false/false**, `authenticated` **true/false/false/false**, `service_role` **true/true/true/true** (untouched).
>
> **Every other grant described below is unchanged.** The `users`, `profiles`, `notifications` and `wanted_posts` column-level grants are exactly as recorded. Live totals: **336** table-grant rows and **1500** column-grant rows in `public` (was 348 / 1542 pre-21.4; Δ −12 / −42, wholly attributable to this one view). Grant rows for relations *other than* `public_profiles`: **320**, unchanged.

**HISTORICAL (pre-21.4) analysis follows.** The column-grant findings below remain accurate and current; only the `public_profiles` table-level grant has changed.

Table-level grants alone appear to omit UPDATE on `users`, `profiles`, `notifications` and `wanted_posts`. **Column-level grants supply them**, scoped tightly:

| Relation | Role | Column-level UPDATE |
|---|---|---|
| `users` | `authenticated` | `bio, first_name, last_name, location, photo_url, username` |
| `profiles` | `authenticated` | `available, bio, category, country_flag, display_name, location, looking_for, role, skills` |
| `notifications` | `authenticated` | **`read` only** |
| `wanted_posts` | `authenticated` | `category, compensation, description, location, remote, role_needed, title` |

Two consequences worth stating:

- **Discrepancy 2 RESOLVED.** The `users` grant **excludes** `anonymized_at`, `is_system` and `id` — exactly what the comment at [2222](../../index.html#L2222) claims. The narrowness is genuinely enforced server-side, not merely by client convention.
- **`wanted_posts` UPDATE excludes `status` and `user_id`**, so ownership and open/closed state cannot be changed over REST; `status` moves only through `close_own_wanted_post`.

**Function EXECUTE grants are correct.** All five `admin_*` functions are granted to `postgres, service_role` **only** — *not* `authenticated`. No privilege escalation. All 20 frontend RPCs are granted to `authenticated` (not `anon`). The three `log_*` trigger functions carry the Postgres default `PUBLIC` EXECUTE, which is low-risk since they are only meaningful as triggers, but it is the one non-uniform grant among the 34.

### 11.5 Counts, reconciled

> **HISTORICAL counts (2026-08, pre-21.5).** Current counts are in §13.1: 17 tables, 18 relations, 25 policies, and no test tables.

| Object | Live | Client demand | Result |
|---|---|---|---|
| `public` tables | **19** | — | 5 unreferenced: `follows`, `likes`, `pending_asset_deletions`, `pending_auth_deletions`, plus the 2 test tables (net of the 14) |
| `public` views | **1** | — | `public_profiles` |
| Relations | **20** | 14 | 6 surplus |
| Functions | **34** | 20 RPCs | 14 surplus: 5 `admin_*`, 5 helpers, 4 trigger functions |
| RLS policies | **27** | — | verified: sums exactly across 19 tables |
| Storage policies | **2** | — | SELECT + INSERT only — see S-3 |
| `public` triggers | **3** | — | all AFTER INSERT activity loggers |
| `auth` triggers | **1** | signup hook | `on_auth_user_created` |
| Realtime tables | **5** | 5, named | **exact match** |

**No frontend dependency is missing from the backend.** All 20 RPCs and all 14 relations exist by name.

### 11.6 RLS posture

> **HISTORICAL (pre-21.5).** Currently RLS is enabled, and not forced, on **all 17** `public` tables (§13.5). The two test tables no longer exist.

RLS is enabled on **17 of 19** tables. The two exceptions are the test tables (S-2).

Reads are participant-scoped through `is_collaboration_participant()`; writes are ownership-scoped through `current_active_stagerz_user_id()`. The design is coherent and consistently applied — which is what makes the `public_profiles` view bypass (S-1) an anomaly rather than the pattern.

**Two tables have RLS enabled and zero policies** — `pending_asset_deletions` and `pending_auth_deletions`. That denies all access to non-owner roles, which is the correct posture for internal queues. **Recorded explicitly, as R-8 requires.**

`relforcerowsecurity` is `false` on **every** table. Owners therefore bypass RLS everywhere; that is the default, and it is the precondition that makes S-1 exploitable.

### 11.7 Signup trigger and identity chain

```sql
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
```

`SECURITY DEFINER`, `search_path = ''`, EXECUTE to `postgres, service_role` only. This is what populates `auth.users.id → user_auth_accounts.auth_user_id → public.users.id`, the chain `getMyDomainId()` ([1358](../../index.html#L1358)) depends on and which the repository has never recorded.

### 11.8 `public_profiles` definition — discrepancy 1 CONFIRMED from DDL

```sql
SELECT id, username, photo_url, is_system, created_at,
       anonymized_at IS NOT NULL AS is_deleted,
       CASE
         WHEN anonymized_at IS NOT NULL THEN 'Deleted User'
         WHEN first_name IS NOT NULL OR last_name IS NOT NULL
           THEN TRIM(BOTH FROM (COALESCE(first_name,'') || ' ') || COALESCE(last_name,''))
         ELSE COALESCE(username, 'STAGERZ Artist')
       END AS display_name
FROM users;
```

`FROM users` — it never reads `profiles`. The Edit Profile screen writes `profiles.display_name` ([2213](../../index.html#L2213)), a column this view cannot see. Phase 21.1's finding is confirmed from the actual definition.

### 11.9 All four known discrepancies resolved

| # | Discrepancy | Resolution |
|---|---|---|
| 1 | `public_profiles` ignores `profiles.display_name` | **CONFIRMED** — §11.8 |
| 2 | `users.username` write narrowness | **CONFIRMED ENFORCED** — column grant excludes internal fields (§11.4) |
| 3 | `collaboration_assets.asset_type` CHECK | **REFUTED — no CHECK exists.** Only `file_size > 0` and `UNIQUE (storage_path)`. The client can write any `asset_type`, and `authenticated` holds a column-level INSERT grant on it. **Phase 21.1's defensive escaping was necessary** |
| 4 | `collaborations.status` RPC-only | **CONFIRMED** — `authenticated` has `SELECT` only on `collaborations`; `status` is further constrained by `CHECK (status IN ('active','completed','archived'))` |

### 11.10 Constraints and indexes of contract significance

- `wanted_applications_wanted_post_id_applicant_id_key` **UNIQUE (wanted_post_id, applicant_id)** — the source of `23505`
- `users_username_key` **UNIQUE (username)**
- `idx_one_owner_per_collaboration` — **partial unique index** on `collaboration_id WHERE participant_type = 'owner'`, enforcing exactly one owner
- `collaborations_wanted_post_id_key` UNIQUE — one collaboration per Wanted post
- `collaboration_assets_storage_path_key` UNIQUE (storage_path); `CHECK (file_size > 0)`
- Length limits enforced in the database as well as in the RPCs: messages `<= 5000`, task titles `<= 300`
- **`collaboration_credits` has no unique constraint** — `P0053 duplicate_credit` is enforced only by an explicit check inside `create_collaboration_credit`, with no database-level backstop against a concurrent duplicate

### 11.11 What remains to transcribe

> **HISTORICAL — resolved 2026-09-17.** The claim below that 12 bodies were captured was never reflected in the repository: the 2026-09-15 re-baseline found 0 of 34 bodies in `functions.sql`. All **34 of 34** function definitions are now in `functions.sql`, byte-identical to the live catalog (§13.3).

Everything above is captured. The one outstanding item is **verbatim bodies for 22 of the 34 functions** in `functions.sql` — 12 are captured. Their *contract-bearing* content is already extracted in full (signature, volatility, security mode, `search_path`, EXECUTE grants, and every `RAISE` with its SQLSTATE and message), so nothing about the contract is unknown; only the full source text is pending.

---

## 12. S-1 escalation — read-only verification of the write-exposure chain *(HISTORICAL — pre-Phase-21.4)*

> **⚠️ THE ENTIRE SECTION 12 IS HISTORICAL EVIDENCE, captured 2026-08-23 BEFORE the fix.**
>
> Every privilege value, plan output and classification in §12.1–§12.6 describes the **pre-remediation** state. The exposure it proves was closed by Phase 21.4 / PR #11. **Do not read §12 as current.**
>
> It is preserved unedited because it is the proof that justified the remediation — the privilege chain, the absence of every defusing mechanism, and the `EXPLAIN` plan showing `Update on users` with no RLS predicate. Deleting it would leave the fix unexplained.
>
> **For the current state, see §12.7 and §0.2.**

Performed 2026-08-23. **No write, and no write test, was performed against production.** All database statements were `SELECT`; the HTTP probes were `OPTIONS` and a `GET` requesting **zero rows**.

### 12.1 Authoritative privilege checks (`has_*_privilege`)

| Check | Result |
|---|---|
| `anon` USAGE on schema `public` | **true** |
| `anon` SELECT / INSERT / UPDATE / **DELETE** on `public_profiles` | **all true** |
| `anon` UPDATE on cols `username`, `photo_url`, `is_system`, `id` | **all true** |
| `anon` SELECT on base `public.users` | **false** |
| `anon` UPDATE on base `public.users` | **false** |
| `postgres` `rolbypassrls` | **true** |
| `anon` `rolbypassrls` | false |
| view owner / base owner | `postgres` / `postgres` |
| `users` RLS enabled / **FORCED** | true / **false** |

`anon` has **no direct access** to `users`. The view is the only path — and it is open, including DELETE.

### 12.2 Defusing mechanisms — all absent

| Candidate | Value |
|---|---|
| `check_option` | **NONE** |
| `security_invoker` / `security_barrier` | **not set** (`reloptions = (none)`) |
| INSTEAD OF triggers on the view | **0** |
| Non-SELECT rules on the view | **0** |
| `is_trigger_updatable` / `_deletable` / `_insertable_into` | NO / NO / NO — genuinely auto-updatable |
| Generated or identity columns in `users` | **(none)** |
| Gateway / API restriction | none discoverable read-only |

### 12.3 PostgREST exposure

- `GET /rest/v1/public_profiles?select=id&limit=0` → **HTTP 200 `[]`**. The view **is** exposed through PostgREST to `anon`.
- `GET /rest/v1/users?select=id&limit=0` → **HTTP 401 / `42501`**. Base table correctly blocked.
- OpenAPI root (`/rest/v1/`) → **HTTP 401, "Only secret API keys can be used for this endpoint."** Not retrievable with the publishable key; no secret key was obtained or used.
- `OPTIONS` returns `Allow: GET, HEAD, POST, OPTIONS` **identically for every relation, including `users`** where `anon` has no privileges at all. The header is therefore **static, not privilege-derived, and is not evidence in either direction.**

**PostgREST implements no write authorisation of its own.** It issues the statement as the role and lets Postgres decide. With the schema exposed and `anon` holding UPDATE on the view, a `PATCH` is issued and Postgres governs the outcome.

### 12.4 Partial mitigation — `safeupdate`

`authenticator` preloads `session_preload_libraries = supautils, safeupdate`, which rejects `UPDATE`/`DELETE` **without a WHERE clause**.

This bounds the impact: an unfiltered mass update or delete is blocked (PostgREST also refuses unfiltered mutations by default). A **targeted** `?id=eq.<uuid>` write supplies a WHERE clause and is **not** blocked.

### 12.5 Column mapping

| View column | Base column | Writable |
|---|---|---|
| `id` | `users.id` | **YES** |
| `username` | `users.username` | **YES** |
| `photo_url` | `users.photo_url` | **YES** |
| `is_system` | `users.is_system` | **YES** |
| `created_at` | `users.created_at` | **YES** |
| `is_deleted` | `anonymized_at IS NOT NULL` — computed | NO |
| `display_name` | CASE expression — computed | NO |

### 12.6 Classification

> ## CONFIRMED CONFIGURATION EXPOSURE — *as classified on 2026-08-23; since REMEDIATED*

Every link is positively verified read-only, and no defusing mechanism exists. `users.username` is UNIQUE, so a targeted write can also collide with or seize another account's username.

**Scope of the claim:** this is confirmed *at configuration level*. End-to-end execution was **not** tested, because that requires a write. `safeupdate` bounds it to targeted, single-row writes rather than mass modification.

**Not remediated *by this phase*.** Phase 21.3 captures the contract; it does not change it. Remediation was carried out separately by **Phase 21.4 / PR #11** — see §12.7.

### 12.7 CURRENT state — S-1 closed, live-verified 2026-08-31

> ## ✅ REMEDIATED — Phase 21.4 / PR #11
>
> The exposure proved in §12.1–§12.6 **no longer exists.**

The chain was broken at its weakest necessary link — the grant — leaving the rest of the design untouched:

| Link from §12.1 / §12.2 | Then (pre-21.4) | Now (live 2026-08-31) |
|---|---|---|
| `anon` INSERT / UPDATE / DELETE on the view | **true / true / true** | **false / false / false** |
| `authenticated` INSERT / UPDATE / DELETE | **true / true / true** | **false / false / false** |
| `anon` / `authenticated` SELECT | true | **true — deliberately retained** |
| `service_role` | all true | all true — untouched |
| Raw ACL | `anon=arwdDxtm` | **`anon=r`, `authenticated=r`** |
| View owner / `relkind` / `reloptions` | `postgres` / `v` / `(none)` | **unchanged** |
| View definition (md5) | `d86256ac1ad53a250c96c315ed69a52e` | **`d86256ac1ad53a250c96c315ed69a52e` — unchanged** |
| `users` RLS enabled / forced | `true` / `false` | **`true` / `false` — unchanged**, 2 policies intact |

**What deliberately did *not* change, and why it matters.** `security_invoker` was **not** set, the view definition was **not** altered, and `users` RLS was **not** touched. The definer-view read gateway remains intentional and load-bearing: neither role can `SELECT public.users` directly, and the `users` SELECT policy is own-row-only, so making the view `security_invoker` would have broken every profile read. The defect was never the definer semantics — it was write privileges on a read gateway.

**Consistency with the documented change.** The resulting ACL is exactly what these two statements produce, and nothing more:

```sql
REVOKE ALL ON TABLE public.public_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO anon, authenticated;
```

`arwdDxtm` → `r` for precisely those two roles; `postgres` and `service_role` untouched; grant-row deltas (−12 table, −42 column) accounted for entirely by this view. Full record: `analysis/phase-21.4/`.

---

## 13. CURRENT server-side contract — epoch `20260916215204` (captured 2026-09-17)

**Source:** a read-only extraction of `kbnmkyvbwkuvcklywdhk` (`stagerz-foundation-v2-test`, PostgreSQL 17.6, `ACTIVE_HEALTHY`), taken 2026-09-16 23:09–23:13 UTC.
- **Epoch:** 42 migrations recorded; latest `20260916215204 backend_integrity_o1_o2_o3`.
- **What was read:** catalog and metadata only. No application row, user, Storage object or secret was read or recorded.
- **Where the detail is:** the six `.sql` files. Each is comment-only, and every definition in them is fingerprinted with a server-side SHA-256. `validation.md` §13 records the method and the reconciliation.

### 13.1 Inventory

| Object | Current | Snapshot |
|---|---|---|
| `public` tables | **17** (RLS enabled 17, forced 0) | `schema.sql` |
| `public` views | **1** (`public_profiles`) | `schema.sql` |
| Columns | **141** | `schema.sql` |
| Constraints | **67** (PK 17, UNIQUE 9, FK 30, CHECK 11) | `schema.sql` |
| Indexes | **40** | `schema.sql` |
| Sequences / user-defined types / rules in `public` | **0 / 0 / 0** | `schema.sql` |
| Functions | **34** (no overloads): 20 frontend RPCs, 5 helpers, 4 trigger functions, 5 `admin_*` | `functions.sql` |
| RLS policies | **25** `public` + **2** `storage.objects` | `rls-policies.sql`, `storage-policies.sql` |
| Non-internal triggers | **3** `public`, **1** `auth.users`, **4** `storage` (platform) | `triggers.sql` |
| Privilege rows | 393 table-level (313 in `public`), 39 column-level, 93 function EXECUTE; 24 default-ACL entries (256 rows) | `grants.sql` |
| Storage buckets | **1** (`collaboration-assets`) | `storage-policies.sql` |
| Realtime (`supabase_realtime`) | **5** tables | `schema.sql` |
| Extensions | pg_stat_statements 1.11, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, uuid-ossp 1.1 | `schema.sql` |

### 13.2 Client demand re-derived (current `index.html`, blob `9720134`)

- **Access paths:** unchanged. All access goes through the eight helpers; the only literal REST path is `/rest/v1/rpc/`, and every RPC name is a string literal.
- **Relations:** the same **14** as §2, all present.
- **RPCs:** the same **20** as §3, all present, all `SECURITY DEFINER` with `search_path=""`, all executable by `authenticated` only (plus `postgres` and `service_role`). Current call lines:
  - `close_own_wanted_post` 2130, `create_wanted_application` 2164, `respond_to_wanted_application` 2550;
  - `change_collaboration_status` 3304, `invite_collaboration_participant` 3440, `remove_collaboration_participant` 3458, `transfer_collaboration_ownership` 3476, `leave_collaboration` 3495;
  - `edit_collaboration_message` 3765, `delete_collaboration_message` 3783, `create_collaboration_message` 3827;
  - `edit_collaboration_task` 4024, `delete_collaboration_task` 4042, `create_collaboration_task` 4064, `complete_collaboration_task` 4089;
  - `edit_collaboration_asset` 4708, `delete_collaboration_asset` 4730;
  - `edit_collaboration_credit` 5108, `delete_collaboration_credit` 5126, `create_collaboration_credit` 5148.
- **Direct writes:** the same **7** sites, compared with the granted columns below.

| # | Line | Write | Columns the frontend sends | Granted to `authenticated` |
|---|---|---|---|---|
| 1 | 2230 | UPDATE `wanted_posts` | title, description, role_needed, category, location, remote, compensation | the same 7 columns — **exact** |
| 2 | 2245 | INSERT `wanted_posts` | user_id, title, description, role_needed, category, location, remote, compensation, status | table-level INSERT — all 11 columns; **also `id`, `created_at`** |
| 3 | 2304 | UPDATE `profiles` | display_name, role, location, bio, skills | 9 columns; **also `available`, `category`, `country_flag`, `looking_for`** |
| 4 | 2314 | UPDATE `users` | username | 6 columns; **also `first_name`, `last_name`, `photo_url`, `bio`, `location`** |
| 5 | 2718 | UPDATE `notifications` | read | `read` only — **exact** |
| 6 | 2726 | UPDATE `notifications` | read | `read` only — **exact** |
| 7 | 4908 | INSERT `collaboration_assets` | the 9 metadata columns | the same 9 columns — **exact** (O-3) |

- **Grants with no frontend write path at all:** `follows` and `likes` INSERT and DELETE (recorded in Phase 21.6 as a product gap).
- **Every such grant stays inside RLS.** Writes are own-row only (`current_active_stagerz_user_id()`), and no internal column (`id` of `users`, `is_system`, `blocked`, `anonymized_at`, ownership or status of other rows) is writable. The width is recorded under R-5 (`validation.md` §14).
- **Storage** (`collaboration-assets`): download at 4777 and 4952, upload at 4898, cleanup `remove` at 4934 (denied by design; no DELETE policy).
- **SQLSTATE branches:** `23505` at 2175 (duplicate application) and 2319 (username taken); `P0012` at 2181 and `P0013` at 2186. `P0053` is handled through the Phase 21.9 translator map. Every other code goes through `backendErrorMessage()`.
- **Realtime:** `postgres_changes` on the five collaboration tables (lines 4258–4270) plus presence.
- **Auth:** `getSession` ×4, `signInWithOtp` ×1, `signOut` ×1, `onAuthStateChange` ×1.

### 13.3 Functions and SQLSTATE contract

- **Definitions:** all **34** `pg_get_functiondef()` texts are in `functions.sql`, byte-identical to the live catalog (34/34 SHA-256 matches; aggregate `1abd299b…8d43`).
- **Attributes:** every function is owned by `postgres`, `SECURITY DEFINER` and `SET search_path TO ''`.
- **EXECUTE:**
  - no function is executable by `anon` or `PUBLIC`;
  - 25 are executable by `authenticated` (the 20 RPCs and 5 helpers);
  - the 5 `admin_*` functions and the 4 trigger functions are limited to `postgres` and `service_role`.
- **Custom SQLSTATEs:** **121** RAISE EXCEPTION sites and **58** distinct codes — 53 raised by client-reachable functions, 5 by `admin_*` only.
  - Tokens, raising functions and classification are **identical** to `analysis/phase-21.9/error-codes.tsv`.
  - All 53 client-facing codes are mapped by the frontend translator (S-4 remains remediated).
- **Non-RAISE code the frontend uses:** `23505`, from `wanted_applications_wanted_post_id_applicant_id_key` and `users_username_key`.

### 13.4 Grants

The details are in `grants.sql`.

**Effective privileges of the API roles on `public`:**

| Role | Privileges |
|---|---|
| `anon` | SELECT on `follows`, `likes`, `profiles`, `public_profiles`, `wanted_posts`; nothing else, and no function EXECUTE |
| `authenticated` | SELECT on every table the app reads, except `users`, which has column-level SELECT only on `id, username, first_name, last_name, photo_url, bio, location`, filtered by RLS to the caller's own row |
| `authenticated` writes | exactly those listed in §13.2, plus `follows` / `likes` INSERT and DELETE |

- **O-1 / O-2 / O-3:** no INSERT on `wanted_applications`; no DELETE on `wanted_posts`; `collaboration_assets` INSERT on the nine columns only.
- **S-1:** `public_profiles` is SELECT-only for both roles.
- **S-6:** neither role holds MAINTAIN on any `public` relation. `anon` and `authenticated` do hold MAINTAIN on `storage.objects` and `storage.buckets`: the documented platform-owned latent twin.
- **Default ACLs:**
  - `postgres` TABLES and SEQUENCES defaults in `public` and `storage` grant only `postgres` and `service_role` (S-5).
  - `postgres` FUNCTIONS defaults and all `supabase_admin` / `supabase_auth_admin` defaults are unchanged platform settings, as documented in Phase 21.6. The `supabase_admin` `public` TABLES default still names `anon` and `authenticated` — the known latent twin, which applies only to objects created as `supabase_admin`.

### 13.5 RLS

- **Coverage:** RLS is enabled on all 17 `public` tables and forced on none; 25 policies, all permissive. Expressions are verbatim in `rls-policies.sql` (aggregate `d16c3e41…1163`).
- **Zero-policy tables (deny-all queues):** `pending_asset_deletions` and `pending_auth_deletions`.
- **Read pattern:** reads are participant-scoped through `is_collaboration_participant()`, or public for `follows`, `likes`, `profiles` and `wanted_posts`.
- **Write pattern:** writes are own-row-scoped through `current_active_stagerz_user_id()`. There are no policies for DELETE on `wanted_posts` or INSERT on `wanted_applications` (O-1, O-2).
- **Asset INSERT check:** adds `deleted_at IS NULL` and the `<collaboration_id>/` folder binding (O-3).

### 13.6 `public_profiles`, Storage, Realtime, Auth, triggers

**`public_profiles`**
- **Definition:** unchanged (pretty-definition md5 `d86256ac…`, SHA-256 `f0651e4d…`), no `security_invoker` or `security_barrier`; SELECT only for `anon` and `authenticated`.
- **Advisor:** the Security Advisor's `security_definer_view` ERROR is the **accepted Phase 21.4 design** — neither remediated nor suppressed.

**Storage** (bucket `collaboration-assets`)
- **Bucket settings:** private, `STANDARD`, no `file_size_limit`, no `allowed_mime_types`, versioning disabled.
- **Policies:** two `storage.objects` policies (SELECT and INSERT for `authenticated`), both authorising by the first path segment through `is_collaboration_participant()`. There is no UPDATE or DELETE policy.
- **Triggers:** platform triggers `protect_objects_delete` and `update_objects_updated_at`.
- **Not captured:** object rows.

**Realtime**
- **`supabase_realtime`:** exactly `collaboration_activity`, `collaboration_assets`, `collaboration_credits`, `collaboration_messages`, `collaboration_tasks` (all columns, no row filter, default replica identity). This matches the frontend's five subscriptions (R-9).
- **Platform publication:** `supabase_realtime_messages_publication`, managed by Supabase.

**Auth — observable facts**
- **Signup trigger:** `on_auth_user_created` (AFTER INSERT on `auth.users`) → `handle_new_auth_user()`, which creates the `users`, `user_auth_accounts` and `profiles` rows.
- **Password protection:** the Security Advisor reports **leaked-password protection disabled** (WARN).
- **Client-side flow (from `index.html`, §8):** email magic link through `signInWithOtp`, redirect to `https://stagerz.app`, implicit flow.
- **NOT OBSERVABLE with the read-only tools available:** site URL, redirect allow-list, enabled providers, sign-up enabled or disabled, email OTP expiry and rate limits, JWT expiry, MFA settings, SMTP configuration. These live in Auth service configuration, not in the database, and were **not** inferred.

**Triggers** (`public`)
- `trg_log_collaboration_asset_activity`, `trg_log_collaboration_credit_activity`, `trg_log_collaboration_message_activity` — AFTER INSERT, FOR EACH ROW, enabled, no WHEN clause.
- The `storage` triggers are platform-owned. The database event triggers are the six Supabase platform triggers (pg_graphql / pg_cron / pg_net helpers and PostgREST schema-cache watchers).

**API roles**
- `authenticator` can become `anon`, `authenticated` or `service_role`, and preloads `supautils, safeupdate`.
- Statement timeouts: `anon` 3s, `authenticated` 8s.
- `postgres` has `BYPASSRLS`; no API role does.

### 13.7 Migration epoch

- **History:** 42 rows in `supabase_migrations.schema_migrations`, `20260712100630` … `20260916215204`; the names are listed in `schema.sql` §8.
- **Not in the history:** Phases 21.4–21.7 were applied with `execute_sql` and have no rows. Their changes are present in the captured state and recorded in `analysis/phase-21.4` … `21.7/migration.sql`.
- **Consequence:** replaying the migration history alone would **not** reproduce the current backend. The snapshot files here are the reviewable description of what exists; they are not a migration chain.
