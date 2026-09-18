# Phase 21.3 R-5 remediation — apply and validation record, 2026-09-17 (UTC)

**Current status (after run 2): APPLIED on the test project. Catalog validation PASS. Behavioural validation PASS on run 2 (40/40). R-5 PASS.** See §11 and §12.

**Status as first recorded after run 1** (kept unchanged below, §1–§10): APPLIED on the test project. Catalog validation PASS. Behavioural validation INCOMPLETE: 38 of 40 results PASS, 2 FAIL (T15, T19).

After run 1, this record was kept as uncommitted local evidence, and no success commit was made. It is committed together with the run-2 evidence.

- **Target:** `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk` (ACTIVE_HEALTHY, PostgreSQL 17.6.1.141).
- **Repository state:**
  - branch `phase-21.3-backend-contract-resume`;
  - HEAD `4e687eeb76c827a630ad68c72f49c13ba16959ba`, parent `b0c0a49`;
  - clean tree before this file was written.
- **Authorization:** explicit product-owner approval for one apply of `migration.sql`, the P/C gates and the rollback-only behavioural run.

## 1. Repository gate — PASS

| File | SHA-256 (committed blob = working tree, LF) |
|---|---|
| `migration.sql` | `5ca16d90ae685e0da450a11de1ef16e602f73b5a5bbc1b5b1bd74e639e47033a` (36,271 bytes); header still says PREPARED, NOT APPLIED |
| `rollback.sql` | `7ac92c1d21930e072973bdfc94164f1c98acf85cdda6578bcfd26a5bf3629e95`; header still says REVIEWED ROLLBACK - NOT EXECUTED |
| `behavioral-validation.sql` | `3f1793eac24e0dff93343516d4fe88c182704eac02c849d45004522a957f09ca` |

## 2. Pre-apply gates — all PASS

| Gate | Result |
|---|---|
| P-1 | commit and hashes as above |
| P-2 | project ref and name verified immediately before apply; `edxicnafggnnvcdvxemk` not touched |
| P-3 | 42 migrations; latest `20260916215204 backend_integrity_o1_o2_o3` |
| P-4 | preflight dry evaluation `P213-R5A-PREFLIGHT-EVAL-v3`: **31/31** values equal the migration constants |
| P-5 | Security Advisor at 14:30:59Z identical to baseline: `security_definer_view` 1 ERROR (accepted), `authenticated_security_definer_function_executable` 25 WARN, `auth_leaked_password_protection` 1 WARN, `rls_enabled_no_policy` 2 INFO. Performance: `unindexed_foreign_keys` 12 INFO, `unused_index` 1 INFO. |
| P-6 | 32 profiles, 24 exact `'New Artist'` (all non-onboarded), 0 case variants, 0 blank, 0 onboarded with placeholder; the only producer is `handle_new_auth_user`; 0 metadata display names; 3 expected display-name changes |

**Pre-apply fingerprint `P213-R5A-FP-PRE` (14:30:30Z).**
- All 12 Phase 21.3 aggregate hashes **equal the `e5244a9` values**: no drift.
- Counts: 34 functions, 25 public policies, 30 FKs, 8 triggers, 67 constraints, 40 indexes, 141 columns.

## 3. Apply

- **Calls:** exactly one `apply_migration(name = 'phase21_3_r5_w1_w3_w4')` with the unchanged content of the committed `migration.sql`. Result: `success`. The migration's own preflight and postflight ran inside that transaction and passed; any failure would have raised.
- **Recorded version:** `20260917143322`, name `phase21_3_r5_w1_w3_w4`, applied 2026-09-17 ~14:33:22 UTC.
- **Stored statement:**
  - one statement of 36,271 bytes, with no CR;
  - its SHA-256 is `5ca16d90ae685e0da450a11de1ef16e602f73b5a5bbc1b5b1bd74e639e47033a`, byte-identical to the committed `migration.sql`;
  - the `rollback` array is empty.

## 4. Post-apply catalog gates

