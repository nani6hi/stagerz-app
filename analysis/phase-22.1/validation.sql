-- =====================================================================
-- STAGERZ - Phase 22.1 - Legacy containment validation
-- =====================================================================
--  ####  DRAFT - NOT EXECUTED - RUN ONLY AS PART OF THE APPROVED APPLY  ####
--
-- Project ref : edxicnafggnnvcdvxemk ONLY.
-- Run so far : Part A ONCE, read-only, 2026-09-19, as the pre-change
--              baseline (remediation-plan.md section 7.3). Part B NEVER.
-- Keys       : no check here uses any client key; the historical-key HTTP
--              probe (V-13b) was NOT approved by the owner.
-- Privacy    : every check returns booleans, counts, SQLSTATEs or md5
--               fingerprints. No row content, email, id or key is read out.
--
-- PART A  - read-only catalog/aggregate checks (V-1 .. V-10 catalog side).
--           Safe to run before and after the change; before the change it
--           documents the failing baseline.
-- PART B  - behavioural checks as the real client roles (SET LOCAL ROLE),
--           inside ONE DO block that ALWAYS ends in RAISE EXCEPTION, so
--           every probe - including the probe table in B-7 and the
--           simulated re-grant in B-6 - is rolled back. Results are
--           reported in the exception message ("VALIDATION RESULTS (rolled
--           back)"), the same convention as Phase 21.3 R-5.
--           Part B attempts writes; run it ONLY AFTER remediation.sql,
--           where every write attempt is expected to be refused. Running
--           it before the change is not permitted (the writes would
--           succeed inside the transaction before being rolled back).
-- =====================================================================


-- ---------------------------------------------------------------------
-- PART A - catalog (read-only). Expected post-change value in [brackets].
-- ---------------------------------------------------------------------
-- P221-VALIDATION-A-v1
WITH t(n) AS (VALUES ('follows'),('likes'),('notifications'),('profiles'),('users'),('wanted_posts')),
priv AS (
  SELECT t.n,
    has_table_privilege('anon',          format('public.%I',t.n), 'SELECT')                              AS anon_sel,
    has_table_privilege('anon',          format('public.%I',t.n), 'INSERT,UPDATE,DELETE')                AS anon_dml,
    has_table_privilege('authenticated', format('public.%I',t.n), 'SELECT,INSERT,UPDATE,DELETE')         AS auth_any,
    has_table_privilege('anon',          format('public.%I',t.n), 'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     OR has_table_privilege('authenticated', format('public.%I',t.n), 'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') AS other_priv,
    has_any_column_privilege('anon', format('public.%I',t.n), 'SELECT,INSERT,UPDATE,REFERENCES')
     OR has_any_column_privilege('authenticated', format('public.%I',t.n), 'SELECT,INSERT,UPDATE,REFERENCES') AS col_priv,
    EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=t.n
            AND p.policyname='p221_containment_deny_client' AND p.permissive='RESTRICTIVE' AND p.cmd='ALL'
            AND p.qual='false' AND p.with_check='false'
            AND p.roles @> '{anon,authenticated}'::name[] AND p.roles <@ '{anon,authenticated}'::name[]) AS deny_policy
  FROM t)
