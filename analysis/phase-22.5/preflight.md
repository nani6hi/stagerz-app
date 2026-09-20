# Phase 22.5 — Preflight (read-only)

**Dates:** 2026-09-20 / 2026-09-21. **Nature:** read-only investigation — repository inspection,
read-only Supabase metadata, public HTTP and DNS. No Supabase mutation, no T2, no test execution.
**Base at the time of the final review:** `main` @ `0e27be81685a3c4459615e92d8ddc5ae0bb27a32`.

---

## 1. Gate reconstruction — what D, E, G and C3 actually require

### D — Auth / API / Realtime

**Proven in production**, repeatedly: Phase 21.2 N-1…N-3 (magic-link sign-in, session restore
across F5 and Ctrl+F5, sign-out, `onAuthStateChange`), N-5 (Realtime `postgres_changes` + presence,
**1 of the 5** subscribed tables), P-5/P-6 (real sign-in on `stagerz.app`), Phase 21.4 8/8
authenticated reads, Phase 21.3 anon-200 / base-table-401 `42501`, and the Phase 22.4 current-epoch
smoke.

**Not proven:** that the **canonical baseline**, applied to an empty environment, yields a working
Auth/API/Realtime runtime. Every result above comes from production, whose schema was built by 43
incremental migrations, not by the baseline. Realtime is unproven on 4 of the 5 published tables,
and the other-artist `public_profiles` read is unproven on the current epoch.

Needs a full Supabase runtime, an Auth user and Realtime. No Storage, no Edge Functions.

### E — Edge Functions

**Proven in production:** `process-pending-asset-deletions` (manual run plus daily scheduled runs —
seven consecutive successes 2026-09-14…09-20) and `reap-orphaned-collaboration-assets` (dry-run and
a real delete of 15 objects, with before/after fingerprints).

**Not proven:** `delete-account` — **never executed anywhere**, and `index.html` contains **zero**
callers, so account deletion is unreachable from the UI. `process-pending-deletions` — **never
executed anywhere**. The *present-object* branch of the asset drainer has never been exercised
(every proven run removed objects that were already absent).

Needs a full runtime, an Auth user, Storage and the Edge runtime.

### G — Storage API

**Proven in production:** Phase 21.2 N-4 (upload, byte-identical SHA-256 download, preview) and
Phase 21.8B (delete path at API level). The clean-room **database** contract (F) is PASS.

**Not proven:** any Storage **API** behaviour on a baseline-built environment. Blocked locally by
`storage-api:v1.72.1` exit 139.

> **Do not conflate this with the two production `collaboration_assets` rows whose Storage objects
> are missing.** That is a pre-existing production data issue, not a clean-room Storage failure.

### C3 — Full Auth-account fixture

**Proven:** the database-side scenario (C2 PASS) — three accounts created through the real
`on_auth_user_created` trigger produced the expected rows, inside a transaction, rolled back.

**Not proven:** that `supabase/seed/fixtures.sql` runs **as written**. Its `auth.users` /
`auth.identities` inserts could not execute, because the direct-Postgres image ships a 2021-era
`auth.users` stub lacking `email_confirmed_at`. Reported as NOT TESTED, **not faked**.

**All four gates require a full Supabase runtime on a baseline-built, disposable environment.**
Three of the four require a real Auth user. None is satisfiable by the direct-Postgres route used
in Phase 22.3.

---

## 2. Runtime targeting — why the frontend needed a change

### The mechanism as it stood

Backend selection happens once, client-side, in the block between the
`STAGERZ ENVIRONMENT SELECTION (BEGIN)/(END)` markers: a two-entry `STAGERZ_ENVIRONMENTS` table
(`production` with literal URL, publishable key and redirect; `local` with a literal
`http://127.0.0.1:54321`, a null key and a null redirect), a four-entry
`STAGERZ_HOST_ENVIRONMENT` map keyed on `window.location.hostname`, and
`stagerzSelectEnvironment()`. Unknown host ⇒ `unknown-host`; missing key ⇒
`environment-not-configured`; either way `startupFailure` is set and **the application never boots**.

