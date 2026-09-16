# Backend integrity remediation (O-1 / O-2 / O-3) — Validation Plan

**Branch:** `backend-integrity-o1-o2-o3`
**Base commit:** `20acbe8292e3b706fd57040f1f2ff6c790e67a62` (`main`)
**Target:** `stagerz-foundation-v2-test` / **`kbnmkyvbwkuvcklywdhk`**
**Status:** **APPLIED AND VALIDATED on the test project, 2026-09-16.**
- Migration version `20260916215204` (`backend_integrity_o1_o2_o3`).
- All pre-apply gates, post-apply catalog gates and behavioural tests pass; the validation left no data behind. Record: **§9**.
- **O-1, O-2 and O-3 are REMEDIATED** on `kbnmkyvbwkuvcklywdhk`.
- The branch is **not merged**. Phase 21.3 stays paused until merge and closure are approved.

Sections 2–8 are the preparation-time plan and baseline, kept as written.

**Files:**
- `migration.sql` — the change;
- `rollback.sql` — the emergency reversal;
- `catalog-fingerprint.sql` — read-only catalog fingerprint, run unchanged before and after;
- `behavioral-validation.sql` — rollback-only behaviour tests (template).

---

## 1. Principles

- **Catalog first, behaviour second.** Behavioural tests run only after the catalog gates pass.
- **No real-user data.** Behavioural tests use synthetic fixture accounts only. Aggregate counts are the only row-derived values ever reported.
- **Nothing persists from validation.** `behavioral-validation.sql` always ends by raising an exception, so every test write is rolled back.
- **Any failed gate stops the phase** (`.apos/VALIDATION_STANDARD.md` §9). Rollback is a separate, explicitly approved decision.

---

## 2. Pre-apply baseline — captured read-only, 2026-09-16

Captured with `catalog-fingerprint.sql` against `kbnmkyvbwkuvcklywdhk`. No application rows were read.

### 2.1 Objects the migration changes

