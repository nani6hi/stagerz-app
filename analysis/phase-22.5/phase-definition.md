# Phase 22.5 — Runtime Rebuild & Test Environment Validation

**Branch of this prerequisite step:** `phase-22.5-local-supabase-url-override`, from `main` @
`0e27be81685a3c4459615e92d8ddc5ae0bb27a32`.
**Status:** **PREREQUISITE IN PROGRESS.** The frontend local-URL override is implemented; **T2 has
NOT been created and is NOT authorized**; the gates remain open.
**Production backend of record:** `kbnmkyvbwkuvcklywdhk` — never used for any destructive test.

---

## 1. Objective

Prove that the canonical repository baseline, plus documented configuration, produces a **working**
Supabase environment — closing the four runtime gates deferred by Phases 22.3 and 22.4 — and give
the two never-executed Edge Functions their first controlled end-to-end exercise, on a **disposable**
environment.

## 2. Target gates

| Gate | What must be proven |
|---|---|
| **D** — Auth / API / Realtime | On a baseline-built environment: magic-link sign-up creating `users` / `profiles` / `user_auth_accounts` via `on_auth_user_created`; authenticated REST reads incl. `public_profiles`; anon base-table read refused (401 / `42501`); an authenticated write persisting; ≥1 Realtime `postgres_changes` event |
| **E** — Edge Functions | All four functions respond correctly to an authorised **and** an unauthorised call; **`delete-account`** and **`process-pending-deletions`** complete their destructive paths on throwaway identities; the *present-object* branch of `process-pending-asset-deletions` is exercised |
| **G** — Storage API | Authenticated upload → byte-identical download → non-participant refused → removal via the drainer |
| **C3** — Full Auth-account fixture | `supabase/seed/fixtures.sql` runs **unmodified** end to end, creating the three `fixture-…@stagerz.test` accounts, with the trigger producing the public rows, and re-running is a no-op |

These four are recorded as OPEN in `analysis/phase-22.3/closeout.md` §2 and were explicitly **not**
converted by Phase 22.4.

## 3. Chosen route: T2 — **proposed, NOT created by this task**

**T2** is a disposable cloud Supabase test project built from the canonical baseline. It is the only
route that can close all four gates:

- **T1 (local stack)** cannot: `storage-api:v1.72.1` exits 139 reproducibly on this machine, so G
  and the Storage-dependent half of E are unreachable.
- **T3 (repurpose the legacy project)** would destroy the Phase 22.1 containment evidence in place
  and is not a clean room. The legacy project is now exported, paused and `INACTIVE`.
- **T4 (production with synthetic accounts)** is **excluded on principle**: production must never be
  used as a disposable clean-room, and `delete-account` is irreversible.

**The Free-plan active-project slot prerequisite is resolved** (legacy paused — see
`legacy-paused-record.md`). **Creating T2 is still a separate, unapproved owner decision.**

## 4. Prerequisite implemented by this step — the local Supabase URL override

Before this change the shipped application could not target T2 from a browser at all: the `local`
environment's URL was a hard-coded literal, and only its *key* was overridable.

`index.html` now lets the **local environment only** take its URL from
`localStorage['stagerz:local-supabase-url']`, validated strictly, with the **production project ref
refused**. Details and rationale: `preflight.md` §2. No secret and no T2 identifier was added to the
repository — the tester supplies T2's publishable key and URL in their own browser.

## 5. Scope

**In scope:** creating T2 (once approved); applying the baseline unmodified; the fingerprint gate
against `supabase/verify/expected-production.json`; deploying the four Edge Functions with
T2-only secrets; configuring Auth from the captured production settings with T2's own Site URL and
redirect list; applying both seed files; executing the D / E / G / C3 matrix; recording evidence;
T2 disposition at closeout.

**Out of scope — explicitly:** custom SMTP, CAPTCHA, backups, CSP, key rotation, session policy,
monitoring, CI; UI and product work; migration-history reconciliation; the two production
`collaboration_assets` rows with missing objects; the stale native Netlify hostname; the apex
A-record gap; Netlify build-settings investigation; **and Docker/WSL removal, which is a separate
owner action and is NOT part of this phase.**

## 6. Mutation boundaries

All mutation is confined to **T2**. **Zero production mutation** — read-only queries only. The
legacy project stays paused and untouched. `expected-production.json`, `fingerprint.sql` and the
canonical baseline are never edited to make a test pass. The GitHub Actions workflow is not
modified: it hard-codes the production function URL and must keep serving production.

## 7. Destructive tests — separate owner approval required

`delete-account` and `process-pending-deletions` are **irreversible** (see `preflight.md` §3).

- They require a **separate, explicit owner go-ahead at the gate**, after the non-destructive gates
  have passed.
- They must use **dedicated throwaway T2 identities only** — accounts created for the sole purpose
  of being destroyed. The three fixture accounts must **never** be destroyed: C3, D and G depend on
  them.
- **Production must never be used for destructive testing**, under any circumstance.
- The `pending_auth_deletions` queue must be seeded with **only** the intended throwaway auth id —
  the drainer trusts the queue and deletes whatever it finds there.

## 8. Required guardrails before any destructive run

1. The production-ref denylist in the frontend override (implemented in this step).
2. A **fresh `STAGERZ_MAINTENANCE_SECRET` for T2** — never the production value.
3. `STAGERZ_ALLOWED_ORIGIN` **set explicitly** on T2 (unset it defaults to `https://stagerz.app`).
4. `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` left unset on T2, so the reaper can only dry-run.
5. A pre-flight assertion immediately before each destructive call: target ref is T2's and **not**
   `kbnmkyvbwkuvcklywdhk`, and the target account is the dedicated throwaway.
6. Ordering: empty-queue run first, then the seeded drain, then `delete-account` last.
7. Evidence records request/response **shapes** only — never secrets, tokens or addresses.

## 9. Acceptance criteria

1. T2 created without touching production or the legacy project.
2. Baseline applies **unmodified**, exit 0, first attempt.
3. **Fingerprint gate: every `exact` key matches**, none weakened.
4. `showcase.sql` applies and is idempotent.
5. **C3** — `fixtures.sql` applies unmodified and is idempotent.
6. **D** — sign-up/sign-in, session restore, authenticated read and write, anon denial, ≥1 Realtime event.
7. **G** — upload, byte-identical download, non-participant refused, removal via the drainer.
8. **E** — all four functions on authorised and unauthorised calls; both destructive paths completed on throwaway identities.
9. Production verifiably unchanged: migration history still 43 rows, latest `20260917143322`.
10. No secret, production key or real user data enters the repository.

## 10. Stop / go gates requiring owner approval

| # | Gate |
|---|---|
| 1 | **Approve creating T2** (slot prerequisite is met; creation is not) |
| 2 | Decide how the throwaway account obtains a **real session** — admin-generated magic link, or one real organisation-member mailbox (`@stagerz.test` cannot receive mail) |
| 3 | **Approve the destructive tests** at the gate, after the non-destructive gates pass |
| 4 | **T2 disposition** at closeout — delete, keep as the standing test environment, or pause |

## 11. Recommended sequence

Override merged *(this step)* → approve T2 → create T2 → baseline → **fingerprint gate (stop if it
fails)** → seeds / C3 → D → G → E non-destructive → **approval gate** → E destructive → evidence →
closeout → T2 disposition. Docker/WSL removal may happen any time after T2 is approved, as a
separate owner action.
