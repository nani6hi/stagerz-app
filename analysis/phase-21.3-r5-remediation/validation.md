# Phase 21.3 R-5 remediation (W-1 / W-3 / W-4) — Validation Plan

**Status:** PREPARED — NOT APPLIED. Nothing in this document has been executed against a database except the read-only captures listed in §2 and the static review in §8.
**Target:** `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk` only.
**Scripts:**
- `migration.sql` — SHA-256 `95ea14d93c60736211544df7dd20dce7ee4c9d11163a08226f5f3882d2a46388`.
- `rollback.sql` — SHA-256 `d6a1bf13643b1e97ae763fc9b1096db5f2c10094243deec5ab3cf5eb7c6eee82`; not executed.
- `behavioral-validation.sql` — SHA-256 `5ca0648a05ec141cdfb5e5b47fad9fb5103574ed05f4ef173cdaf63e14efaba7`; not run.

---

## 1. Principles

- **Read-only until approved.** Before an explicit apply approval, only catalog reads and aggregate counts are allowed. No DDL, DML, `apply_migration`, Storage or Edge Function call, secret access or Advisor action.
- **Fail closed.** The migration and the rollback each verify their exact starting state and their exact result inside one atomic statement.
- **Behavioural checks are rollback-only.** They use synthetic fixtures created inside the same statement, which always ends by raising.
- **Nothing identifying is printed.** Reports contain no row data, user IDs, emails, filenames, storage paths, JWTs, keys or secrets. Schema identifiers are allowed.
- **Accepted design stays accepted.** The `public_profiles` `security_definer_view` Advisor item is never resolved from this workflow and is never called remediated.

## 2. Pre-apply baseline — captured read-only, 2026-09-17 (UTC)

Captures (marked read-only SELECTs):
- `P213-R5R-STATE-v1` — 00:16:29Z;
- `P213-R5R-FN-v1`, `P213-R5R-REF-v1`, `P213-R5R-DEPARSE-v1`;
- `P213-R5R-PREFLIGHT-EVAL-v1` — every migration preflight expression evaluated live.

The Security Advisor was read at 00:30:01Z.

### 2.1 Drift check against the R-5 decision report / `e5244a9`

| Item | Result |
|---|---|
| Migration epoch | 42 migrations, latest `20260916215204`: **unchanged** |
| Public policies / public functions | 25 / 34: **unchanged** |
| `wanted_posts`, `users`, `profiles`, `follows`, `likes`: relation ACLs, column ACLs, policies (name, command, permissive, roles, USING, WITH CHECK), RLS enabled / not forced, columns, defaults, constraints, no triggers | **identical** to the R-5 decision report |
| `public_profiles` | owner `postgres`, `reloptions` NULL, ACL `anon=r`/`authenticated=r` (+ owner, `service_role`), 7 columns / types, depends only on `users`, pretty-definition md5 `d86256ac1ad53a250c96c315ed69a52e`, auto-updatable `YES/YES`: **identical** |
| O-1 / O-2 / O-3 state | `wanted_applications` and `collaboration_assets` relation ACL `authenticated=r`; FK `ON DELETE RESTRICT`; 9 `collaboration_assets` INSERT columns: **intact** |
| Unexplained drift | **none** |

Scope of the check: the whole-schema aggregate fingerprints of `e5244a9` were **not** recomputed in this task. The epoch and object counts are unchanged, and every object the migration touches or asserts was compared exactly.

### 2.2 Mechanical preflight check

Two scratch tools, not committed, checked the migration's constants:
- One parsed the 24 text constants out of `migration.sql`.
- The other compared them with `P213-R5R-PREFLIGHT-EVAL-v1`.

Results:
- **All 18 baseline constants and 6 structural checks match the live catalog.** The structural checks are: no column ACLs on `follows`/`likes`/`public_profiles`, RLS state, view metadata, view dependencies `users`, no dependents, and join safety.
- **All 7 post-change constants** (`*_after`, `c_wp_insert_cols`) derive exactly from the baseline plus only the intended edits.
- **All 21 `rollback.sql` constants** equal the corresponding migration constants: `*_now` = migration `*_after`, and `*_before` = migration `*_before`.

### 2.3 Dependency and consumer evidence

**Database:**
- `public_profiles` has no dependent view or rule, and no publication membership.
- No function body contains the literal `public_profiles`.
- Its own `pg_depend` rows are only its rewrite rule and row type.

**Repository:**
- `supabase/functions/**` references none of `public_profiles`, `follows`, `likes`, `users` name/photo columns or `wanted_posts`.

**`index.html`** (unchanged):

