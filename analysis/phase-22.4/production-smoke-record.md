# Phase 22.4 — Current-Epoch Production Smoke Record

**Executed:** 2026-09-20, manually by the product owner in a live browser against production.
**Target:** `https://stagerz.app` (GitHub Pages, apex). **Backend:** `kbnmkyvbwkuvcklywdhk`.
**Epoch:** frontend `index.html` @ `3b38e6b` (byte-identical to the live build, verified in
`preflight.md` §1); schema epoch **`20260917143322`** (43 migrations).
**Observation method:** browser **Console**. The Network panel was **not** the captured surface, so
every claim below is scoped to what the Console and the visible UI actually showed.

**Overall: PASS at reduced scope.** Every executed test passed. Two areas were not covered — one
by owner decision, one because the UI offered no path. Neither is a failure, and neither is
recorded as evidence of correctness.

---

## 1. Results at a glance

| Test | Result | Classification |
|---|---|---|
| P22.4-1 Startup / production environment selection | **PASS** | TESTED |
| P22.4-2 Authentication + session restoration | **PASS** | TESTED |
| P22.4-3 Stage / core authenticated read | **PASS** | TESTED |
| P22.4-4 Other-artist profile read via Stage | **NOT EXECUTED** | NOT TESTED — UI navigation path absent |
| P22.4-4b Own profile read (additional) | **PASS** | TESTED |
| P22.4-5 Reversible profile write, persistence, restore | **PASS** | TESTED |
| P22.4-6 Collaboration message write/delete | **SKIPPED** | SKIPPED by design/safety decision — **not a FAIL** |
| P22.4-7 Stale-delete error-contract check | **N/A** | N/A — dependant of the skipped P22.4-6 |
| P22.4-8 Sign-out | **PASS** | TESTED |

---

## 2. Executed tests

### P22.4-1 — Startup and production environment selection — **PASS**

- `stagerz.app` loaded normally in an **incognito** browser context.
- **No visible fatal or red runtime error.**
- Console evaluation of `[STAGERZ_ENV.ok, STAGERZ_ENV.name, STAGERZ_ENV.supabaseUrl, startupFailure]`
  returned:
  `[true, 'production', 'https://kbnmkyvbwkuvcklywdhk.supabase.co', null]`
- **Conclusion:** the live application selected the intended production environment and backend,
  and `startupFailure` was `null`.

**Evidence scope — what is NOT claimed:** no complete Network-domain audit was performed manually.
The statement that no request reaches an unexpected Supabase project rests on the **preflight**
evidence only — the deployed bytes are byte-identical to `origin/main`, and static evaluation of
those bytes maps `stagerz.app` to production and fails closed on unknown hosts
(`preflight.md` §1). That is artifact-level evidence, not a runtime network observation.

### P22.4-2 — Authentication and session restoration — **PASS**

- An **existing owner-created tester account** was used. No account was created.
- A **real production magic-link sign-in succeeded**; the browser returned to `stagerz.app` in an
  authenticated state, and Stage rendered after authentication.
- **F5** (normal reload) preserved the authenticated session.
- **Ctrl+F5** (hard reload) preserved the authenticated session.
- **One** magic link was sufficient; no retry was consumed.

No tester e-mail address, magic-link URL, access token or refresh token is recorded here or
anywhere in this repository.

### P22.4-3 — Stage / core authenticated read — **PASS**

- The authenticated Stage screen loaded normally.
- Existing Stage content and posts rendered.
- The owner scrolled through Stage successfully.
- **No visible application error** appeared during the read test.

**Evidence scope — what is NOT claimed:** no detailed Network audit for HTTP 401/403 or SQLSTATE
`42501` was performed. The result is "no user-visible read failure on the current epoch", which is
weaker than "no permission error occurred at the API level".

### P22.4-4b — Own profile read (additional evidence) — **PASS**

- The authenticated user's own **Profile** screen opened and rendered normally.
- **Edit Profile** also loaded successfully.

Recorded separately from P22.4-4 on purpose: this exercises the signed-in user's own profile read,
**not** the `public_profiles` other-artist path.

### P22.4-5 — Reversible profile write, persistence and restoration — **PASS**

Sequence actually performed:

1. Edit Profile opened.
2. `bio` changed from its original production value to the temporary marker **`smoke-20260920`**.
3. **Save Profile** executed.
4. Browser reloaded.
5. Edit Profile reopened — **the marker was still present, proving persistence**.
6. `bio` restored **exactly** to its original value.
7. **Save Profile** executed.
8. Browser reloaded.
9. Edit Profile reopened — **the original value was confirmed restored and the marker was absent**.

**Final state: the original bio is restored; no smoke marker remains.**

The original bio's literal text is deliberately **not** recorded in this repository, per the
standing instruction not to place profile content in repository evidence. Its exact restoration was
verified visually by the owner at step 9.

