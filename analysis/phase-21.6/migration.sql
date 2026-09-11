-- =====================================================================
-- STAGERZ - Phase 21.6 - S-5 remediation
-- =====================================================================
--  ####  EXECUTABLE MIGRATION - NOT YET APPLIED.  ####
--
-- The four statements below have NOT been run against any database.
-- They are prepared for review and await explicit production-mutation
-- approval, which has not been given.
--
-- This file is NOT a descriptive snapshot. It differs deliberately from
-- the .sql files in analysis/phase-21.3/, which carry the opposite
-- header and contain no executable statements.
--
-- (The counterpart marker string used by those snapshots is deliberately
--  not reproduced here, so a grep for it cannot misclassify this file.)
--
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Prepared    : 2026-09-11
-- Applied     : NOT APPLIED
-- Approved by : NOT APPROVED - preparation only
-- Addresses   : S-5 - default privileges for role postgres grant ALL,
--               including TRUNCATE, on every future TABLE, VIEW and
--               SEQUENCE in schemas public and storage to anon and
--               authenticated. Root cause of S-1 and S-2.
-- =====================================================================

-- ---------------------------------------------------------------------
--  ####  READ BEFORE EXECUTING - SIX RULES  ####
--
--  1. FOR ROLE postgres IS MANDATORY.
--     Without it the statement targets the defaults of whichever role
--     is executing. If that is not postgres, the statement succeeds and
--     changes nothing. A silent no-op, indistinguishable from success.
--
--  2. IN SCHEMA IS MANDATORY.
--     Without it Postgres writes a NEW GLOBAL entry (defaclnamespace = 0)
--     instead of modifying the schema-scoped one. The dangerous entry is
--     left untouched and a second, confusing entry is added. Another
--     silent failure.
--
--  3. REVOKE ALL IS DELIBERATE AND FUTURE-PROOF.
--     Never replace it with an enumerated privilege list. Migration
--     20260712144926 enumerated six privileges on public.users and
--     silently left MAINTAIN behind (finding S-6), because MAINTAIN did
--     not exist when that style was learned. ALL covers privilege types
--     that do not exist yet.
--
--  4. service_role AND postgres MUST REMAIN UNTOUCHED.
--     Neither appears in any revoke list below, deliberately. Naming
--     service_role would cut off the trusted backend role; postgres is
--     the owner.
--
--  5. FUNCTIONS DEFAULTS ARE INTENTIONALLY OUT OF SCOPE.
--     Entries postgres/public/FUNCTIONS and postgres/storage/FUNCTIONS
--     are not touched. The only live function exposure on this project
--     comes from the built-in EXECUTE-to-PUBLIC default, not from these
--     entries, so changing them would look like a fix without being one.
--     See phase-definition.md section 7.3.
--
--  6. EXISTING OBJECT ACLs MUST REMAIN UNCHANGED.
--     ALTER DEFAULT PRIVILEGES affects only objects created AFTER it
--     runs. Every existing relacl and proacl must be byte-identical
--     before and after. If any changed, something other than these four
--     statements ran: HARD STOP.
--
--  All four statements must be sent in a single execution so they apply
--  together. Post-change check M-1 verifies all four entries changed; a
--  partial result is a hard-stop outcome (phase-definition.md sec. 12).
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- PRE-CHANGE STATE (captured read-only 2026-09-09)
-- ---------------------------------------------------------------------
--   pg_default_acl: 24 entries, ALL schema-scoped, none global.
--
--   Targeted - grantor postgres:
--     oid 16492  public   TABLES
--       {postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,
--        authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
--     oid 16494  public   SEQUENCES
--       {postgres=rwU/postgres,anon=rwU/postgres,
--        authenticated=rwU/postgres,service_role=rwU/postgres}
--     oid 16548  storage  TABLES     (identical to 16492)
--     oid 16550  storage  SEQUENCES  (identical to 16494)
--
--   Deliberately NOT targeted - grantor postgres:
--     oid 16493  public   FUNCTIONS
--     oid 16549  storage  FUNCTIONS
--
--   Deliberately NOT targeted - platform roles:
--     15 entries, grantor supabase_admin
--        (extensions, graphql, graphql_public, public, realtime)
--      3 entries, grantor supabase_auth_admin (auth)
--
--   Existing objects: none of the 18 relations in public carries the
--   unsafe signature; public holds 0 sequences. Current live exposure
--   from this mechanism is zero. The risk is recurrence.
--
--   This state must be re-verified immediately before applying. See
--   validation.md section 3. HARD STOP ON MISMATCH.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- MIGRATION - exactly the four intended statements, nothing else
-- ---------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- EXPECTED POST-CHANGE STATE
-- ---------------------------------------------------------------------
--   postgres / public  / TABLES     {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
--   postgres / public  / SEQUENCES  {postgres=rwU/postgres,service_role=rwU/postgres}
--   postgres / storage / TABLES     {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
--   postgres / storage / SEQUENCES  {postgres=rwU/postgres,service_role=rwU/postgres}
--
--   pg_default_acl entry count: still 24. Each targeted entry keeps a
--   non-empty ACL (postgres + service_role), so Postgres updates the row
--   in place rather than deleting it.
--
--   Global entries (defaclnamespace = 0): still 0.
--   The other 20 entries: byte-identical.
--   Every existing relacl and proacl: byte-identical.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- ROLLBACK - restores the exact prior state of all four entries
-- ---------------------------------------------------------------------
--   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
--     GRANT ALL ON TABLES TO anon, authenticated;
--   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
--     GRANT ALL ON SEQUENCES TO anon, authenticated;
--   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
--     GRANT ALL ON TABLES TO anon, authenticated;
--   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
--     GRANT ALL ON SEQUENCES TO anon, authenticated;
--
--   ALL on TABLES restores arwdDxtm; ALL on SEQUENCES restores rwU.
--   Byte-exact.
--
--   Rollback RE-OPENS S-5 and must not be run except to recover from a
--   confirmed regression, under the same approval as any production
--   change. It cannot damage existing objects - it is no more
--   retroactive than the migration is.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- DELIBERATELY NOT CHANGED
-- ---------------------------------------------------------------------
--   * FUNCTIONS defaults (oids 16493, 16549) - see rule 5 above
--   * All 15 supabase_admin and 3 supabase_auth_admin entries -
--     platform-owned, including the latent supabase_admin/public/TABLES
--     twin (oid 16496)
--   * Every existing object ACL in every schema
--   * S-6: MAINTAIN held by anon/authenticated on public.users -
--     deferred to Phase 21.7
--   * S-7: EXECUTE-to-PUBLIC on the three log_collaboration_*_activity
--     trigger functions - deferred to Phase 21.7
--   * public_profiles, RLS, policies, storage policies, auth settings
--   * S-3 storage DELETE policy, S-4 SQLSTATE handling
--   * index.html and all application source
-- ---------------------------------------------------------------------
