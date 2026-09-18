-- =====================================================================
-- STAGERZ - Phase 21.3 R-5 remediation - W-1 / W-3 / W-4
-- =====================================================================
--  ####  REVIEWED ROLLBACK - NOT EXECUTED.                          ####
--  ####  Execute only with separate, explicit approval, and only    ####
--  ####  after migration.sql in this directory has been applied.    ####
--
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Restores    : exactly the pre-remediation state captured 2026-09-17
--               (validation.md, section 2) for the objects that
--               migration.sql changes, and nothing else:
--   W-1  wanted_posts   - column INSERT grants removed, table-level
--                         INSERT for authenticated restored
--   W-3  users          - column UPDATE (first_name, last_name,
--                         photo_url, bio, location) restored
--        public_profiles - original definition restored by
--                         CREATE OR REPLACE (owner, ACL, OID and
--                         reloptions are preserved; the postflight
--                         requires the original pretty-definition md5,
--                         so neither the profiles join nor the
--                         'New Artist' placeholder rule survives)
--   W-4  follows/likes  - INSERT, DELETE for authenticated restored;
--                         the four INSERT / DELETE policies re-created
--                         verbatim (permissive, TO PUBLIC, same
--                         expressions)
-- It does not touch rows, columns, tables, functions, triggers,
-- Storage, Edge Functions, profiles (W-2) or the O-1 / O-2 / O-3 state.
--
-- Rows written while the migration was in effect are not modified; the
-- rollback only restores privileges, policies and the view definition.
--
-- Same safety design as migration.sql: ONE DO statement; PREFLIGHT
-- requires the exact post-migration state (and aborts on anything
-- else, including a partially or differently changed state); CHANGES;
-- POSTFLIGHT requires the exact pre-migration baseline.
-- =====================================================================

do $rollback$
declare
  -- ---- state migration.sql leaves behind (rollback preflight) --------
  c_acl_wp_now     constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_acl_fl_now     constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_colacl_wp_now  constant text :=
       'category={authenticated=aw/postgres};compensation={authenticated=aw/postgres};'
    || 'description={authenticated=aw/postgres};location={authenticated=aw/postgres};'
    || 'remote={authenticated=aw/postgres};role_needed={authenticated=aw/postgres};'
    || 'status={authenticated=a/postgres};title={authenticated=aw/postgres};'
    || 'user_id={authenticated=a/postgres}';
  c_colacl_users_now constant text :=
       'bio={authenticated=r/postgres};first_name={authenticated=r/postgres};'
    || 'id={authenticated=r/postgres};last_name={authenticated=r/postgres};'
    || 'location={authenticated=r/postgres};photo_url={authenticated=r/postgres};'
    || 'username={authenticated=rw/postgres}';
  c_pol_follows_now constant text := 'follows are publicly readable|r|true|{0}|true|-';
  c_pol_likes_now   constant text := 'likes are publicly readable|r|true|{0}|true|-';

  -- ---- unchanged by both scripts ---------------------------------------
  c_acl_users      constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}';
  c_acl_profiles   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_acl_view       constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_colacl_profiles constant text :=
       'available={authenticated=w/postgres};bio={authenticated=w/postgres};'
    || 'category={authenticated=w/postgres};country_flag={authenticated=w/postgres};'
    || 'display_name={authenticated=w/postgres};location={authenticated=w/postgres};'
    || 'looking_for={authenticated=w/postgres};role={authenticated=w/postgres};'
    || 'skills={authenticated=w/postgres}';
  c_pol_wp constant text :=
       E'active users can update own wanted posts|w|true|{0}|(user_id = current_active_stagerz_user_id())|(user_id = current_active_stagerz_user_id())\n'
    || E'onboarded active users can insert own wanted posts|a|true|{0}|-|((user_id = current_active_stagerz_user_id()) AND has_completed_onboarding(user_id))\n'
    || 'wanted_posts are publicly readable|r|true|{0}|true|-';
  c_pol_users constant text :=
       E'active users can update own row|w|true|{0}|(id = current_active_stagerz_user_id())|(id = current_active_stagerz_user_id())\n'
    || 'authenticated can read own row|r|true|{0}|(id = current_stagerz_user_id())|-';
  c_pol_profiles constant text :=
       E'active users can update own profile|w|true|{0}|(user_id = current_active_stagerz_user_id())|(user_id = current_active_stagerz_user_id())\n'
    || 'profiles are publicly readable|r|true|{0}|true|-';
  c_view_cols       constant text := 'id uuid,username text,photo_url text,is_system boolean,created_at timestamp with time zone,is_deleted boolean,display_name text';

  -- ---- pre-migration baseline (rollback postflight) --------------------
  c_acl_wp_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ar/postgres}';
  c_acl_fl_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}';
  c_colacl_wp_before constant text :=
       'category={authenticated=w/postgres};compensation={authenticated=w/postgres};'
    || 'description={authenticated=w/postgres};location={authenticated=w/postgres};'
    || 'remote={authenticated=w/postgres};role_needed={authenticated=w/postgres};'
    || 'title={authenticated=w/postgres}';
  c_colacl_users_before constant text :=
       'bio={authenticated=rw/postgres};first_name={authenticated=rw/postgres};'
    || 'id={authenticated=r/postgres};last_name={authenticated=rw/postgres};'
    || 'location={authenticated=rw/postgres};photo_url={authenticated=rw/postgres};'
    || 'username={authenticated=rw/postgres}';
  c_pol_follows_before constant text :=
       E'active users can create own follows|a|true|{0}|-|(follower_id = current_active_stagerz_user_id())\n'
    || E'active users can remove own follows|d|true|{0}|(follower_id = current_active_stagerz_user_id())|-\n'
    || 'follows are publicly readable|r|true|{0}|true|-';
  c_pol_likes_before constant text :=
       E'active users can create own likes|a|true|{0}|-|(user_id = current_active_stagerz_user_id())\n'
    || E'active users can remove own likes|d|true|{0}|(user_id = current_active_stagerz_user_id())|-\n'
    || 'likes are publicly readable|r|true|{0}|true|-';
  c_view_md5_before constant text := 'd86256ac1ad53a250c96c315ed69a52e';

  v_text text;
  v_count bigint;
