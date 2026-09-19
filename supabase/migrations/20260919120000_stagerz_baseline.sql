-- =====================================================================
-- STAGERZ — CANONICAL BACKEND BASELINE (application-owned DDL)
-- migration version 20260919120000
-- =====================================================================
--  ####  CANONICAL — VERIFIED — NOT YET RECORDED IN PRODUCTION HISTORY  ####
--
-- PROVENANCE
--   Generated deterministically by Phase 22.3 from read-only catalog
--   extractions of the production backend of record kbnmkyvbwkuvcklywdhk
--   (P223-DDL-REL/FN/SEC-v1, 2026-09-19; PostgreSQL 17.6; production
--   migration history 43 rows, latest 20260917143322).
--   Promoted unchanged from supabase/baseline/stagerz_baseline.DRAFT.sql,
--   whose verified SHA-256 was
--     7ae91fd169c8579875f0889bcc96e480d9a5b1fd9d453aa96c5a399b1ddba185
--   Everything below the header comment is byte-for-byte that file; only
--   these header comments differ. Evidence:
--   analysis/phase-22.3/baseline-verification-record.md
--
-- VERIFIED (2026-09-20, isolated Docker, supabase/postgres:17.6.1.167)
--   * applied unmodified to two separate EMPTY databases: both exit 0
--   * fingerprint vs supabase/verify/expected-production.json:
--     20/20 exact categories PASS on both runs
--   * run #1 and run #2 byte-identical across all 20 categories
--   * STAGERZ Storage database contract verified (bucket + 2 policies + RLS)
--
-- PURPOSE  Rebuild the STAGERZ application schema on a FRESH, EMPTY
--          Supabase-managed database. It reproduces the CURRENT production
--          state, including the Phase 21.4-21.7 privilege hardening that
--          exists outside the production migration history.
--
-- NEVER    execute against production (kbnmkyvbwkuvcklywdhk) or the legacy
--          project (edxicnafggnnvcdvxemk). Production already holds the
--          equivalent schema; recording this version in production's
--          migration history is a separate, metadata-only, owner-approved
--          operation. The guard below refuses any database that already
--          contains STAGERZ tables.
--
-- PREREQUISITES (platform-managed, must exist first — see supabase/README.md)
--          Supabase roles; auth schema and objects; storage schema with
--          storage.buckets and storage.objects (created by the Storage
--          service's own tenant migrations); the supabase_realtime
--          publication. Storage policies require an owner-capable role
--          context.
--
-- CONTAINS schema, functions, triggers, RLS, policies, grants, default
--          privileges, the Storage bucket definition and its policies, and
--          the Realtime publication membership. NO data, NO users, NO
--          secrets, NO keys. Seed data lives only in supabase/seed/.
--
-- EXCLUDES platform-managed state: schemas auth, storage, realtime, vault,
--          graphql*, extensions' own objects, platform event triggers,
--          storage-internal triggers, role settings.
-- =====================================================================

SET check_function_bodies = false;
SET client_min_messages = warning;

DO $guard$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'public' AND c.relname IN ('collaborations','users','wanted_posts')) THEN
    RAISE EXCEPTION 'STAGERZ baseline: target already contains STAGERZ tables - refusing (never run on production)';
  END IF;
END
$guard$;

-- =====================================================================
-- 1. Extensions required by the application (idempotent)
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
-- pg_stat_statements, supabase_vault, plpgsql: platform-provided; not created here.

-- =====================================================================
-- 2. Tables (columns, defaults, NOT NULL)
-- =====================================================================

CREATE TABLE public.collaboration_activity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    actor_user_id uuid,
    activity_type text NOT NULL,
    reference_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collaboration_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    uploaded_by uuid NOT NULL,
    storage_path text NOT NULL,
    file_name text NOT NULL,
    mime_type text NOT NULL,
    file_size bigint NOT NULL,
    asset_type text NOT NULL,
    title text,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);

CREATE TABLE public.collaboration_credits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    user_id uuid NOT NULL,
    credit_role text NOT NULL,
    credit_order integer DEFAULT 0 NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collaboration_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collaboration_participants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    user_id uuid NOT NULL,
    source_application_id uuid,
    participant_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collaboration_tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collaboration_id uuid NOT NULL,
    creator_id uuid NOT NULL,
    assignee_id uuid,
    title text NOT NULL,
    status text DEFAULT 'todo'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);

CREATE TABLE public.collaborations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wanted_post_id uuid NOT NULL,
    title text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    archived_at timestamp with time zone
);

CREATE TABLE public.follows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    follower_id uuid NOT NULL,
    following_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    post_id uuid NOT NULL,
    post_type text DEFAULT 'performance'::text,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    message text DEFAULT ''::text,
    from_user_id uuid,
    read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    wanted_post_id uuid,
    wanted_application_id uuid,
    target_type text,
    target_id uuid
);

CREATE TABLE public.pending_asset_deletions (
    asset_id uuid NOT NULL,
    collaboration_id uuid NOT NULL,
    file_name text NOT NULL,
    storage_path text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    last_attempted_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.pending_auth_deletions (
    auth_user_id uuid NOT NULL,
    public_user_id uuid NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    last_attempted_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    display_name text NOT NULL,
    role text DEFAULT ''::text,
    category text DEFAULT 'music'::text,
    skills text[] DEFAULT '{}'::text[],
    looking_for text[] DEFAULT '{}'::text[],
    location text DEFAULT ''::text,
    country_flag text DEFAULT ''::text,
    rating numeric DEFAULT 5.0,
    followers_count integer DEFAULT 0,
    collab_count integer DEFAULT 0,
    project_count integer DEFAULT 0,
    available boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    bio text DEFAULT ''::text
);

CREATE TABLE public.user_auth_accounts (
    auth_user_id uuid NOT NULL,
    public_user_id uuid NOT NULL,
    linked_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username text,
    first_name text,
    last_name text,
    photo_url text,
    bio text DEFAULT ''::text,
    location text DEFAULT ''::text,
    is_system boolean DEFAULT false NOT NULL,
    blocked boolean DEFAULT false NOT NULL,
    anonymized_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.wanted_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wanted_post_id uuid NOT NULL,
    applicant_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.wanted_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text,
    role_needed text NOT NULL,
    category text DEFAULT 'music'::text,
    location text DEFAULT ''::text,
    remote boolean DEFAULT true,
    compensation text DEFAULT 'rev_share'::text,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- =====================================================================
-- 3. Primary key, unique and check constraints
-- =====================================================================
ALTER TABLE ONLY public.collaboration_activity ADD CONSTRAINT collaboration_activity_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_assets ADD CONSTRAINT collaboration_assets_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_assets ADD CONSTRAINT collaboration_assets_storage_path_key UNIQUE (storage_path);
ALTER TABLE ONLY public.collaboration_assets ADD CONSTRAINT collaboration_assets_file_size_check CHECK (file_size > 0);
ALTER TABLE ONLY public.collaboration_credits ADD CONSTRAINT collaboration_credits_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_messages ADD CONSTRAINT collaboration_messages_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_messages ADD CONSTRAINT collaboration_messages_body_check CHECK (length(TRIM(BOTH FROM body)) > 0 AND length(body) <= 5000);
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_collaboration_id_user_id_key UNIQUE (collaboration_id, user_id);
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_source_application_id_key UNIQUE (source_application_id);
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_participant_type_check CHECK (participant_type = ANY (ARRAY['owner'::text, 'member'::text]));
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_status_check CHECK (status = ANY (ARRAY['todo'::text, 'done'::text]));
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_title_check CHECK (length(TRIM(BOTH FROM title)) > 0 AND length(title) <= 300);
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT done_has_completed_at CHECK (status <> 'done'::text OR completed_at IS NOT NULL);
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT todo_has_no_completed_at CHECK (status <> 'todo'::text OR completed_at IS NULL);
ALTER TABLE ONLY public.collaborations ADD CONSTRAINT collaborations_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.collaborations ADD CONSTRAINT collaborations_wanted_post_id_key UNIQUE (wanted_post_id);
ALTER TABLE ONLY public.collaborations ADD CONSTRAINT collaborations_status_check CHECK (status = ANY (ARRAY['active'::text, 'completed'::text, 'archived'::text]));
ALTER TABLE ONLY public.follows ADD CONSTRAINT follows_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.follows ADD CONSTRAINT follows_follower_id_following_id_key UNIQUE (follower_id, following_id);
ALTER TABLE ONLY public.follows ADD CONSTRAINT no_self_follow CHECK (follower_id <> following_id);
ALTER TABLE ONLY public.likes ADD CONSTRAINT likes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.likes ADD CONSTRAINT likes_user_id_post_id_post_type_key UNIQUE (user_id, post_id, post_type);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.pending_asset_deletions ADD CONSTRAINT pending_asset_deletions_pkey PRIMARY KEY (storage_path);
ALTER TABLE ONLY public.pending_auth_deletions ADD CONSTRAINT pending_auth_deletions_pkey PRIMARY KEY (auth_user_id);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);
ALTER TABLE ONLY public.user_auth_accounts ADD CONSTRAINT user_auth_accounts_pkey PRIMARY KEY (auth_user_id);
ALTER TABLE ONLY public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.users ADD CONSTRAINT users_username_key UNIQUE (username);
ALTER TABLE ONLY public.wanted_applications ADD CONSTRAINT wanted_applications_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.wanted_applications ADD CONSTRAINT wanted_applications_wanted_post_id_applicant_id_key UNIQUE (wanted_post_id, applicant_id);
ALTER TABLE ONLY public.wanted_applications ADD CONSTRAINT wanted_applications_status_check CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text, 'withdrawn'::text]));
ALTER TABLE ONLY public.wanted_posts ADD CONSTRAINT wanted_posts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.wanted_posts ADD CONSTRAINT wanted_posts_status_check CHECK (status = ANY (ARRAY['open'::text, 'closed'::text]));

