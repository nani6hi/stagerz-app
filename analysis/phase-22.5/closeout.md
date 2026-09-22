# Phase 22.5 — Closeout

**Phase:** Runtime Rebuild & Test Environment Validation
**Status:** **COMPLETE / PASS — closed 2026-09-22**
**Closed from:** `main` @ `2552008d3f013d47f97e8eca11bcc5a17efce5d5` (the PR #36 merge)
**Owner decisions recorded at closeout (2026-09-22):** the AC6 qualification (§4.2) is **accepted**;
the closeout is **approved**; Phase 22.5 may be recorded as **COMPLETE / PASS**. T2 disposition is
**not executed**, and T2 stays intact until this closeout is merged. Docker/WSL are **not** removed.
The local repository folder is **not** moved.

Evidence of record: `phase-definition.md`, `preflight.md`, `t2-execution-record.md` (§1–§15),
`legacy-pre-pause-record.md`, `legacy-paused-record.md`. This document summarises that evidence. It
does not replace, reinterpret or strengthen it.

---

## 1. Objective and scope

**Objective (`phase-definition.md` §1):** prove that the canonical repository baseline plus the
documented configuration produces a **working** Supabase environment. That means closing the four
runtime gates deferred by Phases 22.3 and 22.4 (C3, D, E, G) and giving the two never-executed Edge
Functions, `delete-account` and `process-pending-deletions`, their first controlled end-to-end
exercise, on a **disposable** environment.

**In scope:**
- create a disposable T2
- apply the canonical baseline and pass the fingerprint gate
- apply the seeds and fixtures
- deploy and configure the Edge Functions for T2
- validate gates C3, D, G and E

**Out of scope (`phase-definition.md` §5), and still out of scope:**
- SMTP, CAPTCHA and backups
- CSP, key rotation and session policy
- monitoring and CI
- UI/product work
- migration-history reconciliation
- the 2 production `collaboration_assets` rows whose Storage objects are missing
- the stale Netlify native hostname, the apex `A`-record gap and Netlify build settings
- Docker/WSL removal

**Environments:**
- production `kbnmkyvbwkuvcklywdhk`: read-only throughout
- legacy `edxicnafggnnvcdvxemk`: `INACTIVE`, untouched
- disposable T2 `kjhszwlddzqxcglkpzrn` (`stagerz-t2-disposable-test-r2`)

---

## 2. Final acceptance criteria (`phase-definition.md` §9)

| # | Criterion | Final status | Evidence |
|---|---|---|---|
| 1 | T2 created without touching production or the legacy project | **PASS** | `t2-execution-record.md` §3, §10, §14 |
| 2 | Baseline applies unmodified, exit 0, first attempt | **PASS — with the qualification in §4.1** | §2–§4 |
| 3 | Fingerprint gate: every `exact` key matches | **PASS** | 20/20 (§4); still 20/20 after every later test phase, including destructive Gate E (§14) |
| 4 | `showcase.sql` applies and is idempotent | **PASS** | §5 |
| 5 | C3 — `fixtures.sql` unmodified and idempotent | **PASS** | §5 |
| 6 | D — sign-up/sign-in, session restore, authenticated read and write, anon denial, ≥1 Realtime event | **PASS — with the owner-accepted qualification in §4.2** | §5, §12 (D1–D6), §14 |
| 7 | G — upload, byte-identical download, non-participant refused, removal via the drainer | **PASS** (see the G4 observation, §4.6) | §12 (G1–G4) |
| 8 | E — all four functions authorised and unauthorised; both destructive paths completed on throwaway identities | **PASS** | §8, §12 (G4), §14 (E1, E2) |
| 9 | Production unchanged: 43 migrations, latest `20260917143322` | **PASS** | §10, §14. Edge Functions still v8 / v9 / v11 / v4 with unchanged bundle hashes |
| 10 | No secret, production key or real user data enters the repository | **PASS** | The records hold request/response shapes and synthetic `@stagerz.test` labels only |

---

## 3. Final gate matrix

| Gate / path | Final status | Evidence |
|---|---|---|
| **C3** — fixtures unmodified and idempotent | **CLOSED — PASS** | §5 |
| **D** — D1 sign-in and session restore after reload; D2 account contract; D3 authenticated reads incl. `public_profiles`; D4 anon denial (401 / `42501`); D5 reversible write; D6 Realtime on the app's own channel | **CLOSED — PASS** (AC6 qualification, §4.2) | §12 |
| **G** — G1 upload; G2 byte-identical download; G3 non-participant refused; G4 removal via the drainer | **CLOSED — PASS** (G4 observation, §4.6) | §12 |
| **E** — overall | **CLOSED — PASS** | §8, §12, §14 |
| E · `delete-account`, valid session, destructive path | **PASS** — E1, 14/14, on a dedicated disposable account | §14 |
| E · `delete-account`, unauthorised / invalid session | **PASS** — DA-1..DA-4 (OPTIONS 204, GET 405, no auth 401, invalid token 401); post-deletion repeat call 401 | §8, §14 |
| E · `process-pending-deletions`, empty queue | **PASS** — PPD-4; E2's second invocation `processed = 0` | §8, §14 |
| E · `process-pending-deletions`, seeded disposable account | **PASS** — E2, 8/8, on a second, different disposable account | §14 |
| E · `process-pending-asset-deletions`, empty queue | **PASS** — PAD-4 | §8 |
| E · `process-pending-asset-deletions`, real-object path | **PASS** — G4 | §12 |
| E · maintenance functions, unauthorised | **PASS** — PPD/PAD/REP-1..3 (405 / 401 / 401) | §8 |
| E · orphan reaper, dry-run | **PASS** — REP-4 | §8 |
| E · orphan reaper, **destructive mode** | **NOT RUN — not required** (§4.8) | §8, §14 |

No fixture or showcase/system user was deleted, anonymised or queued. The pre-existing data hash
was identical before E1, after E1 and after E2 (§14).

---

## 4. Qualifications, findings and observations carried into the closeout

### 4.1 AC2 — "first attempt"

The baseline SQL **applied successfully on its first apply in each T2 attempt**. The **first T2
fingerprint failure was caused by CRLF transport mutation**, not by the SQL:

- On T2 attempt 1 (`nkolvtdskgdgmebiehnz`), a Windows CRLF working-tree copy was transmitted, and
  the fingerprint failed 19/20 on `functions`.
- That attempt was deleted with owner approval (`t2-execution-record.md` §2).
- The replacement T2 applied the canonical LF Git blob **unmodified, exit 0, on its first apply**,
  and passed 20/20 (§3–§4).

The baseline itself never required modification or a retry. The history is recorded, not erased.

### 4.2 AC6 / Gate D — public `/otp` magic-link sign-up was NOT exercised (owner-accepted)

**Demonstrated:**
- The `on_auth_user_created` contract on real Supabase Auth user creation: C3 (§5) and the E1/E2
  accounts created with the Auth admin API, whose trigger produced the public row, profile and
  mapping (§14).
- Magic-link **sign-in** and session restore after a full reload (D1).

**Not exercised:** the public `/otp` magic-link **sign-up endpoint** itself. It requires mail
delivery, and `@stagerz.test` addresses cannot receive mail. Sessions were obtained through an
admin-generated magic link, per the owner-approved session method (`phase-definition.md` §10, gate 2).

The owner accepted this qualification at closeout. AC6 and Gate D are PASS **with** this
qualification, not without it. End-to-end public sign-up remains unverified until email delivery
(SMTP) exists.

### 4.3 Access-token (JWT) finding — SECURITY / HARDENING FOLLOW-UP

**Observed after the E1 deletion (`t2-execution-record.md` §14, Findings 1):**
- Supabase Auth **rejected** the deleted user's existing session on user lookup
  (`GET /auth/v1/user` → 403).
- The refresh token **could not** create a new session (400).
- The still-unexpired access JWT was **accepted** by the database API (PostgREST, HTTP 200).
- The **one** tested lookup — the deleted user's own account-mapping (`user_auth_accounts`) lookup —
  returned **0 rows**, because that mapping had been removed.

**Not demonstrated, and not claimed:**
- that no identity resolves in every relevant context
- that the deleted user can access no data
- that every RLS path, view, RPC or Storage endpoint is safe after deletion
- that the old JWT is harmless

The captured **production** JWT lifetime is **3600 seconds**. **T2's lifetime was not independently
observed.** Candidate hardening options were not evaluated here: a shorter JWT lifetime, or an
endpoint-by-endpoint review of what an `authenticated` token without an application identity can
reach.

### 4.4 Account deletion — what was observed vs. inferred

- **Observed at runtime (E1, and E2 for the drainer path):**
  - the Auth login and the `user_auth_accounts` mapping are removed
  - the `public.users` row is retained but anonymised
  - the profile and `public_profiles` show `Deleted User` (`is_deleted = true`)
- **Inferred from code, not demonstrated by E1/E2:** authored or referenced application content is
  **retained** and stays attributed to the anonymised user. The disposable accounts authored no
  content, so this retention was not exercised.

Account deletion is anonymisation plus login removal — **not** full data erasure.

### 4.5 `already_processed` branch

`already_processed` is not reachable from a normal client after a successful deletion. It was not
exercised, and this does not affect the E1 result (§14, Findings 3).

### 4.6 G4 — immediate post-delete HTTP 200 (observation)

Immediately after the drainer removed the object, a participant download on the **previously used
URL** returned HTTP 200 **once**. Shortly afterwards the same URL, a cache-busted URL and the
metadata API all returned 400, and a second drainer run processed 0. **Caching remains only a
hypothesis.** Cache headers were not captured, so the cause is unconfirmed (§12).

### 4.7 D6 — extra cross-user Realtime control (inconclusive)

D6 rests on `postgres_changes` delivered to the app's **own** Realtime channel. A separate, extra
cross-user control was **inconclusive**. It is **not used as Gate D evidence** and is not required
(§12).

### 4.8 Orphan reaper destructive mode — NOT RUN, not required

`phase-definition.md` §8 guardrail 4 required `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` to remain unset
on T2, so the reaper could only dry-run. The §2 Gate E definition requires authorised and
unauthorised calls to the reaper, not its destructive mode. The reaper dry-run (REP-4) and
unauthorised calls passed. **Destructive orphan reaping was never tested.**

### 4.9 Floating Edge Function imports

Three `@2` floating imports in the Edge Function sources were recorded (§7). They are not a gate
failure; they are a hardening follow-up.

---

## 5. Remaining findings — classification

**Classes:**
- **A** — Phase 22.5 blocker
- **B** — foundation/readiness blocker before real users or a public beta
- **C** — security/hardening follow-up
- **D** — product/UX follow-up
- **E** — infrastructure/deferred cleanup
- **F** — observation only

**No class-A item exists.** None of the items below was resolved by Phase 22.5.

| Item | Class | Note |
|---|---|---|
| Deleted user's access JWT accepted at the database API until expiry (§4.3) | **C** | Only one lookup was tested; not demonstrated harmless |
| Retention of authored content after deletion (§4.4) | **D** | Inferred from code; a product/privacy decision |
| G4 transient post-delete 200 (§4.6) | **F** | Cause unconfirmed; caching is a hypothesis |
| Inconclusive extra cross-user Realtime control (§4.7) | **F** | Not used as evidence |
| Floating `@2` Edge Function imports (§4.9) | **C** | |
| Orphan reaper destructive mode not run (§4.8) | **F** | Not required by the phase |
| 2 production `collaboration_assets` rows with missing Storage objects | **B** | Out of scope; unchanged |
| SMTP / email delivery and rate limits | **B** | Also blocks exercising public `/otp` sign-up (§4.2) |
| Backups / Free-plan posture | **B** | |
| CAPTCHA / sign-up abuse protection | **B** | |
| Production test/synthetic data cleanup | **B** | |
| Account-deletion UI (the function has no caller in the app) | **D** | Likely also a readiness item before real users |
| Legacy anon / service_role keys (where applicable) | **C** | |
| Session policy | **C** | |
| CSP | **C** | |
| Monitoring / CI | **E** | Readiness-relevant before live users |
| Migration-history reconciliation | **E** | |
| Stale Netlify native deployment surface | **E** | |
| Apex DNS (`A`-record gap; single-IP dependency) | **E** | |

---

## 6. T2 disposition

**Verdict: SAFE TO DISPOSE after this closeout is merged.**

T2 `kjhszwlddzqxcglkpzrn` **still exists** and is **not deleted or paused**. It holds only:
- the fixture and showcase data
- the 2 expected anonymised `Deleted User` rows left by E1/E2

Every piece of evidence the phase relies on is recorded in this repository. T2 has no remaining
required Phase 22.5 purpose, and it can be rebuilt reproducibly from the canonical baseline.

| Option | Assessment |
|---|---|
| **Delete** (recommended) | Frees the Free-plan project slot, and removes a live project that holds a T2 maintenance secret |
| Pause | Preserves nothing the phase requires |
| Retain temporarily | Only useful as a scratch target for later hardening work |

The disposition requires a separate explicit owner action. **It has not been executed.**

---

## 7. Docker / WSL

**Verdict: NO LONGER REQUIRED for the completed foundation gates.** Every Phase 22.5 runtime proof
ran on the hosted T2, through the Supabase CLI and a headless browser. A local Supabase stack was
never needed.

Docker/WSL remain **optional** for any future local-stack work. They have **not** been uninstalled;
removal is a separate owner action.

---

## 8. What COMPLETE / PASS means — and does not mean

**COMPLETE / PASS means** the defined Phase 22.5 runtime-rebuild and disposable-environment
validation objectives were satisfied:
- the canonical baseline applied unmodified to a clean hosted environment and matched the production
  fingerprint 20/20
- gates C3, D, E and G passed on that disposable environment, within the qualifications recorded in
  §4
- production and legacy were left unchanged

**It does NOT mean:**
- STAGERZ is production-ready
- STAGERZ is public-beta-ready
- SMTP / email delivery is ready
- public `/otp` magic-link sign-up was exercised
- all security hardening is complete, including the JWT follow-up in §4.3
- destructive orphan reaping was tested
- all production data issues are resolved, including the 2 `collaboration_assets` rows
- T2 has been disposed of, or Docker/WSL removed

---

## 9. Next planning focus

**No next implementation phase is started or assigned by this closeout.** The next planning focus is
**production / public-beta readiness**, drawing on the open items in §5.
