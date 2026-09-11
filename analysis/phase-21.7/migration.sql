-- =====================================================================
-- STAGERZ - Phase 21.7 - S-6 and S-7 remediation
-- =====================================================================
--  ####  EXECUTABLE MIGRATION - NOT YET APPLIED.  ####
--
-- The seven statements below have NOT been run against any database.
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
-- Server      : PostgreSQL 17.6 (170006) - MAINTAIN exists only in 17+
-- Prepared    : 2026-09-12
-- Applied     : NOT APPLIED
-- Approved by : NOT APPROVED - preparation only
-- Addresses   : S-6 - anon and authenticated hold MAINTAIN on public.users
--               S-7 - three trigger functions executable by PUBLIC (and,
--                     by explicit grant, by authenticated)
-- =====================================================================

-- ---------------------------------------------------------------------
--  ####  READ BEFORE EXECUTING - SIX RULES  ####
--
--  1. THE EXECUTABLE PORTION IS EXACTLY SEVEN STATEMENTS.
--     One for S-6, six for S-7. Every other line in this file is a
--     comment. No GRANT, ALTER, DROP, CREATE or CASCADE appears in any
--     executable statement.
--
--  2. THE S-6 REVOKE IS NARROW ON PURPOSE.
--     REVOKE MAINTAIN, not REVOKE ALL. MAINTAIN is verified to be the
--     ONLY table-level privilege anon and authenticated hold on
--     public.users, so both forms reach the same end state - but
--     MAINTAIN does not exist as a column-level privilege, so this form
--     provably cannot touch the seven column grants that Edit Profile
--     depends on. Enumeration here is derived from the live ACL, not
--     from habit, which is the distinction from the mistake that
--     created S-6 in the first place.
--
--  3. THE SEVEN COLUMN GRANTS ON public.users MUST SURVIVE UNCHANGED.
--     authenticated holds id=r and username, first_name, last_name,
--     photo_url, bio, location = rw. These are what make profile
--     editing work. If any is missing afterwards: HARD STOP.
--
--  4. TRIGGER FIRING DOES NOT REQUIRE EXECUTE, SO NO COMPENSATING GRANT
--     IS NEEDED. PostgreSQL does not check the DML caller's EXECUTE
--     privilege when firing a trigger. Proven inside this project:
--     handle_new_auth_user() has proacl {postgres=X,service_role=X} -
--     no PUBLIC, not executable by anon or authenticated - and its
--     trigger on auth.users fires on every signup.
--
--  5. NOTHING ABOUT THE FUNCTIONS THEMSELVES CHANGES.
--     Ownership, SECURITY DEFINER, search_path, volatility, bodies and
--     the three triggers are all untouched. Only EXECUTE grants move.
--
--  6. EXISTING RLS, POLICIES AND ALL OTHER OBJECTS MUST REMAIN
--     UNCHANGED. public.users keeps RLS enabled with its two policies
--     and zero triggers. Every other relation, function and column ACL
--     in public and storage must be byte-identical afterwards.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- PRE-CHANGE STATE (captured read-only 2026-09-12)
-- ---------------------------------------------------------------------
--   S-6 - public.users
--     relkind r, owner postgres, RLS enabled=true forced=false,
--     policies=2, triggers=0, dependent views=1 (public_profiles)
--     relacl:
--       {postgres=arwdDxtm/postgres,anon=m/postgres,
--        authenticated=m/postgres,service_role=arwdDxtm/postgres}
--     anon          : MAINTAIN only (no r/a/w/d/D/x/t)
--     authenticated : MAINTAIN only (no r/a/w/d/D/x/t)
--     column grants : authenticated -> id=r; username, first_name,
--                     last_name, photo_url, bio, location = rw  (7 rows)
--     Neither role is a member of any other role, and there is no
--     PUBLIC grant on the table, so MAINTAIN is held directly and
--     nowhere else.
--
--   S-7 - the three trigger functions, all identical in posture
--     public.log_collaboration_asset_activity()
--     public.log_collaboration_credit_activity()
--     public.log_collaboration_message_activity()
--       owner postgres, plpgsql, SECURITY DEFINER, VOLATILE,
--       returns trigger, SET search_path TO ''
--       proacl: {=X/postgres,postgres=X/postgres,
--                authenticated=X/postgres,service_role=X/postgres}
--       PUBLIC        : EXECUTE  (the leading "=X/postgres")
--       anon          : EXECUTE, inherited via PUBLIC only - no explicit grant
--       authenticated : EXECUTE, explicit grant
--       triggers      : trg_log_collaboration_asset_activity   AFTER INSERT ON public.collaboration_assets
--                       trg_log_collaboration_credit_activity  AFTER INSERT ON public.collaboration_credits
--                       trg_log_collaboration_message_activity AFTER INSERT ON public.collaboration_messages
--       frontend      : zero references in index.html; no supaRpc call
--
--   Control case, deliberately NOT modified:
--     public.handle_new_auth_user()
--       proacl {postgres=X/postgres,service_role=X/postgres}
--       anon=false, authenticated=false
--       trigger on_auth_user_created AFTER INSERT ON auth.users - fires
--       on every signup. This is the posture the three functions above
--       are being moved to.
--
--   This state must be re-verified immediately before applying. See
--   validation.md section 3. HARD STOP ON MISMATCH.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- MIGRATION - exactly the seven intended statements, nothing else
-- ---------------------------------------------------------------------

