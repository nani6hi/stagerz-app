# Phase 22.3 — Baseline Inventory (production backend `kbnmkyvbwkuvcklywdhk`)

**Captured:** 2026-09-19, read-only.
- Markers: `P223-DDL-REL-v1` (19:19:38 UTC), `P223-DDL-FN-v1` (19:19:51), `P223-DDL-SEC-v1` (19:20:12), `P223-CHECKS-v1`, `STAGERZ-FINGERPRINT-v1`.
- Edge Function sources via `get_edge_function`.

**Epoch:** PostgreSQL 17.6; migration history 43 rows, latest `20260917143322`, which is unchanged since the Phase 21.3 close.

**Drift check against Phase 21.3 (same epoch):** 34/34 function definitions and 23/23 policies are byte-identical.

**Privacy:** object names, definitions and counts only. No row content, user identifiers, e-mails or secrets. The migration history's `created_by` column holds an account identifier, which was deliberately **not** recorded.

---

## A. Database reproducibility

### A.1 Schemas

| Schema | Owner | Class |
|---|---|---|
| `public` | `pg_database_owner` | **Application**: all STAGERZ objects |
| `auth`, `storage`, `realtime`, `vault`, `graphql`, `graphql_public` | `supabase_admin` | Platform (the application attaches 1 trigger to `auth.users`, 1 bucket row and 2 policies to `storage`) |
| `extensions` | `postgres` | Platform-provided extension schema |
| `pgbouncer` | `pgbouncer` | Platform |
| `supabase_migrations` | `postgres` | Platform CLI bookkeeping (migration history) |

**A.4 / A.10 / others:**
- no materialized views, sequences, identity columns, generated columns, user-defined types, rules, column collations, or table/column comments;
- 1 function comment (`current_stagerz_user_id`);
- replica identity is default everywhere.

**A.5 Column defaults (distinct kinds):** `gen_random_uuid()`, `now()`, literal text/jsonb/text[]/numeric/boolean/integer constants. None calls an application function, so there are no ordering hazards.

**A.20 Extensions:**
- **required by the app** (and created by the baseline): `pgcrypto`, `uuid-ossp` (schema `extensions`);
- **platform-provided:** `pg_stat_statements`, `supabase_vault`, `plpgsql`;
- **not installed:** `pg_cron`, `pg_net`.

**A.21 Realtime:**
- `supabase_realtime` (platform-created, `all_tables = false`) has 5 application members: `collaboration_activity`, `collaboration_assets`, `collaboration_credits`, `collaboration_messages`, `collaboration_tasks` — whole tables, no column lists or row filters;
- `supabase_realtime_messages_publication` (daily `realtime.messages_*` partitions) is platform-managed.

**Totals:**
- 18 relations (17 tables, 1 view), 141 columns;
- constraints: 17 PK, 30 FK, 9 UNIQUE, 11 CHECK, 0 exclusion;
- 14 indexes not backed by constraints;
- 34 functions;
- 4 application triggers (3 `public`, 1 `auth.users`);
- 23 policies (21 `public`, 2 `storage.objects`);
- 18 relation ACLs and 43 column-privilege entries (3 grantees/privilege kinds);
- 24 default-ACL entries (6 owned by `postgres` in `public`/`storage`).
- **Every object ACL is explicit** (no NULL/default ACL), and every grantor is `postgres`. There are no grantable (`WITH GRANT OPTION`) grants.

### Reproduce vs do-not-recreate