-- =====================================================================
-- 4. Foreign keys (after all tables exist)
-- =====================================================================
ALTER TABLE ONLY public.collaboration_activity ADD CONSTRAINT collaboration_activity_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.collaboration_activity ADD CONSTRAINT collaboration_activity_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_assets ADD CONSTRAINT collaboration_assets_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_assets ADD CONSTRAINT collaboration_assets_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_credits ADD CONSTRAINT collaboration_credits_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_credits ADD CONSTRAINT collaboration_credits_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_credits ADD CONSTRAINT collaboration_credits_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_messages ADD CONSTRAINT collaboration_messages_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_messages ADD CONSTRAINT collaboration_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_source_application_id_fkey FOREIGN KEY (source_application_id) REFERENCES wanted_applications(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.collaboration_participants ADD CONSTRAINT collaboration_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_collaboration_id_fkey FOREIGN KEY (collaboration_id) REFERENCES collaborations(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaboration_tasks ADD CONSTRAINT collaboration_tasks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.collaborations ADD CONSTRAINT collaborations_wanted_post_id_fkey FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.follows ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES users(id);
ALTER TABLE ONLY public.follows ADD CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES users(id);
ALTER TABLE ONLY public.likes ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES users(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_wanted_application_id_fkey FOREIGN KEY (wanted_application_id) REFERENCES wanted_applications(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.notifications ADD CONSTRAINT notifications_wanted_post_id_fkey FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.pending_auth_deletions ADD CONSTRAINT pending_auth_deletions_public_user_id_fkey FOREIGN KEY (public_user_id) REFERENCES users(id);
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.user_auth_accounts ADD CONSTRAINT user_auth_accounts_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.user_auth_accounts ADD CONSTRAINT user_auth_accounts_public_user_id_fkey FOREIGN KEY (public_user_id) REFERENCES users(id);
ALTER TABLE ONLY public.wanted_applications ADD CONSTRAINT wanted_applications_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.wanted_applications ADD CONSTRAINT wanted_applications_wanted_post_id_fkey FOREIGN KEY (wanted_post_id) REFERENCES wanted_posts(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.wanted_posts ADD CONSTRAINT wanted_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

-- =====================================================================
-- 5. Indexes not backed by a constraint
-- =====================================================================
CREATE INDEX idx_collaboration_activity_feed ON public.collaboration_activity USING btree (collaboration_id, created_at);
CREATE INDEX idx_collaboration_assets_feed ON public.collaboration_assets USING btree (collaboration_id, created_at);
CREATE INDEX idx_collaboration_credits_order ON public.collaboration_credits USING btree (collaboration_id, credit_order);
CREATE INDEX idx_collaboration_messages_feed ON public.collaboration_messages USING btree (collaboration_id, created_at);
CREATE UNIQUE INDEX idx_one_owner_per_collaboration ON public.collaboration_participants USING btree (collaboration_id) WHERE (participant_type = 'owner'::text);
CREATE INDEX idx_collaboration_tasks_feed ON public.collaboration_tasks USING btree (collaboration_id, created_at);
CREATE INDEX idx_follows_following ON public.follows USING btree (following_id);
CREATE INDEX idx_likes_post ON public.likes USING btree (post_id, post_type);
CREATE INDEX idx_likes_user ON public.likes USING btree (user_id);
CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, read, created_at DESC);
CREATE INDEX idx_user_auth_accounts_public_user ON public.user_auth_accounts USING btree (public_user_id);
CREATE INDEX idx_wanted_applications_applicant ON public.wanted_applications USING btree (applicant_id);
CREATE INDEX idx_wanted_posts_status ON public.wanted_posts USING btree (status);
CREATE INDEX idx_wanted_posts_user ON public.wanted_posts USING btree (user_id);

-- =====================================================================
-- 6. Functions (34, all SECURITY DEFINER, owner postgres)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.admin_anonymize_account(p_public_user_id uuid)
 RETURNS TABLE(pending_auth_user_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (select 1 from public.users where id = p_public_user_id) then
    raise exception 'target_not_found' using errcode = 'P0007';
  end if;

  update public.users
    set anonymized_at = coalesce(anonymized_at, now()),
        username = null, first_name = null, last_name = null,
        photo_url = null, bio = null, location = null
    where id = p_public_user_id;

  update public.profiles
    set display_name = 'Deleted User', role = '', category = null,
        skills = '{}', looking_for = '{}', location = '', country_flag = ''
    where user_id = p_public_user_id;

  return query
    select auth_user_id from public.user_auth_accounts where public_user_id = p_public_user_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_block_user(p_public_user_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  update public.users set blocked = true, updated_at = now() where id = p_public_user_id;
$function$;

CREATE OR REPLACE FUNCTION public.admin_link_recovered_account(p_auth_user_id uuid, p_public_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if exists (select 1 from public.user_auth_accounts where auth_user_id = p_auth_user_id) then
    raise exception 'already_mapped' using errcode = 'P0004';
  end if;
  if not exists (select 1 from public.users where id = p_public_user_id and anonymized_at is null) then
    raise exception 'target_not_found_or_anonymized' using errcode = 'P0005';
  end if;
  insert into public.user_auth_accounts (auth_user_id, public_user_id)
    values (p_auth_user_id, p_public_user_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_unblock_user(p_public_user_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  update public.users set blocked = false, updated_at = now() where id = p_public_user_id;
$function$;

CREATE OR REPLACE FUNCTION public.admin_unmap_and_orphan_check(p_auth_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_mapping_count integer;
  v_domain_id uuid;
begin
  select public_user_id into v_domain_id
    from public.user_auth_accounts where auth_user_id = p_auth_user_id;
  if v_domain_id is null then
    raise exception 'mapping_not_found' using errcode = 'P0006';
  end if;
  select count(*) into v_mapping_count
    from public.user_auth_accounts where public_user_id = v_domain_id;
  if v_mapping_count <= 1 then
    raise exception 'cannot_remove_last_credential' using errcode = 'P0003';
  end if;
  delete from public.user_auth_accounts where auth_user_id = p_auth_user_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.change_collaboration_status(p_collaboration_id uuid, p_new_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_current_status text;
  v_activity_type text;
  v_collab_title text;
  v_notif_type text;
  v_notif_title text;
  v_notif_message text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status, title into v_current_status, v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_current_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;

  if not public.is_collaboration_owner(p_collaboration_id) then
    raise exception 'only_owner_may_change_status' using errcode = 'P0022';
  end if;

  if not (
    (v_current_status = 'active'    and p_new_status = 'completed') or
    (v_current_status = 'completed' and p_new_status = 'active')    or
    (v_current_status = 'completed' and p_new_status = 'archived')  or
    (v_current_status = 'archived'  and p_new_status = 'completed')
  ) then
    raise exception 'invalid_status_transition' using errcode = 'P0023';
  end if;

  v_activity_type := case
    when p_new_status = 'completed' and v_current_status = 'active' then 'collaboration_completed'
    when p_new_status = 'active' then 'collaboration_reopened'
    when p_new_status = 'archived' then 'collaboration_archived'
    when p_new_status = 'completed' and v_current_status = 'archived' then 'collaboration_restored'
  end;

  update public.collaborations
    set status = p_new_status,
        completed_at = case
          when p_new_status = 'completed' and completed_at is null then now()
          else completed_at
        end,
        archived_at = case
          when p_new_status = 'archived' then now()
          else null
        end
    where id = p_collaboration_id;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, v_activity_type, p_collaboration_id, jsonb_build_object('previous_status', v_current_status, 'new_status', p_new_status));

  if v_activity_type = 'collaboration_completed' then
    v_notif_type := 'collaboration_completed';
    v_notif_title := 'Collaboration completed';
    v_notif_message := 'Collaboration "' || v_collab_title || '" was completed';
  elsif v_activity_type = 'collaboration_reopened' then
    v_notif_type := 'collaboration_reopened';
    v_notif_title := 'Collaboration reopened';
    v_notif_message := 'Collaboration "' || v_collab_title || '" was reopened';
  elsif v_activity_type = 'collaboration_archived' then
    v_notif_type := 'collaboration_archived';
    v_notif_title := 'Collaboration archived';
    v_notif_message := 'Collaboration "' || v_collab_title || '" was archived';
  end if;

  if v_notif_type is not null then
    insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
      select cp.user_id, v_caller_id, v_notif_type, v_notif_title, v_notif_message, 'collaboration', p_collaboration_id
      from public.collaboration_participants cp
      where cp.collaboration_id = p_collaboration_id
        and cp.user_id <> v_caller_id;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.close_own_wanted_post(p_post_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := public.current_active_stagerz_user_id();
begin
  if v_user_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;
  update public.wanted_posts
    set status = 'closed'
    where id = p_post_id and user_id = v_user_id and status = 'open';
  if not found then
    raise exception 'post_not_found_or_not_open_or_not_owned' using errcode = 'P0008';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.complete_collaboration_task(p_task_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_title text;
  v_collab_title text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id into v_collaboration_id
    from public.collaboration_tasks where id = p_task_id;

  if v_collaboration_id is null then
    raise exception 'task_not_found' using errcode = 'P0020';
  end if;

  select status, title into v_collab_status, v_collab_title from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(v_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  update public.collaboration_tasks
    set status = 'done', completed_at = now()
    where id = p_task_id and status = 'todo'
    returning title into v_title;

  if not found then
    raise exception 'task_not_found_or_not_todo' using errcode = 'P0021';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'task_completed', p_task_id, jsonb_build_object('title', v_title));

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, v_caller_id, 'collaboration_task_completed', 'Task completed',
           'Task "' || v_title || '" completed in "' || v_collab_title || '"', 'collaboration', v_collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = v_collaboration_id
      and cp.user_id <> v_caller_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_collaboration_credit(p_collaboration_id uuid, p_user_id uuid, p_role text)
 RETURNS TABLE(credit_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_trimmed_role text;
  v_next_order int;
  v_new_credit_id uuid;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status into v_collab_status from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(p_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  if not exists (
    select 1 from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = p_user_id
  ) then
    raise exception 'credited_user_not_a_participant' using errcode = 'P0052';
  end if;

  v_trimmed_role := trim(p_role);
  if length(v_trimmed_role) = 0 then
    raise exception 'role_empty' using errcode = 'P0049';
  end if;

  -- Duplicate prevention: one active credit per participant per
  -- collaboration. Since credit deletion is a genuine hard delete
  -- (Phase 16.1, Task model, no soft-delete), a NEW credit for the
  -- same participant is correctly allowed again once any prior one
  -- has actually been removed -- this check only ever sees currently
  -- existing rows, never historical ones.
  if exists (
    select 1 from public.collaboration_credits
    where collaboration_id = p_collaboration_id and user_id = p_user_id
  ) then
    raise exception 'duplicate_credit' using errcode = 'P0053';
  end if;

  select coalesce(max(credit_order), -1) + 1 into v_next_order
    from public.collaboration_credits where collaboration_id = p_collaboration_id;

  insert into public.collaboration_credits (collaboration_id, user_id, credit_role, credit_order, created_by)
    values (p_collaboration_id, p_user_id, v_trimmed_role, v_next_order, v_caller_id)
    returning id into v_new_credit_id;

  return query select v_new_credit_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_collaboration_message(p_collaboration_id uuid, p_body text)
 RETURNS TABLE(message_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_trimmed_body text;
  v_new_message_id uuid;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status into v_collab_status from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(p_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  v_trimmed_body := trim(p_body);
  if length(v_trimmed_body) = 0 then
    raise exception 'body_empty' using errcode = 'P0056';
  end if;
  if length(v_trimmed_body) > 5000 then
    raise exception 'body_too_long' using errcode = 'P0057';
  end if;

  -- sender_id is derived here, server-side, from the resolved
  -- caller identity -- never accepted as a parameter, never
  -- trusted from the client. The existing AFTER INSERT trigger
  -- (log_collaboration_message_activity) fires exactly as it
  -- already does for a direct insert -- no parallel activity or
  -- notification logic is introduced here.
  insert into public.collaboration_messages (collaboration_id, sender_id, body)
    values (p_collaboration_id, v_caller_id, v_trimmed_body)
    returning id into v_new_message_id;

  return query select v_new_message_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_collaboration_task(p_collaboration_id uuid, p_title text, p_assignee_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(task_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_trimmed_title text;
  v_new_task_id uuid;
  v_collab_title text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status, title into v_collab_status, v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(p_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  v_trimmed_title := trim(p_title);
  if length(v_trimmed_title) = 0 then
    raise exception 'title_empty' using errcode = 'P0017';
  end if;
  if length(v_trimmed_title) > 300 then
    raise exception 'title_too_long' using errcode = 'P0018';
  end if;

  if p_assignee_id is not null then
    if not exists (
      select 1 from public.collaboration_participants
      where collaboration_id = p_collaboration_id and user_id = p_assignee_id
    ) then
      raise exception 'assignee_not_a_participant' using errcode = 'P0019';
    end if;
  end if;

  insert into public.collaboration_tasks (collaboration_id, creator_id, assignee_id, title)
    values (p_collaboration_id, v_caller_id, p_assignee_id, v_trimmed_title)
    returning id into v_new_task_id;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, 'task_created', v_new_task_id, jsonb_build_object('title', v_trimmed_title));

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, v_caller_id, 'collaboration_task_created', 'New task',
           'New task "' || v_trimmed_title || '" in "' || v_collab_title || '"', 'collaboration', p_collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = p_collaboration_id
      and cp.user_id <> v_caller_id;

  return query select v_new_task_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_wanted_application(p_wanted_post_id uuid)
 RETURNS TABLE(application_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_applicant_id uuid := public.current_active_stagerz_user_id();
  v_owner_id uuid;
  v_status text;
  v_title text;
  v_new_application_id uuid;
begin
  if v_applicant_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select user_id, status, title into v_owner_id, v_status, v_title
    from public.wanted_posts
    where id = p_wanted_post_id;

  if v_owner_id is null then
    raise exception 'wanted_post_not_found' using errcode = 'P0011';
  end if;

  if v_status <> 'open' then
    raise exception 'wanted_post_not_open' using errcode = 'P0012';
  end if;

  if v_owner_id = v_applicant_id then
    raise exception 'cannot_apply_to_own_wanted' using errcode = 'P0013';
  end if;

  insert into public.wanted_applications (wanted_post_id, applicant_id)
    values (p_wanted_post_id, v_applicant_id)
    returning id into v_new_application_id;

  insert into public.notifications (user_id, from_user_id, type, title, message, wanted_post_id, wanted_application_id, read, target_type, target_id)
    values (
      v_owner_id,
      v_applicant_id,
      'wanted.application.created',
      'New application',
      'New application for "' || v_title || '"',
      p_wanted_post_id,
      v_new_application_id,
      false,
      'wanted_post',
      p_wanted_post_id
    );

  return query select v_new_application_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.current_active_stagerz_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select u.id
  from public.user_auth_accounts uaa
  join public.users u on u.id = uaa.public_user_id
  where uaa.auth_user_id = auth.uid()
    and u.blocked = false
    and u.anonymized_at is null;
$function$;

CREATE OR REPLACE FUNCTION public.current_stagerz_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select public_user_id from public.user_auth_accounts where auth_user_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.delete_collaboration_asset(p_asset_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_uploaded_by uuid;
  v_file_name text;
  v_storage_path text;
  v_deleted_at timestamptz;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, uploaded_by, file_name, storage_path, deleted_at
    into v_collaboration_id, v_uploaded_by, v_file_name, v_storage_path, v_deleted_at
    from public.collaboration_assets where id = p_asset_id;
  if v_collaboration_id is null then
    raise exception 'asset_not_found' using errcode = 'P0044';
  end if;
  if v_deleted_at is not null then
    raise exception 'asset_pending_deletion' using errcode = 'P0045';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if v_caller_id <> v_uploaded_by and not public.is_collaboration_owner(v_collaboration_id) then
    raise exception 'only_uploader_or_owner_may_delete' using errcode = 'P0046';
  end if;

  update public.collaboration_assets
    set deleted_at = now()
    where id = p_asset_id and deleted_at is null;
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'delete_failed' using errcode = 'P0043';
  end if;

  insert into public.pending_asset_deletions (asset_id, collaboration_id, file_name, storage_path)
    values (p_asset_id, v_collaboration_id, v_file_name, v_storage_path);

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'asset_deleted', p_asset_id, jsonb_build_object('file_name', v_file_name));
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_collaboration_credit(p_credit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_participant_id uuid;
  v_role text;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, user_id, credit_role
    into v_collaboration_id, v_participant_id, v_role
    from public.collaboration_credits where id = p_credit_id;
  if v_collaboration_id is null then
    raise exception 'credit_not_found' using errcode = 'P0047';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_owner(v_collaboration_id) then
    raise exception 'only_owner_may_delete_credit' using errcode = 'P0050';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'credit_deleted', p_credit_id, jsonb_build_object(
      'credit_id', p_credit_id,
      'participant_id', v_participant_id,
      'role', v_role
    ));

  delete from public.collaboration_credits where id = p_credit_id;
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'delete_failed' using errcode = 'P0051';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_collaboration_message(p_message_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_sender_id uuid;
  v_collab_status text;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, sender_id into v_collaboration_id, v_sender_id
    from public.collaboration_messages where id = p_message_id;
  if v_collaboration_id is null then
    raise exception 'message_not_found' using errcode = 'P0054';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  -- Author or collaboration owner -- exactly the Task deletion model.
  if v_caller_id <> v_sender_id and not public.is_collaboration_owner(v_collaboration_id) then
    raise exception 'only_author_or_owner_may_delete_message' using errcode = 'P0058';
  end if;

  -- Hard delete: no soft-delete precedent exists for this table (no
  -- deleted_at column, no Storage coordination dependency) -- the
  -- Task model applies, not the Asset model.
  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'message_deleted', p_message_id, '{}'::jsonb);

  delete from public.collaboration_messages where id = p_message_id;
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'delete_failed' using errcode = 'P0059';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_collaboration_task(p_task_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_creator_id uuid;
  v_title text;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, creator_id, title into v_collaboration_id, v_creator_id, v_title
    from public.collaboration_tasks where id = p_task_id;
  if v_collaboration_id is null then
    raise exception 'task_not_found' using errcode = 'P0020';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if v_caller_id <> v_creator_id and not public.is_collaboration_owner(v_collaboration_id) then
    raise exception 'only_creator_or_owner_may_delete' using errcode = 'P0042';
  end if;

  delete from public.collaboration_tasks where id = p_task_id;
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'delete_failed' using errcode = 'P0043';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'task_deleted', p_task_id, jsonb_build_object('title', v_title));
end;
$function$;

CREATE OR REPLACE FUNCTION public.edit_collaboration_asset(p_asset_id uuid, p_title text, p_description text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_deleted_at timestamptz;
  v_file_name text;
  v_previous_title text;
  v_previous_description text;
  v_new_title text;
  v_new_description text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, deleted_at, file_name, title, description
    into v_collaboration_id, v_deleted_at, v_file_name, v_previous_title, v_previous_description
    from public.collaboration_assets where id = p_asset_id;
  if v_collaboration_id is null then
    raise exception 'asset_not_found' using errcode = 'P0044';
  end if;
  if v_deleted_at is not null then
    raise exception 'asset_pending_deletion' using errcode = 'P0045';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(v_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  v_new_title := nullif(trim(p_title), '');
  v_new_description := nullif(trim(p_description), '');

  update public.collaboration_assets
    set title = v_new_title,
        description = v_new_description
    where id = p_asset_id;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'asset_edited', p_asset_id, jsonb_build_object(
      'asset_id', p_asset_id,
      'file_name', v_file_name,
      'previous_title', v_previous_title,
      'new_title', v_new_title,
      'previous_description', v_previous_description,
      'new_description', v_new_description
    ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.edit_collaboration_credit(p_credit_id uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_participant_id uuid;
  v_previous_role text;
  v_new_role text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, user_id, credit_role
    into v_collaboration_id, v_participant_id, v_previous_role
    from public.collaboration_credits where id = p_credit_id;
  if v_collaboration_id is null then
    raise exception 'credit_not_found' using errcode = 'P0047';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_owner(v_collaboration_id) then
    raise exception 'only_owner_may_edit_credit' using errcode = 'P0048';
  end if;

  v_new_role := trim(p_role);
  if length(v_new_role) = 0 then
    raise exception 'role_empty' using errcode = 'P0049';
  end if;

  update public.collaboration_credits
    set credit_role = v_new_role
    where id = p_credit_id;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'credit_edited', p_credit_id, jsonb_build_object(
      'credit_id', p_credit_id,
      'participant_id', v_participant_id,
      'previous_role', v_previous_role,
      'new_role', v_new_role
    ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.edit_collaboration_message(p_message_id uuid, p_new_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_sender_id uuid;
  v_collab_status text;
  v_trimmed_body text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, sender_id into v_collaboration_id, v_sender_id
    from public.collaboration_messages where id = p_message_id;
  if v_collaboration_id is null then
    raise exception 'message_not_found' using errcode = 'P0054';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(v_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  -- Author only -- deliberately stricter than Tasks' any-participant
  -- edit model, per explicit instruction for this phase.
  if v_caller_id <> v_sender_id then
    raise exception 'only_author_may_edit_message' using errcode = 'P0055';
  end if;

  v_trimmed_body := trim(p_new_body);
  if length(v_trimmed_body) = 0 then
    raise exception 'body_empty' using errcode = 'P0056';
  end if;
  if length(v_trimmed_body) > 5000 then
    raise exception 'body_too_long' using errcode = 'P0057';
  end if;

  update public.collaboration_messages
    set body = v_trimmed_body
    where id = p_message_id;

  -- No message content in metadata, matching the established rule
  -- that message text is never stored in collaboration_activity.
  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'message_edited', p_message_id, '{}'::jsonb);
end;
$function$;

CREATE OR REPLACE FUNCTION public.edit_collaboration_task(p_task_id uuid, p_new_title text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collaboration_id uuid;
  v_collab_status text;
  v_old_title text;
  v_trimmed_title text;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select collaboration_id, title into v_collaboration_id, v_old_title
    from public.collaboration_tasks where id = p_task_id;
  if v_collaboration_id is null then
    raise exception 'task_not_found' using errcode = 'P0020';
  end if;

  select status into v_collab_status from public.collaborations where id = v_collaboration_id;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_participant(v_collaboration_id) then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;

  v_trimmed_title := trim(p_new_title);
  if length(v_trimmed_title) = 0 then
    raise exception 'title_empty' using errcode = 'P0017';
  end if;
  if length(v_trimmed_title) > 300 then
    raise exception 'title_too_long' using errcode = 'P0018';
  end if;

  -- Only title changes -- status and assignee are never touched.
  update public.collaboration_tasks
    set title = v_trimmed_title
    where id = p_task_id;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (v_collaboration_id, v_caller_id, 'task_edited', p_task_id, jsonb_build_object('previous_title', v_old_title, 'new_title', v_trimmed_title));
end;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_new_user_id uuid;
begin
  insert into public.users default values returning id into v_new_user_id;
  insert into public.user_auth_accounts (auth_user_id, public_user_id) values (new.id, v_new_user_id);
  insert into public.profiles (user_id, display_name)
    values (v_new_user_id, coalesce(new.raw_user_meta_data->>'display_name', 'New Artist'));
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.has_completed_onboarding(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select username is not null from public.users where id = p_user_id;
$function$;

CREATE OR REPLACE FUNCTION public.invite_collaboration_participant(p_collaboration_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_collab_title text;
  v_target_blocked boolean;
  v_target_anonymized timestamptz;
  v_target_exists boolean;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status, title into v_collab_status, v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_owner(p_collaboration_id) then
    raise exception 'only_owner_may_invite' using errcode = 'P0030';
  end if;

  if p_user_id = v_caller_id then
    raise exception 'cannot_invite_self' using errcode = 'P0031';
  end if;

  select true, blocked, anonymized_at into v_target_exists, v_target_blocked, v_target_anonymized
    from public.users where id = p_user_id;
  if v_target_exists is null then
    raise exception 'target_user_not_found' using errcode = 'P0032';
  end if;
  if v_target_blocked is true or v_target_anonymized is not null then
    raise exception 'target_user_not_eligible' using errcode = 'P0033';
  end if;

  if exists (
    select 1 from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = p_user_id
  ) then
    raise exception 'already_a_participant' using errcode = 'P0034';
  end if;

  insert into public.collaboration_participants (collaboration_id, user_id, participant_type)
    values (p_collaboration_id, p_user_id, 'member');

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, 'participant_invited', p_user_id, '{}'::jsonb);

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    values (p_user_id, v_caller_id, 'collaboration_participant_invited', 'Added to a collaboration',
            'You were added to "' || v_collab_title || '"', 'collaboration', p_collaboration_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.is_collaboration_owner(p_collaboration_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.collaboration_participants
    where collaboration_id = p_collaboration_id
      and user_id = public.current_active_stagerz_user_id()
      and participant_type = 'owner'
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_collaboration_participant(p_collaboration_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.collaboration_participants
    where collaboration_id = p_collaboration_id
      and user_id = public.current_stagerz_user_id()
  );
$function$;

CREATE OR REPLACE FUNCTION public.leave_collaboration(p_collaboration_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_title text;
  v_caller_type text;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select title into v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_collab_title is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;

  select participant_type into v_caller_type
    from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = v_caller_id;

  if v_caller_type is null then
    raise exception 'not_a_participant' using errcode = 'P0015';
  end if;
  if v_caller_type = 'owner' then
    raise exception 'owner_must_transfer_before_leaving' using errcode = 'P0040';
  end if;

  delete from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = v_caller_id and participant_type = 'member';
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'leave_failed' using errcode = 'P0041';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, 'participant_left', v_caller_id, '{}'::jsonb);

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, v_caller_id, 'collaboration_participant_left', 'Participant left',
           'A participant left "' || v_collab_title || '"', 'collaboration', p_collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = p_collaboration_id
      and cp.user_id <> v_caller_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.log_collaboration_asset_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_collab_title text;
begin
  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (new.collaboration_id, new.uploaded_by, 'asset_uploaded', new.id, jsonb_build_object('file_name', new.file_name));

  select title into v_collab_title from public.collaborations where id = new.collaboration_id;

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, new.uploaded_by, 'collaboration_asset_uploaded', 'New asset',
           'New asset "' || new.file_name || '" in "' || v_collab_title || '"', 'collaboration', new.collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = new.collaboration_id
      and cp.user_id <> new.uploaded_by;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.log_collaboration_credit_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_collab_title text;
begin
  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (new.collaboration_id, new.created_by, 'credit_added', new.id, jsonb_build_object('credit_role', new.credit_role, 'credited_user_id', new.user_id));

  select title into v_collab_title from public.collaborations where id = new.collaboration_id;

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, new.created_by, 'collaboration_credit_added', 'New credit',
           'New credit added in "' || v_collab_title || '"', 'collaboration', new.collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = new.collaboration_id
      and cp.user_id <> new.created_by;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.log_collaboration_message_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_collab_title text;
begin
  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (new.collaboration_id, new.sender_id, 'message_posted', new.id, '{}'::jsonb);

  select title into v_collab_title from public.collaborations where id = new.collaboration_id;

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, new.sender_id, 'collaboration_message_posted', 'New message',
           'New message in "' || v_collab_title || '"', 'collaboration', new.collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = new.collaboration_id
      and cp.user_id <> new.sender_id;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.remove_collaboration_participant(p_collaboration_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_collab_title text;
  v_target_type text;
  v_rows_changed int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status, title into v_collab_status, v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_owner(p_collaboration_id) then
    raise exception 'only_owner_may_remove' using errcode = 'P0035';
  end if;

  select participant_type into v_target_type
    from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = p_user_id;

  if v_target_type is null then
    raise exception 'target_not_a_participant' using errcode = 'P0036';
  end if;
  if v_target_type = 'owner' then
    raise exception 'cannot_remove_owner' using errcode = 'P0037';
  end if;

  delete from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = p_user_id and participant_type = 'member';
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'removal_failed' using errcode = 'P0038';
  end if;

  if not exists (
    select 1 from public.collaboration_participants where collaboration_id = p_collaboration_id
  ) then
    raise exception 'cannot_leave_zero_participants' using errcode = 'P0039';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, 'participant_removed', p_user_id, '{}'::jsonb);

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    values (p_user_id, v_caller_id, 'collaboration_participant_removed', 'Removed from a collaboration',
            'You were removed from "' || v_collab_title || '"', 'collaboration', p_collaboration_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_wanted_application(p_application_id uuid, p_new_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner_id uuid := public.current_active_stagerz_user_id();
  v_applicant_id uuid;
  v_wanted_post_id uuid;
  v_title text;
  v_collab_id uuid;
  v_collab_status text;
begin
  if v_owner_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  if p_new_status not in ('accepted', 'rejected') then
    raise exception 'invalid_target_status' using errcode = 'P0009';
  end if;

  update public.wanted_applications
    set status = p_new_status, updated_at = now()
    where id = p_application_id
      and status = 'pending'
      and exists (
        select 1 from public.wanted_posts wp
        where wp.id = wanted_applications.wanted_post_id
          and wp.user_id = v_owner_id
      )
    returning applicant_id, wanted_post_id into v_applicant_id, v_wanted_post_id;

  if not found then
    raise exception 'application_not_found_or_not_pending_or_not_owned' using errcode = 'P0010';
  end if;

  select title into v_title from public.wanted_posts where id = v_wanted_post_id;

  if p_new_status = 'accepted' then
    select id, status into v_collab_id, v_collab_status
      from public.collaborations
      where wanted_post_id = v_wanted_post_id;

    if v_collab_id is not null and v_collab_status <> 'active' then
      raise exception 'collaboration_not_active' using errcode = 'P0014';
    end if;

    if v_collab_id is null then
      insert into public.collaborations (wanted_post_id, title, status)
        values (v_wanted_post_id, v_title, 'active')
        on conflict (wanted_post_id) do nothing
        returning id into v_collab_id;

      if v_collab_id is null then
        select id, status into v_collab_id, v_collab_status
          from public.collaborations where wanted_post_id = v_wanted_post_id;
        if v_collab_status <> 'active' then
          raise exception 'collaboration_not_active' using errcode = 'P0014';
        end if;
      else
        insert into public.collaboration_participants (collaboration_id, user_id, participant_type)
          values (v_collab_id, v_owner_id, 'owner');

        insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
          values (v_collab_id, v_owner_id, 'collaboration_created', v_collab_id, '{}'::jsonb);
      end if;
    end if;

    insert into public.collaboration_participants (collaboration_id, user_id, source_application_id, participant_type)
      values (v_collab_id, v_applicant_id, p_application_id, 'member');

    insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
      values (v_collab_id, v_applicant_id, 'participant_joined', v_collab_id, '{}'::jsonb);

    -- Kept as 'wanted_post' (unchanged semantics) rather than
    -- upgraded to 'collaboration' -- a deliberate, conservative
    -- choice: Phase 13.1 only noted this as a possible future
    -- refinement, not a required change, and altering an existing
    -- type's target semantics is a real behavior change beyond
    -- "add the generic columns."
    insert into public.notifications (user_id, from_user_id, type, title, message, wanted_post_id, wanted_application_id, read, target_type, target_id)
      values (
        v_applicant_id, v_owner_id,
        'wanted.application.accepted',
        'Application accepted',
        'Your application for "' || v_title || '" was accepted',
        v_wanted_post_id, p_application_id, false,
        'wanted_post', v_wanted_post_id
      );
  else
    insert into public.notifications (user_id, from_user_id, type, title, message, wanted_post_id, wanted_application_id, read, target_type, target_id)
      values (
        v_applicant_id, v_owner_id,
        'wanted.application.rejected',
        'Application rejected',
        'Your application for "' || v_title || '" was rejected',
        v_wanted_post_id, p_application_id, false,
        'wanted_post', v_wanted_post_id
      );
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.transfer_collaboration_ownership(p_collaboration_id uuid, p_new_owner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid := public.current_active_stagerz_user_id();
  v_collab_status text;
  v_collab_title text;
  v_rows_changed int;
  v_owner_count int;
begin
  if v_caller_id is null then
    raise exception 'no_active_stagerz_identity' using errcode = 'P0001';
  end if;

  select status, title into v_collab_status, v_collab_title from public.collaborations where id = p_collaboration_id;
  if v_collab_status is null then
    raise exception 'collaboration_not_found' using errcode = 'P0016';
  end if;
  if v_collab_status <> 'active' then
    raise exception 'collaboration_not_active' using errcode = 'P0014';
  end if;

  if not public.is_collaboration_owner(p_collaboration_id) then
    raise exception 'only_owner_may_transfer' using errcode = 'P0024';
  end if;

  if p_new_owner_id = v_caller_id then
    raise exception 'cannot_transfer_to_self' using errcode = 'P0025';
  end if;
  if not exists (
    select 1 from public.collaboration_participants
    where collaboration_id = p_collaboration_id and user_id = p_new_owner_id and participant_type = 'member'
  ) then
    raise exception 'new_owner_not_a_current_member' using errcode = 'P0026';
  end if;

  update public.collaboration_participants
    set participant_type = 'member'
    where collaboration_id = p_collaboration_id and user_id = v_caller_id and participant_type = 'owner';
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'owner_demotion_failed' using errcode = 'P0027';
  end if;

  update public.collaboration_participants
    set participant_type = 'owner'
    where collaboration_id = p_collaboration_id and user_id = p_new_owner_id and participant_type = 'member';
  get diagnostics v_rows_changed = row_count;
  if v_rows_changed <> 1 then
    raise exception 'owner_promotion_failed' using errcode = 'P0028';
  end if;

  select count(*) into v_owner_count
    from public.collaboration_participants
    where collaboration_id = p_collaboration_id and participant_type = 'owner';
  if v_owner_count <> 1 then
    raise exception 'owner_count_invariant_violated' using errcode = 'P0029';
  end if;

  insert into public.collaboration_activity (collaboration_id, actor_user_id, activity_type, reference_id, metadata)
    values (p_collaboration_id, v_caller_id, 'ownership_transferred', p_new_owner_id, jsonb_build_object('previous_owner', v_caller_id, 'new_owner', p_new_owner_id));

  insert into public.notifications (user_id, from_user_id, type, title, message, target_type, target_id)
    select cp.user_id, v_caller_id, 'collaboration_ownership_transferred', 'Ownership transferred',
           'Ownership of "' || v_collab_title || '" was transferred', 'collaboration', p_collaboration_id
    from public.collaboration_participants cp
    where cp.collaboration_id = p_collaboration_id
      and cp.user_id <> v_caller_id;
end;
$function$;

-- =====================================================================
-- 7. Views
-- =====================================================================
CREATE VIEW public.public_profiles AS
 SELECT u.id,
    u.username,
    u.photo_url,
    u.is_system,
    u.created_at,
    u.anonymized_at IS NOT NULL AS is_deleted,
        CASE
            WHEN u.anonymized_at IS NOT NULL THEN 'Deleted User'::text
            WHEN p.name <> ''::text AND p.name <> 'New Artist'::text THEN p.name
            WHEN regexp_replace(u.username, '^[[:space:]]+|[[:space:]]+$'::text, ''::text, 'g'::text) <> ''::text THEN u.username
            ELSE 'STAGERZ Artist'::text
        END AS display_name
   FROM users u
     LEFT JOIN ( SELECT pr.user_id,
            regexp_replace(pr.display_name, '^[[:space:]]+|[[:space:]]+$'::text, ''::text, 'g'::text) AS name
           FROM profiles pr) p ON p.user_id = u.id;

-- =====================================================================
-- 8. Triggers (application-owned, including the one on auth.users)
-- =====================================================================
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
CREATE TRIGGER trg_log_collaboration_asset_activity AFTER INSERT ON collaboration_assets FOR EACH ROW EXECUTE FUNCTION log_collaboration_asset_activity();
CREATE TRIGGER trg_log_collaboration_credit_activity AFTER INSERT ON collaboration_credits FOR EACH ROW EXECUTE FUNCTION log_collaboration_credit_activity();
CREATE TRIGGER trg_log_collaboration_message_activity AFTER INSERT ON collaboration_messages FOR EACH ROW EXECUTE FUNCTION log_collaboration_message_activity();

-- =====================================================================
-- 9. Row level security
-- =====================================================================
ALTER TABLE public.collaboration_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaborations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_asset_deletions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_auth_deletions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_auth_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wanted_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wanted_posts ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- 10. Policies (public schema, then storage.objects)
-- =====================================================================
CREATE POLICY "participants can read collaboration activity" ON public.collaboration_activity AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(collaboration_id));
CREATE POLICY "active participants can create collaboration asset metadata" ON public.collaboration_assets AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((uploaded_by = current_active_stagerz_user_id()) AND is_collaboration_participant(collaboration_id) AND (EXISTS ( SELECT 1
   FROM collaborations c
  WHERE ((c.id = collaboration_assets.collaboration_id) AND (c.status = 'active'::text)))) AND (deleted_at IS NULL) AND (split_part(storage_path, '/'::text, 1) = (collaboration_id)::text) AND (length(storage_path) > (length((collaboration_id)::text) + 1))));
CREATE POLICY "participants can read collaboration asset metadata" ON public.collaboration_assets AS PERMISSIVE FOR SELECT TO authenticated USING ((is_collaboration_participant(collaboration_id) AND (deleted_at IS NULL)));
CREATE POLICY "participants can read collaboration credits" ON public.collaboration_credits AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(collaboration_id));
CREATE POLICY "participants can read collaboration messages" ON public.collaboration_messages AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(collaboration_id));
CREATE POLICY "participants can read co-participants in their collaboration" ON public.collaboration_participants AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(collaboration_id));
CREATE POLICY "participants can read collaboration tasks" ON public.collaboration_tasks AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(collaboration_id));
CREATE POLICY "participants can read their own collaboration" ON public.collaborations AS PERMISSIVE FOR SELECT TO authenticated USING (is_collaboration_participant(id));
CREATE POLICY "follows are publicly readable" ON public.follows AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "likes are publicly readable" ON public.likes AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "active users can update own notifications" ON public.notifications AS PERMISSIVE FOR UPDATE TO PUBLIC USING ((user_id = current_active_stagerz_user_id())) WITH CHECK ((user_id = current_active_stagerz_user_id()));
CREATE POLICY "users read only own notifications" ON public.notifications AS PERMISSIVE FOR SELECT TO PUBLIC USING ((user_id = current_stagerz_user_id()));
CREATE POLICY "active users can update own profile" ON public.profiles AS PERMISSIVE FOR UPDATE TO PUBLIC USING ((user_id = current_active_stagerz_user_id())) WITH CHECK ((user_id = current_active_stagerz_user_id()));
CREATE POLICY "profiles are publicly readable" ON public.profiles AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "users read only own credential mappings" ON public.user_auth_accounts AS PERMISSIVE FOR SELECT TO PUBLIC USING ((public_user_id = current_stagerz_user_id()));
CREATE POLICY "active users can update own row" ON public.users AS PERMISSIVE FOR UPDATE TO PUBLIC USING ((id = current_active_stagerz_user_id())) WITH CHECK ((id = current_active_stagerz_user_id()));
CREATE POLICY "authenticated can read own row" ON public.users AS PERMISSIVE FOR SELECT TO PUBLIC USING ((id = current_stagerz_user_id()));
CREATE POLICY "applicant or wanted owner can read applications" ON public.wanted_applications AS PERMISSIVE FOR SELECT TO authenticated USING (((applicant_id = current_stagerz_user_id()) OR (EXISTS ( SELECT 1
   FROM wanted_posts wp
  WHERE ((wp.id = wanted_applications.wanted_post_id) AND (wp.user_id = current_stagerz_user_id()))))));
CREATE POLICY "active users can update own wanted posts" ON public.wanted_posts AS PERMISSIVE FOR UPDATE TO PUBLIC USING ((user_id = current_active_stagerz_user_id())) WITH CHECK ((user_id = current_active_stagerz_user_id()));
CREATE POLICY "onboarded active users can insert own wanted posts" ON public.wanted_posts AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (((user_id = current_active_stagerz_user_id()) AND has_completed_onboarding(user_id)));
CREATE POLICY "wanted_posts are publicly readable" ON public.wanted_posts AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "participants can read collaboration assets" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (((bucket_id = 'collaboration-assets'::text) AND is_collaboration_participant(((storage.foldername(name))[1])::uuid)));
CREATE POLICY "participants can upload collaboration assets" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'collaboration-assets'::text) AND is_collaboration_participant(((storage.foldername(name))[1])::uuid)));

-- =====================================================================
-- 11. Storage bucket (definition only; no objects)
-- =====================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('collaboration-assets', 'collaboration-assets', false, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- =====================================================================
-- 12. Realtime publication membership (publication itself is platform-managed)
-- =====================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_activity;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_assets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_credits;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_tasks;

-- =====================================================================
-- 13. Privileges — relations (exact production ACLs; revoke-then-grant)
-- =====================================================================
REVOKE ALL ON TABLE public.collaboration_activity FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_activity TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_activity TO service_role;
REVOKE ALL ON TABLE public.collaboration_assets FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_assets TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_assets TO service_role;
REVOKE ALL ON TABLE public.collaboration_credits FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_credits TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_credits TO service_role;
REVOKE ALL ON TABLE public.collaboration_messages FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_messages TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_messages TO service_role;
REVOKE ALL ON TABLE public.collaboration_participants FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_participants TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_participants TO service_role;
REVOKE ALL ON TABLE public.collaboration_tasks FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaboration_tasks TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaboration_tasks TO service_role;
REVOKE ALL ON TABLE public.collaborations FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.collaborations TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.collaborations TO service_role;
REVOKE ALL ON TABLE public.follows FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.follows TO anon;
GRANT SELECT ON TABLE public.follows TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.follows TO service_role;
REVOKE ALL ON TABLE public.likes FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.likes TO anon;
GRANT SELECT ON TABLE public.likes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.likes TO service_role;
REVOKE ALL ON TABLE public.notifications FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.notifications TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.notifications TO service_role;
REVOKE ALL ON TABLE public.pending_asset_deletions FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.pending_asset_deletions TO service_role;
REVOKE ALL ON TABLE public.pending_auth_deletions FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.pending_auth_deletions TO service_role;
REVOKE ALL ON TABLE public.profiles FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.profiles TO anon;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO service_role;
REVOKE ALL ON TABLE public.public_profiles FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.public_profiles TO anon;
GRANT SELECT ON TABLE public.public_profiles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.public_profiles TO service_role;
REVOKE ALL ON TABLE public.user_auth_accounts FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.user_auth_accounts TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.user_auth_accounts TO service_role;
REVOKE ALL ON TABLE public.users FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.users TO service_role;
REVOKE ALL ON TABLE public.wanted_applications FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.wanted_applications TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.wanted_applications TO service_role;
REVOKE ALL ON TABLE public.wanted_posts FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.wanted_posts TO anon;
GRANT SELECT ON TABLE public.wanted_posts TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.wanted_posts TO service_role;

-- =====================================================================
-- 14. Privileges — columns
-- =====================================================================
GRANT INSERT (asset_type, collaboration_id, description, file_name, file_size, mime_type, storage_path, title, uploaded_by) ON TABLE public.collaboration_assets TO authenticated;
GRANT UPDATE (read) ON TABLE public.notifications TO authenticated;
GRANT UPDATE (available, bio, category, country_flag, display_name, location, looking_for, role, skills) ON TABLE public.profiles TO authenticated;
GRANT SELECT (bio, first_name, id, last_name, location, photo_url, username) ON TABLE public.users TO authenticated;
GRANT UPDATE (username) ON TABLE public.users TO authenticated;
GRANT INSERT (category, compensation, description, location, remote, role_needed, status, title, user_id) ON TABLE public.wanted_posts TO authenticated;
GRANT UPDATE (category, compensation, description, location, remote, role_needed, title) ON TABLE public.wanted_posts TO authenticated;

-- =====================================================================
-- 15. Privileges — functions (exact production ACLs)
-- =====================================================================
REVOKE ALL ON FUNCTION public.admin_anonymize_account(p_public_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_anonymize_account(p_public_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.admin_block_user(p_public_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_block_user(p_public_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.admin_link_recovered_account(p_auth_user_id uuid, p_public_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_link_recovered_account(p_auth_user_id uuid, p_public_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.admin_unblock_user(p_public_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_unblock_user(p_public_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.admin_unmap_and_orphan_check(p_auth_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_unmap_and_orphan_check(p_auth_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.change_collaboration_status(p_collaboration_id uuid, p_new_status text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.change_collaboration_status(p_collaboration_id uuid, p_new_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_collaboration_status(p_collaboration_id uuid, p_new_status text) TO service_role;
REVOKE ALL ON FUNCTION public.close_own_wanted_post(p_post_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.close_own_wanted_post(p_post_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_own_wanted_post(p_post_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.complete_collaboration_task(p_task_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.complete_collaboration_task(p_task_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_collaboration_task(p_task_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.create_collaboration_credit(p_collaboration_id uuid, p_user_id uuid, p_role text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_collaboration_credit(p_collaboration_id uuid, p_user_id uuid, p_role text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_collaboration_credit(p_collaboration_id uuid, p_user_id uuid, p_role text) TO service_role;
REVOKE ALL ON FUNCTION public.create_collaboration_message(p_collaboration_id uuid, p_body text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_collaboration_message(p_collaboration_id uuid, p_body text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_collaboration_message(p_collaboration_id uuid, p_body text) TO service_role;
REVOKE ALL ON FUNCTION public.create_collaboration_task(p_collaboration_id uuid, p_title text, p_assignee_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_collaboration_task(p_collaboration_id uuid, p_title text, p_assignee_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_collaboration_task(p_collaboration_id uuid, p_title text, p_assignee_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.create_wanted_application(p_wanted_post_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_wanted_application(p_wanted_post_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_wanted_application(p_wanted_post_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.current_active_stagerz_user_id() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_active_stagerz_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_active_stagerz_user_id() TO service_role;
REVOKE ALL ON FUNCTION public.current_stagerz_user_id() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.current_stagerz_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_stagerz_user_id() TO service_role;
REVOKE ALL ON FUNCTION public.delete_collaboration_asset(p_asset_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_asset(p_asset_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_asset(p_asset_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.delete_collaboration_credit(p_credit_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_credit(p_credit_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_credit(p_credit_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.delete_collaboration_message(p_message_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_message(p_message_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_message(p_message_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.delete_collaboration_task(p_task_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_task(p_task_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_collaboration_task(p_task_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.edit_collaboration_asset(p_asset_id uuid, p_title text, p_description text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_asset(p_asset_id uuid, p_title text, p_description text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_asset(p_asset_id uuid, p_title text, p_description text) TO service_role;
REVOKE ALL ON FUNCTION public.edit_collaboration_credit(p_credit_id uuid, p_role text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_credit(p_credit_id uuid, p_role text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_credit(p_credit_id uuid, p_role text) TO service_role;
REVOKE ALL ON FUNCTION public.edit_collaboration_message(p_message_id uuid, p_new_body text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_message(p_message_id uuid, p_new_body text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_message(p_message_id uuid, p_new_body text) TO service_role;
REVOKE ALL ON FUNCTION public.edit_collaboration_task(p_task_id uuid, p_new_title text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_task(p_task_id uuid, p_new_title text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_collaboration_task(p_task_id uuid, p_new_title text) TO service_role;
REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_auth_user() TO service_role;
REVOKE ALL ON FUNCTION public.has_completed_onboarding(p_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_completed_onboarding(p_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_completed_onboarding(p_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.invite_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.invite_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.is_collaboration_owner(p_collaboration_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_collaboration_owner(p_collaboration_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_collaboration_owner(p_collaboration_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.is_collaboration_participant(p_collaboration_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_collaboration_participant(p_collaboration_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_collaboration_participant(p_collaboration_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.leave_collaboration(p_collaboration_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.leave_collaboration(p_collaboration_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_collaboration(p_collaboration_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.log_collaboration_asset_activity() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.log_collaboration_asset_activity() TO service_role;
REVOKE ALL ON FUNCTION public.log_collaboration_credit_activity() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.log_collaboration_credit_activity() TO service_role;
REVOKE ALL ON FUNCTION public.log_collaboration_message_activity() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.log_collaboration_message_activity() TO service_role;
REVOKE ALL ON FUNCTION public.remove_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.remove_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_collaboration_participant(p_collaboration_id uuid, p_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.respond_to_wanted_application(p_application_id uuid, p_new_status text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_to_wanted_application(p_application_id uuid, p_new_status text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_wanted_application(p_application_id uuid, p_new_status text) TO service_role;
REVOKE ALL ON FUNCTION public.transfer_collaboration_ownership(p_collaboration_id uuid, p_new_owner_id uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.transfer_collaboration_ownership(p_collaboration_id uuid, p_new_owner_id uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_collaboration_ownership(p_collaboration_id uuid, p_new_owner_id uuid) TO service_role;

-- =====================================================================
-- 16. Default privileges for future objects created by postgres (S-5 state)
-- =====================================================================
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage REVOKE ALL ON TABLES FROM anon, authenticated;
-- FUNCTIONS default entries (public/f, storage/f) are left at the platform default,
-- exactly as in production (see Phase 21.6 rule 5).

-- =====================================================================
-- 17. Comments
-- =====================================================================
COMMENT ON FUNCTION public.current_stagerz_user_id() IS 'Returns null when no authenticated or mapped identity exists for a role permitted to execute it; anon has no direct EXECUTE privilege.';

-- end of baseline
