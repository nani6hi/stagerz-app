-- =====================================================================
-- STAGERZ seed — (b) TECHNICAL VALIDATION FIXTURES      NON-PRODUCTION ONLY
-- =====================================================================
-- Three synthetic accounts and one small collaboration scenario for manual
-- end-to-end checks and behavioural validation on a local or test
-- environment.
--
-- * Synthetic identities only, on the reserved `.test` top-level domain
--   (RFC 2606), so they can never reach a real mailbox. Passwordless: sign
--   in through the environment's own magic-link flow (locally the link
--   appears in the stack's mail catcher).
-- * Auth users are inserted with fixed ids. The application's own trigger
--   on_auth_user_created -> handle_new_auth_user() then creates each
--   public.users / profiles / user_auth_accounts row exactly as a real
--   sign-up does. The fixture then gives those rows fixed usernames and
--   display names.
-- * Deterministic keys: auth ids 00000000-0000-4000-b000-0000000000x1,
--   usernames fixture_owner / fixture_member / fixture_applicant, and
--   fixed ids for posts, collaboration, task and message. Re-running is a
--   no-op.
-- * Refuses to run if any existing Auth user is not a fixture account,
--   which is the production guard.
-- * Requires the canonical baseline (and optionally showcase.sql) first.
-- =====================================================================

DO $fixture_guard$
BEGIN
  IF to_regclass('public.user_auth_accounts') IS NULL THEN
    RAISE EXCEPTION 'fixtures: baseline not applied';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE email IS NULL OR email NOT LIKE 'fixture-%@stagerz.test') THEN
    RAISE EXCEPTION 'fixtures: database contains non-fixture Auth users - refusing (never seed production)';
  END IF;
END
$fixture_guard$;

-- 1. Auth accounts (no password; confirmed so magic-link sign-in works immediately)
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
SELECT '00000000-0000-0000-0000-000000000000', v.id, 'authenticated', 'authenticated', v.email, '', now(),
       '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('display_name', v.display_name), now(), now(),
       '', '', '', ''
FROM (VALUES
  ('00000000-0000-4000-b000-000000000011'::uuid, 'fixture-owner@stagerz.test',     'Fixture Owner'),
  ('00000000-0000-4000-b000-000000000021'::uuid, 'fixture-member@stagerz.test',    'Fixture Member'),
  ('00000000-0000-4000-b000-000000000031'::uuid, 'fixture-applicant@stagerz.test', 'Fixture Applicant')
) AS v(id, email, display_name)
WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v.id);

INSERT INTO auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
SELECT gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), now(), now(), NULL
FROM auth.users u
WHERE u.email LIKE 'fixture-%@stagerz.test'
  AND NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email');

-- 2. Give the trigger-created public rows deterministic, recognisable names
UPDATE public.users pu SET username = v.username, first_name = v.first_name
FROM public.user_auth_accounts m
JOIN (VALUES
  ('00000000-0000-4000-b000-000000000011'::uuid, 'fixture_owner',     'Owner'),
  ('00000000-0000-4000-b000-000000000021'::uuid, 'fixture_member',    'Member'),
  ('00000000-0000-4000-b000-000000000031'::uuid, 'fixture_applicant', 'Applicant')
) AS v(auth_id, username, first_name) ON v.auth_id = m.auth_user_id
WHERE pu.id = m.public_user_id AND pu.username IS DISTINCT FROM v.username;

-- 3. Scenario: owner has one open post (applicant has applied) and one
--    closed post that became a collaboration with the member.
DO $fixture_scenario$
DECLARE
  v_owner uuid; v_member uuid; v_applicant uuid;
BEGIN
  SELECT id INTO v_owner     FROM public.users WHERE username = 'fixture_owner';
  SELECT id INTO v_member    FROM public.users WHERE username = 'fixture_member';
  SELECT id INTO v_applicant FROM public.users WHERE username = 'fixture_applicant';
  IF v_owner IS NULL OR v_member IS NULL OR v_applicant IS NULL THEN
    RAISE EXCEPTION 'fixtures: sign-up trigger did not create the public users';
  END IF;

  INSERT INTO public.wanted_posts (id, user_id, title, description, role_needed, status) VALUES
    ('00000000-0000-4000-b000-000000000101', v_owner, 'Fixture open post',   'Validation fixture.', 'Bassist', 'open'),
    ('00000000-0000-4000-b000-000000000102', v_owner, 'Fixture closed post', 'Validation fixture.', 'Drummer', 'closed')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.wanted_applications (id, wanted_post_id, applicant_id, status) VALUES
    ('00000000-0000-4000-b000-000000000201', '00000000-0000-4000-b000-000000000101', v_applicant, 'pending')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.collaborations (id, wanted_post_id, title, status) VALUES
    ('00000000-0000-4000-b000-000000000301', '00000000-0000-4000-b000-000000000102', 'Fixture collaboration', 'active')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.collaboration_participants (id, collaboration_id, user_id, participant_type) VALUES
    ('00000000-0000-4000-b000-000000000401', '00000000-0000-4000-b000-000000000301', v_owner,  'owner'),
    ('00000000-0000-4000-b000-000000000402', '00000000-0000-4000-b000-000000000301', v_member, 'member')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.collaboration_tasks (id, collaboration_id, creator_id, assignee_id, title, status) VALUES
    ('00000000-0000-4000-b000-000000000501', '00000000-0000-4000-b000-000000000301', v_owner, v_member, 'Fixture task', 'todo')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.collaboration_messages (id, collaboration_id, sender_id, body) VALUES
    ('00000000-0000-4000-b000-000000000601', '00000000-0000-4000-b000-000000000301', v_owner, 'Fixture message.')
  ON CONFLICT (id) DO NOTHING;
END
$fixture_scenario$;
