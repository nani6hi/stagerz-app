-- =====================================================================
-- STAGERZ - Backend integrity remediation - O-1 / O-2 / O-3
-- POST-APPLY BEHAVIOURAL VALIDATION - ROLLBACK-ONLY TEMPLATE
-- =====================================================================
--  ####  TEMPLATE - NOT RUN. RUN ONLY AFTER migration.sql IS APPLIED  ####
--  ####  AND ONLY WITH EXPLICIT APPROVAL.                              ####
--
-- Rollback guarantee: the whole script is ONE DO statement that always
-- ends by RAISING an exception carrying the results. Every write made by
-- the tests (applications, notifications, activity rows, asset metadata,
-- queue rows, ownership transfer) is therefore rolled back, whatever the
-- caller's transaction handling is. Nothing is committed; Realtime emits
-- nothing for rolled-back work. The expected final output is an ERROR
-- whose message starts with "VALIDATION RESULTS (rolled back)".
--
-- Identities: SYNTHETIC FIXTURE ACCOUNTS ONLY. Never real users. Fill the
-- placeholders at validation time; do not commit the filled-in copy and
-- do not print identifiers in any report (results below contain none).
--
-- Fixture requirements (all synthetic):
--   A  active, onboarded user (applicant); has NOT applied to P1
--   B  active user; owns open post P1 that has NO collaboration
--   O  active user; owns post P2, which HAS an ACTIVE collaboration C
--      in which O is the current owner
--   M  active user; member (not owner) of C
--
-- Role switching mirrors PostgREST: role 'authenticated' plus JWT claims,
-- so auth.uid() and every RLS policy behave as for a real API request.
-- The executing session must be allowed to SET ROLE authenticated.
--
-- Change 2026-09-16 (after first use): eleven bare string literals
-- appended to the text[] results array now carry an explicit ::text
-- cast. Without it PostgreSQL parses the literal as an array value
-- (22P02 "malformed array literal"). No test, expectation or rollback
-- behaviour changed. The executed copy, with in-statement synthetic
-- fixtures, is behavioral-validation-run-2026-09-16.sql.
-- =====================================================================

do $validation$
declare
  -- ===== FILL IN (synthetic fixture identities only) =====================
  p_a_auth   uuid := null;  -- auth.users id of A
  p_a_user   uuid := null;  -- public.users id of A
  p_b_auth   uuid := null;  -- auth.users id of B
  p_post1    uuid := null;  -- open post owned by B, no collaboration, A not applied
  p_o_auth   uuid := null;  -- auth.users id of O
  p_o_user   uuid := null;  -- public.users id of O
  p_post2    uuid := null;  -- post owned by O with active collaboration C
  p_collab   uuid := null;  -- C
  p_m_user   uuid := null;  -- public.users id of M (member of C)
  -- =======================================================================

  results  text[] := '{}';
  v_state  text;
  v_msg    text;
  v_id     uuid;
  v_asset  uuid;
  v_n      bigint;
  v_step   text;
