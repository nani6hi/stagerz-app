-- =====================================================================
-- STAGERZ - backend integrity remediation (O-1 / O-2 / O-3)
-- READ-ONLY CATALOG FINGERPRINT
-- =====================================================================
-- Read-only. Catalog SELECTs only. Reads NO application row data.
-- Run it unchanged before and after the migration; compare the output
-- with the expected values recorded in validation.md.
--
-- Project ref : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- =====================================================================
with tabs as (
  select unnest(array[
    'public.wanted_applications',
    'public.wanted_posts',
    'public.collaborations',
    'public.collaboration_assets'
  ])::regclass as oid
)
select json_build_object(
  -- ---- objects this migration changes -------------------------------
  'tables', (
    select json_agg(json_build_object(
      'table', t.oid::text,
      'relacl', c.relacl::text,
      'rls_enabled', c.relrowsecurity,
      'rls_forced', c.relforcerowsecurity,
      'owner', pg_get_userbyid(c.relowner),
      'column_acls', (
        select json_object_agg(a.attname, a.attacl::text order by a.attname)
        from pg_attribute a
        where a.attrelid = t.oid and a.attnum > 0
          and not a.attisdropped and a.attacl is not null)
    ) order by t.oid::text)
    from tabs t join pg_class c on c.oid = t.oid),
  'policies', (
    select json_agg(json_build_object(
      'table', p.polrelid::regclass::text,
      'name', p.polname,
      'cmd', p.polcmd::text,
      'permissive', p.polpermissive,
      'roles', (select json_agg(case when r = 0 then 'public' else pg_get_userbyid(r) end order by 1)
                from unnest(p.polroles) r),
      'using', pg_get_expr(p.polqual, p.polrelid),
      'check', pg_get_expr(p.polwithcheck, p.polrelid)
    ) order by p.polrelid::regclass::text, p.polname)
    from pg_policy p where p.polrelid in (select oid from tabs)),
  'authenticated_privileges', (
    select json_object_agg(t.oid::text, json_build_object(
      'insert_table', has_table_privilege('authenticated', t.oid, 'INSERT'),
      'insert_any_column', has_any_column_privilege('authenticated', t.oid, 'INSERT'),
      'insert_columns', (
        select string_agg(a.attname, ',' order by a.attname)
        from pg_attribute a
        where a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped
          and has_column_privilege('authenticated', t.oid, a.attnum, 'INSERT')),
      'select', has_table_privilege('authenticated', t.oid, 'SELECT'),
      'update_any_column', has_any_column_privilege('authenticated', t.oid, 'UPDATE'),
      'delete', has_table_privilege('authenticated', t.oid, 'DELETE')
    ) order by t.oid::text)
    from tabs t),
  'collaborations_wanted_post_fk', (
    select json_build_object(
      'name', conname,
      'def', pg_get_constraintdef(oid),
      'on_delete', confdeltype::text,
      'on_update', confupdtype::text,
      'match', confmatchtype::text,
      'deferrable', condeferrable,
      'deferred', condeferred,
      'validated', convalidated)
    from pg_constraint
    where conrelid = 'public.collaborations'::regclass
      and conname = 'collaborations_wanted_post_id_fkey'),
  'collaborations_wanted_post_id_column', (
    select json_build_object('type', format_type(atttypid, atttypmod), 'not_null', attnotnull)
    from pg_attribute
    where attrelid = 'public.collaborations'::regclass and attname = 'wanted_post_id'),
  'collaborations_constraints', (
    select json_agg(conname || ' [' || contype::text || '] ' || pg_get_constraintdef(oid) order by conname)
    from pg_constraint where conrelid = 'public.collaborations'::regclass),
  'wanted_applications_wanted_post_fk', (
    select pg_get_constraintdef(oid) from pg_constraint
    where conrelid = 'public.wanted_applications'::regclass
      and conname = 'wanted_applications_wanted_post_id_fkey'),
  -- ---- whole-schema fingerprints (must change only where intended) ---
  'public_table_count', (
    select count(*) from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r'),
  'public_rls_enabled_count', (
    select count(*) from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' and relrowsecurity),
  'public_rls_forced_count', (
    select count(*) from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' and relforcerowsecurity),
  'public_policy_count', (
    select count(*) from pg_policy p join pg_class c on c.oid = p.polrelid
    where c.relnamespace = 'public'::regnamespace),
  'public_policies_md5_excluding_changed_tables', (
    select md5(string_agg(
      p.polrelid::regclass::text || '|' || p.polname || '|' || p.polcmd::text || '|' ||
      p.polpermissive::text || '|' || p.polroles::text || '|' ||
      coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '|' ||
      coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''),
      E'\n' order by p.polrelid::regclass::text, p.polname))
    from pg_policy p join pg_class c on c.oid = p.polrelid
    where c.relnamespace = 'public'::regnamespace
      and p.polrelid not in ('public.wanted_applications'::regclass,
                             'public.wanted_posts'::regclass,
                             'public.collaboration_assets'::regclass)),
  'public_relacl_md5_excluding_changed_tables', (
    select md5(string_agg(relname || '=' || coalesce(relacl::text, ''), E'\n' order by relname))
    from pg_class
    where relnamespace = 'public'::regnamespace and relkind in ('r', 'v')
      and relname not in ('wanted_applications', 'wanted_posts', 'collaboration_assets')),
  'public_attacl_md5_excluding_changed_tables', (
    select md5(string_agg(c.relname || '.' || a.attname || '=' || a.attacl::text, E'\n' order by c.relname, a.attname))
    from pg_attribute a join pg_class c on c.oid = a.attrelid
    where c.relnamespace = 'public'::regnamespace and a.attacl is not null
      and c.relname not in ('wanted_applications', 'wanted_posts', 'collaboration_assets')),
  'public_fk_count', (
    select count(*) from pg_constraint where contype = 'f' and connamespace = 'public'::regnamespace),
  'public_fk_md5_excluding_changed_fk', (
    select md5(string_agg(conrelid::regclass::text || '.' || conname || ' ' || pg_get_constraintdef(oid),
                          E'\n' order by conrelid::regclass::text, conname))
    from pg_constraint
    where contype = 'f' and connamespace = 'public'::regnamespace
      and conname <> 'collaborations_wanted_post_id_fkey'),
  'public_function_definitions_md5', (
    select md5(string_agg(proname || ':' || md5(pg_get_functiondef(oid)), ',' order by proname))
    from pg_proc where pronamespace = 'public'::regnamespace),
  'public_function_acl_md5', (
    select md5(string_agg(proname || ':' || coalesce(proacl::text, ''), ',' order by proname))
    from pg_proc where pronamespace = 'public'::regnamespace),
  'public_function_count', (
    select count(*) from pg_proc where pronamespace = 'public'::regnamespace),
  'public_trigger_md5', (
    select md5(string_agg(c.relname || '.' || t.tgname || ' ' || pg_get_triggerdef(t.oid), E'\n' order by c.relname, t.tgname))
    from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and c.relnamespace = 'public'::regnamespace),
  'public_profiles', (
    select json_build_object('relacl', relacl::text, 'reloptions', reloptions,
                             'viewdef_md5', md5(pg_get_viewdef(oid, true)))
    from pg_class where oid = 'public.public_profiles'::regclass),
  'pending_asset_deletions', (
    select json_build_object('relacl', relacl::text, 'rls_enabled', relrowsecurity,
      'policies', (select count(*) from pg_policy where polrelid = 'public.pending_asset_deletions'::regclass))
    from pg_class where oid = 'public.pending_asset_deletions'::regclass),
  'storage_objects_policies_md5', (
    select md5(string_agg(policyname || '|' || cmd || '|' || coalesce(qual, '') || '|' || coalesce(with_check, ''),
                          E'\n' order by policyname))
    from pg_policies where schemaname = 'storage' and tablename = 'objects'),
  'migration_history', (
    select json_build_object('count', count(*), 'latest', max(version))
    from supabase_migrations.schema_migrations)
) as fingerprint;