| Object | Baseline |
|---|---|
| `wanted_applications` ACL | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}`; no column ACLs |
| `wanted_applications` authenticated INSERT columns | `applicant_id,created_at,id,status,updated_at,wanted_post_id` |
| `wanted_applications` policies | INSERT "active users can apply to open wanted posts" (authenticated, permissive); SELECT "applicant or wanted owner can read applications" |
| `wanted_posts` ACL | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}`; column UPDATE ACLs on 7 content columns |
| `wanted_posts` DELETE | authenticated **true**; policy "active users can delete own wanted posts" (PUBLIC, permissive, `USING (user_id = current_active_stagerz_user_id())`) |
| `wanted_posts` other policies | "active users can update own wanted posts", "onboarded active users can insert own wanted posts", "wanted_posts are publicly readable" |
| `collaborations_wanted_post_id_fkey` | `FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE CASCADE`; ON UPDATE NO ACTION; MATCH SIMPLE; not deferrable; validated |
| `collaborations.wanted_post_id` | `uuid NOT NULL`; `collaborations_wanted_post_id_key UNIQUE (wanted_post_id)` |
| `wanted_applications_wanted_post_id_fkey` | `… ON DELETE CASCADE` (**not changed**) |
| `collaboration_assets` ACL | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}`; no column ACLs |
| `collaboration_assets` authenticated INSERT columns | all 12: `asset_type,collaboration_id,created_at,deleted_at,description,file_name,file_size,id,mime_type,storage_path,title,uploaded_by` |
| `collaboration_assets` INSERT policy | "active participants can create collaboration asset metadata", authenticated, permissive, three conditions (verbatim in `migration.sql`) |
| `collaboration_assets` SELECT policy | `(is_collaboration_participant(collaboration_id) AND (deleted_at IS NULL))` (**not changed**) |
| RLS | enabled, not forced, on all four tables |

The exact deparsed policy expressions are embedded verbatim in `migration.sql` (preflight) and `rollback.sql` (postflight).

### 2.2 Whole-schema fingerprints

| Key | Baseline | Expected after apply |
|---|---|---|
| `public_table_count` | 17 | 17 |
| `public_rls_enabled_count` / `forced` | 17 / 0 | 17 / 0 |
| `public_policy_count` | 27 | **25** (two policies dropped) |
| `public_policies_md5_excluding_changed_tables` | `2b8b76654eee27dcb4f2aa51ea3c9cc0` | unchanged |
| `public_relacl_md5_excluding_changed_tables` | `88d21a97310bbeeac5a0ac94e2b56b32` | unchanged |
| `public_attacl_md5_excluding_changed_tables` | `2f9f82543f2239899adc50b7bec8ca2d` | unchanged |
| `public_fk_count` | 30 | 30 |
| `public_fk_md5_excluding_changed_fk` | `82ed42214cfec7bf2b9de58af0330b49` | unchanged |
| `public_function_count` | 34 | 34 |
| `public_function_definitions_md5` | `04d3928e3ec29d19e6f6e653d17b73ab` | unchanged |
| `public_function_acl_md5` | `1e60caa47c4f5132a038b3479a2e69fb` | unchanged |
| `public_trigger_md5` (non-internal) | `fbae629d602f3a895f793c741f5bff2c` | unchanged |
| `public_profiles` | ACL `anon=r`, `authenticated=r`; `reloptions` NULL; viewdef md5 `d86256ac1ad53a250c96c315ed69a52e` | unchanged |
| `pending_asset_deletions` | ACL postgres + service_role only; RLS on; 0 policies | unchanged |
| `storage_objects_policies_md5` | `269618b8917de15fc22c9d2e4545fd28` | unchanged |
| `migration_history` | 41 rows, latest `20260721122606` | **42** rows; the new row is this migration |

### 2.3 Aggregate data baseline (counts only)

Captured 2026-09-16 21:37 UTC. Counts only; no row contents, identifiers or text were read or recorded.

| Measure | Count |
|---|---|
| `collaboration_assets` total / soft-deleted | 15 / 0 |
| `collaboration_assets` rows whose `storage_path` is not `<collaboration_id>/<something>` | **0** — every existing row already satisfies the new INSERT check (which applies to new inserts only) |
| `pending_asset_deletions` | 0 |
| `collaborations` | 11 |
| Non-`pending` applications with no participant created from them | 9 |

**Breakdown of the 9:**
- **4 `rejected`:** expected, since a rejection creates no participant.
- **1 `accepted` whose applicant has a `participant_joined` activity:** consistent with a member who later left or was removed.
- **4 `accepted` whose post has no collaboration:**
  - all 4 were last updated on **2026-07-15, before** the collaboration tables were created (migration `20260715121007`);
  - none has `updated_at = created_at`;
  - 2 carry an "accepted" notification.

This is consistent with accepts made through the pre-collaboration version of the respond flow. It is **not evidence** that O-1 was used, but it is not conclusive either, and it is **not changed** by this remediation. It is recorded for the Phase 21.3 snapshot as legacy data.

### 2.4 Security Advisor baseline — 2026-09-15 22:42 UTC

| Lint | Level | Count |
|---|---|---|
| `security_definer_view` (`public.public_profiles`) | ERROR | 1 — **accepted design** (Phase 21.4; `phase-definition.md` §6) |
| `authenticated_security_definer_function_executable` | WARN | 25 |
| `auth_leaked_password_protection` | WARN | 1 |
| `rls_enabled_no_policy` (`pending_asset_deletions`, `pending_auth_deletions`) | INFO | 2 |

---

## 3. PRE-APPLY gates

All must pass immediately before `apply_migration`.

| # | Gate | Pass condition |
|---|---|---|
| P-1 | Target | Project name `stagerz-foundation-v2-test`, ref `kbnmkyvbwkuvcklywdhk`, status `ACTIVE_HEALTHY` |
| P-2 | Repository | Clean working tree; the commit being applied is the reviewed one. SHA-256 of the LF-normalized committed blobs: `migration.sql` = `7f273f084330506cc1689f8e955902313b9d948d5645d4405ed9633003ef5221`, `rollback.sql` = `941c3b99963614324ce103dc68e5005550051520a83dfedd8025abf3ad5e1ba8`. Send the **LF** content (`git show <commit>:<path>`), not the CRLF working copy |
| P-3 | No drift | `catalog-fingerprint.sql` output equals §2.1 and §2.2 exactly |
| P-4 | Migration reviewed | Independent review of `migration.sql` complete |
| P-5 | Rollback reviewed | Independent review of `rollback.sql` complete; it is **not** executed |
| P-6 | Approval | Explicit user approval naming `apply_migration` and this file |
| P-7 | Fixtures | Synthetic fixture identities for `behavioral-validation.sql` chosen (no real users) |
| P-8 | Advisor | Output equals §2.4 |

`migration.sql` also enforces P-3 itself: its PREFLIGHT aborts, with nothing applied, if any affected ACL, policy or FK differs from the baseline.

---

## 4. Apply procedure (for the later, approved step)

1. Send `migration.sql` **unchanged** as the `query` of one `apply_migration` call against `kbnmkyvbwkuvcklywdhk`, with name `backend_integrity_o1_o2_o3`.
2. The whole change is one `DO` statement, so it is atomic. The in-file POSTFLIGHT aborts it unless the intended state was reached.
3. Record the version assigned by the platform.

---

## 5. POST-APPLY catalog gates

Run `catalog-fingerprint.sql` unchanged.

| # | Gate | Pass condition |
|---|---|---|
| C-1 | RLS | Enabled and not forced on all 17 `public` tables |
| C-2 | O-1 | `wanted_applications` ACL `…,authenticated=r/postgres`; authenticated INSERT columns **none**; only the SELECT policy remains |
| C-3 | O-2 grant | `wanted_posts` ACL `…,anon=r/postgres,authenticated=ar/postgres`; authenticated DELETE **false**; DELETE policy absent; the other three policies unchanged |
| C-4 | O-2 FK | `collaborations_wanted_post_id_fkey` = `FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT`; ON UPDATE NO ACTION; MATCH SIMPLE; not deferrable; validated; UNIQUE and NOT NULL unchanged |
| C-5 | O-2 untouched FK | `wanted_applications_wanted_post_id_fkey` still `ON DELETE CASCADE` |
| C-6 | O-3 columns | `collaboration_assets` ACL `…,authenticated=r/postgres`; authenticated INSERT columns exactly `asset_type,collaboration_id,description,file_name,file_size,mime_type,storage_path,title,uploaded_by` |
| C-7 | O-3 policy | WITH CHECK begins with the three original conditions verbatim and adds `(deleted_at IS NULL)`, the `split_part(storage_path, '/'::text, 1)` binding and the `length(storage_path)` minimum; SELECT policy unchanged |
| C-8 | Unrelated state | Every "unchanged" row in §2.2 matches; `public_policy_count` = 25 |
| C-9 | `public_profiles` | Unchanged (ACL, `reloptions` NULL, viewdef md5) |
| C-10 | Functions | Definitions and ACL md5 unchanged; count 34 |
| C-11 | Queue / drainer / reaper | `pending_asset_deletions` unchanged. No Edge Function redeployed: the four bundle hashes equal the recorded ones. `.github/workflows/` and `supabase/functions/` unchanged in git |
| C-12 | Migration history | 42 rows; the new row has name `backend_integrity_o1_o2_o3` |
| C-13 | File ↔ applied hash | The stored statements of the new history row, joined, equal the content of `migration.sql` sent in step 4 (md5 on both sides, LF). If the platform stores them differently (split or trimmed), **stop** and compare executable content by review before continuing |
| C-14 | Advisor | No new ERROR. `security_definer_view` still exactly 1 finding, `public.public_profiles`. Other counts equal §2.4 |

---

## 6. POST-APPLY behavioural gates

Run `behavioral-validation.sql` with synthetic fixtures filled in. Expected final output: an ERROR beginning `VALIDATION RESULTS (rolled back):` listing only PASS lines.

| Test | Observation | Expected |
|---|---|---|
| T1 | O-1 | Direct `wanted_applications` INSERT (status `accepted`) → **42501 permission denied** |
| T2 | O-1 | `create_wanted_application` → succeeds; one `pending` application and one owner notification |
| T3 | O-2 | Post owner's direct `wanted_posts` DELETE → **42501** |
| T4 / T4b | O-2 | Privileged DELETE of a post with a collaboration → **23503**; collaboration still present |
| T5 | O-2 | `transfer_collaboration_ownership` succeeds, then the former owner's DELETE → **42501** |
| T6 | O-2 | `close_own_wanted_post` → post `closed` |
| T7 | O-3 | Frontend-shaped 9-column INSERT with `RETURNING` → succeeds |
| T8 / T9 / T10 | O-3 | Explicit `id` / `created_at` / `deleted_at` (T10 without `RETURNING`) → **42501 permission denied** |
| T11 / T11b | O-3 | Path in another folder / folder-only path → **RLS violation** |
| T12 | O-3 | `delete_collaboration_asset` on the T7 row → soft-deleted and queued |

**Afterwards:**
- Re-run `catalog-fingerprint.sql`: it must be identical to the C-gates result, proving the tests left nothing behind.
- Re-check the §2.3 aggregates and queue count: unchanged.

**Optional, separately approved production smoke** (real frontend, synthetic or owner-controlled test accounts): apply to a Wanted post, accept, upload an asset, preview and download it, delete it, close a post. These are real writes and need their own approval and cleanup plan.

---

## 7. Exit criteria

The observations may be marked REMEDIATED only when:
- all C-gates and T-tests pass;
- the results are recorded here;
- the change is merged with documentation.

**Phase 21.3 may resume only after that.** Its snapshot must then be captured as a new post-remediation epoch.

---

## 8. Static review of this preparation (2026-09-16)

Nothing in this directory has been executed against any database, apart from the read-only `catalog-fingerprint.sql` and the count-only queries of §2.3.

| Check | Result |
|---|---|
| Scope | Only the six files in this directory are added; no other path changes |
| `git diff --check` | clean |
| Secrets / identifiers | No key, token, connection string, UUID, email or storage path in any file |
| Executable content | `migration.sql`: one `DO` statement with 8 DDL statements (REVOKE ×3, GRANT ×1 column-level, DROP POLICY ×2, ALTER TABLE ×1, ALTER POLICY ×1). `rollback.sql`: one `DO` statement with 9 DDL statements (REVOKE ×2, GRANT ×3, ALTER POLICY ×1, ALTER TABLE ×1, CREATE POLICY ×2). No DML and no function or table DDL in either |
| Parse (offline, PostgreSQL 17 parser via `libpg-query`) | All four `.sql` files parse. Every DDL statement in both change sections parses individually and has the intended target, privilege, role, policy command and FK `ON DELETE` action (`r` in the migration, `c` in the rollback). Block structure balanced |
| Inverse check | The rollback reverses exactly the migration's statements, in reverse order |
| Expression fidelity | Parse trees of the rollback's three policy expressions equal the trees of the verbatim captured live deparse, ignoring only the explicit `public.` qualification. The migration's new asset check keeps the original three AND terms identical and adds exactly three: `deleted_at IS NULL` and the two path conditions |
| PL/pgSQL bodies | Not parsed offline: the available parser build has no PL/pgSQL entry point. They are guarded by review and by the in-file PREFLIGHT/POSTFLIGHT; any runtime error aborts the whole `DO` statement with nothing applied |

---

## 9. Apply and validation record — 2026-09-16 (UTC)

Explicit user approval covered: applying the committed `migration.sql` once to `kbnmkyvbwkuvcklywdhk`, the rollback-only synthetic behavioural validation, read-only inspection, and this record. `rollback.sql` was **not** executed.

### 9.1 Pre-apply gates

| Gate | Result |
|---|---|
| Repository | Branch `backend-integrity-o1-o2-o3` at `2c0fb5e98a82b38aa095227f2f0be5527f4809f9` (parent `20acbe8`); equals `origin`; clean; `main` / `origin/main` unchanged at `20acbe8` |
| Migration bytes | Committed LF blob: SHA-256 `7f273f084330506cc1689f8e955902313b9d948d5645d4405ed9633003ef5221` (= §3 P-2), md5 `a98f61314fddb46e8e04cf19b00accfd`, 18,133 bytes, 0 CR |
| P-1 Target | `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.141; session user `postgres` |
| P-3 No drift | `catalog-fingerprint.sql` output identical to §2.1 and §2.2 (27 policies, 30 FKs, 34 functions, 41 migrations, latest `20260721122606`, all md5s equal) |
| P-4 / P-5 / P-6 | Review completed; explicit apply approval given |
| P-7 Fixtures | Synthetic fixtures created inside the rolled-back validation statement (§9.4); no real account used |
| P-8 Advisor | Equal to §2.4: ERROR `security_definer_view` ×1 (`public.public_profiles`), WARN ×25 and ×1, INFO ×2 |
| Row-count baseline (for §9.5) | Captured 21:51:11 UTC, counts only |