| Must be reproduced (application-owned) | Must NOT be recreated manually (platform-managed) |
|---|---|
| 17 tables, 1 view (`public_profiles`, no `security_invoker`: the accepted S-1 design), constraints, 14 extra indexes | Schemas `auth`, `storage`, `realtime`, `vault`, `graphql*`, `extensions`, `pgbouncer`, `supabase_migrations` and their objects |
| 34 functions and their EXECUTE ACLs (S-7/R-5 revocations included) | Platform event triggers `pgrst_ddl_watch`, `pgrst_drop_watch`, `issue_graphql_placeholder`, `issue_pg_cron_access`, `issue_pg_graphql_access`, `issue_pg_net_access` |
| 3 `public` triggers and `on_auth_user_created` on `auth.users` | 4 Storage-internal triggers (`enforce_bucket_name_length_trigger`, `protect_buckets_delete`, `protect_objects_delete`, `update_objects_updated_at`) |
| RLS on all 17 tables, 21 `public` and 2 `storage.objects` policies | The publications themselves; `realtime.messages` partitions |
| Table and column grants (S-1, S-2, S-6 state) and the 4 `postgres` TABLE/SEQUENCE default ACLs (S-5 state) | Role settings (`statement_timeout` etc.), `supabase_admin` / `supabase_auth_admin` default ACLs, `postgres` FUNCTIONS default ACLs (left at platform default, as in production) |
| Bucket `collaboration-assets` (private, no limits); Realtime membership (5 tables); extensions `pgcrypto`, `uuid-ossp` | `pg_stat_statements`, `supabase_vault`, `plpgsql` |
| — | **Data** of every kind (rows, Auth users, Storage objects), which is never in the baseline |


---

## B. Migration history

| Finding | Evidence |
|---|---|
| 43 rows, `20260712100630` … `20260917143322` | `supabase_migrations.schema_migrations` |
| **All 43 rows store their SQL** (`statements` populated; 1 statement array each; ~238 KB total) and have `rollback` empty | `P223-DDL-SEC-v1` (counts, byte sizes and md5 only; statement text not copied) |
| Represented as SQL in the repo: **2 of 43** (`20260916215204` = `analysis/backend-integrity-remediation/migration.sql`; `20260917143322` = `analysis/phase-21.3-r5-remediation/migration.sql`) | Repo survey |
| Only in Supabase history: **41** (`web_identity_forward_and_rls` … `phase_19_1_enable_realtime_publication`) | as above |
| The first migration creates 8 tables from scratch (no reliance on pre-existing application tables detected) and contains 4 INSERTs; `web_identity_seed` contains 3 INSERTs (the fictional showcase data) | `P223-CHECKS-v1` (keyword counts only) |
| **Applied outside the migration history** (via `execute_sql`, deliberately): Phase 21.4 (S-1 `public_profiles` narrowing), 21.5 (DROP of `_test_results` / `_test_run_log`), 21.6 (S-5 default privileges), 21.7 (S-6/S-7 `MAINTAIN` and `EXECUTE` revocations) | `analysis/phase-21.4…21.7/migration.sql`; `backend-contract.md:754-766` |
| `20260719001753` and `20260719083801` share the name `phase_12_1_participant_management` (two different bodies) | history listing |

**Can history be retrieved faithfully?** Yes, the text is retrievable read-only. **Can it be replayed faithfully?** Not without additions:
- the 4 out-of-band phases must be appended as synthetic migrations;
- 21.5 depends on test tables that the early history created;
- the history contains the fictional seed inserts;
- it replays many intermediate states (including defects later fixed, S-1 … S-7) before arriving at the current state.

Replay equivalence would have to be proven with the same fingerprint gate, after a considerably larger effort. → Strategy recommendation in `reproducibility-design.md` §1.

## C. Edge Functions

| Function | Version | `verify_jwt` | Repo source | Deployed = repo? | Secrets / env by name |
|---|---|---|---|---|---|
| `delete-account` | 8 | false | `supabase/functions/delete-account/index.ts` plus `_shared/delete-auth-account.ts` | **Identical** (2/2 files) | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_ALLOWED_ORIGIN` (optional) |
| `process-pending-deletions` | 9 | false | `…/process-pending-deletions/{index,delete-auth-account,maintenance-auth}.ts` | **Identical** (3/3) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET` |
| `process-pending-asset-deletions` | 11 | false | `…/process-pending-asset-deletions/{index,maintenance-auth}.ts` | **Identical** (2/2) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET` |
| `reap-orphaned-collaboration-assets` | 4 | false | `…/reap-orphaned-collaboration-assets/{index,reaper,maintenance-auth}.ts` (`reaper.test.ts` not deployed) | **Identical** (3/3) | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_MAINTENANCE_SECRET`, `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` |

