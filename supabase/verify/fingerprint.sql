-- =====================================================================
-- STAGERZ — reproducibility fingerprint (READ-ONLY)
-- =====================================================================
-- Run against ANY STAGERZ environment (production, test, rebuilt). It only
-- reads the catalog and returns md5 fingerprints per category of
-- APPLICATION-OWNED state, plus a few environment-specific values that are
-- reported but never compared.
--
-- Gate: a rebuilt environment passes when every key under "exact" equals
-- supabase/verify/expected-production.json -> "exact". Keys under
-- "environment" are informational (they legitimately differ between
-- environments). No row content, user data or secret is read.
--
-- Marker: STAGERZ-FINGERPRINT-v1
-- =====================================================================
WITH
cols AS (
  SELECT c.relname, a.attnum, a.attname, format_type(a.atttypid, a.atttypmod) AS typ, a.attnotnull,
         pg_get_expr(d.adbin, d.adrelid) AS def
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m')
),
app_triggers AS (
  SELECT n.nspname, c.relname, t.tgname, pg_get_triggerdef(t.oid, true) AS def, t.tgenabled
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE NOT t.tgisinternal AND (n.nspname = 'public' OR (n.nspname = 'auth' AND c.relname = 'users'))
),
rel_grants AS (
  SELECT c.relname, CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END AS grantee, x.privilege_type, x.is_grantable
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
  WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m','S','f') AND x.grantee <> c.relowner
),
col_grants AS (
  SELECT c.relname, a.attname, CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END AS grantee, x.privilege_type
  FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(a.attacl) x
  WHERE n.nspname = 'public' AND a.attacl IS NOT NULL AND a.attnum > 0 AND NOT a.attisdropped
),
fns AS (
  SELECT p.oid, p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS sig, p.proowner, p.proacl
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'
),
fn_grants AS (
  SELECT f.sig, CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END AS grantee, x.privilege_type
  FROM fns f CROSS JOIN LATERAL aclexplode(coalesce(f.proacl, acldefault('f', f.proowner))) x
  WHERE x.grantee <> f.proowner
),
pols AS (
  SELECT schemaname, tablename, policyname, permissive, array_to_string(roles, ',') AS roles, cmd,
         coalesce(qual, '') AS q, coalesce(with_check, '') AS wc
  FROM pg_policies WHERE schemaname IN ('public', 'storage')
),
dacl AS (
  SELECT n.nspname, d.defaclobjtype::text AS objtype,
         CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END AS grantee, x.privilege_type
  FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) x
  WHERE pg_get_userbyid(d.defaclrole) = 'postgres' AND n.nspname IN ('public', 'storage')
)
SELECT jsonb_build_object(
  'marker', 'STAGERZ-FINGERPRINT-v1',
  'exact', jsonb_build_object(
    'relations', (SELECT md5(string_agg(c.relname || ':' || c.relkind::text || ':' || c.relrowsecurity || ':' || c.relforcerowsecurity, '|' ORDER BY c.relname))
                  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m','S','f')),
    'relation_count', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m','S','f')),
    'columns', (SELECT md5(string_agg(relname || '.' || attnum || '.' || attname || ':' || typ || ':' || attnotnull || ':' || coalesce(def, ''), '|' ORDER BY relname, attnum)) FROM cols),
    'column_count', (SELECT count(*) FROM cols),
    'constraints', (SELECT md5(string_agg(c.relname || ':' || k.conname || ':' || k.contype::text || ':' || pg_get_constraintdef(k.oid, true), '|' ORDER BY c.relname, k.conname))
                    FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public'),
    'indexes', (SELECT md5(string_agg(ic.relname || ':' || pg_get_indexdef(i.indexrelid), '|' ORDER BY ic.relname))
                FROM pg_index i JOIN pg_class ic ON ic.oid = i.indexrelid JOIN pg_namespace n ON n.oid = ic.relnamespace WHERE n.nspname = 'public'),
    'views', (SELECT md5(string_agg(c.relname || ':' || coalesce(array_to_string(c.reloptions, ','), '') || ':' || pg_get_viewdef(c.oid, true), '|' ORDER BY c.relname))
              FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('v','m')),
    'functions', (SELECT md5(string_agg(f.sig || ':' || md5(pg_get_functiondef(f.oid)), '|' ORDER BY f.sig)) FROM fns f),
    'function_count', (SELECT count(*) FROM fns),
    'triggers', (SELECT md5(string_agg(nspname || '.' || relname || '.' || tgname || ':' || tgenabled::text || ':' || def, '|' ORDER BY nspname, relname, tgname)) FROM app_triggers),
    'trigger_count', (SELECT count(*) FROM app_triggers),
    'policies', (SELECT md5(string_agg(schemaname || '.' || tablename || '.' || policyname || ':' || permissive || ':' || roles || ':' || cmd || ':' || q || ':' || wc, '|' ORDER BY schemaname, tablename, policyname)) FROM pols),
    'policy_count', (SELECT count(*) FROM pols),
    'relation_grants', (SELECT md5(string_agg(relname || ':' || grantee || ':' || privilege_type || ':' || is_grantable, '|' ORDER BY relname, grantee, privilege_type)) FROM rel_grants),
    'column_grants', (SELECT md5(string_agg(relname || '.' || attname || ':' || grantee || ':' || privilege_type, '|' ORDER BY relname, attname, grantee, privilege_type)) FROM col_grants),
    'function_grants', (SELECT md5(string_agg(sig || ':' || grantee || ':' || privilege_type, '|' ORDER BY sig, grantee, privilege_type)) FROM fn_grants),
    'default_privileges', (SELECT md5(string_agg(nspname || '/' || objtype || ':' || grantee || ':' || privilege_type, '|' ORDER BY nspname, objtype, grantee, privilege_type)) FROM dacl),
    'realtime_members', (SELECT string_agg(pt.tablename, ',' ORDER BY pt.tablename) FROM pg_publication_tables pt WHERE pt.pubname = 'supabase_realtime' AND pt.schemaname = 'public'),
    'buckets', (SELECT string_agg(id || ':' || public || ':' || coalesce(file_size_limit::text, '-') || ':' || coalesce(array_to_string(allowed_mime_types, ','), '-'), '|' ORDER BY id) FROM storage.buckets),
    'app_extensions', (SELECT string_agg(e.extname || '@' || n.nspname, ',' ORDER BY e.extname) FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname IN ('pgcrypto', 'uuid-ossp'))
  ),
  'environment', jsonb_build_object(
    'database_version', current_setting('server_version'),
    'extension_versions', (SELECT string_agg(extname || ' ' || extversion, ', ' ORDER BY extname) FROM pg_extension),
    -- migration history is environment-specific; read it separately with
    -- `supabase migration list` (this query must also run on a fresh project
    -- where supabase_migrations may not exist yet).
    'migration_history_present', to_regclass('supabase_migrations.schema_migrations') IS NOT NULL,
    'app_row_counts_total', (SELECT sum(n_live_tup) FROM pg_stat_user_tables WHERE schemaname = 'public'),
    'auth_users', (SELECT count(*) FROM auth.users),
    'storage_objects', (SELECT count(*) FROM storage.objects)
  )
) AS fingerprint;