### 9.2 Apply

- **Call:** one `apply_migration` call, name `backend_integrity_o1_o2_o3`, with the committed LF content unchanged.
- **Result:** success. The in-file PREFLIGHT and POSTFLIGHT both passed; any failure would have aborted the whole statement.
- **Recorded migration:** version **`20260916215204`** (applied 2026-09-16 21:52:04 UTC).
- **Stored statements:** exactly one statement, **md5 `a98f61314fddb46e8e04cf19b00accfd`, 18,133 bytes — identical to the committed file** (C-13).
- **History:** the previous 41 rows are unchanged (fingerprint `d2f56c8198fab655bcbae00144912144` before and after).
- **Single call:** no other persistent database change was made; no statement was applied separately or retried.

### 9.3 Post-apply catalog gates

| Gate | Result |
|---|---|
| C-1 RLS | **PASS** — 17/17 enabled, 0 forced |
| C-2 O-1 | **PASS** — `wanted_applications` ACL `…,authenticated=r/postgres`; authenticated INSERT columns none; only "applicant or wanted owner can read applications" remains |
| C-3 O-2 grant | **PASS** — `wanted_posts` ACL `…,anon=r/postgres,authenticated=ar/postgres`; DELETE false; DELETE policy absent; the other three policies unchanged |
| C-4 O-2 FK | **PASS** — `FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT`; on update `a`, match `s`, not deferrable, validated; `collaborations_wanted_post_id_key UNIQUE (wanted_post_id)` and NOT NULL unchanged |
| C-5 | **PASS** — `wanted_applications_wanted_post_id_fkey` still `ON DELETE CASCADE` |
| C-6 O-3 columns | **PASS** — ACL `…,authenticated=r/postgres`; column ACLs `{authenticated=a/postgres}` on exactly `asset_type, collaboration_id, description, file_name, file_size, mime_type, storage_path, title, uploaded_by` |
| C-7 O-3 policy | **PASS** — `((uploaded_by = current_active_stagerz_user_id()) AND is_collaboration_participant(collaboration_id) AND (EXISTS (… c.status = 'active' …)) AND (deleted_at IS NULL) AND (split_part(storage_path, '/'::text, 1) = (collaboration_id)::text) AND (length(storage_path) > (length((collaboration_id)::text) + 1)))`; SELECT policy unchanged |
| C-8 Unrelated state | **PASS** — policies 25; every "unchanged" md5 in §2.2 identical |
| C-9 `public_profiles` | **PASS** — ACL, `reloptions` NULL, viewdef md5 `d86256ac…` unchanged; `users` ACL and RLS unchanged |
| C-10 Functions | **PASS** — 34; definitions md5 `04d3928e…`, ACL md5 `1e60caa4…` unchanged |
| C-11 Queue / drainer / reaper | **PASS** — `pending_asset_deletions` unchanged; the four Edge Functions keep their versions (8 / 9 / 11 / 4) and bundle hashes (`79b2fa66…`, `66f3c27a…`, `d3c3f1b5…`, `b0663090…`); no workflow or function file changed |
| C-12 History | **PASS** — 42 rows; the new row is `20260916215204 backend_integrity_o1_o2_o3` |
| C-13 File ↔ applied | **PASS** — stored statement md5 and length equal the committed file |
| C-14 Advisor | **PASS** — unchanged after apply and after validation: no new finding; `security_definer_view` still exactly 1 (`public.public_profiles`, accepted) |