- Dependencies: remote `esm.sh` `@supabase/supabase-js@2` (floating, in 3 functions) and `@2.112.1` (pinned, in the reaper). No import map.
- No deployment-order dependency.
- The maintenance-auth file is intentionally duplicated in 3 functions (bundling constraint).
- `verify_jwt = false` is required for all four (each authenticates itself), and is recorded now in `supabase/config/environment-inventory.md` (previously only in Phase 21.8A/B docs).

## D. Storage

- **1 bucket:** `collaboration-assets`, `public = false`, `file_size_limit` NULL, `allowed_mime_types` NULL, type STANDARD.
- **2 policies on `storage.objects`:** SELECT `participants can read collaboration assets`, INSERT `participants can upload collaboration assets` (both via application helper functions); no UPDATE or DELETE policy.
- **Path convention:** `<collaboration-uuid>/<timestamp>-<rand>-<name>`. All 13 current objects are exactly 2 path levels deep.
- **Platform vs app:** the bucket row and the 2 policies are application setup (baseline §11 and §10). The Storage schema, its triggers and object metadata are platform. Objects are data: not in the baseline, and **not covered by database backups**.
- **Known open item (unchanged, out of scope):** 2 `collaboration_assets` rows reference missing objects (15 rows vs 13 objects).

---

## A (detail). Object inventory generated from the extraction

### A.2–A.10 Relations (public)

| Relation | Kind | RLS | Columns | PK | FK | Unique | Check | Extra indexes | Table grants (non-owner) | Column grants |
|---|---|---|---|---|---|---|---|---|---|---|
| `collaboration_activity` | table | on | 7 | 1 | 2 | 0 | 0 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `collaboration_assets` | table | on | 12 | 1 | 2 | 1 | 1 | 1 | authenticated:S service_role:DIMRSTTgU | authenticated:I (9 cols) |
| `collaboration_credits` | table | on | 7 | 1 | 3 | 0 | 0 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `collaboration_messages` | table | on | 5 | 1 | 2 | 0 | 1 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `collaboration_participants` | table | on | 6 | 1 | 3 | 2 | 1 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `collaboration_tasks` | table | on | 8 | 1 | 3 | 0 | 4 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `collaborations` | table | on | 8 | 1 | 1 | 1 | 1 | 0 | authenticated:S service_role:DIMRSTTgU | — |
| `follows` | table | on | 4 | 1 | 2 | 1 | 1 | 1 | anon:S authenticated:S service_role:DIMRSTTgU | — |
| `likes` | table | on | 5 | 1 | 1 | 1 | 0 | 2 | anon:S authenticated:S service_role:DIMRSTTgU | — |
| `notifications` | table | on | 12 | 1 | 4 | 0 | 0 | 1 | authenticated:S service_role:DIMRSTTgU | authenticated:U (1 cols) |
| `pending_asset_deletions` | table | on | 7 | 1 | 0 | 0 | 0 | 0 | service_role:DIMRSTTgU | — |
| `pending_auth_deletions` | table | on | 5 | 1 | 1 | 0 | 0 | 0 | service_role:DIMRSTTgU | — |
| `profiles` | table | on | 16 | 1 | 1 | 1 | 0 | 0 | anon:S authenticated:S service_role:DIMRSTTgU | authenticated:U (9 cols) |
| `public_profiles` | view | n/a | 7 | 0 | 0 | 0 | 0 | 0 | anon:S authenticated:S service_role:DIMRSTTgU | — |
| `user_auth_accounts` | table | on | 3 | 1 | 2 | 0 | 0 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `users` | table | on | 12 | 1 | 0 | 1 | 0 | 0 | service_role:DIMRSTTgU | authenticated:S authenticated:U (7 cols) |
| `wanted_applications` | table | on | 6 | 1 | 2 | 1 | 1 | 1 | authenticated:S service_role:DIMRSTTgU | — |
| `wanted_posts` | table | on | 11 | 1 | 1 | 0 | 1 | 2 | anon:S authenticated:S service_role:DIMRSTTgU | authenticated:I authenticated:U (9 cols) |

