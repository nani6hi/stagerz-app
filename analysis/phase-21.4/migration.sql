-- =====================================================================
-- STAGERZ — Phase 21.4 — S-1 remediation
-- =====================================================================
--  ####  THIS FILE IS AN EXECUTABLE MIGRATION.  ####
--
-- It is NOT a descriptive snapshot. It differs deliberately and
-- fundamentally from the .sql files in analysis/phase-21.3/, which are
-- read-only extraction artifacts carrying the opposite header and
-- containing no executable statements.
--
-- (The counterpart marker string used by those snapshots is deliberately
--  not reproduced here, so a grep for it cannot misclassify this file.)
--
-- The two statements below WERE APPLIED to the live project.
--
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Applied     : 2026-08-23
-- Approved by : user, explicitly, as the ONLY permitted production mutation
-- Addresses   : S-1 — unauthenticated write path to public.users through
--               the auto-updatable public.public_profiles view
-- =====================================================================

-- ---------------------------------------------------------------------
-- PRE-CHANGE STATE (captured immediately before applying)
-- ---------------------------------------------------------------------
--   relacl: postgres=arwdDxtm/postgres | anon=arwdDxtm/postgres
--         | authenticated=arwdDxtm/postgres | service_role=arwdDxtm/postgres
--
--   anon          : SELECT=t INSERT=t UPDATE=t DELETE=t
--   authenticated : SELECT=t INSERT=t UPDATE=t DELETE=t
--   service_role  : SELECT=t INSERT=t UPDATE=t DELETE=t
--   view owner    : postgres      reloptions: (none)
--   viewdef md5   : d86256ac1ad53a250c96c315ed69a52e
--   users RLS     : enabled=true forced=false policies=2
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- MIGRATION — exactly the two approved statements, nothing else
-- ---------------------------------------------------------------------

REVOKE ALL ON TABLE public.public_profiles FROM anon, authenticated;

GRANT SELECT ON TABLE public.public_profiles TO anon, authenticated;

-- ---------------------------------------------------------------------
-- ROLLBACK — restores the exact prior ACL (arwdDxtm for both roles)
-- ---------------------------------------------------------------------
--   GRANT ALL ON TABLE public.public_profiles TO anon, authenticated;
--
-- Rollback re-opens S-1 and must not be run except to recover from a
-- confirmed regression, under the same approval as any production change.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- DELIBERATELY NOT CHANGED
-- ---------------------------------------------------------------------
--   * security_invoker on the view — would break every profile read;
--     neither anon nor authenticated can SELECT public.users, and the
--     users SELECT policy is own-row-only. The definer semantics are
--     load-bearing: this view is an intentional controlled read gateway.
--   * public.users RLS (enabled, not forced) — untouched
--   * ALTER DEFAULT PRIVILEGES (finding S-5, the root cause) — untouched
--   * service_role privileges — untouched (trusted backend role)
--   * S-2 test tables, S-3 storage DELETE policy, S-4 SQLSTATE handling
-- ---------------------------------------------------------------------