### 9.4 Behavioural validation (rollback-only)

Executed with `behavioral-validation-run-2026-09-16.sql`.

**Fixtures, synthetic only.** At the start of the same statement it creates four synthetic auth users; the normal signup trigger creates their public rows. It then creates two synthetic posts, one application, and one collaboration through the real accept RPC (owner plus member). Every write ends with the statement's final exception.

**Result** (message of the final, intended exception):

| Test | Result |
|---|---|
| Fixtures | 4 synthetic users, 2 posts, 1 collaboration with 2 participants |
| T1 direct application INSERT | **PASS** — denied, 42501 |
| T2 `create_wanted_application` | **PASS** — pending application plus one owner notification |
| T3 owner DELETE of post | **PASS** — denied, 42501 |
| T4 privileged DELETE of post with collaboration | **PASS** — 23503 (FK RESTRICT) |
| T4b collaboration still present | **PASS** |
| T5 transfer, then former-owner DELETE | **PASS** — transfer succeeded; DELETE denied, 42501 |
| T6 `close_own_wanted_post` | **PASS** — post closed |
| T7 frontend-shaped asset INSERT with RETURNING | **PASS** |
| T8 explicit `id` | **PASS** — denied, 42501 |
| T9 explicit `created_at` | **PASS** — denied, 42501 |
| T10 explicit `deleted_at` (no RETURNING) | **PASS** — denied, 42501 |
| T11 foreign-folder `storage_path` | **PASS** — denied by RLS |
| T11b folder-only `storage_path` | **PASS** — denied by RLS |
| T12 `delete_collaboration_asset` | **PASS** — soft-deleted and queued |