| Gate | Result | Evidence (`P213-R5A-CGATES-v2`, `P213-R5A-FP-POST`) |
|---|---|---|
| C-1 | PASS | `wanted_posts` ACL `{…,anon=r/postgres,authenticated=r/postgres}` |
| C-2 | PASS | INSERT columns exactly `user_id,title,description,role_needed,category,location,remote,compensation,status`; `id` and `created_at` not insertable; no table-level INSERT; UPDATE the 7 previous columns; SELECT all 11; no DELETE; `anon` no writes. Column ACLs `aw` ×7, `a` on `status` and `user_id`. |
| C-3 | PASS | 3 `wanted_posts` policies byte-identical (the INSERT RLS with `has_completed_onboarding` is kept) |
| C-4 | PASS | `users` UPDATE = `username` only; `first_name`, `last_name`, `photo_url`, `bio`, `location` not updatable; SELECT columns unchanged; `anon` none; relation ACL and 2 policies unchanged |
| C-5 | PASS | `profiles` (W-2): relation ACL, 9 column UPDATE grants and 2 policies unchanged |
| C-6 | PASS | `public_profiles`: kind `v`, owner `postgres`, `reloptions` NULL, ACL unchanged, no column ACLs; `anon` and `authenticated` hold SELECT only (INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER/MAINTAIN all false) |
| C-7 | PASS | columns `id uuid, username text, photo_url text, is_system boolean, created_at timestamptz, is_deleted boolean, display_name text` |
| C-8 | PASS | depends on `profiles, users`; no dependents; not auto-updatable (`NO/NO`); new pretty definition md5 `14f32be36ede54565cb69d3bd27a37fb`, SHA-256 `264abc115b84afc0640c35800f655afe04224ff280d31c140fd335f69dda45af`; contains the option A rule |
| C-9 | PASS | 32 rows = users; 0 mismatches against the option A specification; 0 rows show `'New Artist'`; 3 values changed versus the legacy rule (as predicted); 24 show `'STAGERZ Artist'`; 0 system users changed |
| C-10 | PASS | `follows` / `likes` ACL `{…,anon=r/postgres,authenticated=r/postgres}`; no INSERT/UPDATE/DELETE for `anon` or `authenticated`; SELECT kept for both; only the `… are publicly readable` policy remains on each; both tables exist; rows unchanged (0 / 0) |
| C-11 | PASS | 21 public policies (listed by name in the capture); 34 functions; RLS enabled and not forced on the 5 tables |
| C-12 | PASS | See the aggregate table below. |
| C-13 | PASS | See the reconciliation list below. |
| C-14 | PASS | Security Advisor at 14:35:40Z and Performance Advisor at 14:35:43Z identical to P-5. The `public_profiles` item is still present and still accepted. Nothing was resolved. |

**C-12 aggregates.** Unchanged sets equal `e5244a9`: functions `1abd299b…`, columns `21c9b64f…`, constraints `98350d5e…`, indexes `85a12404…`, storage policies `eee0fad6…`, triggers `62f69d51…`, function privileges `a357d806…`, default ACLs `d231ccfa…`.

The sets that changed did so exactly as intended:

| Set | New SHA-256 prefix | What changed |
|---|---|---|
| public policies | `980132a2…` | 25 → 21 |
| view | `264abc11…` | option A definition |
| table privileges | `bf9b8893…` | 393 → 388 rows: wanted_posts INSERT, follows/likes INSERT + DELETE |
| column privileges | `c8baf993…` | 39 → 43 rows: +9 wanted_posts INSERT, −5 users UPDATE |

**C-13 reconciliation.** Everything below was identical before and after the apply:
- policies excluding `follows` / `likes`;
- table privileges excluding `wanted_posts`, `follows`, `likes`;
- column privileges excluding `wanted_posts` and `users`;
- effective `anon` / `authenticated` privileges on every other relation;
- RLS state;
- function security (SECURITY DEFINER, config, owner);
- trigger enabled states and event triggers;
- Realtime publication membership and publication flags;
- bucket configuration, extensions, schema privileges, API role settings and attributes;
- O-1 (no `wanted_applications` INSERT, SELECT policy only), O-2 (no DELETE, FK `ON DELETE RESTRICT`), O-3 (9 INSERT columns, path-bound WITH CHECK);
- the S-state checks: `public_profiles` not writable, no test tables, no API-role MAINTAIN on `public`, `log_*` executable only by `postgres` / `service_role`, both deletion queues with RLS on, no policies and no API-role access, postgres default-ACL grantees unchanged.