| Area | What the page does |
|---|---|
| `wanted_posts` | inserts exactly the 9 granted columns, with `status:'open'` |
| `users` | the only client write is `{username}`; `fetchMyProfile` still reads the legacy columns, and SELECT is kept |
| `profiles` | written with `{display_name, role, location, bio, skills}`; `saveProfile` rejects an empty display name and an invalid or missing username |
| `public_profiles` | 6 SELECT call sites; every renderer falls back to `'STAGERZ Artist'` on an empty `display_name` |
| `follows` / `likes` | no writes |
| signup | `signInWithOtp` sends no user metadata, so every new profile starts as `'New Artist'` |
| onboarding | `has_completed_onboarding` = `username IS NOT NULL` |

### 2.4 Aggregate data baseline (counts only)

| Count | Value |
|---|---|
| `users` | 32 |
| users without profile / profiles without user | 0 / 0 |
| profiles with blank `display_name` | 0 |
| profiles with `'New Artist'` | 24, all of them non-onboarded users (onboarded with placeholder: 0) |
| users with NULL `username` | 24 |
| users with `first_name` or `last_name` | 5 |
| users with `photo_url` | 0 |
| anonymized users | 0 |
| `display_name` values that the new view would change | 27 (24 → `'New Artist'`, 3 → the chosen profile name) |
| system users affected | 0 |

### 2.5 Security Advisor baseline — 2026-09-17 00:30 UTC (identical to 2026-09-15)

| Lint | Level | Count |
|---|---|---|
| `security_definer_view` (`public.public_profiles`) | ERROR | 1 — **accepted Phase 21.4 design** |
| `authenticated_security_definer_function_executable` | WARN | 25 |
| `auth_leaked_password_protection` | WARN | 1 |
| `rls_enabled_no_policy` (`pending_asset_deletions`, `pending_auth_deletions`) | INFO | 2 |

## 3. PRE-APPLY gates (at apply time, all read-only)

| Gate | Check | Pass condition |
|---|---|---|
| P-1 | Branch / commit | the reviewed commit is checked out; `migration.sql` SHA-256 equals the value above |
| P-2 | Project | `get_project` on `kbnmkyvbwkuvcklywdhk` = `stagerz-foundation-v2-test`, healthy. Never `edxicnafggnnvcdvxemk`. |
| P-3 | Epoch | still 42 migrations, latest `20260916215204`; otherwise stop and re-review |
| P-4 | Preflight dry evaluation | re-run the `P213-R5R-PREFLIGHT-EVAL` query (§2); all values equal the migration constants |
| P-5 | Advisor | equals §2.5 |
| P-6 | Counts | §2.4 re-captured; any change is explained before apply |

## 4. Apply procedure (for the later, approved step)

1. One `apply_migration` call with the unchanged content of `migration.sql`, under a descriptive name such as `phase21_3_r5_w1_w3_w4`.
2. **On error:** the statement has rolled back entirely. Record the message, re-run P-4, and **stop**. Do not retry with edits, and do not run `rollback.sql`.
3. **On success:** read `supabase_migrations.schema_migrations` for the new version and verify that `statements[1]` hashes to the `migration.sql` SHA-256, computed server-side with `encode(sha256(convert_to(x,'UTF8')),'hex')`.

## 5. POST-APPLY catalog gates (read-only)

The migration's own postflight already enforces C-1 to C-11 inside the transaction. They are re-checked independently afterwards.