**First attempt (also rolled back).** The first execution aborted with `22P02 malformed array literal`. The committed template appended eleven untyped string literals to the `text[]` results array; T7's own PASS line was one of them, so T7 was reported as failed and T12 hit the same defect. The abort rolled the whole statement back.

The literals were given `::text` casts. No test or expectation changed, and the rollback design was untouched. The corrected template is `behavioral-validation.sql`, and the executed copy is kept as evidence. The second execution is the result above.

### 9.5 No data left behind

Counts only, captured before validation (21:51:11) and after both executions (21:56:32).

| Relation | Before | After |
|---|---|---|
| `auth.users` / `public.users` / `user_auth_accounts` / `profiles` | 27 / 32 / 27 / 32 | 27 / 32 / 27 / 32 |
| `wanted_posts` (closed) | 25 (2) | 25 (2) |
| `wanted_applications` | 18 | 18 |
| `collaborations` / participants (owners) | 11 / 21 (11) | 11 / 21 (11) |
| messages / tasks / credits / activity | 28 / 14 / 10 / 175 | 28 / 14 / 10 / 175 |
| `collaboration_assets` / `pending_asset_deletions` / `pending_auth_deletions` | 15 / 0 / 0 | 15 / 0 / 0 |
| `notifications` | 128 | 128 |
| `storage.objects` | 13 | 13 |
| Latest `created_at` per table (including Storage) | unchanged | unchanged |
| Synthetic markers (usernames, post titles, profile names, auth metadata, asset paths) | 0 | 0 |