SELECT jsonb_build_object(
  'V1_anon_select_tables',        (SELECT count(*) FROM priv WHERE anon_sel),                 -- [0]
  'V2_anon_dml_tables',           (SELECT count(*) FROM priv WHERE anon_dml),                 -- [0]
  'V3_authenticated_any_tables',  (SELECT count(*) FROM priv WHERE auth_any),                 -- [0]
  'V3_column_priv_tables',        (SELECT count(*) FROM priv WHERE col_priv),                 -- [0]
  'V4_truncate_etc_tables',       (SELECT count(*) FROM priv WHERE other_priv),               -- [0]
  'V1_deny_policy_tables',        (SELECT count(*) FROM priv WHERE deny_policy),              -- [6]
  'V1_rls_enabled_tables',        (SELECT count(*) FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
                                    WHERE s.nspname='public' AND c.relkind='r' AND c.relrowsecurity),        -- [6]
  'V1_policies_total',            (SELECT count(*) FROM pg_policies WHERE schemaname='public'),             -- [24]
  'V5_client_defacl_priv_tuples', (SELECT count(*) FROM pg_default_acl d, aclexplode(d.defaclacl) x
                                    WHERE pg_get_userbyid(d.defaclrole)='postgres'
                                      AND d.defaclnamespace::regnamespace::text IN ('public','storage')
                                      AND d.defaclobjtype IN ('r','S')
                                      AND x.grantee IN ('anon'::regrole::oid,'authenticated'::regrole::oid)),  -- [0]  (pre-change 44 privilege tuples)
  'V5_defacl_entries',            (SELECT count(*) FROM pg_default_acl),                                    -- [24] (O-1 skipped)
  'V5_defacl_global',             (SELECT count(*) FROM pg_default_acl WHERE defaclnamespace=0),            -- [0]  (O-1 skipped)
  'V5_platform_defacl_tuples',    (SELECT count(*) FROM pg_default_acl d, aclexplode(d.defaclacl) x
                                    WHERE pg_get_userbyid(d.defaclrole)='supabase_admin'
                                      AND d.defaclnamespace::regnamespace::text='public'
                                      AND x.grantee IN ('anon'::regrole::oid,'authenticated'::regrole::oid)), -- [24] residual, platform-owned, unchanged
  'V6_rls_auto_enable_anon',      has_function_privilege('anon','public.rls_auto_enable()','EXECUTE'),          -- [false]
  'V6_rls_auto_enable_auth',      has_function_privilege('authenticated','public.rls_auto_enable()','EXECUTE'), -- [false]
  'V6_rls_auto_enable_acl',       (SELECT proacl::text FROM pg_proc WHERE oid='public.rls_auto_enable()'::regprocedure),
                                                                  -- [{postgres=X/postgres,service_role=X/postgres}]
  'V6_event_trigger_enabled',     EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname='ensure_rls' AND evtenabled='O'), -- [true]
  'V7_rows', jsonb_build_object('users',(SELECT count(*) FROM public.users),'wanted_posts',(SELECT count(*) FROM public.wanted_posts),
             'profiles',(SELECT count(*) FROM public.profiles),'notifications',(SELECT count(*) FROM public.notifications),
             'follows',(SELECT count(*) FROM public.follows),'likes',(SELECT count(*) FROM public.likes)),
                                                                  -- [users 3, wanted_posts 5, others 0]
  'V8_auth_users',                (SELECT count(*) FROM auth.users),                                        -- [2]
  'V8_auth_identities',           (SELECT count(*) FROM auth.identities),                                   -- [2]
  'V9_storage_buckets',           (SELECT count(*) FROM storage.buckets),                                   -- [0]
  'V9_storage_objects',           (SELECT count(*) FROM storage.objects),                                   -- [0]
  'V9_storage_policies',          (SELECT count(*) FROM pg_policies WHERE schemaname='storage'),            -- [0]
  'fp_col_md5',                   (SELECT md5(string_agg(table_name||'.'||column_name||':'||data_type,'|' ORDER BY table_name,ordinal_position))
                                    FROM information_schema.columns WHERE table_schema='public'),            -- [e038cf2a45b7c033e4cb4a5e81bf0779]
  'fp_fn_def_md5',                md5(pg_get_functiondef('public.rls_auto_enable()'::regprocedure)),        -- [6998ea6b4c2480f5d2e34b5dcf3f8d36]
  'max_activity', jsonb_build_object(
      'users_updated',(SELECT max(updated_at) FROM public.users),
      'auth_last_sign_in',(SELECT max(last_sign_in_at) FROM auth.users),
      'auth_updated',(SELECT max(updated_at) FROM auth.users))    -- [all <= 2026-07-12]
) AS p221_validation_a;


-- ---------------------------------------------------------------------
-- PART B - behavioural, ALWAYS ROLLED BACK. Run only after remediation.
-- ---------------------------------------------------------------------
-- P221-VALIDATION-B-v1
DO $p221v$
DECLARE
  tbls   constant text[] := array['follows','likes','notifications','profiles','users','wanted_posts'];
  roles_ constant text[] := array['anon','authenticated'];
  r text; t text; st text; ok int := 0; bad int := 0; lines text := ''; n bigint; rls boolean; acl text;
  -- Each probe runs as a client role in its own BEGIN/EXCEPTION sub-block and
  -- PASSES only if it fails with the expected SQLSTATE. For B-7a/b, 0A000
  -- ("can only be called as ... trigger") would mean the EXECUTE check was
  -- passed: FAIL.
