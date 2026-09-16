-- =====================================================================
-- STAGERZ - Backend integrity remediation - O-1 / O-2 / O-3
-- =====================================================================
--  ####  EXECUTABLE MIGRATION CANDIDATE - PREPARED, NOT APPLIED.  ####
--
-- Status      : PREPARED. NOT APPLIED to any database.
-- Apply only  : after independent review AND explicit approval, through
--               apply_migration, with this file's content sent unchanged.
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Baseline    : captured read-only 2026-09-16 with catalog-fingerprint.sql
--               (expected values in validation.md, section 2)
-- Rollback    : rollback.sql in this directory (reviewed, NOT executed)
--
-- This file is NOT part of a Supabase migration chain. The repository
-- does not contain the project's 41 remote migrations, and this file
-- does not claim otherwise. It is the reviewed source of truth for ONE
-- future apply_migration call; see phase-definition.md, section 7.
--
-- It is NOT a descriptive snapshot like the .sql files in
-- analysis/phase-21.3/; everything below the header is executable.
--
-- ---------------------------------------------------------------------
-- WHAT IT CHANGES - exactly three observations, nothing else
-- ---------------------------------------------------------------------
-- O-1  wanted_applications
--      - REVOKE INSERT from authenticated
--      - DROP POLICY "active users can apply to open wanted posts"
--      => create_wanted_application() becomes the only creation path.
--         SELECT privilege and the SELECT policy are untouched.
--
-- O-2  wanted_posts / collaborations
--      - REVOKE DELETE on wanted_posts from authenticated
--      - DROP POLICY "active users can delete own wanted posts"
--      - collaborations_wanted_post_id_fkey: ON DELETE CASCADE
--                                          -> ON DELETE RESTRICT
--        (same name, column, referenced table/column, MATCH SIMPLE,
--         ON UPDATE NO ACTION, NOT DEFERRABLE; the separate UNIQUE
--         constraint and the column's NOT NULL are not touched)
--      => no client can physically delete a post, and no role can
--         delete a post that produced a collaboration.
--         wanted_applications -> wanted_posts stays ON DELETE CASCADE.
--
-- O-3  collaboration_assets
--      - REVOKE the table-level INSERT from authenticated
--      - GRANT column-level INSERT on exactly the nine columns the
--        frontend sends: collaboration_id, uploaded_by, storage_path,
--        file_name, mime_type, file_size, asset_type, title, description
--        (id, created_at and deleted_at are no longer client-insertable;
--         their defaults / lifecycle are unchanged)
--      - ALTER POLICY "active participants can create collaboration
--        asset metadata": WITH CHECK keeps all three existing conditions
--        and adds
--          deleted_at IS NULL
--          first storage_path component = collaboration_id::text,
--          followed by '/' and at least one character
--
-- NOT CHANGED: public.public_profiles (accepted Security Advisor item),
-- users, any function, any trigger, Storage, pending_asset_deletions,
-- the drainer, the reaper, wanted_posts INSERT/UPDATE, index.html.
--
-- ---------------------------------------------------------------------
-- SAFETY DESIGN
-- ---------------------------------------------------------------------
-- The whole change is ONE DO statement, so it is atomic regardless of
-- how the caller wraps it: any failed guard raises and nothing persists.
--   1. PREFLIGHT - aborts unless the live state equals the reviewed
--      baseline exactly (ACLs, column ACLs, policy expressions, FK).
--   2. CHANGES   - the statements listed above.
--   3. POSTFLIGHT - aborts unless the resulting state is exactly the
--      intended one.
-- search_path is pinned for the duration of the transaction so the
-- deparsed expressions compared by the guards are stable. All object
-- references in DDL are schema-qualified.
-- =====================================================================

do $migration$
declare
  -- ---- reviewed baseline, captured verbatim from the live catalog ----
  c_acl_wa_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}';
  c_acl_wp_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}';
  c_acl_ca_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=ar/postgres}';
  c_wa_insert_check constant text := E'((applicant_id = current_active_stagerz_user_id()) AND (EXISTS ( SELECT 1\n   FROM wanted_posts wp\n  WHERE ((wp.id = wanted_applications.wanted_post_id) AND (wp.status = ''open''::text) AND (wp.user_id <> wanted_applications.applicant_id)))))';
  c_wp_delete_using constant text := '(user_id = current_active_stagerz_user_id())';
  c_ca_insert_check constant text := E'((uploaded_by = current_active_stagerz_user_id()) AND is_collaboration_participant(collaboration_id) AND (EXISTS ( SELECT 1\n   FROM collaborations c\n  WHERE ((c.id = collaboration_assets.collaboration_id) AND (c.status = ''active''::text)))))';
  c_fk_before      constant text := 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE CASCADE';

  -- ---- intended result ------------------------------------------------
  c_acl_wa_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}';
  c_acl_wp_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ar/postgres}';
  c_acl_ca_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}';
  c_fk_after       constant text := 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT';
  c_ca_insert_cols constant text := 'asset_type,collaboration_id,description,file_name,file_size,mime_type,storage_path,title,uploaded_by';

  v_text text;
  v_count int;
