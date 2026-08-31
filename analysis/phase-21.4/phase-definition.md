# Phase 21.4 — S-1: Close the Unauthenticated Write Path to `public.users`

**Branch:** `phase-21.4-s1-anon-write-exposure`
**Base commit:** `ebfe536` (`origin/main`)
**Type:** Security remediation. **Contains a real, applied backend migration** — unlike Phase 21.3, which is read-only extraction.
**Project:** `kbnmkyvbwkuvcklywdhk`
**Status:** Migration applied 2026-08-23. Not committed, not pushed.

---

## 1. Why this is a separate phase

S-1 was discovered *during* Phase 21.3's read-only backend extraction. It is not fixed there, for two reasons:

1. **Phase 21.3 is unfinished and paused.** Its snapshot is partially captured; landing a production change inside it would mix an undocumented backend mutation into an incomplete record.
2. **Phase 21.3's `.sql` files are descriptive snapshots that must never be executed** — every one carries a `NOT A MIGRATION` header, and its validation check S-2 asserts they contain no executable statement. Putting an executable migration in that directory would destroy the distinction the phase exists to establish.

This phase therefore carries its own `migration.sql`, explicitly labelled executable.

## 2. The finding

`public.public_profiles` is an auto-updatable view owned by `postgres`, without `security_invoker`. `public.users` has RLS enabled but **not** forced, and `postgres` has `rolbypassrls = true`. `anon` and `authenticated` held **full** privileges (`arwdDxtm`) on the view.

Consequence: an **unauthenticated** caller could write to `public.users` through the view, bypassing the base-table RLS policy and the deliberately narrow column grants. Writable columns: `id`, `username`, `photo_url`, `is_system`, `created_at`. `username` is UNIQUE, so a targeted write could collide with or seize another account's username.

Confirmed non-destructively: `EXPLAIN` (no `ANALYZE`) as `anon` produced `Update on users` **with no RLS predicate in the plan**, while the same statement against the base table was rejected `42501`. Full evidence in `analysis/phase-21.3/backend-contract.md` §12.

## 3. Fix — Option B, minimal

```sql
REVOKE ALL ON TABLE public.public_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO anon, authenticated;
```

**Why this and nothing more.** The application performs **zero** writes through this view — all seven references in `index.html` are `SELECT`. The write privileges were never used and serve no purpose. Removing them closes the exposure with no functional change.

**Why not `security_invoker`.** It would break every profile read: neither role can `SELECT public.users`, and the `users` SELECT policy is own-row-only, so participant lists, applicant lists, artist profiles, message senders and user search would all fail or return only the caller. The definer behaviour is the intended design; the defect was granting writes on a read gateway.

## 4. Root cause — recorded, not fixed here

`ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES TO anon, authenticated, service_role` is in force, so **every new table or view in `public` is automatically granted ALL to `anon`**. Exactly three relations still carry that untouched signature: `_test_results`, `_test_run_log`, `public_profiles`.

Logged as **S-5**. Out of scope for this fix by explicit instruction, but it means S-1's class will recur on any new object until addressed.

## 5. Scope boundaries

**In scope:** the two statements above, against `public.public_profiles` only.

**Explicitly excluded:** `security_invoker`; any change to `public.users` RLS; any change to default privileges (S-5); `service_role` privileges; S-2 (test tables), S-3 (storage DELETE policy), S-4 (unhandled SQLSTATEs); any `index.html` change; resuming Phase 21.3.

## 6. Related findings, preserved and unremediated

| ID | Finding |
|---|---|
| S-2 | `_test_results` / `_test_run_log` — RLS disabled, `anon` holds full privileges including TRUNCATE |
| S-3 | No DELETE policy on `storage.objects`; the frontend's `remove()` cannot succeed |
| S-4 | 58 backend SQLSTATEs, 4 handled; the other 54 surface as raw snake_case tokens |
| S-5 | Default privileges grant ALL on new objects to `anon` — the root cause of S-1 and S-2 |