BEGIN
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'P221V: run as postgres'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND policyname='p221_containment_deny_client') THEN
    RAISE EXCEPTION 'P221V: remediation not applied - Part B must not run before remediation.sql';
  END IF;

  -- B-1 .. B-5: every table x every client role x every operation -> 42501
  FOREACH r IN ARRAY roles_ LOOP
    FOREACH t IN ARRAY tbls LOOP
      -- B-1 SELECT (V-1 / V-3)
      st := 'none';
      BEGIN EXECUTE format('SET LOCAL ROLE %I', r); EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n; RESET ROLE;
      EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
      IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B1 %s SELECT %s -> %s;', r, t, st); END IF;
      -- B-2 INSERT (V-2)
      st := 'none';
      BEGIN EXECUTE format('SET LOCAL ROLE %I', r); EXECUTE format('INSERT INTO public.%I DEFAULT VALUES', t); RESET ROLE;
      EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
      IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B2 %s INSERT %s -> %s;', r, t, st); END IF;
      -- B-3 UPDATE (V-2)
      st := 'none';
      BEGIN EXECUTE format('SET LOCAL ROLE %I', r); EXECUTE format('UPDATE public.%I SET id = id WHERE false', t); RESET ROLE;
      EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
      IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B3 %s UPDATE %s -> %s;', r, t, st); END IF;
      -- B-4 DELETE (V-2)
      st := 'none';
      BEGIN EXECUTE format('SET LOCAL ROLE %I', r); EXECUTE format('DELETE FROM public.%I WHERE false', t); RESET ROLE;
      EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
      IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B4 %s DELETE %s -> %s;', r, t, st); END IF;
      -- B-5 TRUNCATE (V-4)
      st := 'none';
      BEGIN EXECUTE format('SET LOCAL ROLE %I', r); EXECUTE format('TRUNCATE public.%I', t); RESET ROLE;
      EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
      IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B5 %s TRUNCATE %s -> %s;', r, t, st); END IF;
    END LOOP;
  END LOOP;  -- 2 roles x 6 tables x 5 ops = 60 probes

  -- B-6 defence in depth (V-13): simulate an accidental future re-grant on the
  --      largest table; the restrictive policy alone must still deny.
  GRANT SELECT, INSERT ON public.wanted_posts TO anon;          -- rolled back with everything else
  st := 'none';
  BEGIN SET LOCAL ROLE anon; SELECT count(*) INTO n FROM public.wanted_posts; RESET ROLE;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
  IF st = 'none' AND n = 0 THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B6a regrant SELECT visible=%s st=%s;', n, st); END IF;
  st := 'none';
  BEGIN SET LOCAL ROLE anon; INSERT INTO public.wanted_posts DEFAULT VALUES; RESET ROLE;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
  -- 42501 = "new row violates row-level security policy". PostgreSQL evaluates RLS WITH CHECK
  -- before NOT NULL constraints (ExecInsert), so 23502 (wanted_posts.title) would mean the row
  -- got PAST the restrictive policy: that is a FAIL. Only 42501 passes.
  IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B6b regrant INSERT st=%s;', st); END IF;

  -- B-7 LG-4 (V-6): client cannot call rls_auto_enable(); the event trigger still fires.
  st := 'none';
  BEGIN SET LOCAL ROLE anon; PERFORM public.rls_auto_enable(); RESET ROLE;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
  IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B7a anon rls_auto_enable st=%s;', st); END IF;
  st := 'none';
  BEGIN SET LOCAL ROLE authenticated; PERFORM public.rls_auto_enable(); RESET ROLE;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; RESET ROLE; END;
  IF st = '42501' THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B7b authenticated rls_auto_enable st=%s;', st); END IF;

  CREATE TABLE public.p221_probe (id int);                       -- rolled back
  SELECT c.relrowsecurity, coalesce(c.relacl::text,'<null>') INTO rls, acl FROM pg_class c WHERE c.oid = 'public.p221_probe'::regclass;
  -- B-7c ensure_rls still fires after the EXECUTE revoke
  IF rls THEN ok := ok + 1; ELSE bad := bad + 1; lines := lines || ' FAIL B7c ensure_rls did not enable RLS on new table;'; END IF;
  -- B-8 LG-2 (V-5): a NEW postgres-created table gets no client-role grant
  IF NOT has_table_privilege('anon','public.p221_probe','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     AND NOT has_table_privilege('authenticated','public.p221_probe','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') THEN
    ok := ok + 1; ELSE bad := bad + 1; lines := lines || format(' FAIL B8 new table acl=%s;', acl); END IF;

  -- expected: 60 + 2 + 3 + 1 = 66 PASS, 0 FAIL
  RAISE EXCEPTION 'VALIDATION RESULTS (rolled back): PASS=% FAIL=% (expected 66/0)%', ok, bad,
    CASE WHEN lines = '' THEN '' ELSE ' |' || lines END;
END
$p221v$;