Edge Functions were unchanged (read-only `list_edge_functions` before and after):

| Function | Version | `ezbr_sha256` prefix |
|---|---|---|
| `delete-account` | v8 | `79b2fa66…` |
| `process-pending-deletions` | v9 | `66f3c27a…` |
| `process-pending-asset-deletions` | v11 | `d3c3f1b5…` |
| `reap-orphaned-collaboration-assets` | v4 | `b0663090…` |

**Row fingerprints.** Row count and row-content hash of all 21 tables (17 `public`, `auth.users`, `auth.identities`, `storage.buckets`, `storage.objects`) are identical before and after the apply. The apply changed no data.

## 5. Behavioural validation — run 1 (rollback-only)

**How it ran.** `behavioral-validation.sql` was executed once, verbatim; the sent text equals the committed file, SHA-256 `3f1793ea…09ca`.
- The statement ended with the intended `P0001 VALIDATION RESULTS (rolled back)`, so nothing was committed.
- Results (labels only, no identifiers): **38 of 40 PASS, 2 FAIL** (fixture setup plus T1–T12, T13-1 to T13-12 and T14–T28).

| Result | Tests |
|---|---|
| **PASS** | FIXTURES; T1–T4 (W-1); T5 (W-2); T6, T7–T11 (W-3 users); T12; T13-1 to T13-12 (decision cases A–G: anonymized, genuine trimmed, exact / space-padded / tab-and-newline-padded placeholder, empty, whitespace-only, placeholder + NULL / blank username, anonymized precedence, NULL name, NULL name + NULL username); T14 (real signup placeholder hidden); T16 (Edit Profile placeholder → username); T17 (anon: exactly 7 keys, 1 row per user); T18 (anon cannot read `users`); T20 (RLS hides other users' rows); T21–T24 (follow / like INSERT / DELETE denied); T25 (follows / likes readable by authenticated and anon); T26–T28 (O-1 / O-2 / O-3 still denied) |
| **FAIL** | **T15** "non-placeholder name suppressed"; **T19** "unexpected 55000" |

### 5.1 Root cause of the two failures — test-template defects, not backend defects

**T15 — fixture ordering defect.**
- T13 cases 11 and 12 delete fixture B's `profiles` row (template lines 269–270), and the loop only restores `username` and `anonymized_at` (line 285).
- T15 then runs `update public.profiles … where user_id = b_user` (lines 310 and 313), which affects **0 rows**. `public_profiles` therefore correctly shows B's username (the NULL-name fallback), and the test's expectation of `new artist` / `New Artist Collective` fails.
- T15 never exercised the case-sensitivity rule. That rule was verified before apply only against the identical expression on synthetic literals (`P213-R5F-EXPR-v1`, 18/18: `new artist`, `NEW ARTIST` and `New Artist Collective` are kept). The deployed view's CASE is that same expression. **The case-sensitivity rule has not yet been proven on the live view by a passing behavioural test.**

**T19 — wrong expected SQLSTATE.**
- After W-3, `public_profiles` is a join view and therefore not auto-updatable (C-8, `NO/NO`, intended and asserted by the migration postflight).
- PostgreSQL rejects `UPDATE public_profiles` while rewriting the query, with `55000` (object not in prerequisite state, "cannot update view"). The privilege check that would give `42501` never runs.
- The template accepted only `42501`. The security property still holds, since the write was denied and `authenticated` has no UPDATE privilege on the view (C-6). The test's exact expectation is wrong for the new view shape.

**No backend change, no rollback and no re-run were made**, as the task's failure rule requires.

## 6. Cleanup proof — PASS (`P213-R5A-CLEANUP-v1`, 14:37:57Z)

- **Residue counts:** 0 for each of:
  - users named `zz_r5_validation%`;
  - profiles with test display names;
  - auth users with test metadata;
  - test wanted posts;
  - follows and likes (0 total, as before);
  - legacy test names;
  - anonymized users.
- **Row fingerprints:** all 21 table fingerprints equal the pre-apply and post-apply values, covering auth users and identities, Storage buckets and objects, and both deletion queues (0 / 0).

## 7. Migration history — PASS

- 43 migrations.
- The first 42 have an unchanged fingerprint `a987da85…ada3`.
- Exactly one new migration was added: `20260917143322 phase21_3_r5_w1_w3_w4`, which is also the latest. Its stored statement equals the committed file.
- No rollback or repair migration exists.

## 8. R-5 re-evaluation (after run 1; superseded by §12)

- **W-1:** no longer wider. INSERT is limited to the 9 frontend columns; `id` and `created_at` are refused (C-2, T2, T3).
- **W-2:** reviewed, intentional, non-material dormant width. Unchanged (C-5, T5).
- **W-3:** matches the product contract. Only `username` is updatable; the view follows the profile-centred option A rule (C-4, C-8, C-9, T6–T14, T16).
- **W-4:** no unused direct write capability remains (C-10, T21–T24, T25).

**Verdict: R-5 is NOT recorded as PASS (formally FAIL / pending).** The catalog evidence and every write-width test support the R-5 rule. However, the approved validation plan requires T1–T28 all PASS, and two tests failed through template defects (§5.1). The case-sensitivity rule (T15) has not been proven on the live view, and T19's pass condition needs correcting.

## 9. Phase 21.3 status (after run 1; step 1 completed in §11)

INCOMPLETE. No other substantive backend blocker was found. Remaining:
1. Under a new approval: correct `behavioral-validation.sql`.
   - T15: re-create or use a fixture that still has a profile row.
   - T19: accept `55000` (not auto-updatable) or `42501` as denial, and assert the view is not updatable.
   - Commit the fix, then run it once more, rollback-only.
2. Record the apply and validation in `validation.md`, then commit that evidence.
3. Regenerate the six Phase 21.3 snapshots for epoch `20260917143322`, re-run the fingerprints, and record R-5.
4. Update the Phase 21.3 documentation and `.apos/PROJECT_CONTEXT.md`.

## 10. Mutations performed (apply and run 1)

- The one authorized `apply_migration`.
- One rollback-only behavioural statement, whose synthetic writes were all rolled back.

Nothing else. In particular:
- `rollback.sql` was not executed;
- there was no second migration, no repair SQL and no other mutating SQL;
- there was no Storage, Edge Function, secret, Advisor-resolve, deployment, workflow, push, PR, merge or branch action.

---

## 11. Behavioural validation — run 2 (corrected template, rollback-only), 2026-09-17 ~17:30 UTC

**Authorization.** Explicit product-owner approval to correct only T15 and T19 and to run the corrected template exactly once. No backend change was authorized, and none was made.

**Pre-retest state (`P213-R5B-STATE-PRE`, 17:29:06Z).**
- **Target:** `get_project` returned `kbnmkyvbwkuvcklywdhk` / `stagerz-foundation-v2-test`, ACTIVE_HEALTHY.
- **Migrations:** 43; latest `20260917143322 phase21_3_r5_w1_w3_w4`; stored statement SHA-256 still `5ca16d90…033a`.
- **Counts:** 21 public policies; 34 functions; functions aggregate `1abd299b…` unchanged.
- **W state as validated:**
  - W-1: 9 INSERT columns; policies unchanged.
  - W-2: `profiles` grants and policies unchanged.
  - W-3: `users` UPDATE = `username`; view md5 `14f32be3…`, owner `postgres`, `reloptions` NULL, `NO/NO`.
  - W-4: `follows` / `likes` `authenticated=r`, read policies only.
- **Row fingerprints:** all 21 tables equal the run-1 post-apply capture.
- **Drift:** none.

**Template correction** (diff limited to T15, T19 and a header change note):

| Test | Run 1 (template `3f1793ea…09ca`) | Run 2 (template `9bccf38f…2f44`) |
|---|---|---|
| T15 | updated fixture B, whose profile row T13 had deleted: 0 rows affected, rule not exercised | updates fixture N (profile row never removed), requires each UPDATE to affect exactly 1 row, and checks the live view for `new artist` and `New Artist Collective`. Suppression would show `'STAGERZ Artist'` (N has no username) and FAIL. |
| T19 | accepted only `42501` | accepts only `55000` with message `cannot update view…` (join view not auto-updatable; raised during rewrite) or `42501` with `permission denied…`. A successful UPDATE still records FAIL; any other error is FAIL. |

**Static validation before the run.**
- The file parses: one `DoStmt`; the PL/pgSQL body parses; 169/169 embedded statements parse.
- The PASS/FAIL label inventory is identical to the committed version, so no test was removed or renamed.
- No COMMIT. The final unconditional `raise exception` is the last statement of the outer block, which has no handler, so rollback is forced.
- No identifiers or secrets; LF only; ASCII only; 28,510 bytes.

**Execution.** Exactly one `execute_sql`. The text sent is byte-identical to the corrected file (SHA-256 `9bccf38fbc7d6064a9ac9442b227c2549566e8d2825039a8b6ea33e6d2ba2f44`), verified from the session transcript. The statement ended with the intended `P0001 VALIDATION RESULTS (rolled back)`.

**Results: 40 of 40 PASS.**

| Group | Result |
|---|---|
| FIXTURES | PASS |
| T1–T4 (W-1: frontend-shaped insert; explicit `id` / `created_at` denied; non-onboarded refused) | PASS |
| T5 (W-2: Edit Profile save) | PASS |
| T6–T12 (W-3: `username` update; 5 legacy columns denied; name from `profiles`) | PASS |
| T13-1 to T13-12 (decision cases A–G) | PASS |
| T14 (signup placeholder hidden) | PASS |
| **T15** | **PASS**: "case variant and longer names are shown as chosen" |
| T16 (Edit Profile placeholder → username) | PASS |
| T17, T18, T20 (anon sees 7 keys; anon cannot read `users`; RLS hides other users) | PASS |
| **T19** | **PASS**: "public_profiles is not writable by authenticated (55000)" |
| T21–T24 (follow / like INSERT and DELETE denied) | PASS |
| T25 (follows / likes readable by authenticated and anon) | PASS |
| T26–T28 (O-1 / O-2 / O-3 still denied) | PASS |

**Cleanup and backend proof (`P213-R5B-STATE-POST`, 17:32:13Z).**
- Every item of the pre-retest capture is identical after the run: migrations, stored statement, counts, functions aggregate, W-1..W-4 catalog state, and the row fingerprints of all 21 tables (including auth users and identities, Storage buckets and objects, and both deletion queues).
- Residue counts are all 0: test usernames, test profile names, test auth metadata, test posts, follows (0), likes (0), legacy test names, anonymized users, and users without a profile.

**Security Advisor (17:32:17Z).** Identical to the baseline: 1 ERROR (accepted `public_profiles`), 25 WARN, 1 WARN, 2 INFO. Nothing was resolved.

## 12. Final R-5 result — PASS

All exit criteria in `validation.md` §9 hold:
- P-1 to P-6 pass;
- the apply succeeded, with a verified stored-statement hash;
- C-1 to C-14 pass;
- T1–T28, including T13-1 to T13-12, pass (run 2) with no data left behind;
- the apply record is documented.

| Finding | Status |
|---|---|
| W-1 | remediated |
| W-2 | reviewed; intentional, non-material dormant width |
| W-3 | remediated (profile-centred, option A) |
| W-4 | remediated |

**Phase 21.3 remains INCOMPLETE** until, under separate approvals:
- the six snapshots are regenerated for epoch `20260917143322` and the fingerprints re-run;
- R-5 is recorded in the Phase 21.3 documents;
- the documentation and `PROJECT_CONTEXT` are closed.

## 13. Mutations performed (run 2)

- One rollback-only behavioural `execute_sql`; all of its synthetic writes were rolled back (§11).
- Nothing else:
  - no `apply_migration`, no migration, no `rollback.sql`;
  - no backend repair or change, no other mutating SQL;
  - no Storage, Edge Function, secret, Advisor-resolve, deployment or workflow action;
  - no push, PR, merge or branch action.
