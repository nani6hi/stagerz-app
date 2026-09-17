-- =====================================================================
-- STAGERZ - Phase 21.3 R-5 remediation - W-1 / W-3 / W-4
-- =====================================================================
--  ####  EXECUTABLE MIGRATION CANDIDATE - PREPARED, NOT APPLIED.  ####
--
-- Status      : PREPARED. NOT APPLIED to any database.
-- Apply only  : after independent review AND explicit approval, through
--               apply_migration, with this file's content sent unchanged.
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Baseline    : captured read-only 2026-09-17 (validation.md, section 2);
--               migration epoch 42 / 20260916215204; equals the
--               Phase 21.3 snapshot committed in e5244a9.
-- Rollback    : rollback.sql in this directory (reviewed, NOT executed)
--
-- This file is NOT part of a Supabase migration chain. It is the
-- reviewed source of truth for ONE future apply_migration call; see
-- phase-definition.md, section 6. It does not rewrite or supersede the
-- descriptive snapshot files in analysis/phase-21.3/.
--
-- ---------------------------------------------------------------------
-- WHAT IT CHANGES - exactly three R-5 findings, nothing else
-- ---------------------------------------------------------------------
-- W-1  wanted_posts  (decision: NARROW)
--      - REVOKE the table-level INSERT from authenticated
--      - GRANT column-level INSERT on exactly the nine columns the
--        frontend sends: user_id, title, description, role_needed,
--        category, location, remote, compensation, status
--        => id and created_at are no longer client-insertable; their
--           defaults are unchanged. The INSERT policy, the UPDATE column
--           grants, SELECT and the status CHECK are not touched.
--        (status = 'open' enforcement is optional hardening and is NOT
--         part of this change; phase-definition.md, section 4.)
--
-- W-2  profiles column UPDATE grants  (decision: ACCEPT) - NOT CHANGED.
--
-- W-3  users / public_profiles  (decision: PROFILE-CENTRED MODEL)
--      - REVOKE column-level UPDATE (first_name, last_name, photo_url,
--        bio, location) on users from authenticated
--        => authenticated keeps UPDATE (username) only; every column
--           SELECT grant on users is kept; no column is dropped.
--      - CREATE OR REPLACE VIEW public.public_profiles
--        same seven columns, same names, same order, same types;
--        display_name now derives from profiles.display_name:
--          anonymized                      -> 'Deleted User'   (unchanged)
--          btrim(profiles.display_name)<>'' -> that trimmed value
--          otherwise                        -> username, then
--                                              'STAGERZ Artist' (unchanged)
--        users.first_name / last_name no longer feed the view.
--        No WITH (...) clause: reloptions stay NULL, so the view keeps
--        running with its owner's rights exactly as today (the accepted
--        Phase 21.4 security_definer_view design). CREATE OR REPLACE
--        keeps the owner, the ACL and the relation OID.
--
-- W-4  follows / likes  (decision: KEEP TABLES, DISABLE UNUSED WRITES)
--      - REVOKE INSERT, DELETE on both tables from authenticated
--      - DROP the four now-inert INSERT / DELETE policies (option B)
--        => tables, rows, SELECT grants and SELECT policies are kept.
--
-- NOT CHANGED: profiles grants/policies (W-2), any row, any column, any
-- table, any function, any trigger, Storage, Edge Functions, the
-- O-1 / O-2 / O-3 remediation, index.html.
--
-- ---------------------------------------------------------------------
-- SAFETY DESIGN
-- ---------------------------------------------------------------------
-- The whole change is ONE DO statement, so it is atomic regardless of
-- how the caller wraps it: any failed guard raises and nothing persists.
--   1. PREFLIGHT  - aborts unless the live state equals the reviewed
--      baseline exactly (ACLs, column ACLs, policies, view definition,
--      view columns and dependencies, join-safety constraints).
--   2. CHANGES    - the statements listed above.
--   3. POSTFLIGHT - aborts unless the resulting state is exactly the
--      intended one, including a row-by-row equivalence check of the new
--      view against its specification (the check returns no data).
-- search_path is pinned for the duration of the transaction so the
-- deparsed expressions compared by the guards are stable. All object
-- references in DDL are schema-qualified. No secrets are involved.
-- =====================================================================