Legend: S select, I insert, U update, D delete, T truncate, R references, Tg trigger, M maintain.

### A.11 Functions (public) — all `SECURITY DEFINER`, owner `postgres`, `SET search_path TO ''`

| Function | Lang | EXECUTE granted to (besides owner) |
|---|---|---|
| `admin_anonymize_account(p_public_user_id uuid)` | plpgsql | service_role |
| `admin_block_user(p_public_user_id uuid)` | sql | service_role |
| `admin_link_recovered_account(p_auth_user_id uuid, p_public_user_id uuid)` | plpgsql | service_role |
| `admin_unblock_user(p_public_user_id uuid)` | sql | service_role |
| `admin_unmap_and_orphan_check(p_auth_user_id uuid)` | plpgsql | service_role |
| `change_collaboration_status(p_collaboration_id uuid, p_new_status text)` | plpgsql | authenticated, service_role |
| `close_own_wanted_post(p_post_id uuid)` | plpgsql | authenticated, service_role |
| `complete_collaboration_task(p_task_id uuid)` | plpgsql | authenticated, service_role |
| `create_collaboration_credit(p_collaboration_id uuid, p_user_id uuid, p_role text)` | plpgsql | authenticated, service_role |
| `create_collaboration_message(p_collaboration_id uuid, p_body text)` | plpgsql | authenticated, service_role |
| `create_collaboration_task(p_collaboration_id uuid, p_title text, p_assignee_id uuid)` | plpgsql | authenticated, service_role |
| `create_wanted_application(p_wanted_post_id uuid)` | plpgsql | authenticated, service_role |
| `current_active_stagerz_user_id()` | sql | authenticated, service_role |
| `current_stagerz_user_id()` | sql | authenticated, service_role |
| `delete_collaboration_asset(p_asset_id uuid)` | plpgsql | authenticated, service_role |
| `delete_collaboration_credit(p_credit_id uuid)` | plpgsql | authenticated, service_role |
| `delete_collaboration_message(p_message_id uuid)` | plpgsql | authenticated, service_role |
| `delete_collaboration_task(p_task_id uuid)` | plpgsql | authenticated, service_role |
| `edit_collaboration_asset(p_asset_id uuid, p_title text, p_description text)` | plpgsql | authenticated, service_role |
| `edit_collaboration_credit(p_credit_id uuid, p_role text)` | plpgsql | authenticated, service_role |
| `edit_collaboration_message(p_message_id uuid, p_new_body text)` | plpgsql | authenticated, service_role |
| `edit_collaboration_task(p_task_id uuid, p_new_title text)` | plpgsql | authenticated, service_role |
| `handle_new_auth_user()` | plpgsql | service_role |
| `has_completed_onboarding(p_user_id uuid)` | sql | authenticated, service_role |
| `invite_collaboration_participant(p_collaboration_id uuid, p_user_id uuid)` | plpgsql | authenticated, service_role |
| `is_collaboration_owner(p_collaboration_id uuid)` | sql | authenticated, service_role |
| `is_collaboration_participant(p_collaboration_id uuid)` | sql | authenticated, service_role |
| `leave_collaboration(p_collaboration_id uuid)` | plpgsql | authenticated, service_role |
| `log_collaboration_asset_activity()` | plpgsql | service_role |
| `log_collaboration_credit_activity()` | plpgsql | service_role |
| `log_collaboration_message_activity()` | plpgsql | service_role |
| `remove_collaboration_participant(p_collaboration_id uuid, p_user_id uuid)` | plpgsql | authenticated, service_role |
| `respond_to_wanted_application(p_application_id uuid, p_new_status text)` | plpgsql | authenticated, service_role |
| `transfer_collaboration_ownership(p_collaboration_id uuid, p_new_owner_id uuid)` | plpgsql | authenticated, service_role |

### A.12–A.13 Triggers