begin
  perform set_config('search_path', 'public', true);

  -- ===================================================================
  -- 1. PREFLIGHT - the exact state migration.sql leaves behind
  -- ===================================================================
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_now
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_wp_now then
    raise exception 'rollback preflight: wanted_posts grants are not the post-migration state';
  end if;
  if (select relacl::text from pg_class where oid = 'public.users'::regclass) is distinct from c_acl_users
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_users_now then
    raise exception 'rollback preflight: users grants are not the post-migration state';
  end if;
  if (select relacl::text from pg_class where oid = 'public.follows'::regclass) is distinct from c_acl_fl_now
     or (select relacl::text from pg_class where oid = 'public.likes'::regclass) is distinct from c_acl_fl_now then
    raise exception 'rollback preflight: follows / likes ACL is not the post-migration state';
  end if;
  select count(*) into v_count from pg_attribute
   where attrelid in ('public.follows'::regclass, 'public.likes'::regclass, 'public.public_profiles'::regclass)
     and attnum > 0 and not attisdropped and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'rollback preflight: unexpected column-level ACLs on follows / likes / public_profiles';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.follows'::regclass) is distinct from c_pol_follows_now
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.likes'::regclass) is distinct from c_pol_likes_now then
    raise exception 'rollback preflight: follows / likes policies are not the post-migration state';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.wanted_posts'::regclass) is distinct from c_pol_wp
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.users'::regclass) is distinct from c_pol_users then
    raise exception 'rollback preflight: wanted_posts / users policies differ from the reviewed state';
  end if;
  if (select relacl::text from pg_class where oid = 'public.profiles'::regclass) is distinct from c_acl_profiles
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_profiles
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.profiles'::regclass) is distinct from c_pol_profiles then
    raise exception 'rollback preflight: profiles grants / policies differ from the reviewed state';
  end if;
  if exists (select 1 from pg_class
              where oid in ('public.wanted_posts'::regclass, 'public.users'::regclass, 'public.profiles'::regclass,
                            'public.follows'::regclass, 'public.likes'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'rollback preflight: RLS state differs from the reviewed state';
  end if;

  -- public_profiles must be the migration's view
  if not exists (select 1 from pg_class
                  where oid = 'public.public_profiles'::regclass and relkind = 'v'
                    and relowner = 'postgres'::regrole and reloptions is null
                    and relacl::text = c_acl_view) then
    raise exception 'rollback preflight: public_profiles kind / owner / options / ACL differ';
  end if;
  if (select string_agg(attname::text || ' ' || format_type(atttypid, atttypmod), ',' order by attnum)
        from pg_attribute where attrelid = 'public.public_profiles'::regclass and attnum > 0 and not attisdropped)
     is distinct from c_view_cols then
    raise exception 'rollback preflight: public_profiles columns differ';
  end if;
  if (select string_agg(distinct d.refobjid::regclass::text, ',' order by d.refobjid::regclass::text)
        from pg_depend d join pg_rewrite r on r.oid = d.objid
       where d.classid = 'pg_rewrite'::regclass and r.ev_class = 'public.public_profiles'::regclass
         and d.refclassid = 'pg_class'::regclass and d.refobjid <> 'public.public_profiles'::regclass)
     is distinct from 'profiles,users' then
    raise exception 'rollback preflight: public_profiles is not the migration''s view (dependencies)';
  end if;
  if exists (select 1 from pg_depend d join pg_rewrite r on r.oid = d.objid
              where d.classid = 'pg_rewrite'::regclass and d.refobjid = 'public.public_profiles'::regclass
                and r.ev_class <> 'public.public_profiles'::regclass) then
    raise exception 'rollback preflight: another view or rule now depends on public_profiles';
  end if;
  v_text := pg_get_viewdef('public.public_profiles'::regclass, true);
  if position('first_name' in v_text) > 0
     or position('LEFT JOIN' in v_text) = 0
     or position('''New Artist''::text' in v_text) = 0 then
    raise exception 'rollback preflight: public_profiles is not the migration''s view (definition)';
  end if;
  -- the migration's final display-name rule (option A), counts only
  select count(*) into v_count
    from public.users u
    left join public.profiles p on p.user_id = u.id
    left join public.public_profiles v on v.id = u.id
   where v.id is null
      or v.display_name is distinct from
         case
           when u.anonymized_at is not null then 'Deleted User'
           when p.display_name is not null
                and substring(p.display_name from '^[[:space:]]*(.*[^[:space:]])[[:space:]]*$') is not null
                and substring(p.display_name from '^[[:space:]]*(.*[^[:space:]])[[:space:]]*$') <> 'New Artist'
             then substring(p.display_name from '^[[:space:]]*(.*[^[:space:]])[[:space:]]*$')
           when u.username is not null and u.username ~ '[^[:space:]]' then u.username
           else 'STAGERZ Artist'
         end;
  if v_count <> 0
     or (select count(*) from public.public_profiles) <> (select count(*) from public.users) then
    raise exception 'rollback preflight: public_profiles does not behave as the migration''s view';
  end if;

  -- ===================================================================
  -- 2. CHANGES
  -- ===================================================================

  -- ---- W-1 ------------------------------------------------------------
  revoke insert (user_id, title, description, role_needed, category,
                 location, remote, compensation, status)
    on table public.wanted_posts from authenticated;
  grant insert on table public.wanted_posts to authenticated;

  -- ---- W-3 ------------------------------------------------------------
  grant update (first_name, last_name, photo_url, bio, location)
    on table public.users to authenticated;

  create or replace view public.public_profiles as
  select id,
         username,
         photo_url,
         is_system,
         created_at,
         anonymized_at is not null as is_deleted,
         case
           when anonymized_at is not null then 'Deleted User'::text
           when first_name is not null or last_name is not null
             then trim(both from (coalesce(first_name, ''::text) || ' '::text) || coalesce(last_name, ''::text))
           else coalesce(username, 'STAGERZ Artist'::text)
         end as display_name
    from public.users;

  -- ---- W-4 ------------------------------------------------------------
  grant insert, delete on table public.follows, public.likes to authenticated;
  create policy "active users can create own follows" on public.follows
    for insert with check (follower_id = public.current_active_stagerz_user_id());
  create policy "active users can remove own follows" on public.follows
    for delete using (follower_id = public.current_active_stagerz_user_id());
  create policy "active users can create own likes" on public.likes
    for insert with check (user_id = public.current_active_stagerz_user_id());
  create policy "active users can remove own likes" on public.likes
    for delete using (user_id = public.current_active_stagerz_user_id());

  -- ===================================================================
  -- 3. POSTFLIGHT - exactly the pre-migration baseline
  -- ===================================================================
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_before
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_wp_before then
    raise exception 'rollback postflight: wanted_posts grants are not the baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.wanted_posts'::regclass) is distinct from c_pol_wp then
    raise exception 'rollback postflight: wanted_posts policies changed';
  end if;
  if (select relacl::text from pg_class where oid = 'public.users'::regclass) is distinct from c_acl_users
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_users_before then
    raise exception 'rollback postflight: users grants are not the baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.users'::regclass) is distinct from c_pol_users then
    raise exception 'rollback postflight: users policies changed';
  end if;
  if (select relacl::text from pg_class where oid = 'public.follows'::regclass) is distinct from c_acl_fl_before
     or (select relacl::text from pg_class where oid = 'public.likes'::regclass) is distinct from c_acl_fl_before then
    raise exception 'rollback postflight: follows / likes ACL is not the baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.follows'::regclass) is distinct from c_pol_follows_before
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.likes'::regclass) is distinct from c_pol_likes_before then
    raise exception 'rollback postflight: follows / likes policies are not the baseline';
  end if;
  select count(*) into v_count from pg_attribute
   where attrelid in ('public.follows'::regclass, 'public.likes'::regclass, 'public.public_profiles'::regclass)
     and attnum > 0 and not attisdropped and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'rollback postflight: unexpected column-level ACLs on follows / likes / public_profiles';
  end if;
  if (select relacl::text from pg_class where oid = 'public.profiles'::regclass) is distinct from c_acl_profiles
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_profiles
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.profiles'::regclass) is distinct from c_pol_profiles then
    raise exception 'rollback postflight: profiles grants / policies changed';
  end if;
  if exists (select 1 from pg_class
              where oid in ('public.wanted_posts'::regclass, 'public.users'::regclass, 'public.profiles'::regclass,
                            'public.follows'::regclass, 'public.likes'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'rollback postflight: RLS state changed';
  end if;

  -- public_profiles: original definition, security properties, behaviour
  if not exists (select 1 from pg_class
                  where oid = 'public.public_profiles'::regclass and relkind = 'v'
                    and relowner = 'postgres'::regrole and reloptions is null
                    and relacl::text = c_acl_view) then
    raise exception 'rollback postflight: public_profiles kind / owner / options / ACL changed';
  end if;
  v_text := pg_get_viewdef('public.public_profiles'::regclass, true);
  if md5(v_text) is distinct from c_view_md5_before
     or position('New Artist' in v_text) > 0
     or position('profiles' in v_text) > 0 then
    raise exception 'rollback postflight: public_profiles definition is not the original one';
  end if;
  if (select string_agg(attname::text || ' ' || format_type(atttypid, atttypmod), ',' order by attnum)
        from pg_attribute where attrelid = 'public.public_profiles'::regclass and attnum > 0 and not attisdropped)
     is distinct from c_view_cols then
    raise exception 'rollback postflight: public_profiles columns changed';
  end if;
  if (select string_agg(distinct d.refobjid::regclass::text, ',' order by d.refobjid::regclass::text)
        from pg_depend d join pg_rewrite r on r.oid = d.objid
       where d.classid = 'pg_rewrite'::regclass and r.ev_class = 'public.public_profiles'::regclass
         and d.refclassid = 'pg_class'::regclass and d.refobjid <> 'public.public_profiles'::regclass)
     is distinct from 'users' then
    raise exception 'rollback postflight: public_profiles does not depend on users only';
  end if;
  if (select is_updatable || '/' || is_insertable_into from information_schema.views
       where table_schema = 'public' and table_name = 'public_profiles') is distinct from 'YES/YES' then
    raise exception 'rollback postflight: public_profiles updatability is not the original one';
  end if;
  if not has_table_privilege('anon', 'public.public_profiles', 'SELECT')
     or not has_table_privilege('authenticated', 'public.public_profiles', 'SELECT')
     or has_table_privilege('anon', 'public.public_profiles', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
     or has_table_privilege('authenticated', 'public.public_profiles', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') then
    raise exception 'rollback postflight: public_profiles anon / authenticated privileges changed';
  end if;

  -- ---- common ---------------------------------------------------------
  if (select count(*) from pg_policy p join pg_class c on c.oid = p.polrelid
       where c.relnamespace = 'public'::regnamespace) <> 25 then
    raise exception 'rollback postflight: public policy count is not 25';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace) <> 34 then
    raise exception 'rollback postflight: public function count changed';
  end if;
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass)
       is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}'
     or (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass)
       is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}'
     or (select pg_get_constraintdef(oid) from pg_constraint
          where conrelid = 'public.collaborations'::regclass and conname = 'collaborations_wanted_post_id_fkey')
       is distinct from 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT' then
    raise exception 'rollback postflight: O-1 / O-2 / O-3 remediation state is not intact';
  end if;
end
$rollback$;