do $migration$
declare
  -- ---- reviewed baseline, captured verbatim from the live catalog ----
  c_acl_wp_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ar/postgres}';
  c_acl_fl_before  constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=ard/postgres}';
  c_acl_users      constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}';
  c_acl_profiles   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_acl_view       constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';

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
  c_colacl_profiles constant text :=
       'available={authenticated=w/postgres};bio={authenticated=w/postgres};'
    || 'category={authenticated=w/postgres};country_flag={authenticated=w/postgres};'
    || 'display_name={authenticated=w/postgres};location={authenticated=w/postgres};'
    || 'looking_for={authenticated=w/postgres};role={authenticated=w/postgres};'
    || 'skills={authenticated=w/postgres}';

  -- policy signature: name|cmd|permissive|roles|USING|WITH CHECK  ({0} = PUBLIC)
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
  c_pol_follows_before constant text :=
       E'active users can create own follows|a|true|{0}|-|(follower_id = current_active_stagerz_user_id())\n'
    || E'active users can remove own follows|d|true|{0}|(follower_id = current_active_stagerz_user_id())|-\n'
    || 'follows are publicly readable|r|true|{0}|true|-';
  c_pol_likes_before constant text :=
       E'active users can create own likes|a|true|{0}|-|(user_id = current_active_stagerz_user_id())\n'
    || E'active users can remove own likes|d|true|{0}|(user_id = current_active_stagerz_user_id())|-\n'
    || 'likes are publicly readable|r|true|{0}|true|-';

  c_view_md5_before constant text := 'd86256ac1ad53a250c96c315ed69a52e';  -- pg_get_viewdef(oid, true)
  c_view_cols       constant text := 'id uuid,username text,photo_url text,is_system boolean,created_at timestamp with time zone,is_deleted boolean,display_name text';

  -- ---- intended result ------------------------------------------------
  c_acl_wp_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_acl_fl_after   constant text := '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,anon=r/postgres,authenticated=r/postgres}';
  c_colacl_wp_after constant text :=
       'category={authenticated=aw/postgres};compensation={authenticated=aw/postgres};'
    || 'description={authenticated=aw/postgres};location={authenticated=aw/postgres};'
    || 'remote={authenticated=aw/postgres};role_needed={authenticated=aw/postgres};'
    || 'status={authenticated=a/postgres};title={authenticated=aw/postgres};'
    || 'user_id={authenticated=a/postgres}';
  c_colacl_users_after constant text :=
       'bio={authenticated=r/postgres};first_name={authenticated=r/postgres};'
    || 'id={authenticated=r/postgres};last_name={authenticated=r/postgres};'
    || 'location={authenticated=r/postgres};photo_url={authenticated=r/postgres};'
    || 'username={authenticated=rw/postgres}';
  c_wp_insert_cols  constant text := 'user_id,title,description,role_needed,category,location,remote,compensation,status';
  c_wp_update_cols  constant text := 'title,description,role_needed,category,location,remote,compensation';
  c_users_select_cols constant text := 'id,username,first_name,last_name,photo_url,bio,location';
  c_pol_follows_after constant text := 'follows are publicly readable|r|true|{0}|true|-';
  c_pol_likes_after   constant text := 'likes are publicly readable|r|true|{0}|true|-';

  v_text text;
  v_count bigint;
