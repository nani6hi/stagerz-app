-- =====================================================================
-- STAGERZ - Phase 21.5 - S-2 pre-drop recovery snapshot
-- =====================================================================
--  ####  RECOVERY SNAPSHOT. NOT APPLIED. NOT A ROUTINE MIGRATION.  ####
--
-- This file exists so that the DROP performed by migration.sql in this
-- same directory is reversible. Once that DROP runs, this file is the
-- ONLY copy of the data in public._test_results and public._test_run_log.
--
-- Unlike the descriptive extraction artifacts in analysis/phase-21.3/,
-- the statements below ARE executable. They are held here deliberately
-- unexecuted, as an emergency recovery path only.
--
-- Project ref  : kbnmkyvbwkuvcklywdhk  (stagerz-foundation-v2-test)
-- Captured     : 2026-09-08 12:32:35+00 (read-only verification)
-- Source rows  : 4 (_test_results) + 24 (_test_run_log) = 28
-- Status       : CAPTURED - NOT EXECUTED
-- =====================================================================

-- ---------------------------------------------------------------------
--  ####  WARNING - READ BEFORE RESTORING  ####
--
--  RESTORING THIS SNAPSHOT BEFORE S-5 IS REMEDIATED WILL RE-ACQUIRE THE
--  CURRENT postgres DEFAULT TABLE PRIVILEGES AND CAN REINTRODUCE S-2.
--
--  Mechanism: ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON
--  TABLES TO anon, authenticated, service_role is still in force on this
--  project (finding S-5, out of scope for Phase 21.5). Any table created
--  by role postgres in schema public is granted ALL to anon and
--  authenticated automatically at CREATE time - including TRUNCATE.
--  Recreating these two tables therefore restores exactly the exposure
--  Phase 21.5 removed, without any GRANT appearing anywhere in this file.
--
--  Restore is a recovery path for a CONFIRMED regression only. It is
--  never routine. It requires the same explicit production-mutation
--  approval as any other backend change. If restore is ever performed,
--  the resulting ACL must be inspected immediately and the exposure
--  either accepted deliberately or revoked as a follow-up.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- STRUCTURE AS CAPTURED
-- ---------------------------------------------------------------------
--  public._test_results
--    id         integer                  NOT NULL DEFAULT nextval('_test_results_id_seq')
--    message    text                     NULL
--    logged_at  timestamp with time zone NULL     DEFAULT now()
--    PRIMARY KEY (id) - _test_results_pkey; no other index, no constraint
--
--  public._test_run_log
--    id           integer                  NOT NULL DEFAULT nextval('_test_run_log_id_seq')
--    run_id       uuid                     NOT NULL
--    test_name    text                     NOT NULL
--    status       text                     NOT NULL
--    details      text                     NULL
--    recorded_at  timestamp with time zone NOT NULL DEFAULT now()
--    PRIMARY KEY (id) - _test_run_log_pkey; no other index, no constraint
--
--  Both tables: RLS disabled and not forced, 0 policies, 0 triggers,
--  0 foreign keys in either direction, no dependent view, not a member
--  of any publication.
--
--  serial is used below rather than an explicit CREATE SEQUENCE. It
--  reproduces the captured state exactly: an integer column, NOT NULL,
--  DEFAULT nextval on a sequence of the same name that is OWNED BY the
--  column. That ownership is why the two sequences disappear along with
--  the tables when migration.sql runs, and reappear with them here.
-- ---------------------------------------------------------------------

CREATE TABLE public._test_results (
    id         serial PRIMARY KEY,
    message    text,
    logged_at  timestamptz DEFAULT now()
);

