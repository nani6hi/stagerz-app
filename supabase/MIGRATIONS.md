# STAGERZ — database migration convention (B1, owner-approved 2026-09-19)

## Canonical baseline

| Item | Value |
|---|---|
| Strategy | **B1**: one canonical executable baseline plus forward incremental migrations. The historical 43-migration chain is **not** the rebuild path. An archive of it may be kept separately later, for reference only |
| Canonical migration | **`supabase/migrations/20260919120000_stagerz_baseline.sql`** |
| Canonical file SHA-256 | `8c292ef427c2c2c1ddf1d7833a6530e0a0f33ccb166c5da480eb228c41d78c82` |
| Verified DRAFT it was promoted from (retired) | `7ae91fd169c8579875f0889bcc96e480d9a5b1fd9d453aa96c5a399b1ddba185` |
| Substantive SQL (identical in both; only header comments differ) | `cd2fcf93825b6b0c8655f0ebf0e497668069d7a217608d1a10643de6985fcf0c` |
| Status | **VERIFIED** by two clean rebuilds from empty databases, 20/20 exact fingerprint categories matching production on both runs, byte-identical between runs. Evidence: `analysis/phase-22.3/baseline-verification-record.md` |

## Production history safety — READ THIS FIRST

- **Production already contains the equivalent schema state.** The canonical baseline must **never be executed** against `kbnmkyvbwkuvcklywdhk`. Its own guard refuses any database that already holds STAGERZ tables.
- Production's migration history still holds its own 43 rows (latest `20260917143322`) and **does not** contain `20260919120000`.
- Reconciling that (recording the baseline version as already applied, e.g. `supabase migration repair --status applied 20260919120000`) is a **separate, metadata-only production operation that requires explicit owner approval**. It has not been done.
- Until then the repository baseline and the production migration history are **deliberately distinct**. That is a known, documented state, not a defect.
- The repository is **not linked** to any Supabase project. Do not run `supabase link` or `supabase db push` without explicit approval: with a link in place, `db push` would try to apply this baseline to the linked project.

## Applying the baseline to a NEW environment

See `README.md` for the full rebuild procedure and the platform prerequisites it depends on (storage tables, owner-capable role for storage policies).

## Naming and form of future migrations

- **File name:** `supabase/migrations/<YYYYMMDDHHMMSS>_<snake_case_description>.sql`, UTC timestamp, strictly later than `20260919120000`. One logical change per file.
- **Header comment:** phase, purpose, a pre-flight/post-flight summary, and which fingerprint categories are expected to change.
- **Guarded style**, as used in Phases 21.x and 22.1: explicit pre-flight check of the expected state, the change, a post-flight assertion, all in one transaction so any mismatch aborts everything.
- **Content:** no data changes mixed into schema migrations; no secrets, user data or environment-specific URLs.

## Forward-only, and rollback

- **Migrations are forward-only.** A mistake is corrected by a new migration. **Never edit an already-applied migration**, and never edit the canonical baseline for ordinary future changes.
- **For every non-trivial change,** a reviewed reverse script is kept with that change's analysis (`analysis/<phase>/rollback.sql`, the established pattern). It is never auto-applied, is guarded, and runs only with separate owner approval.
- **Rollback of data** relies on backups (a separate production-readiness item; the Free plan has none).

## Verification after every migration

1. Apply to the local/test environment first. Run `verify/fingerprint.sql` plus the behavioural probes.
2. Apply to production (approved), then run `verify/fingerprint.sql` on production.
3. Update `supabase/verify/expected-production.json` in the **same change**, so the repository's expected fingerprint always equals production.
4. Re-run a clean local rebuild (baseline + all migrations) and confirm it still matches. That keeps reproducibility continuous.

## Safety against accidental application

- `supabase/config.toml` is deliberately **not** in the repository; local verification uses a scratch workspace outside it.
- The repository is not linked to any project, and the Supabase GitHub integration / branching is not enabled.
- The baseline refuses to run on any database that already contains STAGERZ tables.
- The seeds refuse to run on any database with non-seed users.