begin
  perform set_config('search_path', 'public', true);

  -- ===================================================================
  -- 1. PREFLIGHT
  -- ===================================================================

  -- ---- table ACLs -----------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_before then
    raise exception 'preflight: wanted_posts ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.follows'::regclass) is distinct from c_acl_fl_before then
    raise exception 'preflight: follows ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.likes'::regclass) is distinct from c_acl_fl_before then
    raise exception 'preflight: likes ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.users'::regclass) is distinct from c_acl_users then
    raise exception 'preflight: users ACL differs from reviewed baseline';
  end if;
  if (select relacl::text from pg_class where oid = 'public.profiles'::regclass) is distinct from c_acl_profiles then
    raise exception 'preflight: profiles ACL differs from reviewed baseline';
  end if;

  -- ---- column ACLs (empty ACLs are ignored) ---------------------------
  if (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
       where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
         and coalesce(array_length(attacl, 1), 0) > 0)
     is distinct from c_colacl_wp_before then
    raise exception 'preflight: wanted_posts column ACLs differ from reviewed baseline';
  end if;
  if (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
       where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
         and coalesce(array_length(attacl, 1), 0) > 0)
     is distinct from c_colacl_users_before then
    raise exception 'preflight: users column ACLs differ from reviewed baseline';
  end if;
  if (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
       where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped
         and coalesce(array_length(attacl, 1), 0) > 0)
     is distinct from c_colacl_profiles then
    raise exception 'preflight: profiles column ACLs differ from reviewed baseline';
  end if;
  select count(*) into v_count from pg_attribute
   where attrelid in ('public.follows'::regclass, 'public.likes'::regclass, 'public.public_profiles'::regclass)
     and attnum > 0 and not attisdropped and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'preflight: unexpected column-level ACLs on follows / likes / public_profiles';
  end if;

  -- ---- policies -------------------------------------------------------
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.wanted_posts'::regclass) is distinct from c_pol_wp then
    raise exception 'preflight: wanted_posts policies differ from reviewed baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.users'::regclass) is distinct from c_pol_users then
    raise exception 'preflight: users policies differ from reviewed baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.profiles'::regclass) is distinct from c_pol_profiles then
    raise exception 'preflight: profiles policies differ from reviewed baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.follows'::regclass) is distinct from c_pol_follows_before then
    raise exception 'preflight: follows policies differ from reviewed baseline';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.likes'::regclass) is distinct from c_pol_likes_before then
    raise exception 'preflight: likes policies differ from reviewed baseline';
  end if;

  -- ---- RLS ------------------------------------------------------------
  if exists (select 1 from pg_class
              where oid in ('public.wanted_posts'::regclass, 'public.users'::regclass, 'public.profiles'::regclass,
                            'public.follows'::regclass, 'public.likes'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'preflight: RLS state on an affected table differs from reviewed baseline';
  end if;

  -- ---- public_profiles ------------------------------------------------
  if not exists (select 1 from pg_class
                  where oid = 'public.public_profiles'::regclass and relkind = 'v'
                    and relowner = 'postgres'::regrole and reloptions is null
                    and relacl::text = c_acl_view) then
    raise exception 'preflight: public_profiles kind / owner / options / ACL differ from reviewed baseline';
  end if;
  if md5(pg_get_viewdef('public.public_profiles'::regclass, true)) is distinct from c_view_md5_before then
    raise exception 'preflight: public_profiles definition differs from reviewed baseline';
  end if;
  if (select string_agg(attname::text || ' ' || format_type(atttypid, atttypmod), ',' order by attnum)
        from pg_attribute where attrelid = 'public.public_profiles'::regclass and attnum > 0 and not attisdropped)
     is distinct from c_view_cols then
    raise exception 'preflight: public_profiles columns differ from reviewed baseline';
  end if;
  if (select string_agg(distinct d.refobjid::regclass::text, ',' order by d.refobjid::regclass::text)
        from pg_depend d join pg_rewrite r on r.oid = d.objid
       where d.classid = 'pg_rewrite'::regclass and r.ev_class = 'public.public_profiles'::regclass
         and d.refclassid = 'pg_class'::regclass and d.refobjid <> 'public.public_profiles'::regclass)
     is distinct from 'users' then
    raise exception 'preflight: public_profiles dependencies differ from reviewed baseline';
  end if;
  if exists (select 1 from pg_depend d join pg_rewrite r on r.oid = d.objid
              where d.classid = 'pg_rewrite'::regclass and d.refobjid = 'public.public_profiles'::regclass
                and r.ev_class <> 'public.public_profiles'::regclass) then
    raise exception 'preflight: another view or rule depends on public_profiles';
  end if;

  -- ---- join safety for the new view: at most one profile per user -----
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.profiles'::regclass and conname = 'profiles_user_id_key'
                    and contype = 'u' and pg_get_constraintdef(oid) = 'UNIQUE (user_id)')
     or not exists (select 1 from pg_constraint
                     where conrelid = 'public.profiles'::regclass and conname = 'profiles_user_id_fkey'
                       and pg_get_constraintdef(oid) = 'FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE')
     or (select attnotnull::text || ' ' || format_type(atttypid, atttypmod) from pg_attribute
          where attrelid = 'public.profiles'::regclass and attname = 'user_id') is distinct from 'true uuid'
     or (select attnotnull::text || ' ' || format_type(atttypid, atttypmod) from pg_attribute
          where attrelid = 'public.profiles'::regclass and attname = 'display_name') is distinct from 'true text' then
    raise exception 'preflight: profiles.user_id uniqueness / FK / types differ from reviewed baseline';
  end if;

  -- ===================================================================
  -- 2. CHANGES
  -- ===================================================================

  -- ---- W-1 ------------------------------------------------------------
  revoke insert on table public.wanted_posts from authenticated;
  grant insert (user_id, title, description, role_needed, category,
                location, remote, compensation, status)
    on table public.wanted_posts to authenticated;

  -- ---- W-3 ------------------------------------------------------------
  revoke update (first_name, last_name, photo_url, bio, location)
    on table public.users from authenticated;

  create or replace view public.public_profiles as
  select u.id,
         u.username,
         u.photo_url,
         u.is_system,
         u.created_at,
         (u.anonymized_at is not null) as is_deleted,
         case
           when u.anonymized_at is not null then 'Deleted User'::text
           when nullif(btrim(p.display_name), ''::text) is not null then btrim(p.display_name)
           else coalesce(u.username, 'STAGERZ Artist'::text)
         end as display_name
    from public.users u
    left join public.profiles p on p.user_id = u.id;

  -- ---- W-4 ------------------------------------------------------------
  revoke insert, delete on table public.follows, public.likes from authenticated;
  drop policy "active users can create own follows" on public.follows;
  drop policy "active users can remove own follows" on public.follows;
  drop policy "active users can create own likes" on public.likes;
  drop policy "active users can remove own likes" on public.likes;

  -- ===================================================================
  -- 3. POSTFLIGHT
  -- ===================================================================

  -- ---- W-1 ------------------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.wanted_posts'::regclass) is distinct from c_acl_wp_after then
    raise exception 'postflight: wanted_posts ACL is not the intended one';
  end if;
  if (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
       where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
         and coalesce(array_length(attacl, 1), 0) > 0)
     is distinct from c_colacl_wp_after then
    raise exception 'postflight: wanted_posts column ACLs are not the intended ones';
  end if;
  if (select string_agg(attname::text, ',' order by attnum) from pg_attribute
       where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.wanted_posts', attnum, 'INSERT'))
     is distinct from c_wp_insert_cols then
    raise exception 'postflight: authenticated INSERT columns on wanted_posts are not exactly the nine intended';
  end if;
  if (select string_agg(attname::text, ',' order by attnum) from pg_attribute
       where attrelid = 'public.wanted_posts'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.wanted_posts', attnum, 'UPDATE'))
     is distinct from c_wp_update_cols then
    raise exception 'postflight: authenticated UPDATE columns on wanted_posts changed unexpectedly';
  end if;
  if not has_table_privilege('authenticated', 'public.wanted_posts', 'SELECT')
     or has_table_privilege('authenticated', 'public.wanted_posts', 'DELETE')
     or has_any_column_privilege('anon', 'public.wanted_posts', 'INSERT') then
    raise exception 'postflight: wanted_posts SELECT / DELETE / anon privileges changed unexpectedly';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.wanted_posts'::regclass) is distinct from c_pol_wp then
    raise exception 'postflight: wanted_posts policies changed unexpectedly';
  end if;

  -- ---- W-2 (must be untouched) ----------------------------------------
  if (select relacl::text from pg_class where oid = 'public.profiles'::regclass) is distinct from c_acl_profiles
     or (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
          where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped
            and coalesce(array_length(attacl, 1), 0) > 0) is distinct from c_colacl_profiles
     or (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                           || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                           || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
           from pg_policy where polrelid = 'public.profiles'::regclass) is distinct from c_pol_profiles then
    raise exception 'postflight: profiles grants or policies changed (W-2 must stay untouched)';
  end if;

  -- ---- W-3: users -----------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.users'::regclass) is distinct from c_acl_users then
    raise exception 'postflight: users ACL changed unexpectedly';
  end if;
  if (select string_agg(attname::text || '=' || attacl::text, ';' order by attname) from pg_attribute
       where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
         and coalesce(array_length(attacl, 1), 0) > 0)
     is distinct from c_colacl_users_after then
    raise exception 'postflight: users column ACLs are not the intended ones';
  end if;
  if (select string_agg(attname::text, ',' order by attnum) from pg_attribute
       where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.users', attnum, 'UPDATE'))
     is distinct from 'username' then
    raise exception 'postflight: authenticated UPDATE columns on users are not exactly username';
  end if;
  if (select string_agg(attname::text, ',' order by attnum) from pg_attribute
       where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped
         and has_column_privilege('authenticated', 'public.users', attnum, 'SELECT'))
     is distinct from c_users_select_cols then
    raise exception 'postflight: authenticated SELECT columns on users changed unexpectedly';
  end if;
  if has_any_column_privilege('anon', 'public.users', 'SELECT')
     or has_any_column_privilege('anon', 'public.users', 'UPDATE')
     or has_any_column_privilege('authenticated', 'public.users', 'INSERT')
     or has_table_privilege('authenticated', 'public.users', 'DELETE') then
    raise exception 'postflight: users privileges widened unexpectedly';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.users'::regclass) is distinct from c_pol_users then
    raise exception 'postflight: users policies changed unexpectedly';
  end if;

  -- ---- W-3: public_profiles security properties -----------------------
  if not exists (select 1 from pg_class
                  where oid = 'public.public_profiles'::regclass and relkind = 'v'
                    and relowner = 'postgres'::regrole and reloptions is null
                    and relacl::text = c_acl_view) then
    raise exception 'postflight: public_profiles kind / owner / options / ACL changed';
  end if;
  if (select string_agg(attname::text || ' ' || format_type(atttypid, atttypmod), ',' order by attnum)
        from pg_attribute where attrelid = 'public.public_profiles'::regclass and attnum > 0 and not attisdropped)
     is distinct from c_view_cols then
    raise exception 'postflight: public_profiles column names / order / types changed';
  end if;
  select count(*) into v_count from pg_attribute
   where attrelid = 'public.public_profiles'::regclass and attnum > 0 and not attisdropped
     and coalesce(array_length(attacl, 1), 0) > 0;
  if v_count <> 0 then
    raise exception 'postflight: public_profiles gained column-level ACLs';
  end if;
  if not has_table_privilege('anon', 'public.public_profiles', 'SELECT')
     or not has_table_privilege('authenticated', 'public.public_profiles', 'SELECT')
     or has_table_privilege('anon', 'public.public_profiles', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
     or has_table_privilege('authenticated', 'public.public_profiles', 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') then
    raise exception 'postflight: public_profiles anon / authenticated privileges changed';
  end if;
  if (select string_agg(distinct d.refobjid::regclass::text, ',' order by d.refobjid::regclass::text)
        from pg_depend d join pg_rewrite r on r.oid = d.objid
       where d.classid = 'pg_rewrite'::regclass and r.ev_class = 'public.public_profiles'::regclass
         and d.refclassid = 'pg_class'::regclass and d.refobjid <> 'public.public_profiles'::regclass)
     is distinct from 'profiles,users' then
    raise exception 'postflight: public_profiles does not depend on exactly profiles and users';
  end if;
  v_text := pg_get_viewdef('public.public_profiles'::regclass, true);
  if md5(v_text) = c_view_md5_before
     or position('first_name' in v_text) > 0
     or position('last_name' in v_text) > 0
     or position('LEFT JOIN profiles p ON p.user_id = u.id' in v_text) = 0 then
    raise exception 'postflight: public_profiles definition is not the intended one';
  end if;
  if (select is_updatable || '/' || is_insertable_into from information_schema.views
       where table_schema = 'public' and table_name = 'public_profiles') is distinct from 'NO/NO' then
    raise exception 'postflight: public_profiles is unexpectedly still auto-updatable';
  end if;

  -- ---- W-3: public_profiles row-by-row equivalence --------------------
  -- Same row set as users, and every column equals its specification.
  -- Only counts are computed; no row data leaves this statement.
  if (select count(*) from public.public_profiles) <> (select count(*) from public.users)
     or (select count(distinct id) from public.public_profiles) <> (select count(*) from public.users) then
    raise exception 'postflight: public_profiles row set differs from users';
  end if;
  select count(*) into v_count
    from public.users u
    left join public.profiles p on p.user_id = u.id
    left join public.public_profiles v on v.id = u.id
   where v.id is null
      or (v.username, v.photo_url, v.is_system, v.created_at, v.is_deleted, v.display_name)
         is distinct from
         (u.username, u.photo_url, u.is_system, u.created_at, (u.anonymized_at is not null),
          case
            when u.anonymized_at is not null then 'Deleted User'
            when p.display_name is not null and btrim(p.display_name) <> '' then btrim(p.display_name)
            when u.username is not null then u.username
            else 'STAGERZ Artist'
          end);
  if v_count <> 0 then
    raise exception 'postflight: public_profiles rows do not match the specification (% rows)', v_count;
  end if;

  -- ---- W-4 ------------------------------------------------------------
  if (select relacl::text from pg_class where oid = 'public.follows'::regclass) is distinct from c_acl_fl_after
     or (select relacl::text from pg_class where oid = 'public.likes'::regclass) is distinct from c_acl_fl_after then
    raise exception 'postflight: follows / likes ACL is not the intended one';
  end if;
  if has_any_column_privilege('authenticated', 'public.follows', 'INSERT')
     or has_any_column_privilege('authenticated', 'public.likes', 'INSERT')
     or has_table_privilege('authenticated', 'public.follows', 'DELETE')
     or has_table_privilege('authenticated', 'public.likes', 'DELETE')
     or has_any_column_privilege('authenticated', 'public.follows', 'UPDATE')
     or has_any_column_privilege('authenticated', 'public.likes', 'UPDATE') then
    raise exception 'postflight: authenticated can still write follows / likes';
  end if;
  if not has_table_privilege('authenticated', 'public.follows', 'SELECT')
     or not has_table_privilege('authenticated', 'public.likes', 'SELECT')
     or not has_table_privilege('anon', 'public.follows', 'SELECT')
     or not has_table_privilege('anon', 'public.likes', 'SELECT') then
    raise exception 'postflight: follows / likes SELECT privileges changed';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.follows'::regclass) is distinct from c_pol_follows_after then
    raise exception 'postflight: follows policy set is not the intended one';
  end if;
  if (select string_agg(polname::text || '|' || polcmd::text || '|' || polpermissive::text || '|' || polroles::text
                        || '|' || coalesce(pg_get_expr(polqual, polrelid), '-')
                        || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '-'), E'\n' order by polname)
        from pg_policy where polrelid = 'public.likes'::regclass) is distinct from c_pol_likes_after then
    raise exception 'postflight: likes policy set is not the intended one';
  end if;

  -- ---- common ---------------------------------------------------------
  if exists (select 1 from pg_class
              where oid in ('public.wanted_posts'::regclass, 'public.users'::regclass, 'public.profiles'::regclass,
                            'public.follows'::regclass, 'public.likes'::regclass)
                and (not relrowsecurity or relforcerowsecurity)) then
    raise exception 'postflight: RLS state changed on an affected table';
  end if;
  if (select count(*) from pg_policy p join pg_class c on c.oid = p.polrelid
       where c.relnamespace = 'public'::regnamespace) <> 21 then
    raise exception 'postflight: public policy count is not 21 (25 - 4)';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace) <> 34 then
    raise exception 'postflight: public function count changed';
  end if;
  -- O-1 / O-2 / O-3 remediation must still be in place
  if (select relacl::text from pg_class where oid = 'public.wanted_applications'::regclass)
       is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}'
     or (select relacl::text from pg_class where oid = 'public.collaboration_assets'::regclass)
       is distinct from '{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=r/postgres}'
     or (select pg_get_constraintdef(oid) from pg_constraint
          where conrelid = 'public.collaborations'::regclass and conname = 'collaborations_wanted_post_id_fkey')
       is distinct from 'FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT'
     or (select string_agg(attname::text, ',' order by attname) from pg_attribute
          where attrelid = 'public.collaboration_assets'::regclass and attnum > 0 and not attisdropped
            and has_column_privilege('authenticated', 'public.collaboration_assets', attnum, 'INSERT'))
       is distinct from 'asset_type,collaboration_id,description,file_name,file_size,mime_type,storage_path,title,uploaded_by' then
    raise exception 'postflight: O-1 / O-2 / O-3 remediation state is not intact';
  end if;
end
$migration$;