| Table | Trigger | Function | Class |
|---|---|---|---|
| `auth.users` | `on_auth_user_created` | `handle_new_auth_user` | application |
| `public.collaboration_assets` | `trg_log_collaboration_asset_activity` | `log_collaboration_asset_activity` | application |
| `public.collaboration_credits` | `trg_log_collaboration_credit_activity` | `log_collaboration_credit_activity` | application |
| `public.collaboration_messages` | `trg_log_collaboration_message_activity` | `log_collaboration_message_activity` | application |
| `storage.buckets` | `enforce_bucket_name_length_trigger` | `storage.enforce_bucket_name_length` | platform (Storage-internal) |
| `storage.buckets` | `protect_buckets_delete` | `storage.protect_delete` | platform (Storage-internal) |
| `storage.objects` | `protect_objects_delete` | `storage.protect_delete` | platform (Storage-internal) |
| `storage.objects` | `update_objects_updated_at` | `storage.update_updated_at_column` | platform (Storage-internal) |

Event triggers (all platform-managed, owner `supabase_admin`): `issue_graphql_placeholder`, `issue_pg_cron_access`, `issue_pg_graphql_access`, `issue_pg_net_access`, `pgrst_ddl_watch`, `pgrst_drop_watch`. None is application-owned.

### A.15 Policies

| Schema.table | Policy | Command | Roles | Permissive |
|---|---|---|---|---|
| `public.collaboration_activity` | participants can read collaboration activity | SELECT | authenticated | PERMISSIVE |
| `public.collaboration_assets` | active participants can create collaboration asset metadata | INSERT | authenticated | PERMISSIVE |
| `public.collaboration_assets` | participants can read collaboration asset metadata | SELECT | authenticated | PERMISSIVE |
| `public.collaboration_credits` | participants can read collaboration credits | SELECT | authenticated | PERMISSIVE |
| `public.collaboration_messages` | participants can read collaboration messages | SELECT | authenticated | PERMISSIVE |
| `public.collaboration_participants` | participants can read co-participants in their collaboration | SELECT | authenticated | PERMISSIVE |
| `public.collaboration_tasks` | participants can read collaboration tasks | SELECT | authenticated | PERMISSIVE |
| `public.collaborations` | participants can read their own collaboration | SELECT | authenticated | PERMISSIVE |
| `public.follows` | follows are publicly readable | SELECT | public | PERMISSIVE |
| `public.likes` | likes are publicly readable | SELECT | public | PERMISSIVE |
| `public.notifications` | active users can update own notifications | UPDATE | public | PERMISSIVE |
| `public.notifications` | users read only own notifications | SELECT | public | PERMISSIVE |
| `public.profiles` | active users can update own profile | UPDATE | public | PERMISSIVE |
| `public.profiles` | profiles are publicly readable | SELECT | public | PERMISSIVE |
| `public.user_auth_accounts` | users read only own credential mappings | SELECT | public | PERMISSIVE |
| `public.users` | active users can update own row | UPDATE | public | PERMISSIVE |
| `public.users` | authenticated can read own row | SELECT | public | PERMISSIVE |
| `public.wanted_applications` | applicant or wanted owner can read applications | SELECT | authenticated | PERMISSIVE |
| `public.wanted_posts` | active users can update own wanted posts | UPDATE | public | PERMISSIVE |
| `public.wanted_posts` | onboarded active users can insert own wanted posts | INSERT | public | PERMISSIVE |
| `public.wanted_posts` | wanted_posts are publicly readable | SELECT | public | PERMISSIVE |
| `storage.objects` | participants can read collaboration assets | SELECT | authenticated | PERMISSIVE |
| `storage.objects` | participants can upload collaboration assets | INSERT | authenticated | PERMISSIVE |

### A.19 Default privileges (owner `postgres`, application-relevant)

| Schema / object type | ACL |
|---|---|
| public / FUNCTIONS | `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |
| storage / FUNCTIONS | `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |
| public / TABLES | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| public / SEQUENCES | `{postgres=rwU/postgres,service_role=rwU/postgres}` |
| storage / TABLES | `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}` |
| storage / SEQUENCES | `{postgres=rwU/postgres,service_role=rwU/postgres}` |

Other default-ACL entries (18) belong to `supabase_admin` / `supabase_auth_admin` or other platform schemas and are platform-managed.
