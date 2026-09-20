# Phase 22.4 — Preflight (read-only)


> **NOTE (2026-09-20, after the migration).** The deployment facts recorded below — in particular
> that `www.stagerz.app` resolved through Netlify and that Netlify held the `stagerz.app` custom
> domain — describe the state **at preflight time**. They were superseded the same day by migration
> Steps 3 and 4. Current architecture: `analysis/phase-22.4/closeout.md` §2 and
> `netlify-surface-diagnosis.md` §10. This file is preserved unchanged as the preflight audit trail.

**Date:** 2026-09-20. **Nature:** read-only. No file was edited, no environment mutated.
**Base:** `origin/main` = `3b38e6b849a88e46aa0fd67c0f7040e761b274b5`, verified. Working tree clean.

---

## 1. The epoch under test

| Layer | Value | How established |
|---|---|---|
| Frontend source | `index.html` @ `3b38e6b`; last functional change `cb2bb12` | git |
| Deployed at `stagerz.app` | **byte-identical to `origin/main:index.html`** — HTTP 200, 276,708 bytes, `Content-Length` exact, SHA-256 `6b847208cdd0ab10…` | cache-busted public GET, hash comparison against the git blob |
| GitHub Pages freshness | `Server: GitHub.com`; `Last-Modified 2026-09-20T12:01:19Z` — **39 s after the PR #28 merge** (12:00:40Z); Actions `build` / `deploy` check-runs succeeded 12:00:45–12:01:13Z | public HTTP headers, GitHub REST |
| Host mapping | `stagerz.app`, `www.stagerz.app` and both `*.netlify.app` hosts → **production**; `localhost` / `127.0.0.1` → local; everything else fails closed | source + static evaluation of the **deployed** bytes |
| Backend selected | `https://kbnmkyvbwkuvcklywdhk.supabase.co`, publishable key, auth redirect fixed to `https://stagerz.app` | static evaluation of the deployed bytes |
| Backend project | `kbnmkyvbwkuvcklywdhk`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.141, `eu-north-1` | Supabase read-only metadata |
| Schema epoch | **43 migrations, latest `20260917143322`**; `20260919120000` (the baseline) **absent**, as designed | Supabase `list_migrations` (read-only) |
| Edge Functions | 4 ACTIVE, all `verify_jwt: false` — no drift from the Phase 22.3 capture | Supabase read-only metadata |

### Static verification of the deployed artifact

The environment-selection block was extracted from **the bytes `stagerz.app` actually served** and
evaluated offline. This is **not** a runtime test and does not by itself satisfy P22.4-1:

| Hostname | Result |
|---|---|
| `stagerz.app` | `ok=true`, `production`, project `kbnmkyvbwkuvcklywdhk`, redirect `https://stagerz.app` |
| `www.stagerz.app` | same |
| `deploy-preview-28--aquamarine-puppy-beccd9.netlify.app` | `ok=false`, `unknown-host` |
| `evil-stagerz.app` | `ok=false`, `unknown-host` |
| *(empty hostname)* | `ok=false`, `unknown-host` |

## 2. Auth constraints that shaped the plan

From `supabase/config/environment-inventory.md` §6:

- magic link only; **Site URL and a single redirect URL, `https://stagerz.app`** — so the smoke
  **must** run on the apex; sign-in cannot complete on any `*.netlify.app` host;
- **custom SMTP OFF** — default SMTP delivers only to Supabase organisation team members;
- **rate limit: 2 e-mails per hour, project-wide** — one attempt, one retry;
- sign-ups **ON** and the client calls `signInWithOtp` with `shouldCreateUser: true`, so a mistyped
  address creates a permanent account. The address was to be pasted, never retyped.

## 3. Tester data (from documentation only; no user rows were queried)

- `kbnmkyvbwkuvcklywdhk` holds **no known external users** (Phase 22.0, owner testimony O-6).
- **27 `auth.users`: 4 genuine-email accounts, all owner-created test accounts; 23 synthetic**
  with no auth identity, which therefore **cannot sign in**.
- 32 `users` / `profiles` (5 fictional seed profiles), 25 wanted posts, 11 collaborations.
- The smoke was to use **one existing owner test account**. No address, token or magic-link URL is
  recorded anywhere in this repository.

## 4. Approved write boundary

| # | Write | Reversible |
|---|---|---|
| 1 | Tester `profiles.bio` — temporary marker, then exact restoration | **Yes** |
| — | The `saveProfile()` path also re-writes the unchanged `users.username`; inherent to the existing UI save path, accepted in advance | n/a |

Plus Auth session rows from sign-in/sign-out. **No other application write was approved.**

### Why P22.4-6 was withdrawn

Source inspection of the canonical baseline established that a collaboration message is **not**
residue-free:

- `trg_log_collaboration_message_activity` (AFTER INSERT) writes a `collaboration_activity` row
  (`message_posted`) **and** notification rows to the other participants;
- `delete_collaboration_message` writes a second activity row (`message_deleted`) before deleting.

None of those is removable through the UI, so a "temporary" smoke message would leave **2 activity
rows and at least 1 notification** permanently in production. The owner therefore skipped P22.4-6,
and P22.4-7 (which depended on it) became N/A.

### The error-contract trigger that was evaluated and rejected

The obvious candidate — an over-length message raising `P0057` — is **blocked client-side**
(`maxlength="5000"` plus explicit length checks), so it never reaches the backend and is not a
valid test. The only safe backend trigger identified was a stale-UI second delete raising `P0054`
(rolled back, therefore residue-free), but it depends on P22.4-6 and was withdrawn with it.

## 5. Scheduled maintenance workflow (read-only; never triggered)

`process-pending-asset-deletions.yml`, via the public GitHub REST API — 12 runs total:

| Run | Timestamp (UTC) | Event | Conclusion |
|---|---|---|---|
| **#12** | **2026-09-20 08:32:05Z** | schedule | **success** |
| #11 | 2026-09-19 08:00:26Z | schedule | success |
| #10 | 2026-09-18 08:12:09Z | schedule | success |
| #9 | 2026-09-17 08:36:45Z | schedule | success |
| #8 | 2026-09-16 08:32:04Z | schedule | success |
| #7 | 2026-09-15 08:37:44Z | schedule | success |
| #6 | 2026-09-14 08:50:57Z | schedule | success |
| #5 | 2026-09-13 12:39:33Z | workflow_dispatch | success |
| #1–#4 | 2026-09-13 | workflow_dispatch | failure (initial setup, resolved by #5) |

**Seven consecutive scheduled successes, 2026-09-14 through 2026-09-20.** The workflow fails before
any request if the maintenance secret is missing, and a wrong secret would be rejected, so these
successes evidence that the secret path remains configured and accepted. **This corrects a stale
statement in the Phase 22.3 closeout — see that file's §7 correction record.**

## 6. GO / NO-GO

**GO**, issued 2026-09-20, conditional on: using an existing tester address that can receive
Supabase default mail and pasting rather than retyping it; accepting or skipping the P22.4-6
residue; selecting an `active` collaboration from the UI without opening its Assets tab; running on
`https://stagerz.app` only; and recording the original bio before editing.

The owner subsequently reduced scope by skipping P22.4-6 and P22.4-7. Execution and results:
`production-smoke-record.md`.
