# STAGERZ backend — repository definition

**Production backend of record:** Supabase project **`kbnmkyvbwkuvcklywdhk`** (Phase 22.2, Option A).
**Legacy, contained project:** `edxicnafggnnvcdvxemk` — Phase 22.1 containment; detached, not a backend for anything.
**Strategy:** **B1** — one canonical executable baseline plus forward incremental migrations (`MIGRATIONS.md`).

**Status (Phase 22.3):** the canonical baseline is **verified** by two clean rebuilds from empty databases (20/20 exact fingerprint categories matching production, byte-identical between runs). It has **not** been executed against production, and production's migration history has **not** been changed. See `analysis/phase-22.3/baseline-verification-record.md`.

## Layout

| Path | What it is | State |
|---|---|---|
| `migrations/20260919120000_stagerz_baseline.sql` | **Canonical baseline**: all application-owned database state | Verified; never executed on production |
| `MIGRATIONS.md` | Baseline version, naming, forward-only rule, rollback, verification, production-history safety | Convention |
| `functions/` | Source of the 4 deployed Edge Functions (+ `_shared/`, `reaper.test.ts`) | **Live**: byte-identical to deployed (verified 2026-09-19) |
| `verify/fingerprint.sql` | Read-only reproducibility fingerprint (runs on any environment) | Read-only |
| `verify/expected-production.json` | Production fingerprint a rebuild must match | Captured 2026-09-19 |
| `config/environment-inventory.md` | Edge Function config, secrets **by name**, Storage, Realtime, key state, full Auth capture | Complete |
| `seed/showcase.sql`, `seed/fixtures.sql`, `seed/README.md` | (a) synthetic showcase data, (b) technical fixtures — **non-production only** | Showcase and the database-side scenario verified locally |

`config.toml` is deliberately absent: local verification runs in a scratch workspace outside the repository, so no CLI command can target a linked project from here.

## What the repository reproduces, and what it does not

**Application-owned — reproduced by the baseline:** the `public` schema (17 tables, 1 view, 34 `SECURITY DEFINER` functions with `search_path=''`), constraints, indexes, 3 `public` triggers plus `on_auth_user_created` on `auth.users`, RLS on all tables, 21 `public` policies, exact table/column/function grants, the `postgres` default privileges (S-5 state), the private `collaboration-assets` bucket and its 2 `storage.objects` policies, the `supabase_realtime` membership of the 5 collaboration tables, and the `pgcrypto` / `uuid-ossp` extensions.

**Platform-managed — must NOT be recreated manually:** the schemas `auth`, `storage`, `realtime`, `vault`, `graphql`, `graphql_public`, `extensions`, `pgbouncer`, `supabase_migrations` and their objects; the publications themselves; platform event triggers; Storage-internal triggers; `pg_stat_statements`, `supabase_vault`, `plpgsql`; role settings; the `supabase_admin` / `supabase_auth_admin` default privileges.

**Configuration outside the database — documented, not code:** Auth settings (`config/environment-inventory.md` §6, captured 2026-09-19), Edge Function secret **values**, the GitHub Actions secret, and API keys.

**Never in this repository:** secrets, access tokens, service-role or API key values, passwords, real user e-mails, user rows or uploaded files.

## Platform prerequisites for a rebuild (verified the hard way)

The baseline targets a **Supabase-managed database**. Before it can run, these must exist:

1. Supabase roles (`anon`, `authenticated`, `service_role`, `authenticator`, `supabase_admin`, `supabase_storage_admin`, …).
2. The `auth` schema and its objects, including `auth.users` — the baseline attaches `on_auth_user_created` to it. A plain database image ships only an old stub; the real schema comes from the Auth service.
3. The `storage` schema **with `storage.buckets` and `storage.objects`**. A plain database image creates the schema but **no tables**: they come from the Storage service's own tenant migrations.
4. The `supabase_realtime` publication (the baseline adds tables to it, and does not create it).
5. The `extensions` schema.

On a real Supabase project (cloud or a healthy `supabase start`) all of this exists already. It only had to be constructed by hand for the isolated Docker verification, using the **official** Storage tenant migrations from `supabase/storage-api:v1.72.1` (67 migrations; production and that image were both at tenant migration **id 67** during verification).

**Storage policies need an owner-capable role.** `storage.objects` is owned by `supabase_storage_admin`. During isolated verification a local-only `GRANT supabase_storage_admin TO postgres` was required, because hosted Supabase wires this privilege differently. **That grant is local scaffolding: it is not part of the baseline and must never be added to a production migration.**

## Rebuild procedure (for a NEW, EMPTY environment only — never production)

1. Start or create the target environment — never `kbnmkyvbwkuvcklywdhk` or `edxicnafggnnvcdvxemk`. Confirm the platform prerequisites above exist.
2. Apply `migrations/20260919120000_stagerz_baseline.sql` once. It refuses to run if STAGERZ tables already exist.
3. Optionally apply `seed/showcase.sql`, then `seed/fixtures.sql` (non-production only).
4. Deploy the 4 Edge Functions from `functions/` with `--no-verify-jwt` (each authenticates itself).
5. Set the function secrets **by name** (`config/environment-inventory.md`), generated for that environment only.
6. Configure Auth from the captured production settings, with that environment's own Site URL and redirect list.
7. Run `verify/fingerprint.sql` and compare its `exact` block with `verify/expected-production.json`. **Every key must match.**
8. Point a frontend at it: `index.html` selects the backend by hostname; `localhost` uses the local stack, whose key is set once in the browser (`localStorage['stagerz:local-supabase-key']`). Unknown hosts are blocked.

## Test environments

**T1, a local stack, remains the preferred first test environment** — zero cost and no cloud project slot.

**Current limitation:** on this machine `supabase start` cannot complete, because `storage-api:v1.72.1` exits 139 (segfault) reproducibly, even on a freshly booted host with over 5 GB RAM free. Postgres and Realtime run fine. The database gate was therefore proven by running the database image directly. Until that is resolved, the local stack cannot validate the Auth/API/Realtime or Edge Function runtimes, and a cloud test project (T2) is the fallback for those.
