-- =====================================================================
-- STAGERZ - Phase 22.1 - Legacy containment ROLLBACK
-- =====================================================================
--  ####  DRAFT - NEVER EXECUTED - REQUIRES SEPARATE OWNER APPROVAL  ####
--
-- Project ref : edxicnafggnnvcdvxemk ONLY.
--
-- WARNING: a full rollback RE-OPENS LG-1, LG-2, LG-3 and LG-4 - the legacy
-- tester data becomes publicly readable and writable again through the
-- anon key published in git history. It exists only to recover from a
-- confirmed, unexpected regression. Nothing depends on this project, so
-- no such regression is anticipated.
--
-- Accidental-execution guard: the block does NOTHING unless the executing
-- session first sets an explicit approval flag naming the section(s):
--
--     SET LOCAL p221.rollback_approved = 'R-4';          -- one section
--     SET LOCAL p221.rollback_approved = 'R-1,R-2,R-3,R-4';  -- all
--
-- in the same transaction as the DO block, i.e. executed as ONE script:
--     BEGIN; SET LOCAL p221.rollback_approved = '...'; <the DO block below>; COMMIT;
-- SET LOCAL expires at transaction end, so the approval cannot leak into
-- a later execution. Without the flag the block raises and changes nothing.
-- Sections are independent and can be rolled back selectively, e.g. only R-4 if the ensure_rls event trigger were ever
-- found to need client EXECUTE (not expected).
--
-- It restores ONLY what remediation.sql changed:
--   R-1  table privileges of anon/authenticated on the 6 public tables
--   R-2  the 6 p221_containment_deny_client restrictive policies (dropped)
--   R-3  the 4 postgres default-ACL entries (public/storage, TABLES/SEQUENCES)
--   R-4  EXECUTE on public.rls_auto_enable() for PUBLIC, anon, authenticated
-- O-1 was SKIPPED by the owner; its inverse is kept at the end for reference only.
--
-- Semantic, not byte, restoration: GRANT appends ACL items, so the ACL text
-- order after rollback differs from the original, e.g. a table becomes
--   {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres}
-- instead of the original order. The privilege SET is identical; the
-- verification below compares sets via aclexplode, not text.
-- =====================================================================

DO $p221rb$
DECLARE
  approved text := coalesce(current_setting('p221.rollback_approved', true), '');
  secs text[];
  t text;
  c_tables constant text[] := array['follows','likes','notifications','profiles','users','wanted_posts'];
BEGIN
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'P221RB: run as postgres'; END IF;
  IF approved = '' THEN
    RAISE EXCEPTION 'P221RB: not approved - set p221.rollback_approved to the section list first. Nothing changed.';
  END IF;
  secs := string_to_array(replace(approved, ' ', ''), ',');
  IF NOT secs <@ array['R-1','R-2','R-3','R-4'] THEN
    RAISE EXCEPTION 'P221RB: unknown section in %', approved;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
             WHERE s.nspname = 'public' AND c.relname = 'collaboration_assets') THEN
    RAISE EXCEPTION 'P221RB: wrong project';
  END IF;

  IF 'R-1' = ANY (secs) THEN
    GRANT ALL ON TABLE public.follows, public.likes, public.notifications,
                       public.profiles, public.users, public.wanted_posts
      TO anon, authenticated;                       -- restores arwdDxtm (incl. TRUNCATE, MAINTAIN)
  END IF;

  IF 'R-2' = ANY (secs) THEN
    FOREACH t IN ARRAY c_tables LOOP
      EXECUTE format('DROP POLICY IF EXISTS p221_containment_deny_client ON public.%I', t);
    END LOOP;
  END IF;

  IF 'R-3' = ANY (secs) THEN
    ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  GRANT ALL ON TABLES    TO anon, authenticated;
    ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  GRANT ALL ON SEQUENCES TO anon, authenticated;
    ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES    TO anon, authenticated;
    ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON SEQUENCES TO anon, authenticated;
  END IF;

  IF 'R-4' = ANY (secs) THEN
    GRANT EXECUTE ON FUNCTION public.rls_auto_enable() TO PUBLIC, anon, authenticated;
  END IF;

  -- verification (set-based) of each rolled-back section
  IF 'R-1' = ANY (secs) THEN
    FOREACH t IN ARRAY c_tables LOOP
      IF NOT has_table_privilege('anon', format('public.%I', t), 'SELECT')
         OR NOT has_table_privilege('authenticated', format('public.%I', t), 'TRUNCATE') THEN
        RAISE EXCEPTION 'P221RB: R-1 verification failed on %', t;
      END IF;
    END LOOP;
  END IF;
  IF 'R-2' = ANY (secs) AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND policyname = 'p221_containment_deny_client') THEN
    RAISE EXCEPTION 'P221RB: R-2 verification failed';
  END IF;
  IF 'R-3' = ANY (secs) AND (SELECT count(*) FROM pg_default_acl d, aclexplode(d.defaclacl) x
       WHERE pg_get_userbyid(d.defaclrole) = 'postgres' AND d.defaclnamespace::regnamespace::text IN ('public','storage')
         AND d.defaclobjtype IN ('r','S') AND x.grantee IN ('anon'::regrole::oid, 'authenticated'::regrole::oid)) <> 44 THEN
    RAISE EXCEPTION 'P221RB: R-3 verification failed (expected 44 privilege tuples)';
  END IF;
  IF 'R-4' = ANY (secs) AND NOT (has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE')
       AND EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) x WHERE p.oid = 'public.rls_auto_enable()'::regprocedure AND x.grantee = 0)) THEN
    RAISE EXCEPTION 'P221RB: R-4 verification failed';
  END IF;

  RAISE NOTICE 'P221 rollback applied for sections %', secs;
END
$p221rb$;

-- =====================================================================
-- O-1 ROLLBACK (only if O-1 was applied) - commented out
--
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;   -- removes the global entry
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  GRANT ALL ON FUNCTIONS TO anon, authenticated;
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON FUNCTIONS TO anon, authenticated;
-- Expected after: pg_default_acl back to 24 entries, 0 global.
-- =====================================================================
--
-- NON-DATABASE ROLLBACK (only if the corresponding action was approved and done)
--   N-1 legacy API keys disabled  -> Dashboard > Project Settings > API Keys >
--        "Legacy API keys" > Re-enable. Restores the same anon and
--        service_role JWTs (they are derived from the unchanged JWT secret).
--   N-2 sign-ups disabled          -> Dashboard > Authentication > Sign In /
--        Providers > "Allow new users to sign up" back to its recorded
--        prior value.
-- =====================================================================
