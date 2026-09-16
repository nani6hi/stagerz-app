-- =====================================================================
-- STAGERZ - Backend integrity remediation - O-1 / O-2 / O-3
-- EMERGENCY ROLLBACK for migration.sql
-- =====================================================================
--  ####  EXECUTABLE ROLLBACK - PREPARED, NOT EXECUTED.  ####
--
-- Status      : PREPARED for review and emergency use only. NOT executed.
-- Use only    : with explicit approval, and only after migration.sql has
--               been applied. Its preflight refuses to run otherwise.
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
--
-- WARNING: running this rollback RE-OPENS O-1, O-2 and O-3. It restores
-- the reviewed pre-change state exactly; it does not make that state safe.
--
-- It reverses ONLY what migration.sql changes:
--   O-3  collaboration_assets: remove the nine column-level INSERT grants,
--        restore the table-level INSERT grant, restore the original
--        INSERT policy WITH CHECK (three conditions).
--   O-2  collaborations_wanted_post_id_fkey back to ON DELETE CASCADE;
--        restore DELETE on wanted_posts to authenticated and the original
--        DELETE policy (no TO clause -> role PUBLIC, permissive).
--   O-1  restore INSERT on wanted_applications to authenticated and the
--        original INSERT policy (TO authenticated, permissive).
--
-- Policy expressions are the live definitions captured 2026-09-16,
-- schema-qualified so they do not depend on the caller's search_path.
-- The POSTFLIGHT compares the re-created expressions, byte for byte,
-- with the verbatim captured deparse and aborts on any difference.
--
-- Known representational note: after the column grants are revoked,
-- PostgreSQL may keep an empty column ACL ('{}') instead of NULL. Both
-- mean "no column privilege"; the guards treat them as equivalent.
-- Effective privileges and every table ACL are restored exactly.
-- =====================================================================

do $rollback$
declare
  -- ---- state migration.sql produces (required before rolling back) ---
  c_acl_wa_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}';
  c_acl_wp_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ar/postgres}';
  c_acl_ca_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}';
  c_fk_after       constant text := 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT';

  -- ---- reviewed pre-change baseline, verbatim from the live catalog ---
  c_acl_wa_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}';
  c_acl_wp_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}';
  c_acl_ca_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}';
  c_wa_insert_check constant text := E'((applicant_id = current_active_stagerz_user_id()) AND (EXISTS ( SELECT 1\n   FROM wanted_posts wp\n  WHERE ((wp.id = wanted_applications.wanted_post_id) AND (wp.status = ''open''::text) AND (wp.user_id <> wanted_applications.applicant_id)))))';
  c_wp_delete_using constant text := '(user_id = current_active_stagerz_user_id())';
  c_ca_insert_check constant text := E'((uploaded_by = current_active_stagerz_user_id()) AND is_collaboration_participant(collaboration_id) AND (EXISTS ( SELECT 1\n   FROM collaborations c\n  WHERE ((c.id = collaboration_assets.collaboration_id) AND (c.status = ''active''::text)))))';
  c_fk_before      constant text := 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE CASCADE';
  c_ca_insert_cols_before constant text := 'asset_type,collaboration_id,created_at,deleted_at,description,file_name,file_size,id,mime_type,storage_path,title,uploaded_by';
  c_wa_insert_cols_before constant text := 'applicant_id,created_at,id,status,updated_at,wanted_post_id';

  v_text text;
  v_count int;
