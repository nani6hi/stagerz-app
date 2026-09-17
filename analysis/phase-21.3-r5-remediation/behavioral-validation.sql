-- =====================================================================
-- STAGERZ - Phase 21.3 R-5 remediation - W-1 / W-3 / W-4
-- POST-APPLY BEHAVIOURAL VALIDATION - ROLLBACK-ONLY TEMPLATE
-- =====================================================================
--  ####  TEMPLATE - NOT RUN. RUN ONLY AFTER migration.sql IS APPLIED  ####
--  ####  AND ONLY WITH EXPLICIT APPROVAL.                              ####
--
-- Rollback guarantee: the whole script is ONE DO statement that always
-- ends by RAISING an exception carrying the results. Every write made
-- here (synthetic auth users and the rows their trigger creates, posts,
-- follows, likes, profile / username edits) is therefore rolled back,
-- whatever the caller's transaction handling is. Nothing is committed;
-- Realtime emits nothing for rolled-back work. The expected final
-- output is an ERROR whose message starts with
-- "VALIDATION RESULTS (rolled back)".
--
-- Identities: SYNTHETIC FIXTURES ONLY, created inside this statement
-- through the normal on_auth_user_created trigger (same technique as
-- analysis/backend-integrity-remediation/
-- behavioral-validation-run-2026-09-16.sql). No existing user or row is
-- read by a test or written. Results contain no identifiers or values.
--   A  onboarded (username set)      - the acting user
--   B  onboarded                     - the other user
--   N  not onboarded (username NULL)
--
-- Role switching mirrors PostgREST: role 'authenticated' plus JWT
-- claims, so auth.uid() and every RLS policy behave as for a real API
-- request. Role 'anon' is used the same way without claims. The
-- executing session must be allowed to SET ROLE authenticated / anon.
-- A GUC change made inside a failing inner block is undone with that
-- block; every block is followed by RESET ROLE.
-- =====================================================================

do $validation$
declare
  results   text[] := '{}';
  v_state   text;
  v_msg     text;
  v_id      uuid;
  v_n       bigint;
  v_txt     text;
  v_bool    boolean;
  a_auth    uuid := gen_random_uuid();
  b_auth    uuid := gen_random_uuid();
  n_auth    uuid := gen_random_uuid();
  a_user    uuid;
  b_user    uuid;
  n_user    uuid;
  a_uname   text;
  b_uname   text;