A compact catalog re-check after validation still shows the §9.3 state: ACLs, FK, 25 policies, the nine insert columns, function md5, 42 migrations, 17 RLS tables.

### 9.6 Evidence limitations

- **Database-level only.** Behaviour was tested in PostgreSQL with the `authenticated` role and JWT claims set exactly as PostgREST sets them. No HTTP request went through PostgREST or the API gateway, and no production UI smoke test was run.
- **Synthetic accounts only.** They were created and rolled back inside one statement; real accounts were not exercised.
- **Unchanged header.** `migration.sql` still carries its preparation-time "PREPARED, NOT APPLIED" header. The file is deliberately unchanged so that its bytes stay identical to the applied migration; this section is the authoritative status.
- **Transaction-control side effects.** Rolled-back work leaves no rows, but not every side effect is transactional; statistics counters can advance. No sequences exist in `public`.
- **Untested asset upload.** Storage uploads were not tested; the frontend upload path is covered only by the frontend-shaped metadata insert (T7).

### 9.7 Final status

| Observation | Status |
|---|---|
| **O-1** | **REMEDIATED** — applied 2026-09-16, catalog and behaviour validated |
| **O-2** | **REMEDIATED** — applied 2026-09-16, catalog and behaviour validated |
| **O-3** | **REMEDIATED** — applied 2026-09-16, catalog and behaviour validated |
| `public_profiles` Advisor item | Unchanged; accepted design |

**Not yet done:**
- merge of `backend-integrity-o1-o2-o3`;
- project-level documentation (Phase 21.3 snapshot, `PROJECT_CONTEXT.md`);
- resuming Phase 21.3.

Each needs its own approval. `rollback.sql` remains available and unexecuted.
