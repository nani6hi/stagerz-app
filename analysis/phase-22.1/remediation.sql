-- =====================================================================
-- STAGERZ - Phase 22.1 - Legacy Supabase containment (LG-1 .. LG-4)
-- =====================================================================
--  ####  EXECUTABLE REMEDIATION - APPLIED 2026-09-19 - DO NOT RE-EXECUTE  ####
--
-- APPLIED to edxicnafggnnvcdvxemk on 2026-09-19, between 13:14:49 and
-- 13:17:16 UTC, as ONE execute_sql call containing this file verbatim as
-- committed in b31bd26 (SHA-256 b4bb0484593d8094cb5239188f011815f484de6de55467b2a803af18bd188f37).
-- Result: committed; pre-flight and post-flight passed. No migration id
-- (migration tool not used). Validation: Part A as expected, Part B
-- PASS=66 FAIL=0. See apply-validation-record-2026-09-19.md.
-- This annotated copy differs from the executed text in these header
-- comment lines only; the DO block is byte-identical. Re-running it would
-- stop at the pre-flight ("containment policy already present").
--
-- (Original header line, prepared text: "DRAFT - NOT APPLIED - DO NOT
--  EXECUTE WITHOUT OWNER APPROVAL".)
--
-- Project ref : edxicnafggnnvcdvxemk  ("stagerz-app", legacy Telegram-era)
--               NEVER run against kbnmkyvbwkuvcklywdhk.
-- Prepared    : 2026-09-19 (plan / pre-change review)
-- Execute as  : postgres (current_user = session_user = postgres), via a
--               single direct SQL execution (execute_sql), NOT the
--               migration tool: this project has no migration history
--               and apply_migration would create supabase_migrations as
--               an extra, unapproved change.
-- Atomicity   : ONE DO block. Any failed assertion raises, and the whole
--               block - pre-flight, changes, post-flight - is rolled back.
--
-- Changes (core set, see remediation-plan.md section 4):
--   R-1  REVOKE ALL on the 6 public tables FROM anon, authenticated
--        (LG-1 layer B, LG-3)
--   R-2  ADD one RESTRICTIVE deny-all policy per table for anon,
--        authenticated (LG-1 defence in depth; legacy policies kept)
--   R-3  ALTER DEFAULT PRIVILEGES FOR ROLE postgres, public + storage,
--        TABLES + SEQUENCES: REVOKE ALL FROM anon, authenticated (LG-2)
--   R-4  REVOKE EXECUTE ON public.rls_auto_enable() FROM PUBLIC, anon,
--        authenticated (LG-4)
--
-- Optional O-1 (function default privileges) is at the end, COMMENTED
-- OUT. OWNER DECISION 2026-09-19: O-1 SKIPPED - it is NOT executed in
-- Phase 22.1 (optional residual hardening item, not a blocker).
--
-- Rules carried over from Phase 21.6 (S-5):
--   * FOR ROLE postgres and IN SCHEMA are mandatory (silent no-op /
--     new global entry otherwise).
--   * REVOKE ALL, never an enumerated list (covers MAINTAIN and any
--     future privilege type).
--   * postgres and service_role are never named in a revoke.
-- =====================================================================

DO $p221$
DECLARE
  -- pre-change fingerprints, captured read-only 2026-09-19 (P221-PRECHANGE-FINGERPRINT-v1)
  c_relacl_md5        constant text := 'ff81dd8ad8ae8264d531931a0cbd52f0';
  c_policies_md5      constant text := 'a5ddf5ad03f8c5c333470e4af9e5d292';
  c_defacl_md5_all    constant text := '5a6e897e1a22110d8b9cefb7c128cfa6';
  c_defacl_md5_untgt  constant text := '94a24e2550d616f304d33cc6f4b5d9a5';
  c_fn_def_md5        constant text := '6998ea6b4c2480f5d2e34b5dcf3f8d36';
  c_fn_acl_pre        constant text := '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}';
  c_fn_acl_post       constant text := '{postgres=X/postgres,service_role=X/postgres}';
  c_col_md5           constant text := 'e038cf2a45b7c033e4cb4a5e81bf0779';
  c_st_relacl_md5     constant text := '04360dda0d641c7805b22e23d8c6e59b';
  c_st_fnacl_md5      constant text := 'c90dd3853e9865ba8ca26d33bade167f';
  c_tbl_acl_pre       constant text := '{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}';
  c_tbl_acl_post      constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}';
  c_tables            constant text[] := array['follows','likes','notifications','profiles','users','wanted_posts'];
  c_rows_pre          constant text := '{"likes": 0, "users": 3, "follows": 0, "profiles": 0, "wanted_posts": 5, "notifications": 0}';

  v text; t text; j jsonb; rows_pre jsonb;