CREATE TABLE public._test_run_log (
    id           serial PRIMARY KEY,
    run_id       uuid        NOT NULL,
    test_name    text        NOT NULL,
    status       text        NOT NULL,
    details      text,
    recorded_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- DATA - public._test_results (4 rows, original ids preserved)
--
-- id 2 is absent in the source. The sequence reached 5 with only 4
-- surviving rows, so a row was inserted and later removed. The gap is
-- reproduced faithfully; it is not an omission in this snapshot.
-- ---------------------------------------------------------------------

INSERT INTO public._test_results (id, message, logged_at) VALUES
  (1, 'PASS Test 1',  '2026-07-12 10:18:41.799185+00'),
  (3, 'PASS Test 3a', '2026-07-12 10:18:41.799185+00'),
  (4, 'PASS Test 3b', '2026-07-12 10:18:41.799185+00'),
  (5, 'PASS Test 4',  '2026-07-12 10:18:41.799185+00');

-- ---------------------------------------------------------------------
-- DATA - public._test_run_log (24 rows, original ids preserved)
--
-- Ids run 39-62 contiguously. Ids 1-38 are absent in the source: at
-- least one earlier run was cleared before this one. Reproduced as
-- captured.
--
-- Single run_id d098113c-397d-4d93-a444-5d7f6bc9e485, single instant
-- 2026-07-12 15:11:12.495837+00, status PASS on all 24 rows.
-- ---------------------------------------------------------------------

INSERT INTO public._test_run_log (id, run_id, test_name, status, details, recorded_at) VALUES
  (39, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 1',   'PASS', 'mapping count = 1',                                        '2026-07-12 15:11:12.495837+00'),
  (40, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 2',   'PASS', 'expected 23505, got 23505',                                '2026-07-12 15:11:12.495837+00'),
  (41, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 3a',  'PASS', 'expected 42501, got 42501',                                '2026-07-12 15:11:12.495837+00'),
  (42, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 3b',  'PASS', 'blocked=true confirmed under service_role',                '2026-07-12 15:11:12.495837+00'),
  (43, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 4',   'PASS', 'resolved id matched expected',                             '2026-07-12 15:11:12.495837+00'),
  (44, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 5a',  'PASS', 'expected 42501, got 42501',                                '2026-07-12 15:11:12.495837+00'),
  (45, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 5b',  'PASS', 'resolver returned NULL as expected',                       '2026-07-12 15:11:12.495837+00'),
  (46, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 6',   'PASS', 'expected P0001, got P0001',                                '2026-07-12 15:11:12.495837+00'),
  (47, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 7',   'PASS', 'rows affected = 0',                                        '2026-07-12 15:11:12.495837+00'),
  (48, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 8',   'PASS', 'rows affected = 0',                                        '2026-07-12 15:11:12.495837+00'),
  (49, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 8b',  'PASS', 'rows affected = 0',                                        '2026-07-12 15:11:12.495837+00'),
  (50, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 8c',  'PASS', 'anonymized_at unchanged on repeat call',                   '2026-07-12 15:11:12.495837+00'),
  (51, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 9',   'PASS', 'expected 42501, got 42501',                                '2026-07-12 15:11:12.495837+00'),
  (52, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 10',  'PASS', 'expected 23502, got 23502',                                '2026-07-12 15:11:12.495837+00'),
  (53, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 11',  'PASS', 'insert with null from_user_id succeeded',                  '2026-07-12 15:11:12.495837+00'),
  (54, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 12',  'PASS', 'status transitioned to closed',                            '2026-07-12 15:11:12.495837+00'),
  (55, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 12b', 'PASS', 'expected P0008, got P0008',                                '2026-07-12 15:11:12.495837+00'),
  (56, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 13',  'PASS', 'expected 42501, got 42501',                                '2026-07-12 15:11:12.495837+00'),
  (57, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 14',  'PASS', 'expected 42501, got 42501',                                '2026-07-12 15:11:12.495837+00'),
  (58, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 15',  'PASS', 'blocked/anonymized_at absent from view',                   '2026-07-12 15:11:12.495837+00'),
  (59, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 16',  'PASS', 'resolved via public_profiles, display_name = Deleted User', '2026-07-12 15:11:12.495837+00'),
  (60, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 17',  'PASS', '1 row, attempt_count = 1',                                 '2026-07-12 15:11:12.495837+00'),
  (61, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 17b', 'PASS', 'record cleared',                                           '2026-07-12 15:11:12.495837+00'),
  (62, 'd098113c-397d-4d93-a444-5d7f6bc9e485', 'Test 18',  'PASS', 'oldest row returned first',                                '2026-07-12 15:11:12.495837+00');

-- ---------------------------------------------------------------------
-- SEQUENCE STATE
--
-- Captured live: _test_results_id_seq last_value = 5,  is_called = true
--                _test_run_log_id_seq  last_value = 62, is_called = true
-- Both: start 1, increment 1, cache 1, no cycle, max 2147483647.
--
-- The explicit ids in the INSERTs above do not advance the sequences, so
-- these two calls are required. Without them the next insert would
-- collide on the primary key.
-- ---------------------------------------------------------------------

SELECT setval('public._test_results_id_seq', 5,  true);
SELECT setval('public._test_run_log_id_seq',  62, true);

-- ---------------------------------------------------------------------
-- WHAT THIS SNAPSHOT DOES NOT RESTORE
-- ---------------------------------------------------------------------
--   * Grants. None are written here, on purpose. See the warning above:
--     the default privileges apply themselves at CREATE time, so writing
--     GRANT statements would only make the reacquisition look intended.
--   * Physical identifiers (oid, ctid), sequence page state, planner
--     statistics. None of these is contract-relevant.
--   * The harness that produced these rows. It was never in this
--     repository and is not recoverable from it.
-- ---------------------------------------------------------------------