| Gate | Check | Expected |
|---|---|---|
| C-1 | `wanted_posts` relation ACL | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}` |
| C-2 | `wanted_posts` column privileges for `authenticated` | INSERT = `user_id,title,description,role_needed,category,location,remote,compensation,status`; UPDATE = the 7 previous columns; SELECT on all; no DELETE |
| C-3 | `wanted_posts` policies | 3, byte-identical to the baseline |
| C-4 | `users` column privileges for `authenticated` | UPDATE = `username` only; SELECT = `id,username,first_name,last_name,photo_url,bio,location`; `anon` none; relation ACL and 2 policies unchanged |
| C-5 | `profiles` (W-2) | relation ACL, 9 column UPDATE grants and 2 policies unchanged |
| C-6 | `public_profiles` security | `relkind='v'`, owner `postgres`, `reloptions` NULL, ACL unchanged, no column ACLs; `anon` and `authenticated` hold SELECT only |
| C-7 | `public_profiles` shape | columns `id uuid, username text, photo_url text, is_system boolean, created_at timestamptz, is_deleted boolean, display_name text` in this order |
| C-8 | `public_profiles` definition | depends on exactly `profiles` and `users`; no `first_name` / `last_name`; contains `LEFT JOIN profiles p ON p.user_id = u.id`; not auto-updatable. **Record** the new pretty-definition md5 and SHA-256 for the snapshot. |
| C-9 | `public_profiles` rows (counts only) | row count = `users` count; 0 rows differ from the specification; `display_name` change count equals §2.4 (27), unless P-6 explained a difference |
| C-10 | `follows`, `likes` | relation ACL `…,anon=r/postgres,authenticated=r/postgres`; only the `… are publicly readable` policy remains on each; row counts unchanged |
| C-11 | Global counts | 21 public policies (25 − 4); 34 functions; RLS enabled and not forced on the 5 tables |
| C-12 | Untouched object sets | Regenerated Phase 21.3 aggregates (§6 of the Phase 21.3 method) for **functions, storage policies, triggers, constraints, indexes, columns, function privileges and default ACLs** equal the `e5244a9` values (§5.1). The only sets that change are **public policies, the view, table privileges and column privileges**, and exactly as described here. |
| C-13 | O-1 / O-2 / O-3 and S-1..S-8 | O-state as in §2.1; the Phase 21.3 S-1..S-6 checks still PASS; S-7 and S-8 objects (Storage policies, Edge Function set and settings) unchanged by the C-12 aggregates and a read-only `list_edge_functions` |
| C-14 | Security Advisor | identical to §2.5 (same lints, levels and counts; the `public_profiles` item still present and still accepted). Any new item is a failure. Nothing is resolved. |

### 5.1 `e5244a9` aggregates to compare (C-12)

| Object set | Expected after apply | SHA-256 at `e5244a9` |
|---|---|---|
| Functions (34) | unchanged | `1abd299b5e3f39bd5919e522357f2d8e17522ff87421f4560c6bf79c03588d43` |
| Storage policies | unchanged | `eee0fad6695c94ba20688da0a3bcba6009a59760ab9008b8fe2d522c8810536d` |
| Triggers | unchanged | `62f69d51ba813ccbc6743cfc9af1f9b79255c9c8a77c14af6f7585d1b50806eb` |
| Constraints | unchanged | `98350d5e1189c1588d566f6976f61a0f17f8f00f56e27100b181f4717da1f2ac` |
| Indexes | unchanged | `85a1240403166bd7fc4afcdab2dd263e33b7ce30dc7577363f204020dab992bb` |
| Columns | unchanged | `21c9b64ff9a598b8e37ae19d36adae8f84ac3eb0a5e6a219459495d462d0bf61` |
| Function privileges | unchanged | `a357d8063de20cc086bddb6a9977d0ed10fc9cd329e714193b1825e9dd16d520` |
| Default ACLs | unchanged | `d231ccfaa157897c13e9b66980ba8298de51e36637caddc37473e643480f4def` |
| Public policies | **changes** (25 → 21) | `d16c3e415c8163fadce6fa91f0996baf41b9f6a80e3613ed407f9b7205311163` |
| View | **changes** | `f0651e4d89598ebcb4876a1267fefe5f8ca61c66f10ba1b46fb08aa45bf18706` |
| Table privileges | **changes** (W-1, W-4) | `7b785fb172a68861f02ccdce9a7f1e82ede7a4054f4c9a08cd9493a9a00b0155` |
| Column privileges | **changes** (W-1, W-3) | `fc922a1f19525b146d72745f21437ae25193c50918963be72ffd1b5f12aadece` |

## 6. POST-APPLY behavioural gates (rollback-only)

`behavioral-validation.sql` is run once, with explicit approval, **after** a successful apply.

- **Fixtures:** it creates three synthetic auth users through the normal signup trigger, plus one privileged follow and one privileged like, all inside the statement.
- **Expected output:** an ERROR whose message starts with `VALIDATION RESULTS (rolled back)` and lists `FIXTURES …` and T1–T28, **all PASS**.
- **Afterwards:** read-only counts must show that no synthetic user, profile, post, follow or like remains. Record only counts.

| Test | Area | Scenario | Expected |
|---|---|---|---|
| T1 | W-1 | onboarded user inserts a frontend-shaped post (9 columns, `RETURNING id`) | succeeds |
| T2 | W-1 | insert with explicit `id` | `42501` permission denied |
| T3 | W-1 | insert with explicit `created_at` | `42501` permission denied |
| T4 | W-1 regression | non-onboarded user inserts a post | `42501` RLS violation |
| T5 | W-2 unchanged + W-3 | Edit Profile update (`display_name, role, location, bio, skills`) | 1 row updated; `public_profiles.display_name` shows the new name |
| T6 | W-3 | `username` update | 1 row updated; visible in `public_profiles` |
| T7–T11 | W-3 | update `users.first_name`, `last_name`, `photo_url`, `bio`, `location` | each `42501` permission denied |
| T12 | W-3 | legacy first/last name present (privileged) | `display_name` still from `profiles` |
| T13 | W-3 | blank (whitespace) profile `display_name` | falls back to `username` |
| T14 | W-3 | empty `display_name` and NULL `username` | `'STAGERZ Artist'` |
| T15 | W-3 | padded `display_name` | trimmed |
| T16 | W-3 | anonymized user | `'Deleted User'`, `is_deleted = true` |
| T17 | W-3 no new exposure | `anon` reads the view | exactly the 7 public keys; one row per user |
| T18 | W-3 no new exposure | `anon` reads `users` | `42501` |
| T19 | W-3 | `authenticated` updates `public_profiles` | `42501` |
| T20 | W-3 | `authenticated` reads another user's `users` row | 0 rows (RLS) |
| T21–T24 | W-4 | follow INSERT, follow DELETE, like INSERT, like DELETE | each `42501` permission denied |
| T25 | W-4 | `authenticated` and `anon` read the privileged follow and like | visible to both (4 of 4) |
| T26–T28 | Global | direct `wanted_applications` INSERT (O-1), `wanted_posts` DELETE (O-2), `collaboration_assets` INSERT with explicit `id` (O-3) | each still `42501` |

**W-2** is covered by T5 (the Edit Profile write still works) together with C-5 (its grants and policies are byte-identical). No W-2 behaviour changes.

**Frontend smoke (optional, separately approved; no code change).** Walk through, in order:
1. Edit Profile save;
2. create a wanted post;
3. open an artist profile;
4. use collaboration invite search.

Expected: the chosen display name appears everywhere `public_profiles` is shown.

## 7. Rollback validation (only if a rollback is separately approved)

1. Pre-run: `rollback.sql`'s own preflight requires exactly the post-migration state (C-1 to C-11).
2. After it succeeds, all of the following equal the §2 baseline:
   - relation and column ACLs;
   - policies (25);
   - `public_profiles` pretty-definition md5 `d86256ac1ad53a250c96c315ed69a52e`, dependencies `{users}`, updatability `YES/YES`, owner, ACL and `reloptions`;
   - the §5.1 aggregates, which all equal the `e5244a9` values again.
3. Advisor equals §2.5.

## 8. Static review of this preparation (2026-09-17)

| Check | Result |
|---|---|
| Top-level parse (`@libpg-query/parser@17`, PostgreSQL 17 grammar) | each file is exactly one `DoStmt` |
| PL/pgSQL parse of each DO body (`parsePlPgSQL`) | OK for all three |
| Embedded SQL / expressions parsed individually | migration 91/91, rollback 67/67, behavioural 148/148 |
| DDL inventory, migration | `revoke insert` (`wanted_posts`), `grant insert (9 cols)`, `revoke update (5 cols)` (`users`), `create or replace view public.public_profiles`, `revoke insert, delete` (`follows`, `likes`), 4× `drop policy`; **nothing else** |
| DDL inventory, rollback | exact inverses: `revoke insert (9 cols)`, `grant insert`, `grant update (5 cols)`, original view, `grant insert, delete`, 4× `create policy` |
| Forbidden content | no `drop table` / `drop column` / `alter table`, no DML outside the postflight counts (migration / rollback), no `storage.` object, no function / trigger DDL, no `security_invoker` / `WITH (…)`, no `ALTER … OWNER`, no secrets, no project URLs, no user identifiers |
| Preflight constants vs live | all match (§2.2) |
| Rollback view text vs live definition | same raw parse tree (locations / schema qualification ignored) as the live pretty definition, so the md5 postflight is expected to pass |
| Postflight join deparse | PostgreSQL 17 pretty deparse of a join qual confirmed on system views as `LEFT JOIN <rel> <alias> ON <qual>` without parentheses |
| New view normalized (offline deparse) | `SELECT u.id, u.username, u.photo_url, u.is_system, u.created_at, u.anonymized_at IS NOT NULL AS is_deleted, CASE WHEN u.anonymized_at IS NOT NULL THEN 'Deleted User'::text WHEN NULLIF(btrim(p.display_name), ''::text) IS NOT NULL THEN btrim(p.display_name) ELSE COALESCE(u.username, 'STAGERZ Artist'::text) END AS display_name FROM public.users u LEFT JOIN public.profiles p ON p.user_id = u.id` |
| Line endings | LF only, no CR, in all files |

**Not verifiable offline** (checked at apply time by the scripts themselves, fail-closed):
- the server's exact aclitem rendering for the new column grants (`aw`, `a`);
- the server's deparse of the rollback view (its md5).

A mismatch aborts the statement with no change.

## 9. Exit criteria

R-5 remediation is **complete** only when all of the following hold:
- P-1 to P-6 pass;
- the apply succeeds, with a verified stored-statement hash;
- C-1 to C-14 pass;
- T1 to T28 pass, with no data left behind;
- the apply record is documented.

Then Phase 21.3 can regenerate its snapshot and re-evaluate R-5, with W-1, W-3 and W-4 remediated and W-2 accepted as reviewed and non-material. Until then, **R-5 remains FAIL** and Phase 21.3 remains **INCOMPLETE**.