BEGIN
  -- ------------------------------------------------------------------
  -- PRE-FLIGHT (read-only). Every check must match the reviewed state.
  -- ------------------------------------------------------------------
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'P221 PRE: must run as postgres (current_user=%, session_user=%)', current_user, session_user;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'public')
     OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
                WHERE s.nspname = 'public' AND c.relname = 'collaboration_assets') THEN
    -- collaboration_assets exists only on kbnmkyvbwkuvcklywdhk: wrong-project guard
    RAISE EXCEPTION 'P221 PRE: wrong project (Foundation v2 schema detected)';
  END IF;
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
      WHERE s.nspname = 'public' AND c.relkind IN ('r','v','m','p','f','S')) <> 6 THEN
    RAISE EXCEPTION 'P221 PRE: expected exactly 6 relations in public';
  END IF;
  IF (SELECT data_type FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'id') IS DISTINCT FROM 'bigint' THEN
    RAISE EXCEPTION 'P221 PRE: public.users.id is not bigint (not the legacy v1 schema)';
  END IF;

  SELECT md5(string_agg(c.relname||':'||coalesce(c.relacl::text,''),'|' ORDER BY c.relname)) INTO v
    FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'public';
  IF v <> c_relacl_md5 THEN RAISE EXCEPTION 'P221 PRE: public relacl fingerprint drifted (%)', v; END IF;

  SELECT md5(string_agg(tablename||':'||policyname||':'||cmd||':'||permissive||':'||roles::text||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' ORDER BY tablename, policyname)) INTO v
    FROM pg_policies WHERE schemaname = 'public';
  IF v <> c_policies_md5 THEN RAISE EXCEPTION 'P221 PRE: policy fingerprint drifted (%)', v; END IF;

  SELECT md5(string_agg(o||':'||s||':'||t2||':'||a,'|' ORDER BY o, s, t2)) INTO v FROM
    (SELECT pg_get_userbyid(defaclrole) o, defaclnamespace::regnamespace::text s, defaclobjtype::text t2, defaclacl::text a FROM pg_default_acl) d;
  IF v <> c_defacl_md5_all THEN RAISE EXCEPTION 'P221 PRE: default-ACL fingerprint drifted (%)', v; END IF;
  IF (SELECT count(*) FROM pg_default_acl) <> 24 OR (SELECT count(*) FROM pg_default_acl WHERE defaclnamespace = 0) <> 0 THEN
    RAISE EXCEPTION 'P221 PRE: default-ACL entry count drifted';
  END IF;

  IF md5(pg_get_functiondef('public.rls_auto_enable()'::regprocedure)) <> c_fn_def_md5 THEN
    RAISE EXCEPTION 'P221 PRE: rls_auto_enable() definition drifted';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rls_auto_enable()'::regprocedure) <> c_fn_acl_pre THEN
    RAISE EXCEPTION 'P221 PRE: rls_auto_enable() ACL drifted';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND policyname = 'p221_containment_deny_client') THEN
    RAISE EXCEPTION 'P221 PRE: containment policy already present - already applied?';
  END IF;

  rows_pre := jsonb_build_object(
    'users',(SELECT count(*) FROM public.users), 'wanted_posts',(SELECT count(*) FROM public.wanted_posts),
    'profiles',(SELECT count(*) FROM public.profiles), 'notifications',(SELECT count(*) FROM public.notifications),
    'follows',(SELECT count(*) FROM public.follows), 'likes',(SELECT count(*) FROM public.likes));
  IF rows_pre <> c_rows_pre::jsonb THEN RAISE EXCEPTION 'P221 PRE: row counts drifted (%)', rows_pre; END IF;
  IF (SELECT count(*) FROM auth.users) <> 2 THEN RAISE EXCEPTION 'P221 PRE: auth.users count drifted'; END IF;
  IF (SELECT count(*) FROM storage.buckets) <> 0 OR (SELECT count(*) FROM storage.objects) <> 0 THEN
    RAISE EXCEPTION 'P221 PRE: storage not empty';
  END IF;

  -- ------------------------------------------------------------------
  -- CHANGES
  -- ------------------------------------------------------------------
  -- R-1  (LG-1 layer B, LG-3): no client-role table privilege of any kind
  REVOKE ALL ON TABLE public.follows, public.likes, public.notifications,
                      public.profiles, public.users, public.wanted_posts
    FROM anon, authenticated;

  -- R-2  (LG-1 defence in depth): restrictive deny-all for client roles.
  --      Restrictive policies are AND-ed with the permissive ones, so the
  --      legacy USING (true) policies can no longer admit any row for
  --      anon/authenticated even if table privileges are re-granted later.
  --      The 18 legacy policies are kept unchanged as historical record.
  FOREACH t IN ARRAY c_tables LOOP
    EXECUTE format(
      'CREATE POLICY p221_containment_deny_client ON public.%I AS RESTRICTIVE FOR ALL TO anon, authenticated USING (false) WITH CHECK (false)', t);
    EXECUTE format(
      'COMMENT ON POLICY p221_containment_deny_client ON public.%I IS %L', t,
      'Phase 22.1 legacy containment: deny all client-role access. Remove only via analysis/phase-22.1/rollback.sql with owner approval.');
  END LOOP;

  -- R-3  (LG-2): future tables / views / sequences created by postgres
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON TABLES    FROM anon, authenticated;
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON TABLES    FROM anon, authenticated;
  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON SEQUENCES FROM anon, authenticated;

  -- R-4  (LG-4): event-trigger function not callable by client roles.
  --      The event trigger ensure_rls keeps firing: firing does not check
  --      EXECUTE (verified behaviourally by validation.sql B-7).
  REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;

  -- ------------------------------------------------------------------
  -- POST-FLIGHT
  -- ------------------------------------------------------------------
  FOREACH t IN ARRAY c_tables LOOP
    SELECT c.relacl::text INTO v FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
      WHERE s.nspname = 'public' AND c.relname = t;
    IF v <> c_tbl_acl_post THEN RAISE EXCEPTION 'P221 POST: %.relacl = %', t, v; END IF;
    IF has_table_privilege('anon', format('public.%I', t), 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
       OR has_table_privilege('authenticated', format('public.%I', t), 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') THEN
      RAISE EXCEPTION 'P221 POST: client role still holds a privilege on %', t;
    END IF;
    IF has_any_column_privilege('anon', format('public.%I', t), 'SELECT,INSERT,UPDATE,REFERENCES')
       OR has_any_column_privilege('authenticated', format('public.%I', t), 'SELECT,INSERT,UPDATE,REFERENCES') THEN
      RAISE EXCEPTION 'P221 POST: client role still holds a column privilege on %', t;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = t
                   AND policyname = 'p221_containment_deny_client' AND permissive = 'RESTRICTIVE'
                   AND cmd = 'ALL' AND roles @> '{anon,authenticated}'::name[] AND roles <@ '{anon,authenticated}'::name[] AND qual = 'false' AND with_check = 'false') THEN
      RAISE EXCEPTION 'P221 POST: containment policy missing or wrong on %', t;
    END IF;
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = format('public.%I', t)::regclass) THEN
      RAISE EXCEPTION 'P221 POST: RLS not enabled on %', t;
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'public') <> 24 THEN
    RAISE EXCEPTION 'P221 POST: expected 24 policies (18 legacy + 6 containment)';
  END IF;
  SELECT md5(string_agg(tablename||':'||policyname||':'||cmd||':'||permissive||':'||roles::text||':'||coalesce(qual,'')||':'||coalesce(with_check,''),'|' ORDER BY tablename, policyname)) INTO v
    FROM pg_policies WHERE schemaname = 'public' AND policyname <> 'p221_containment_deny_client';
  IF v <> c_policies_md5 THEN RAISE EXCEPTION 'P221 POST: a legacy policy changed'; END IF;

  IF EXISTS (SELECT 1 FROM pg_default_acl d, aclexplode(d.defaclacl) x
             WHERE pg_get_userbyid(d.defaclrole) = 'postgres'
               AND d.defaclnamespace::regnamespace::text IN ('public','storage')
               AND d.defaclobjtype IN ('r','S')
               AND x.grantee IN ('anon'::regrole::oid, 'authenticated'::regrole::oid)) THEN
    RAISE EXCEPTION 'P221 POST: targeted default ACL still grants to a client role';
  END IF;
  IF (SELECT count(*) FROM pg_default_acl) <> 24 OR (SELECT count(*) FROM pg_default_acl WHERE defaclnamespace = 0) <> 0 THEN
    RAISE EXCEPTION 'P221 POST: default-ACL entry count changed (IN SCHEMA trap?)';
  END IF;
  SELECT md5(string_agg(o||':'||s||':'||t2||':'||a,'|' ORDER BY o, s, t2)) INTO v FROM
    (SELECT pg_get_userbyid(defaclrole) o, defaclnamespace::regnamespace::text s, defaclobjtype::text t2, defaclacl::text a FROM pg_default_acl
      WHERE NOT (pg_get_userbyid(defaclrole) = 'postgres' AND defaclnamespace::regnamespace::text IN ('public','storage') AND defaclobjtype IN ('r','S'))) d;
  IF v <> c_defacl_md5_untgt THEN RAISE EXCEPTION 'P221 POST: an untargeted default-ACL entry changed'; END IF;

  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rls_auto_enable()'::regprocedure) <> c_fn_acl_post THEN
    RAISE EXCEPTION 'P221 POST: rls_auto_enable() ACL unexpected';
  END IF;
  IF has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE') THEN
    RAISE EXCEPTION 'P221 POST: rls_auto_enable() still client-executable';
  END IF;
  IF md5(pg_get_functiondef('public.rls_auto_enable()'::regprocedure)) <> c_fn_def_md5 THEN
    RAISE EXCEPTION 'P221 POST: rls_auto_enable() definition changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls' AND evtenabled = 'O'
                 AND evtfoid = 'public.rls_auto_enable()'::regprocedure) THEN
    RAISE EXCEPTION 'P221 POST: event trigger ensure_rls missing or disabled';
  END IF;

  -- untouched surfaces
  SELECT md5(string_agg(table_name||'.'||column_name||':'||data_type,'|' ORDER BY table_name, ordinal_position)) INTO v
    FROM information_schema.columns WHERE table_schema = 'public';
  IF v <> c_col_md5 THEN RAISE EXCEPTION 'P221 POST: column structure changed'; END IF;
  SELECT md5(string_agg(c.relname||':'||coalesce(c.relacl::text,''),'|' ORDER BY c.relname)) INTO v
    FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'storage';
  IF v <> c_st_relacl_md5 THEN RAISE EXCEPTION 'P221 POST: storage relation ACLs changed'; END IF;
  SELECT md5(string_agg(p.oid::regprocedure::text||':'||coalesce(p.proacl::text,''),'|' ORDER BY p.oid::regprocedure::text)) INTO v
    FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace WHERE s.nspname = 'storage';
  IF v <> c_st_fnacl_md5 THEN RAISE EXCEPTION 'P221 POST: storage function ACLs changed'; END IF;

  j := jsonb_build_object(
    'users',(SELECT count(*) FROM public.users), 'wanted_posts',(SELECT count(*) FROM public.wanted_posts),
    'profiles',(SELECT count(*) FROM public.profiles), 'notifications',(SELECT count(*) FROM public.notifications),
    'follows',(SELECT count(*) FROM public.follows), 'likes',(SELECT count(*) FROM public.likes));
  IF j <> rows_pre THEN RAISE EXCEPTION 'P221 POST: row counts changed (%)', j; END IF;
  IF (SELECT count(*) FROM auth.users) <> 2 THEN RAISE EXCEPTION 'P221 POST: auth.users count changed'; END IF;
  IF (SELECT count(*) FROM storage.buckets) <> 0 OR (SELECT count(*) FROM storage.objects) <> 0 THEN
    RAISE EXCEPTION 'P221 POST: storage changed';
  END IF;

  RAISE NOTICE 'P221 containment applied: pre-flight PASS, R-1..R-4 done, post-flight PASS';
END
$p221$;

-- =====================================================================
-- OPTIONAL O-1 - function default privileges (LG-2, function part)
-- COMMENTED OUT. SKIPPED BY THE OWNER (2026-09-19) - NOT executed in
-- Phase 22.1. Would need a new, explicit owner decision. Originally: apply as a
-- separate execution after the core block has passed validation.
--
-- Why optional: the per-schema FUNCTIONS entries grant EXECUTE to
-- anon/authenticated, but PostgreSQL's built-in default ALSO grants
-- EXECUTE to PUBLIC on every new function. Revoking only the per-schema
-- entries would look like a fix without being one (Phase 21.6 rule 5).
-- A real fix needs the GLOBAL revoke from PUBLIC as well, which applies to
-- every function postgres creates in ANY schema. On this dormant project
-- that has no practical downside, but it is broader than the findings.
--
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public  REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;   -- adds ONE global entry
--
-- Expected after O-1: pg_default_acl = 25 entries, 1 global
--   (postgres / 0 / f = {postgres=X/postgres}); the two per-schema FUNCTIONS
--   entries = {postgres=X/postgres,service_role=X/postgres}.
-- =====================================================================
