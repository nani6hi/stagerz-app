# Phase 22.3 — Baseline Verification Record (local reproducibility gate)

**Date:** 2026-09-19 / 2026-09-20. **Environment:** isolated local Docker only. **Production was never touched** (read-only queries only).

## 1. Artifact lineage

| Stage | Path | SHA-256 |
|---|---|---|
| Verified DRAFT (the exact bytes tested) | `supabase/baseline/stagerz_baseline.DRAFT.sql` *(retired after promotion)* | `7ae91fd169c8579875f0889bcc96e480d9a5b1fd9d453aa96c5a399b1ddba185` |
| Canonical migration (promoted) | `supabase/migrations/20260919120000_stagerz_baseline.sql` | `8c292ef427c2c2c1ddf1d7833a6530e0a0f33ccb166c5da480eb228c41d78c82` |
| **Substantive SQL** (everything from `SET check_function_bodies = false;` onward), identical in both | — | `cd2fcf93825b6b0c8655f0ebf0e497668069d7a217608d1a10643de6985fcf0c` |

Only the header comments differ between the two files. The executable SQL is byte-for-byte the verified artifact. The DRAFT was generated deterministically (two generations byte-identical) and is reproducible from the recorded catalog extractions.

## 2. Test environment

- Image `public.ecr.aws/supabase/postgres:17.6.1.167` (production runs PostgreSQL 17.6).
- Disposable containers with local-only credentials, **no published ports** (all access through `docker exec`), separate volume per run.
- The Supabase CLI stack (`supabase start`) could **not** be used: `storage-api:v1.72.1` exits 139 (segfault) on this machine, reproducibly, on a freshly booted host with over 5 GB RAM free. Postgres and Realtime containers exit cleanly, so this is specific to that image.

## 3. Platform prerequisites (what a pristine database image does and does not provide)

**Provided by the database image:** PostgreSQL 17.6; schemas `auth`, `storage`, `realtime`, `extensions`, `graphql`, `graphql_public`, `vault`; `auth.users` (a 2021-era stub); all Supabase roles; the `supabase_realtime` publication; the 5 extensions; `postgres` default privileges matching production; an empty `public`.

**NOT provided:** `storage.buckets` and `storage.objects`. The `storage` schema exists but is empty; its tables are created by the Storage service's own tenant migrations.

**Scaffolding used (local only, never part of the baseline):**
1. The **official** 67 tenant migrations from `supabase/storage-api:v1.72.1`, copied unmodified with `docker cp` from a container that was **created but never started** (its Node process, the crashing part, was never executed). IDs 1–67, consecutive; canonical order is **numeric** (`00010-…` is id 10), not alphabetical.
   - They cannot be concatenated: `0001-initialmigration.sql` is `select 1` with no semicolon. They were applied one file per session, as the vendor runner does.
   - Applied as `supabase_storage_admin` (TCP `trust` inside the container), which yields **production-matching ownership** of the storage tables.
   - The vendor's own `storage.install_roles=false` switch was used, because every role already exists in the image. No vendor SQL was modified.
   - **Version match:** production's `storage.migrations` is at id 67 (`objects-null-version-index`), the same as this image's last migration.
2. `GRANT supabase_storage_admin TO postgres` — required locally so `postgres` could create policies on the storage tables. In production `postgres` is *not* a member yet the policies exist, so hosted Supabase wires this privilege differently. **This grant is local scaffolding and must never appear in a production migration.**

## 4. Results

| Run | Storage scaffolding | Baseline apply | Fingerprint vs production |
|---|---|---|---|
| **#1** (container `stagerz-gate1`, fresh volume) | 67/67 applied, exit 0 | unmodified, `ON_ERROR_STOP`, single transaction → **exit 0, 0 errors** | **20/20 exact categories PASS, 0 FAIL** |
| **#2** (container `stagerz-gate2`, destroyed and recreated from empty) | 67/67 applied, exit 0 | same file, same hash → **exit 0, 0 errors** | **20/20 PASS, 0 FAIL** |

**Determinism:** runs #1 and #2 are **byte-identical across all 20 categories**.

**Categories compared (all PASS, both runs):** relations, relation_count, columns, column_count, constraints, indexes, views, functions, function_count, triggers, trigger_count, policies, policy_count, relation_grants, column_grants, function_grants, default_privileges, realtime_members, buckets, app_extensions. No expected value was weakened.

**Environment values (reported, never compared):** database version 17.6; extension versions; `migration_history_present=false` locally; row, Auth and Storage counts all 0.

### Storage database contract (F) — PASS
- Bucket `collaboration-assets`: private, no size limit, no MIME restriction.
- Both policies on `storage.objects`: `participants can read collaboration assets` (SELECT) and `participants can upload collaboration assets` (INSERT), permissive, role `authenticated`.
- RLS enabled, not forced. Policy expressions are covered by the matching `policies` hash.

### Seeds
- **Showcase — PASS:** 4 fictional system users, 4 profiles, 3 open posts; re-running changed nothing (idempotent).
- **Fixtures, Auth-account creation — NOT TESTED:** the image's `auth.users` stub lacks `email_confirmed_at` and other GoTrue-managed columns, so the file's Auth inserts cannot run. Not faked.
- **Fixtures, database-side scenario — PASS:** with the three accounts created through the **real** `on_auth_user_created` trigger (which produced the user row, mapping and "New Artist" profile exactly as in production), the fixture file's own step 2–3 statements produced 3 fixture users, 2 posts, 1 application, 1 collaboration, 2 participants, 1 task, 1 message, plus the activity row and notification generated by the message trigger. Executed inside a transaction and rolled back; the database returned to showcase-only state.

## 5. Platform differences observed (not STAGERZ-owned, outside every compared category)

| Difference | Local | Production |
|---|---|---|
| Storage tables | 10 (adds `iceberg_namespaces`, `iceberg_tables`) | 8 |
| `storage.migrations` rows | 0 (SQL applied directly, not through the vendor runner) | 67 |
| Storage table ownership | `supabase_storage_admin` | `supabase_storage_admin` (match) |

## 6. Validation matrix

| # | Item | Status |
|---|---|---|
| A | Database baseline reproducibility | **PASS** (twice, from empty) |
| B | Production STAGERZ fingerprint equivalence | **PASS** (20/20, both runs) |
| C | Synthetic showcase seeds | **PASS** (including idempotency) |
| C2 | Database-side fixture scenario | **PASS** |
| C3 | Full Auth-account fixture creation | **PARTIAL / NOT RUNTIME-PROVEN** |
| D | Auth / API / Realtime runtime | **NOT TESTED** |
| E | Edge Functions runtime | **NOT TESTED** |
| F | Storage database contract | **PASS** |
| G | Storage API runtime | **BLOCKED** locally (`storage-api:v1.72.1` exit 139) |

**Phase 22.3 is not a full Supabase runtime proof.** It proves the database baseline and its equivalence to the production database contract.

**Closure note (2026-09-20).** Phase 22.3 was closed **COMPLETE / PASS** with **C3, D, E and G still open**. They are carried forward, unchanged in status, as the scope of the proposed Phase 22.5, and must not be described as passed. What each one actually leaves unproven — and what production evidence already exists for it — is set out in `closeout.md` §2. Nothing in this record was revised at closure.

## 7. Cleanup

Both test containers and both volumes were removed (0 remaining). Cached images kept. Docker and WSL left installed and healthy. No `.wslconfig` was created, no WSL distribution unregistered, no Docker reset.