begin
  perform set_config('search_path', 'public', true);

  -- ===================================================================
  -- 1. PREFLIGHT - migration.sql must be in effect
  -- ===================================================================
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass) is distinct from c_acl_wa_after
     or (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_after
     or (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass) is distinct from c_acl_ca_after then
    raise exception 'rollback preflight: table ACLs are not the post-migration state';
  end if;
  if exists (select 1 from pg_policy where polrelid = 'public.wanted_applications'::regclass
                                       and polname = 'active users can apply to open wanted posts')
     or exists (select 1 from pg_policy where polrelid = 'public.wanted_posts'::regclass
                                          and polname = 'active users can delete own wanted posts') then
    raise exception 'rollback preflight: a policy removed by migration.sql already exists';
  end if;
  if (select pg_get_constraintdef(oid) from pg_constraint
       where conrelid = 'public.collaborations'::regclass
         and conname = 'collaborations_wanted_post_id_fkey') is distinct from c_fk_after then
    raise exception 'rollback preflight: collaborations_wanted_post_id_fkey is not the post-migration state';
  end if;

  -- ===================================================================
  -- 2. REVERSAL (reverse order of migration.sql)
  -- ===================================================================

  -- ---- O-3 ------------------------------------------------------------
  revoke insert (collaboration_id, uploaded_by, storage_path, file_name,
                 mime_type, file_size, asset_type, title, description)
    on table public.collaboration_assets from authenticated;
  revoke insert on table public.collaboration_assets from authenticated;
  grant insert on table public.collaboration_assets to authenticated;
  alter policy "active participants can create collaboration asset metadata"
    on public.collaboration_assets
    with check (
      (uploaded_by = public.current_active_stagerz_user_id())
      and public.is_collaboration_participant(collaboration_id)
      and (exists (select 1
                     from public.collaborations c
                    where ((c.id = collaboration_assets.collaboration_id)
                           and (c.status = 'active'::text))))
    );

  -- ---- O-2 ------------------------------------------------------------
  alter table public.collaborations
    drop constraint collaborations_wanted_post_id_fkey,
    add constraint collaborations_wanted_post_id_fkey
      foreign key (wanted_post_id) references public.wanted_posts (id)
      on delete cascade;
  grant delete on table public.wanted_posts to authenticated;
  create policy "active users can delete own wanted posts"
    on public.wanted_posts
    for delete
    using (user_id = public.current_active_stagerz_user_id());

  -- ---- O-1 ------------------------------------------------------------
  grant insert on table public.wanted_applications to authenticated;
  create policy "active users can apply to open wanted posts"
    on public.wanted_applications
    for insert
    to authenticated
    with check (
      (applicant_id = public.current_active_stagerz_user_id())
      and (exists (select 1
                     from public.wanted_posts wp
                    where ((wp.id = wanted_applications.wanted_post_id)
                           and (wp.status = 'open'::text)
                           and (wp.user_id <> wanted_applications.applicant_id))))
    );

  -- ===================================================================
  -- 3. POSTFLIGHT - exact pre-change state
  -- ===================================================================
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass) is distinct from c_acl_wa_before
     or (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_before
     or (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass) is distinct from c_acl_ca_before then
    raise exception 'rollback postflight: table ACLs do not equal the reviewed baseline';
  end if;

  select count(*) into v_count from pg_attribute
   where attrelid in ('public.wanted_applications'::regclass, 'public.collaboration_assets'::regclass)
     and attnum > 0 and not attisdropped and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'rollback postflight: column-level ACLs remain';
  end if;

  if (select string_agg(attname::text, ',' order by attname) from pg_attribute
       where attrelid = 'public.collaboration_assets'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.collaboration_assets', attnum, 'INSERT'))
     is distinct from c_ca_insert_cols_before
     or (select string_agg(attname::text, ',' order by attname) from pg_attribute
          where attrelid = 'public.wanted_applications'::regclass and attnum > 0 and not attisdropped
            and has_column_privilege('authenticated', 'public.wanted_applications', attnum, 'INSERT'))
     is distinct from c_wa_insert_cols_before then
    raise exception 'rollback postflight: effective INSERT columns do not equal the reviewed baseline';
  end if;

  select pg_get_expr(polwithcheck, polrelid) into v_text from pg_policy
   where polrelid = 'public.wanted_applications'::regclass
     and polname = 'active users can apply to open wanted posts'
     and polcmd = 'a' and polpermissive and polroles = array['authenticated'::regrole::oid] and polqual is null;
  if v_text is distinct from c_wa_insert_check then
    raise exception 'rollback postflight: wanted_applications INSERT policy is not byte-identical to the baseline';
  end if;

  select pg_get_expr(polqual, polrelid) into v_text from pg_policy
   where polrelid = 'public.wanted_posts'::regclass
     and polname = 'active users can delete own wanted posts'
     and polcmd = 'd' and polpermissive and polroles = array[0::oid] and polwithcheck is null;
  if v_text is distinct from c_wp_delete_using then
    raise exception 'rollback postflight: wanted_posts DELETE policy is not byte-identical to the baseline';
  end if;

  select pg_get_expr(polwithcheck, polrelid) into v_text from pg_policy
   where polrelid = 'public.collaboration_assets'::regclass
     and polname = 'active participants can create collaboration asset metadata'
     and polcmd = 'a' and polpermissive and polroles = array['authenticated'::regrole::oid] and polqual is null;
  if v_text is distinct from c_ca_insert_check then
    raise exception 'rollback postflight: collaboration_assets INSERT policy is not byte-identical to the baseline';
  end if;

  select pg_get_constraintdef(oid) into v_text from pg_constraint
   where conrelid = 'public.collaborations'::regclass
     and conname = 'collaborations_wanted_post_id_fkey'
     and contype = 'f' and confdeltype = 'c' and confupdtype = 'a' and confmatchtype = 's'
     and not condeferrable and not condeferred and convalidated;
  if v_text is distinct from c_fk_before then
    raise exception 'rollback postflight: collaborations_wanted_post_id_fkey is not the baseline definition';
  end if;

  if exists (select 1 from pg_class
              where oid in ('public.wanted_applications'::regclass, 'public.wanted_posts'::regclass,
                            'public.collaboration_assets'::regclass, 'public.collaborations'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'rollback postflight: RLS state changed on an affected table';
  end if;
end
$rollback$;