begin
  perform set_config('search_path', 'public', true);
  if not pg_has_role(current_user, 'authenticated', 'MEMBER')
     or not pg_has_role(current_user, 'anon', 'MEMBER') then
    raise exception 'behavioral-validation: session cannot switch to roles authenticated / anon';
  end if;
  -- the migration must be in effect
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass)
       is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}'
     or position('LEFT JOIN profiles p ON p.user_id = u.id' in pg_get_viewdef('public.public_profiles'::regclass, true)) = 0 then
    raise exception 'behavioral-validation: migration.sql is not in effect';
  end if;

  -- ===== SYNTHETIC FIXTURES ============================================
  insert into auth.users (id, aud, role, raw_user_meta_data) values
    (a_auth, 'authenticated', 'authenticated', '{"display_name":"R5 validation A"}'::jsonb),
    (b_auth, 'authenticated', 'authenticated', '{"display_name":"R5 validation B"}'::jsonb),
    (n_auth, 'authenticated', 'authenticated', '{"display_name":"R5 validation N"}'::jsonb);
  select public_user_id into a_user from public.user_auth_accounts where auth_user_id = a_auth;
  select public_user_id into b_user from public.user_auth_accounts where auth_user_id = b_auth;
  select public_user_id into n_user from public.user_auth_accounts where auth_user_id = n_auth;
  if a_user is null or b_user is null or n_user is null then
    raise exception 'behavioral-validation: fixture users were not created by the trigger';
  end if;
  a_uname := 'zz_r5_validation_a_' || substr(md5(a_user::text), 1, 10);
  b_uname := 'zz_r5_validation_b_' || substr(md5(b_user::text), 1, 10);
  update public.users set username = a_uname where id = a_user;
  update public.users set username = b_uname where id = b_user;
  -- privileged history rows that W-4 must keep readable
  insert into public.follows (follower_id, following_id) values (b_user, a_user);
  insert into public.likes (user_id, post_id, post_type) values (b_user, gen_random_uuid(), 'performance');
  results := results || 'FIXTURES 3 synthetic users (2 onboarded, 1 not), 1 follow, 1 like'::text;
  -- =====================================================================

  -- ---------------------------------------------------------------------
  -- W-1  T1: frontend-shaped wanted post insert (with RETURNING) succeeds
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.wanted_posts (user_id, title, description, role_needed, category,
                                     location, remote, compensation, status)
      values (a_user, 'R5 validation post', 'synthetic', 'validator', 'music',
              '', true, 'rev_share', 'open')
      returning id into v_id;
    results := results || case when v_id is not null
                               then 'T1 PASS frontend-shaped insert succeeded with RETURNING'
                               else 'T1 FAIL no id returned' end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T1 FAIL frontend-shaped insert error ' || v_state);
  end;
  execute 'reset role';

  -- W-1  T2: explicit id is denied
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.wanted_posts (id, user_id, title, role_needed)
      values (gen_random_uuid(), a_user, 'R5 validation explicit id', 'validator');
    results := results || 'T2 FAIL insert with explicit id succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T2 PASS explicit id denied (42501)'
                               else 'T2 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- W-1  T3: explicit created_at is denied
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.wanted_posts (user_id, title, role_needed, created_at)
      values (a_user, 'R5 validation explicit created_at', 'validator', now() + interval '365 days');
    results := results || 'T3 FAIL insert with explicit created_at succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T3 PASS explicit created_at denied (42501)'
                               else 'T3 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- W-1  T4 (regression): a non-onboarded user is still refused by RLS
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', n_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', n_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.wanted_posts (user_id, title, role_needed, status)
      values (n_user, 'R5 validation not onboarded', 'validator', 'open');
    results := results || 'T4 FAIL non-onboarded insert succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'new row violates row-level security%'
                               then 'T4 PASS non-onboarded insert refused by RLS (42501)'
                               else 'T4 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- W-2  T5 (unchanged): Edit Profile update of profiles succeeds
  --      (same column set as saveProfile) and display_name is reflected
  --      in public_profiles (W-3)
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    update public.profiles
       set display_name = 'R5 Edited Name', role = 'validator', location = 'nowhere',
           bio = 'synthetic', skills = array['testing']
     where user_id = a_user;
    get diagnostics v_n = row_count;
    select display_name into v_txt from public.public_profiles where id = a_user;
    results := results || case when v_n = 1 and v_txt = 'R5 Edited Name'
                               then 'T5 PASS profile edit succeeded and public_profiles shows the new display_name'
                               else 'T5 FAIL rows=' || v_n || ' reflected=' || coalesce((v_txt = 'R5 Edited Name')::text, 'null') end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T5 FAIL profile edit error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- W-3  T6: username update is still allowed (saveProfile path)
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    update public.users set username = a_uname || '_x' where id = a_user;
    get diagnostics v_n = row_count;
    select username = a_uname || '_x' into v_bool from public.public_profiles where id = a_user;
    results := results || case when v_n = 1 and coalesce(v_bool, false)
                               then 'T6 PASS username update allowed and visible in public_profiles'
                               else 'T6 FAIL rows=' || v_n end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T6 FAIL username update error ' || v_state);
  end;
  execute 'reset role';

  -- W-3  T7-T11: legacy identity columns are no longer updatable
  declare
    v_col text;
    v_no  int := 7;
  begin
    foreach v_col in array array['first_name', 'last_name', 'photo_url', 'bio', 'location'] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
        perform set_config('request.jwt.claim.sub', a_auth::text, true);
        perform set_config('role', 'authenticated', true);
        execute format('update public.users set %I = %L where id = %L', v_col, 'x', a_user);
        results := results || ('T' || v_no || ' FAIL users.' || v_col || ' update succeeded');
      exception when others then
        get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
        results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                                   then 'T' || v_no || ' PASS users.' || v_col || ' update denied (42501)'
                                   else 'T' || v_no || ' FAIL users.' || v_col || ' unexpected ' || v_state end;
      end;
      execute 'reset role';
      v_no := v_no + 1;
    end loop;
  end;

  -- W-3  T12: legacy first/last name no longer feeds display_name
  update public.users set first_name = 'Legacy', last_name = 'Name' where id = b_user;   -- privileged, rolled back
  select display_name into v_txt from public.public_profiles where id = b_user;
  results := results || case when v_txt = 'R5 validation B'
                             then 'T12 PASS display_name comes from profiles, not users.first/last_name'
                             else 'T12 FAIL display_name not from profiles' end;

  -- W-3  T13: blank profile display_name falls back to username
  update public.profiles set display_name = '   ' where user_id = b_user;                -- privileged, rolled back
  select display_name into v_txt from public.public_profiles where id = b_user;
  results := results || case when v_txt = b_uname
                             then 'T13 PASS blank display_name falls back to username'
                             else 'T13 FAIL username fallback' end;

  -- W-3  T14: blank display_name and no username -> 'STAGERZ Artist'
  update public.profiles set display_name = '' where user_id = n_user;                   -- privileged, rolled back
  select display_name into v_txt from public.public_profiles where id = n_user;
  results := results || case when v_txt = 'STAGERZ Artist'
                             then 'T14 PASS final fallback STAGERZ Artist'
                             else 'T14 FAIL final fallback' end;

  -- W-3  T15: surrounding whitespace is trimmed
  update public.profiles set display_name = '  R5 Padded  ' where user_id = n_user;     -- privileged, rolled back
  select display_name into v_txt from public.public_profiles where id = n_user;
  results := results || case when v_txt = 'R5 Padded'
                             then 'T15 PASS display_name is trimmed'
                             else 'T15 FAIL trimming' end;

  -- W-3  T16: anonymized account shows Deleted User / is_deleted
  update public.users set anonymized_at = now() where id = b_user;                       -- privileged, rolled back
  select display_name = 'Deleted User' and is_deleted into v_bool from public.public_profiles where id = b_user;
  results := results || case when coalesce(v_bool, false)
                             then 'T16 PASS anonymized user shows Deleted User and is_deleted'
                             else 'T16 FAIL anonymized rendering' end;
  update public.users set anonymized_at = null where id = b_user;

  -- W-3  T17: anon sees exactly the seven public columns, one row per user
  begin
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('role', 'anon', true);
    select string_agg(k, ',' order by k) into v_txt
      from (select jsonb_object_keys(to_jsonb(v)) k from public.public_profiles v where v.id = a_user) s;
    select count(*) into v_n from public.public_profiles where id in (a_user, b_user, n_user);
    results := results || case when v_txt = 'created_at,display_name,id,is_deleted,is_system,photo_url,username' and v_n = 3
                               then 'T17 PASS anon reads public_profiles: 7 public columns, one row per user'
                               else 'T17 FAIL anon view shape' end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T17 FAIL anon read error ' || v_state);
  end;
  execute 'reset role';

  -- W-3  T18: anon still cannot read users or write the view
  begin
    perform set_config('role', 'anon', true);
    perform 1 from public.users limit 1;
    results := results || 'T18 FAIL anon can read users'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || case when v_state = '42501'
                               then 'T18 PASS anon cannot read users (42501)'
                               else 'T18 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    update public.public_profiles set username = 'x' where id = a_user;
    results := results || 'T19 FAIL authenticated could update public_profiles'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || case when v_state = '42501'
                               then 'T19 PASS public_profiles is not writable by authenticated (42501)'
                               else 'T19 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- W-3  T20: authenticated still cannot read another user's private users row
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into v_n from public.users where id = b_user;
    results := results || case when v_n = 0
                               then 'T20 PASS other users'' rows stay invisible (RLS)'
                               else 'T20 FAIL other user row visible' end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T20 FAIL error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- W-4  T21-T24: follow / like INSERT and DELETE are denied
  -- ---------------------------------------------------------------------
  declare
    v_sql  text;
    v_name text;
    v_no   int := 21;
  begin
    foreach v_sql in array array[
      format('insert into public.follows (follower_id, following_id) values (%L, %L)', a_user, b_user),
      format('delete from public.follows where follower_id = %L', b_user),
      format('insert into public.likes (user_id, post_id) values (%L, %L)', a_user, gen_random_uuid()),
      format('delete from public.likes where user_id = %L', b_user)] loop
      v_name := (array['follow INSERT', 'follow DELETE', 'like INSERT', 'like DELETE'])[v_no - 20];
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', case when v_no in (22, 24) then b_auth else a_auth end, 'role', 'authenticated')::text, true);
        perform set_config('request.jwt.claim.sub', (case when v_no in (22, 24) then b_auth else a_auth end)::text, true);
        perform set_config('role', 'authenticated', true);
        execute v_sql;
        results := results || ('T' || v_no || ' FAIL ' || v_name || ' succeeded');
      exception when others then
        get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
        results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                                   then 'T' || v_no || ' PASS ' || v_name || ' denied (42501)'
                                   else 'T' || v_no || ' FAIL ' || v_name || ' unexpected ' || v_state end;
      end;
      execute 'reset role';
      v_no := v_no + 1;
    end loop;
  end;

  -- W-4  T25: SELECT unchanged for authenticated and anon; history kept
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    select (select count(*) from public.follows where follower_id = b_user and following_id = a_user)
         + (select count(*) from public.likes where user_id = b_user) into v_n;
    execute 'reset role';
    perform set_config('role', 'anon', true);
    select v_n + (select count(*) from public.follows where follower_id = b_user and following_id = a_user)
               + (select count(*) from public.likes where user_id = b_user) into v_n;
    results := results || case when v_n = 4
                               then 'T25 PASS follows / likes remain readable by authenticated and anon'
                               else 'T25 FAIL visible=' || v_n end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T25 FAIL read error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- GLOBAL  T26-T28: O-1 / O-2 / O-3 remain remediated
  -- ---------------------------------------------------------------------
  declare
    v_sql  text;
    v_no   int := 26;
  begin
    foreach v_sql in array array[
      format('insert into public.wanted_applications (wanted_post_id, applicant_id) values (%L, %L)', gen_random_uuid(), a_user),
      format('delete from public.wanted_posts where user_id = %L', a_user),
      format('insert into public.collaboration_assets (id, collaboration_id, uploaded_by, storage_path, file_name) values (%L, %L, %L, %L, %L)',
             gen_random_uuid(), gen_random_uuid(), a_user, 'x/y', 'y')] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', a_auth, 'role', 'authenticated')::text, true);
        perform set_config('request.jwt.claim.sub', a_auth::text, true);
        perform set_config('role', 'authenticated', true);
        execute v_sql;
        results := results || ('T' || v_no || ' FAIL O-' || (v_no - 25) || ' write succeeded');
      exception when others then
        get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
        results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                                   then 'T' || v_no || ' PASS O-' || (v_no - 25) || ' direct write still denied (42501)'
                                   else 'T' || v_no || ' FAIL O-' || (v_no - 25) || ' unexpected ' || v_state end;
      end;
      execute 'reset role';
      v_no := v_no + 1;
    end loop;
  end;

  raise exception 'VALIDATION RESULTS (rolled back): %', array_to_string(results, ' | ');
end
$validation$;