begin
  perform set_config('search_path', 'public', true);

  -- ===================================================================
  -- 1. PREFLIGHT
  -- ===================================================================
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass) is distinct from c_acl_wa_before then
    raise exception 'preflight: wanted_applications ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_before then
    raise exception 'preflight: wanted_posts ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass) is distinct from c_acl_ca_before then
    raise exception 'preflight: collaboration_assets ACL differs from reviewed baseline';
  end if;

  select count(*) into v_count from pg_attribute
   where attrelid in ('public.wanted_applications'::regclass, 'public.collaboration_assets'::regclass)
     and attnum > 0 and not attisdropped and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'preflight: unexpected column-level ACLs on wanted_applications / collaboration_assets';
  end if;

  select pg_get_expr(polwithcheck, polrelid) into v_text from pg_policy
   where polrelid = 'public.wanted_applications'::regclass
     and polname = 'active users can apply to open wanted posts'
     and polcmd = 'a' and polpermissive and polroles = array['authenticated'::regrole::oid];
  if v_text is distinct from c_wa_insert_check then
    raise exception 'preflight: wanted_applications INSERT policy differs from reviewed baseline';
  end if;

  select pg_get_expr(polqual, polrelid) into v_text from pg_policy
   where polrelid = 'public.wanted_posts'::regclass
     and polname = 'active users can delete own wanted posts'
     and polcmd = 'd' and polpermissive and polroles = array[0::oid] and polwithcheck is null;
  if v_text is distinct from c_wp_delete_using then
    raise exception 'preflight: wanted_posts DELETE policy differs from reviewed baseline';
  end if;

  select pg_get_expr(polwithcheck, polrelid) into v_text from pg_policy
   where polrelid = 'public.collaboration_assets'::regclass
     and polname = 'active participants can create collaboration asset metadata'
     and polcmd = 'a' and polpermissive and polroles = array['authenticated'::regrole::oid] and polqual is null;
  if v_text is distinct from c_ca_insert_check then
    raise exception 'preflight: collaboration_assets INSERT policy differs from reviewed baseline';
  end if;

  select pg_get_constraintdef(oid) into v_text from pg_constraint
   where conrelid = 'public.collaborations'::regclass
     and conname = 'collaborations_wanted_post_id_fkey'
     and contype = 'f' and confupdtype = 'a' and confmatchtype = 's'
     and not condeferrable and convalidated;
  if v_text is distinct from c_fk_before then
    raise exception 'preflight: collaborations_wanted_post_id_fkey differs from reviewed baseline';
  end if;

  if exists (select 1 from pg_class
              where oid in ('public.wanted_applications'::regclass, 'public.wanted_posts'::regclass,
                            'public.collaboration_assets'::regclass, 'public.collaborations'::regclass)
                and not relrowsecurity) then
    raise exception 'preflight: RLS is not enabled on every affected table';
  end if;

  -- ===================================================================
  -- 2. CHANGES
  -- ===================================================================

  -- ---- O-1 ------------------------------------------------------------
  revoke insert on table public.wanted_applications from authenticated;
  drop policy "active users can apply to open wanted posts" on public.wanted_applications;

  -- ---- O-2 ------------------------------------------------------------
  revoke delete on table public.wanted_posts from authenticated;
  drop policy "active users can delete own wanted posts" on public.wanted_posts;
  alter table public.collaborations
    drop constraint collaborations_wanted_post_id_fkey,
    add constraint collaborations_wanted_post_id_fkey
      foreign key (wanted_post_id) references public.wanted_posts (id)
      on delete restrict;

  -- ---- O-3 ------------------------------------------------------------
  revoke insert on table public.collaboration_assets from authenticated;
  grant insert (collaboration_id, uploaded_by, storage_path, file_name,
                mime_type, file_size, asset_type, title, description)
    on table public.collaboration_assets to authenticated;
  alter policy "active participants can create collaboration asset metadata"
    on public.collaboration_assets
    with check (
      (uploaded_by = public.current_active_stagerz_user_id())
      and public.is_collaboration_participant(collaboration_id)
      and (exists (select 1
                     from public.collaborations c
                    where ((c.id = collaboration_assets.collaboration_id)
                           and (c.status = 'active'::text))))
      and (deleted_at is null)
      and (split_part(storage_path, '/', 1) = (collaboration_id)::text)
      and (length(storage_path) > (length((collaboration_id)::text) + 1))
    );

  -- ===================================================================
  -- 3. POSTFLIGHT
  -- ===================================================================

  -- ---- O-1 ------------------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass) is distinct from c_acl_wa_after then
    raise exception 'postflight: wanted_applications ACL is not the intended one';
  end if;
  if has_any_column_privilege('authenticated', 'public.wanted_applications', 'INSERT') then
    raise exception 'postflight: authenticated can still INSERT into wanted_applications';
  end if;
  if not has_table_privilege('authenticated', 'public.wanted_applications', 'SELECT') then
    raise exception 'postflight: authenticated lost SELECT on wanted_applications';
  end if;
  if (select array_agg(polname::text order by polname) from pg_policy
       where polrelid = 'public.wanted_applications'::regclass)
     is distinct from array['applicant or wanted owner can read applications'] then
    raise exception 'postflight: wanted_applications policy set is not the intended one';
  end if;

  -- ---- O-2 ------------------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_after then
    raise exception 'postflight: wanted_posts ACL is not the intended one';
  end if;
  if has_table_privilege('authenticated', 'public.wanted_posts', 'DELETE') then
    raise exception 'postflight: authenticated can still DELETE wanted_posts';
  end if;
  if (select array_agg(polname::text order by polname) from pg_policy
       where polrelid = 'public.wanted_posts'::regclass)
     is distinct from array['active users can update own wanted posts',
                            'onboarded active users can insert own wanted posts',
                            'wanted_posts are publicly readable'] then
    raise exception 'postflight: wanted_posts policy set is not the intended one';
  end if;
  select pg_get_constraintdef(oid) into v_text from pg_constraint
   where conrelid = 'public.collaborations'::regclass
     and conname = 'collaborations_wanted_post_id_fkey'
     and contype = 'f' and confdeltype = 'r' and confupdtype = 'a' and confmatchtype = 's'
     and not condeferrable and not condeferred and convalidated
     and confrelid = 'public.wanted_posts'::regclass;
  if v_text is distinct from c_fk_after then
    raise exception 'postflight: collaborations_wanted_post_id_fkey is not ON DELETE RESTRICT as intended';
  end if;
  if (select pg_get_constraintdef(oid) from pg_constraint
       where conrelid = 'public.wanted_applications'::regclass
         and conname = 'wanted_applications_wanted_post_id_fkey')
     is distinct from 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE CASCADE' then
    raise exception 'postflight: wanted_applications_wanted_post_id_fkey changed unexpectedly';
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.collaborations'::regclass
                    and conname = 'collaborations_wanted_post_id_key'
                    and pg_get_constraintdef(oid) = 'UNIQUE (wanted_post_id)')
     or not (select attnotnull from pg_attribute
              where attrelid = 'public.collaborations'::regclass and attname = 'wanted_post_id') then
    raise exception 'postflight: collaborations.wanted_post_id UNIQUE / NOT NULL changed unexpectedly';
  end if;

  -- ---- O-3 ------------------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass) is distinct from c_acl_ca_after then
    raise exception 'postflight: collaboration_assets ACL is not the intended one';
  end if;
  if (select string_agg(attname::text, ',' order by attname) from pg_attribute
       where attrelid = 'public.collaboration_assets'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.collaboration_assets', attnum, 'INSERT'))
     is distinct from c_ca_insert_cols then
    raise exception 'postflight: authenticated INSERT columns on collaboration_assets are not exactly the nine intended';
  end if;
  if not has_table_privilege('authenticated', 'public.collaboration_assets', 'SELECT') then
    raise exception 'postflight: authenticated lost SELECT on collaboration_assets';
  end if;
  select pg_get_expr(polwithcheck, polrelid) into v_text from pg_policy
   where polrelid = 'public.collaboration_assets'::regclass
     and polname = 'active participants can create collaboration asset metadata'
     and polcmd = 'a' and polpermissive and polroles = array['authenticated'::regrole::oid] and polqual is null;
  -- all three original conditions must survive verbatim, in order, as the
  -- leading part of the new expression
  if v_text is null
     or left(v_text, length(c_ca_insert_check) - 1) <> left(c_ca_insert_check, length(c_ca_insert_check) - 1)
     or position('(deleted_at IS NULL)' in v_text) = 0
     or position('split_part(storage_path' in v_text) = 0
     or position('length(storage_path)' in v_text) = 0 then
    raise exception 'postflight: collaboration_assets INSERT policy is not the intended one';
  end if;
  if (select pg_get_expr(polqual, polrelid) from pg_policy
       where polrelid = 'public.collaboration_assets'::regclass
         and polname = 'participants can read collaboration asset metadata')
     is distinct from '(is_collaboration_participant(collaboration_id) AND (deleted_at IS NULL))' then
    raise exception 'postflight: collaboration_assets SELECT policy changed unexpectedly';
  end if;

  -- ---- common ---------------------------------------------------------
  if exists (select 1 from pg_class
              where oid in ('public.wanted_applications'::regclass, 'public.wanted_posts'::regclass,
                            'public.collaboration_assets'::regclass, 'public.collaborations'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'postflight: RLS state changed on an affected table';
  end if;
  if (select relacl::text from pg_class where oid = 'public.public_profiles'::regclass)
     is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}'
     or (select reloptions from pg_class where oid = 'public.public_profiles'::regclass) is not null then
    raise exception 'postflight: public_profiles changed unexpectedly';
  end if;
end
$migration$;