Console screenshots taken during profile activity showed successful Supabase reads returning
**HTTP 200** against the intended `kbnmkyvbwkuvcklywdhk` backend.

**Evidence scope — what is NOT claimed:** the exact `PATCH` request payloads and status codes were
**not** inspected, because the Console rather than the Network panel was open. Specifically, the
planned direct proof that the `users` PATCH carries **`username` only** and no forbidden legacy
column was **not** obtained empirically.

**What can nonetheless be concluded, and on what basis.** `saveProfile()` issues two writes —
`PATCH /rest/v1/profiles` and then `PATCH /rest/v1/users` with `{username}` — and returns early
with an error toast if **either** fails, before showing the success path. The save completed, the
value persisted across a reload, and the restore round-trip also completed. Therefore **both writes
succeeded**, and the narrowed `users` UPDATE width introduced by migration `20260917143322` is
sufficient for the current UI. This is inferred from the source code path combined with the
observed end-to-end success — **it is not a direct payload observation**, and should be recorded as
such.

### P22.4-8 — Sign-out — **PASS**

- The owner signed out through the application.
- **F5** after sign-out remained signed out.
- The login / start state was shown again.

---

## 3. Not executed — P22.4-4, other-artist profile read

**Result: NOT EXECUTED.** During manual testing the Stage UI **did not provide a direct navigation
path** from Stage content or an artist display to another artist's profile. A deep link was **not**
fabricated and DevTools were **not** used to bypass the real UI.

**Classification — this matters:**

- This is **NOT** evidence that the `public_profiles` read contract or any backend behaviour
  failed. Nothing about the backend was learned here.
- It is a **UI / navigation / product finding**: *Stage currently does not expose the expected
  direct artist-profile navigation path that the smoke procedure assumed.*
- Consequence for coverage: the `public_profiles` join — rebuilt by migration `20260917143322` —
  and its `display_name` fallback chain remain **unverified on the current epoch**.

This finding belongs to the product roadmap, not to the backend gates. No fix was attempted.

---

## 4. Skipped and N/A

### P22.4-6 — Collaboration message write/delete — **SKIPPED BY DESIGN / SAFETY DECISION**

Preflight analysis of the canonical baseline established that the proposed create/delete message
test is **not residue-free**: message creation fires
`trg_log_collaboration_message_activity`, writing a `collaboration_activity` row (`message_posted`)
and notification rows to other participants; deleting the message writes a further
`message_deleted` activity row. None of these is removable through the UI, so a nominally temporary
smoke message would have left **permanent production rows**.

The owner intentionally skipped this mutation rather than pollute production.

**This must NOT be classified as FAIL.** It is a deliberate, documented scope reduction.

**Coverage consequence:** the collaboration message create/delete path, the Realtime
`postgres_changes` subscription and the Phase 21.9 error contract remain **unverified on the
current epoch**.

### P22.4-7 — Stale-delete / error-contract check — **N/A**

Dependent on the collaboration write scenario that was intentionally skipped. **No substitute
error-generation test was performed**, as instructed.

---

## 5. Residue check

| Item | Result |
|---|---|
| Tester `profiles.bio` | **Restored to its exact original value**, verified after reload |
| Smoke marker `smoke-20260920` | **Absent** |
| Users created | **None** |
| Wanted posts created | **None** |
| Collaborations created | **None** |
| Collaboration messages created | **None** (P22.4-6 skipped) |
| `collaboration_activity` / notifications | **None created intentionally**; no message was sent, so the message-activity trigger never fired |
| Storage objects | **None touched**; no collaboration Assets tab was opened |
| Edge Functions | **None invoked intentionally** |
| Supabase / Netlify / DNS / Auth / SMTP / keys / migration history | **Unchanged** |

**No known production test residue remains from the executed profile-write test.**

---

## 6. What this evidence does and does not establish

**It establishes**, on the current combined epoch (frontend `3b38e6b`, schema `20260917143322`):

- the production build loads and selects the correct production backend, with `startupFailure` null;
- real magic-link authentication works end to end, and the session survives both a normal and a
  hard reload;
- the authenticated Stage read path works with no user-visible error;
- the signed-in user's own profile and Edit Profile render;
- an authenticated **write** succeeds, persists across reload and can be reversed — which means the
  privilege narrowing of migrations `20260916215204` and `20260917143322` did not break the
  application's own save path;
- sign-out clears the authenticated state and survives a reload.

**It does NOT establish:**

- the `public_profiles` other-artist read on the current epoch (**P22.4-4 not executed**);
- the collaboration message create/delete path, Realtime delivery, or the Phase 21.9 error contract
  (**P22.4-6 skipped, P22.4-7 N/A**);
- anything at network-audit level — no 401/403/`42501` sweep, no PATCH payload inspection;
- **and it does not convert the deferred Phase 22.3 gates D, E, G or C3 into PASS.** Those remain
  exactly as recorded in `analysis/phase-22.3/closeout.md` §2 and are the scope of the proposed
  Phase 22.5.