Verified exhaustively: **one** `createClient` call site, **one** pair of `SUPA_URL` / `SUPA_KEY`
assignments, **one** storage key, and **zero** query-string or hash-based configuration. The
repository is fully static — no build step, no bundler, no `.env`, no config file, no
`netlify.toml`. Neither GitHub Pages nor Netlify injects anything.

### The problem

A browser could **not** be pointed at a future T2 without modifying tracked code. The host map keys
on the hostname serving the page, so a non-production backend requires `localhost` / `127.0.0.1` —
and there the URL was a literal. Only the *key* was overridable. Every other host failed closed.
The only alternative, serving a locally edited untracked copy, would validate a *modified*
artifact, which materially weakens gate D.

### The change (implemented in this step)

The `local` environment opts in with `allowsLocalUrlOverride: true` and may take its URL from
`localStorage['stagerz:local-supabase-url']`. The value is validated strictly and accepted only as
`https://<project-ref>.supabase.co` or `http://127.0.0.1:<port>` (port 1–65535), after trimming
whitespace and trailing slashes. **The production project ref is refused**, and the ref is *derived
from the production URL itself*, so the denylist cannot drift; if derivation ever fails, every
hosted override is refused rather than silently allowed. Anything invalid fails closed through the
existing `environment-not-configured` path — never a silent fallback to production.

**Production immunity is structural, not conventional:** the override is consulted only for an
environment carrying `allowsLocalUrlOverride`, which `production` does not have, and only after the
hostname has resolved to `local`. Setting the storage key on the production origin does nothing.

**Why the denylist is mandatory:** without it, a tester on `localhost` could paste the production
URL and key and then run the destructive tests of §3 **against production**. That is the single
most dangerous interaction in this phase, and the denylist removes it at code level.

No secret and no T2 identifier was committed. The tester supplies T2's URL and publishable key in
their own browser.

---

## 3. The two never-executed Edge Functions

### `delete-account` — irreversible

| Step | Effect | Reversible? |
|---|---|---|
| `admin_anonymize_account(p_public_user_id)` | `users`: sets `anonymized_at`; **nulls** `username`, `first_name`, `last_name`, `photo_url`, `bio`, `location`. `profiles`: `display_name='Deleted User'`, `role=''`, `category=null`, `skills='{}'`, `looking_for='{}'`, `location=''`, `country_flag=''` | **No** — overwritten in place, no prior copy |
| `auth.signOut({ scope: 'global' })` | Revokes all sessions | Moot |
| upsert `pending_auth_deletions` | Queue row | Yes |
| `auth.admin.deleteUser(authUserId)` | **Deletes the GoTrue user.** `user_auth_accounts.auth_user_id` is FK → `auth.users(id)` **ON DELETE CASCADE**, so the mapping row goes with it | **No** |

Secrets: the platform three plus `STAGERZ_ALLOWED_ORIGIN` (optional — **defaults to
`https://stagerz.app`**, so it must be set per environment or CORS will reference production).

**Design fact worth recording:** this is **anonymisation plus auth removal, not content erasure**.
The `public.users` and `profiles` rows survive, and everything the user authored — posts,
collaborations, messages, tasks, assets, credits, activity — **remains**, attributed to an
anonymised user that `public_profiles` renders as `'Deleted User'` with `is_deleted = true`. If
"delete my account" is ever intended to erase content, that is a product gap, not a test gap. This
is an observation, not a legal judgement.

Failure cases worth testing: no `Authorization` → 401; invalid JWT → 401; non-`POST` → 405;
`OPTIONS` → 204 with CORS headers; **idempotency** — a second call for an already-removed mapping
→ `200 {"status":"already_processed"}`.

### `process-pending-deletions` — irreversible