-- --- S-6: remove the MAINTAIN residue from public.users (1 statement) ---

REVOKE MAINTAIN ON TABLE public.users FROM anon, authenticated;

-- --- S-7: reduce the three trigger functions to postgres/service_role
-- --- EXECUTE only (6 statements) ---

REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.log_collaboration_asset_activity() FROM authenticated;

REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.log_collaboration_credit_activity() FROM authenticated;

REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.log_collaboration_message_activity() FROM authenticated;

-- ---------------------------------------------------------------------
-- EXPECTED POST-CHANGE STATE
-- ---------------------------------------------------------------------
--   public.users relacl:
--     {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
--   The anon and authenticated entries disappear entirely, because
--   MAINTAIN was their only table-level privilege. That is expected, not
--   over-revocation.
--
--   public.users, unchanged:
--     seven column grants (id=r; username/first_name/last_name/
--     photo_url/bio/location=rw for authenticated)
--     RLS enabled=true forced=false, both policies, zero triggers
--
--   Each of the three functions:
--     proacl {postgres=X/postgres,service_role=X/postgres}
--     PUBLIC=false  anon=false  authenticated=false
--     service_role=true  postgres=true
--   - byte-identical in shape to handle_new_auth_user().
--
--   Unchanged: owner, SECURITY DEFINER, search_path, volatility, bodies,
--   and all three triggers.
--
--   Security Advisor, expected direction:
--     anon_security_definer_function_executable           3 -> 0 (lint gone)
--     authenticated_security_definer_function_executable  28 -> 25
--     totals                                    5 lints/35 -> 4 lints/29
--   Treated as supporting evidence, not as proof. The catalog diff is
--   the proof.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- ROLLBACK - restores the exact prior privileges for all seven
--            statements. COMMENTED OUT. NOT PART OF THIS MIGRATION.
-- ---------------------------------------------------------------------
--   GRANT MAINTAIN ON TABLE public.users TO anon, authenticated;
--
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_asset_activity() TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_asset_activity() TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_credit_activity() TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_credit_activity() TO authenticated;
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_message_activity() TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION public.log_collaboration_message_activity() TO authenticated;
--
--   Rollback RE-OPENS S-6 and S-7 and must not be run except to recover
--   from a confirmed regression, under the same approval as any
--   production change. It touches only grants, never data or definitions.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- DELIBERATELY NOT CHANGED
-- ---------------------------------------------------------------------
--   * public.handle_new_auth_user() - the control case
--   * Function ownership, SECURITY DEFINER, search_path, bodies
--   * The three triggers and their tables
--   * public.users RLS, its two policies, its seven column grants
--   * service_role and postgres privileges everywhere
--   * pg_default_acl - S-5 was closed in Phase 21.6; untouched here
--   * Platform-owned siblings, out of scope and not alterable:
--       storage.buckets / buckets_analytics / objects - anon and
--       authenticated hold arwdDxtm (including m) granted by
--       supabase_storage_admin, RLS-gated, storage not PostgREST-exposed
--       storage.enforce_bucket_name_length(), storage.protect_delete(),
--       storage.update_updated_at_column() - PUBLIC-executable trigger
--       functions owned by supabase_storage_admin, SECURITY INVOKER
--   * S-3 storage DELETE policy, S-4 SQLSTATE handling
--   * index.html and all application source
-- ---------------------------------------------------------------------