begin
  if p_a_auth is null or p_a_user is null or p_b_auth is null or p_post1 is null
     or p_o_auth is null or p_o_user is null or p_post2 is null or p_collab is null
     or p_m_user is null then
    raise exception 'behavioral-validation: fixture placeholders are not filled in';
  end if;
  if not pg_has_role(current_user, 'authenticated', 'MEMBER') then
    raise exception 'behavioral-validation: session cannot switch to role authenticated';
  end if;
  perform set_config('search_path', 'public', true);

  -- ---------------------------------------------------------------------
  -- O-1  T1: direct INSERT into wanted_applications is denied
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.wanted_applications (wanted_post_id, applicant_id, status)
      values (p_post1, p_a_user, 'accepted');
    results := results || 'T1 FAIL direct application insert succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T1 PASS direct application insert denied (42501)'
                               else 'T1 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-1  T2: create_wanted_application still works and notifies the owner
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_a_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_a_auth::text, true);
    perform set_config('role', 'authenticated', true);
    select application_id into v_id from public.create_wanted_application(p_post1);
    execute 'reset role';
    select count(*) into v_n from (
      select 1 from public.wanted_applications where id = v_id and status = 'pending'
      union all
      select 1 from public.notifications where wanted_application_id = v_id and type = 'wanted.application.created'
    ) s;
    results := results || case when v_id is not null and v_n = 2
                               then 'T2 PASS RPC created a pending application and one owner notification'
                               else 'T2 FAIL rows=' || v_n end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T2 FAIL RPC error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-2  T3: the post owner cannot DELETE a post directly
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    delete from public.wanted_posts where id = p_post2;
    results := results || 'T3 FAIL owner DELETE did not raise'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T3 PASS owner DELETE denied (42501)'
                               else 'T3 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-2  T4: privileged DELETE of a post with a collaboration is refused
  -- ---------------------------------------------------------------------
  begin
    delete from public.wanted_posts where id = p_post2;
    results := results || 'T4 FAIL privileged DELETE cascaded / succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || case when v_state = '23503'
                               then 'T4 PASS privileged DELETE blocked by FK RESTRICT (23503)'
                               else 'T4 FAIL unexpected ' || v_state end;
  end;
  select count(*) into v_n from public.collaborations where id = p_collab;
  results := results || case when v_n = 1 then 'T4b PASS collaboration still present'
                             else 'T4b FAIL collaboration missing' end;

  -- ---------------------------------------------------------------------
  -- O-2  T5: after transferring ownership, the former owner still cannot
  --          delete the post (the transfer itself is rolled back too)
  -- ---------------------------------------------------------------------
  v_step := 'transfer';
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.transfer_collaboration_ownership(p_collab, p_m_user);
    v_step := 'delete';
    delete from public.wanted_posts where id = p_post2;
    results := results || 'T5 FAIL former owner DELETE did not raise'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || case when v_step = 'delete' and v_state = '42501'
                               then 'T5 PASS transfer succeeded; former-owner DELETE denied (42501)'
                               else 'T5 FAIL at ' || v_step || ' ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-2  T6: close_own_wanted_post still works
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_b_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_b_auth::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.close_own_wanted_post(p_post1);
    execute 'reset role';
    select count(*) into v_n from public.wanted_posts where id = p_post1 and status = 'closed';
    results := results || case when v_n = 1 then 'T6 PASS close_own_wanted_post closed the post'
                               else 'T6 FAIL post not closed' end;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    results := results || ('T6 FAIL RPC error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-3  T7: frontend-shaped asset metadata INSERT (RETURNING *) works
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (collaboration_id, uploaded_by, storage_path, file_name, mime_type,
       file_size, asset_type, title, description)
      values (p_collab, p_o_user,
              p_collab::text || '/validation-' || gen_random_uuid()::text || '.txt',
              'validation.txt', 'text/plain', 1, 'document', null, null)
      returning id into v_asset;
    results := results || 'T7 PASS frontend-shaped INSERT succeeded'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    v_asset := null;
    results := results || ('T7 FAIL frontend-shaped INSERT error ' || v_state);
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-3  T8-T10: explicit id / created_at / deleted_at are denied
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (id, collaboration_id, uploaded_by, storage_path, file_name, mime_type, file_size, asset_type)
      values (gen_random_uuid(), p_collab, p_o_user,
              p_collab::text || '/validation-' || gen_random_uuid()::text, 'v', 'text/plain', 1, 'document');
    results := results || 'T8 FAIL explicit id accepted'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T8 PASS explicit id denied (42501)' else 'T8 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (created_at, collaboration_id, uploaded_by, storage_path, file_name, mime_type, file_size, asset_type)
      values (now() - interval '1 year', p_collab, p_o_user,
              p_collab::text || '/validation-' || gen_random_uuid()::text, 'v', 'text/plain', 1, 'document');
    results := results || 'T9 FAIL explicit created_at accepted'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T9 PASS explicit created_at denied (42501)' else 'T9 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- deleted_at, without RETURNING (the return=minimal shape)
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (deleted_at, collaboration_id, uploaded_by, storage_path, file_name, mime_type, file_size, asset_type)
      values (now(), p_collab, p_o_user,
              p_collab::text || '/validation-' || gen_random_uuid()::text, 'v', 'text/plain', 1, 'document');
    results := results || 'T10 FAIL explicit deleted_at accepted'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like 'permission denied%'
                               then 'T10 PASS explicit deleted_at denied (42501)' else 'T10 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-3  T11/T11b: storage_path must sit in the collaboration's folder
  -- ---------------------------------------------------------------------
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (collaboration_id, uploaded_by, storage_path, file_name, mime_type, file_size, asset_type)
      values (p_collab, p_o_user,
              gen_random_uuid()::text || '/validation-mismatch', 'v', 'text/plain', 1, 'document');
    results := results || 'T11 FAIL mismatched path prefix accepted'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like '%row-level security%'
                               then 'T11 PASS mismatched path prefix denied by RLS' else 'T11 FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.collaboration_assets
      (collaboration_id, uploaded_by, storage_path, file_name, mime_type, file_size, asset_type)
      values (p_collab, p_o_user, p_collab::text || '/', 'v', 'text/plain', 1, 'document');
    results := results || 'T11b FAIL folder-only path accepted'::text;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    results := results || case when v_state = '42501' and v_msg like '%row-level security%'
                               then 'T11b PASS folder-only path denied by RLS' else 'T11b FAIL unexpected ' || v_state end;
  end;
  execute 'reset role';

  -- ---------------------------------------------------------------------
  -- O-3  T12: delete_collaboration_asset still soft-deletes and queues
  -- ---------------------------------------------------------------------
  if v_asset is null then
    results := results || 'T12 SKIPPED (T7 did not create a row)'::text;
  else
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', p_o_auth, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', p_o_auth::text, true);
      perform set_config('role', 'authenticated', true);
      perform public.delete_collaboration_asset(v_asset);
      execute 'reset role';
      select count(*) into v_n from (
        select 1 from public.collaboration_assets where id = v_asset and deleted_at is not null
        union all
        select 1 from public.pending_asset_deletions where asset_id = v_asset
      ) s;
      results := results || case when v_n = 2 then 'T12 PASS soft-deleted and queued'
                                 else 'T12 FAIL rows=' || v_n end;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate;
      results := results || ('T12 FAIL RPC error ' || v_state);
    end;
    execute 'reset role';
  end if;

  -- ---------------------------------------------------------------------
  -- Always roll everything back and report
  -- ---------------------------------------------------------------------
  raise exception 'VALIDATION RESULTS (rolled back): %', array_to_string(results, ' | ');
end
$validation$;
