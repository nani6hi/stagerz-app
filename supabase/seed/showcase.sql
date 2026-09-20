-- =====================================================================
-- STAGERZ seed — (a) SHOWCASE / DEMO DATA            NON-PRODUCTION ONLY
-- =====================================================================
-- Fictional "system" artists and open Wanted posts so a fresh local or
-- test environment does not look empty. Newly written for Phase 22.3.
-- NOT copied from production, and containing no real person, e-mail,
-- photo or uploaded file.
--
-- * Deterministic: fixed UUIDs in the reserved block
--   00000000-0000-4000-a000-0000000001xx; re-running is a no-op
--   (ON CONFLICT DO NOTHING).
-- * No Auth users: showcase artists cannot sign in (is_system = true).
-- * Requires the canonical baseline to be applied first.
-- * Refuses to run when the database already holds users that are not
--   part of this showcase, which is the production guard: production
--   has real accounts.
-- =====================================================================

DO $showcase_guard$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'showcase seed: baseline not applied (public.users missing)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users
             WHERE id NOT IN ('00000000-0000-4000-a000-000000000101','00000000-0000-4000-a000-000000000102',
                              '00000000-0000-4000-a000-000000000103','00000000-0000-4000-a000-000000000104')
               AND username NOT LIKE 'fixture\_%') THEN
    RAISE EXCEPTION 'showcase seed: database contains non-seed users - refusing (never seed production)';
  END IF;
END
$showcase_guard$;

INSERT INTO public.users (id, username, first_name, bio, location, is_system) VALUES
  ('00000000-0000-4000-a000-000000000101', 'showcase_nova_keys',    'Nova',   'Synth player and producer (fictional showcase profile).', 'Berlin',    true),
  ('00000000-0000-4000-a000-000000000102', 'showcase_rio_motion',   'Rio',    'Contemporary dancer (fictional showcase profile).',       'Lisbon',    true),
  ('00000000-0000-4000-a000-000000000103', 'showcase_ada_frames',   'Ada',    'Music-video director (fictional showcase profile).',      'Vienna',    true),
  ('00000000-0000-4000-a000-000000000104', 'showcase_juno_strings', 'Juno',   'Session violinist (fictional showcase profile).',         'Amsterdam', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, user_id, display_name, role, category, skills, looking_for, location, available) VALUES
  ('00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000101', 'Nova Keys',    'Producer',  'music', ARRAY['synth','mixing'],       ARRAY['vocalist'],     'Berlin',    true),
  ('00000000-0000-4000-a000-000000000202', '00000000-0000-4000-a000-000000000102', 'Rio Motion',   'Dancer',    'dance', ARRAY['contemporary'],         ARRAY['choreographer'],'Lisbon',    true),
  ('00000000-0000-4000-a000-000000000203', '00000000-0000-4000-a000-000000000103', 'Ada Frames',   'Director',  'film',  ARRAY['directing','editing'],  ARRAY['musician'],     'Vienna',    true),
  ('00000000-0000-4000-a000-000000000204', '00000000-0000-4000-a000-000000000104', 'Juno Strings', 'Violinist', 'music', ARRAY['violin','arranging'],   ARRAY['producer'],     'Amsterdam', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wanted_posts (id, user_id, title, description, role_needed, category, location, remote, status) VALUES
  ('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000101', 'Vocalist for a synth-pop single', 'Fictional showcase post.', 'Vocalist',      'music', 'Berlin', true,  'open'),
  ('00000000-0000-4000-a000-000000000302', '00000000-0000-4000-a000-000000000102', 'Choreographer for a short piece', 'Fictional showcase post.', 'Choreographer', 'dance', 'Lisbon', false, 'open'),
  ('00000000-0000-4000-a000-000000000303', '00000000-0000-4000-a000-000000000103', 'Composer for a music video',      'Fictional showcase post.', 'Composer',      'film',  'Vienna', true,  'open')
ON CONFLICT (id) DO NOTHING;