Batch of 25 from `pending_auth_deletions` ordered by `requested_at`; each row →
`auth.admin.deleteUser`, with outcomes `deleted` / `already_deleted` / `retry_recorded`
(incrementing `attempt_count`). Secrets: platform plus `STAGERZ_MAINTENANCE_SECRET`, accepted as
`Authorization: Bearer <secret>` or `X-STAGERZ-Maintenance-Secret`. **No scheduler exists for it in
the repository.**

**It does not re-verify that anonymisation happened** — any row in the queue means that auth user
is deleted. **The queue contents are the blast radius.**

Failure cases worth testing: wrong or missing secret → 401; non-`POST` → 405; **empty queue →
`200 {"processed":0}`**, the ideal zero-risk first call; and the `already_deleted` path, which
exercises `isAlreadyMissing` and `clearPendingRecord` with no destruction.

### Identities needed in T2

| Purpose | Needs |
|---|---|
| Non-destructive gates (D, G, C3, E-safe) | The three `fixtures.sql` accounts plus `showcase.sql` |
| `delete-account` | **One dedicated throwaway auth user**, created solely to be destroyed, with a **real session JWT** |
| `process-pending-deletions` drain | **One further throwaway auth user** plus one manually inserted queue row |
| `process-pending-deletions` safe first call | Empty queue |

**Practical obstacle:** fixture addresses use the reserved `.test` TLD and **cannot receive mail**,
and T2's default SMTP reaches only organisation members. Obtaining the real session that
`delete-account` requires therefore needs either the Supabase **admin API to generate the magic
link** (no delivery required) or **one real organisation-member mailbox** for that single throwaway
account. This should be settled before the phase starts.

**Confinement holds** provided each destructive test uses its own dedicated account, the three
fixture accounts are never destroyed, and the queue is seeded only with the intended auth id.
Showcase users are `is_system`, have no auth accounts, and cannot be signed in as.

### Residual risk to production or shared infrastructure

With the guardrails in `phase-definition.md` §8: **none identified.** Edge Function URLs, database,
Auth and e-mail budgets are all per-project. The three real coupling points are the frontend
override (closed by the denylist), a reused maintenance secret (closed by generating a fresh one),
and the `STAGERZ_ALLOWED_ORIGIN` default (closed by setting it). The GitHub Actions workflow
hard-codes the production function URL and runs daily at 03:17 UTC — it must be left alone.

---

## 4. Environment options considered

| | T1 local stack | **T2 cloud test project** | T3 repurpose legacy | T4 production + synthetic |
|---|---|---|---|---|
| Feasibility | **Low** — `storage-api:v1.72.1` exit 139, reproducible | **High** | Medium-low | High technically |
| Safety | Highest | **High** — separate project | Poor — destroys containment evidence | **Unacceptable** |
| All four gates provable? | **No** — G and part of E blocked | **Yes** | Yes, at that cost | **No** |

**Chosen: T2.** The Free-plan slot prerequisite is resolved by the legacy pause; creation remains
unapproved.

> **Cost note:** current Supabase plan limits and pricing **require external verification** and are
> deliberately not asserted here. The only plan fact on record is owner-observed from the dashboard:
> free-project limit 2, and another free project requires one to be deleted, paused or upgraded.

---

## 5. Docker / WSL

**No credible need remains for the local Docker route**, and T2 would make it unnecessary for all
planned Foundation validation: every platform prerequisite that Docker had to hand-build exists
natively on a Supabase project.

**Nothing unique lives on that machine** — the scratch workspace held only logs, two fingerprint
JSON files and extracted vendor Storage migrations, and every artifact hash and run result is
recorded in `analysis/phase-22.3/baseline-verification-record.md`. Reinstalling later is roughly
8–12 GB and an hour, per `analysis/phase-22.3/local-rebuild-plan.md`.

**Removal is a separate owner action and is not part of Phase 22.5.** Nothing has been uninstalled.
