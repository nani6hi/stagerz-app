# Phase 22.0 — Investigation Report

**Branch:** `phase-22.0-production-environment-confirmation` (from `main` @ `0c170ed`)
**Date:** 2026-09-19 (UTC)
**Mode:** read-only. No Supabase, Netlify or application change was made.
**Status:** **COMPLETE / PASS — Classification C — MIXED / LEGACY ENVIRONMENT (accepted by the product owner, 2026-09-19).**
- **PASS means the investigation objective was achieved.** The environment question is answered with evidence and every exit criterion is met (§8).
- It does **not** mean the environment architecture is acceptable long-term, and it does **not** mean findings LG-1 … LG-5 are resolved. They remain **OPEN** (§8).
- Owner evidence is in §2A, the legacy-project inspection in §2B, the reassessment in §4, and the closeout in §8.

Privacy: this report contains counts, dates, schema/configuration metadata and project/site identifiers that are already public in the repository. It contains no emails, user IDs, names, message bodies, API keys, tokens or secrets.

---

## 1. Answer in one paragraph

`kbnmkyvbwkuvcklywdhk` is the **only** backend the live STAGERZ frontend has used since 2026-07-13, on both public surfaces. It was **created and declared as a disposable test project**: its Supabase name is `stagerz-foundation-v2-test`, its first migration says *"Applied to disposable test project kbnmkyvbwkuvcklywdhk only"*, and `index.html` still labels the auth flow "TEST ONLY". Its data is overwhelmingly synthetic or seed content, with only 4 genuine email accounts. The original backend, `edxicnafggnnvcdvxemk` ("stagerz-app"), still exists and is healthy, but has been disconnected from the frontend since 2026-07-13.

**Classification (accepted by the owner, 2026-09-19): C — MIXED / LEGACY ENVIRONMENT.** It is a test-designated project that became the de facto live backend of the production domain, next to a still-existing legacy project. The legacy project, inspected in §2B, has been dormant since 2026-07-12, but it is still publicly readable and writable through a valid anon key in public git history (LG-1).

**Owner evidence (§2A) confirms and sharpens this.**
- `kbnmkyvbwkuvcklywdhk` was deliberately created as a disposable Free-plan **test** project, because branching the then-production project would have required the Pro plan.
- `edxicnafggnnvcdvxemk` was at that time **regarded as the production project** and was to remain untouched.
- The test project later acquired the live role **without a documented decision**.
- All 4 genuine accounts are the **owner's test accounts**, so no external user is known on `kbnmkyvbwkuvcklywdhk`.
- The legacy project's data is **STAGERZ tester data** from the original Telegram Mini App stage (O-7, O-8). **No known external-user accounts or data exist in either environment.**
- Telegram was removed from the active application for the time being, **not permanently rejected** (O-9).

---

## 2. Findings per investigation question

### Q1 — Which project does the deployed frontend call? **ESTABLISHED: `kbnmkyvbwkuvcklywdhk`, on every surface.**

- **`https://stagerz.app`** (apex): DNS `185.199.108.153`, a GitHub Pages address; `Server: GitHub.com`; HTTP 200.
  - The served `index.html` is **byte-identical** to `main:index.html`: 274,297 bytes, SHA-256 `249109be…1ead`.
  - It contains exactly one Supabase host, `kbnmkyvbwkuvcklywdhk.supabase.co`, and `emailRedirectTo: 'https://stagerz.app'`.
- **`https://aquamarine-puppy-beccd9.netlify.app`** (`Server: Netlify`): identical to `main` except for a 5-line hosting comment/meta block that Netlify injects. It contains the same single Supabase host and the same redirect.
- **The key belongs to this project:** the page served on `stagerz.app` carries `kbnmkyvbwkuvcklywdhk`'s **active publishable key** (exact match, checked read-only; the key is not reproduced here).
- **Netlify** records `https://stagerz.app` as the site's primary URL. Its current **production-context** deploy was built automatically from `main` @ `0c170ed` (`manual_deploy: false`), with no functions, redirect rules or header rules. `www.stagerz.app` resolves to non-GitHub addresses, consistent with Netlify serving the `www` host.
- **Conclusion:** every public STAGERZ surface is built from `main` and talks to `kbnmkyvbwkuvcklywdhk`.

### Q2 — Can configuration override the hard-coded project? **ESTABLISHED: no.**

- `SUPA_URL` and `SUPA_KEY` are literal constants in `index.html` (one definition each).
- The site has no build step: Netlify reports framework `unknown`, and the served bytes equal the repository file.
- **No** `.env`, `netlify.toml`, `_redirects`, `_headers`, `supabase/config.toml`, `package.json` or other configuration file has ever been committed (all 292 commits checked).
- There is therefore no mechanism by which environment variables could redirect the frontend to another project.

### Q3 — Has STAGERZ used another project? **ESTABLISHED: yes, `edxicnafggnnvcdvxemk`, until 2026-07-13.**

- **2026-06-25:** `index.html` first uses `edxicnafggnnvcdvxemk.supabase.co` (commit `8f3b571`). This is the same day that project was created (2026-06-25 17:06 UTC).
- **Through 2026-07-12:** it remains the frontend's backend; the app of that time used a legacy anon JWT key.
- **2026-07-13 00:48:** commit `24609a8` ("Update index.html", a GitHub web edit) changes **exactly two lines**, `SUPA_URL` and `SUPA_KEY`, from `edxicnafggnnvcdvxemk` to `kbnmkyvbwkuvcklywdhk`, and from a legacy JWT to a `sb_publishable_` key. It is an ancestor of `main`.
- Across all 292 commits on all refs, **only these two Supabase hosts** have ever appeared.

### Q4 — How was `kbnmkyvbwkuvcklywdhk` created and described? **ESTABLISHED: as a disposable test project.**

- Supabase name **`stagerz-foundation-v2-test`**, created **2026-07-12 07:48 UTC**, region `eu-north-1`, ACTIVE_HEALTHY.
- First migration `20260712100630 web_identity_forward_and_rls`, header: *"Applied to disposable test project kbnmkyvbwkuvcklywdhk only."*
- A later migration (`20260712144816`) says "so the test project matches the corrected migration exactly".
- **2026-07-13** (commit `7f57251`): `index.html` gains the "TEST ONLY — disposable project" labels. They explain that the hosted email template sends a magic link rather than a numeric code without custom SMTP, and that the post-send UI "differ[s] from production". The labels are still present on `main` (lines 330 and 1403–1404).
- **2026-07-13** (commit `6a45f90`): `emailRedirectTo: 'https://stagerz.app'` added.
- **2026-07-12:** migration `20260712101119 web_identity_seed` inserts only fictional demo content: 5 system profiles and their Wanted posts.

### Q5 — Character of the data (counts only). **ESTABLISHED: predominantly synthetic; very small genuine usage.**

**Auth accounts (27):**
- **23 synthetic:** NULL `created_at`, no auth provider, example/test/invalid email domains, never signed in. These are inserted fixtures, not sign-ups.
- **4 genuine email sign-ups:** created between 2026-07-13 and 2026-08-24; all confirmed and all signed in at least once; last sign-in 2026-08-24; 2 signed in within the last 30 days; **0 within the last 7 days**.
- Across all 27 accounts there are 3 distinct email domains.

**Other auth tables:**
- 4 identities, all `email`.
- 5 sessions: earliest 2026-07-17, latest update 2026-09-13.
- The Auth audit log is **empty** (0 rows).

**`public.users` (32):**
- 5 system seed profiles, 4 linked to the genuine accounts, 23 linked to synthetic accounts.
- 8 onboarded (5 system + 3 genuine), 2 blocked, 0 anonymized.

**Content:**

| Item | Total | Split by author | Dates |
|---|---|---|---|
| Wanted posts | 25 | 10 genuine, 10 synthetic, 5 seed | 2026-07-12 – 07-26 |
| Applications | 18 | — | 2026-07-14 – 07-26 |
| Collaborations | 11 | — (10 active, 1 completed) | 2026-07-15 – 07-26 |
| Messages | 28 | 20 genuine, 8 synthetic; 6 distinct senders | 2026-07-15 – 08-16 |
| Assets | 15 (all live) | 13 genuine, 2 synthetic | 2026-07-18 – 08-16 |
| Activity | 175 | — | up to 2026-09-12 |
| Notifications | 128 | — | up to 2026-09-12 |
| Follows / likes | 0 / 0 | — | — |

- **Only 2 distinct genuine accounts ever authored content.**
- **Storage:** 1 bucket, 13 objects, about 14.9 MB, created 2026-07-18 – 08-16.

**Timing:** almost all content was created during the 2026-07-12 – 07-26 build window. The later writes fall next to dated validation work recorded in this repository:
- the 2026-08-16 writes sit one day before the Phase 21.2 authenticated regression, recorded as executed 2026-08-17, and are **not** proven to be that run;
- the 2026-09-12 writes match the Phase 21.7 production smoke tests (validation closed 2026-09-12), which sent and deleted a real collaboration message.

**Limits:**
- Whether the 4 genuine accounts belong to the owner or testers, or to external users, **cannot** be determined without reading personal data, and was not attempted. *Resolved by owner evidence (§2A, O-2): all four are owner-created test accounts.*
- The existence of data is not treated as proof of production.

### Q6 — Do its Edge Functions and migrations correspond to repository work? **ESTABLISHED: yes.**

- **Edge Functions:** the 4 functions (`delete-account` v8, `process-pending-deletions` v9, `process-pending-asset-deletions` v11, `reap-orphaned-collaboration-assets` v4) were deployed here 2026-07-12 → 2026-09-13. Their sources were captured into the repository in Phases 21.8A/21.8B.
- **Migrations:** the 43 migrations run from `20260712100630` to `20260917143322`. They include `20260916215204` (O-1/O-2/O-3) and `20260917143322` (R-5), both applied under approval in this repository's phases.
- **Workflow:** the scheduled drainer targets this project's function URL.
- **Scope of repository work:** every backend phase in this repository (21.3–21.9, O-1/O-2/O-3, R-5) was performed against this project.

### Q7 — Is Auth pointed at a live deployment? **PARTLY ESTABLISHED.**

- **Established:**
  - the client sends `emailRedirectTo: 'https://stagerz.app'`;
  - Phase 21.2 recorded that magic links return to `stagerz.app`, the production domain, not to local builds;
  - genuine accounts completed sign-in, so the redirect is accepted in practice.
- **UNKNOWN:** the Auth **site URL**, the **redirect allow-list**, the **email template**, **custom SMTP** and **rate-limit** settings. These are not readable with the available read-only tools (they live in the Auth configuration, not the database) and were not inspected through any other channel.

### Q8 — Any other backend or environment? **ESTABLISHED: one other project** — role unknown at first, established in §2A / §2B: the former Telegram-era backend, now detached and dormant.

- The Supabase account contains exactly **two** projects:
  - `kbnmkyvbwkuvcklywdhk` "stagerz-foundation-v2-test" (created 2026-07-12);
  - `edxicnafggnnvcdvxemk` **"stagerz-app"** (created 2026-06-25, ACTIVE_HEALTHY, PostgreSQL 17.6.1.155, `eu-north-1`).
- `edxicnafggnnvcdvxemk` is referenced **nowhere** in the current application or configuration. Its only current mentions are a "never target" instruction in the R-5 records and `PROJECT_CONTEXT.md`.
- Its contents, data volume and intended future role are **UNKNOWN**: its database was deliberately not queried.
- There is **no** staging or preview backend. Netlify deploy previews, where they exist, are built from the same `index.html` and therefore call the same project.

---

## 2A. Owner evidence — recorded 2026-09-19

Statements by the product owner in answer to the owner-only questions of §4. They are recorded as **owner testimony**: authoritative for intent and for the owner's own accounts, but not independently verifiable from the repository or the catalog.

| # | Owner statement | Effect on the evidence |
|---|---|---|
| **O-1** | On **2026-07-12** the owner deliberately created `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk`, region `eu-north-1`, **Free plan**. | Matches E-7 and E-8 (name; created 2026-07-12 07:48 UTC; `eu-north-1`). Adds the plan tier: **Free**. |
| **O-2** | It was created as a **separate disposable TEST project** because branching the existing production project in Supabase would have required the **Pro** plan. | Confirms the test intent recorded in E-6 … E-8, and explains why a second project exists at all. |
| **O-3** | At that time **`edxicnafggnnvcdvxemk` was regarded as the production project** and was explicitly to **remain untouched**. | New: gives the legacy project (E-9, E-10) a **designated-production** history. It also explains the "never target" rule. |
| **O-4** | The purpose of `kbnmkyvbwkuvcklywdhk` was **Foundation v2 deployment/testing only, not production**. | Confirms E-6 … E-8. |
| **O-5** | Development continued against the test project. Application, backend, Edge Function, Storage/database and security work accumulated there, and it became the backend of the live frontend **without a clearly documented formal decision** converting it from test to production. | Matches E-1 … E-5, E-9, E-12, E-14 and E-17. Confirms that the live role was **acquired by drift**, not designated. |
| **O-6** | **All four genuine-email Auth accounts are TEST ACCOUNTS**, created by the owner for multi-user functional testing (messaging between users, uploads, downloads, other account-to-account features). They are not known external users. | Resolves unknown 2. With E-11, **no known external user exists** on `kbnmkyvbwkuvcklywdhk`: 23 synthetic accounts, 4 owner test accounts, 5 fictional seed profiles. |
| **O-7** | *(recorded at closeout, 2026-09-19)* The data in `edxicnafggnnvcdvxemk` belongs to **STAGERZ testers**. The 3 legacy `users` rows and the 2 Auth accounts are tester data, not known external production users. The `wanted_posts` rows also belong to that early development and testing period. | Resolves the legacy data-ownership question left open by §2B (answers A and C). With O-6, **no known external-user accounts or data exist in either environment**. No personal identifier is recorded here. |
| **O-8** | STAGERZ **began as a Telegram Mini App**, and `edxicnafggnnvcdvxemk` belongs to that earlier Telegram-based stage. STAGERZ then changed direction toward the standalone application, and Telegram integration was stopped and removed from the active application **for the time being**. | Explains the Telegram-era v1 schema (E-21), and why the frontend switch (`24609a8`) coincided with the move to Foundation v2. Consistent with the product decision recorded in `PROJECT_CONTEXT.md` (Telegram preserved as a future-version concept). |
| **O-9** | **Telegram was NOT permanently rejected as a concept**; it may become useful again in a future STAGERZ phase. Retiring or containing the old Telegram-era backend is **not** a decision that STAGERZ can never integrate with Telegram again. | Scope guard for any follow-up that touches `edxicnafggnnvcdvxemk`: such work concerns that project's exposure and data, not Telegram as a product direction. |

**Resulting timeline:**
1. **2026-06-25:** `edxicnafggnnvcdvxemk` ("stagerz-app") is created; it is the frontend's backend and the designated production project.
2. **2026-07-12:** `kbnmkyvbwkuvcklywdhk` is created as a disposable Free-plan test project for Foundation v2.
3. **2026-07-13:** the frontend is switched to it (`24609a8`) and labelled "TEST ONLY".
4. **Since then:** it serves the production domain, with no formal re-designation. The designated-production project has been detached from the frontend ever since.

---

## 2B. Legacy project `edxicnafggnnvcdvxemk` — read-only inspection, 2026-09-19

**Authorization.** The product owner lifted the "never target" rule for **read-only** inspection L-1 … L-10 only, for this investigation.

**Method.** Metadata tools plus catalog and aggregate `SELECT`s (markers `P220-LEGACY-CATALOG-v1`, `P220-LEGACY-COLS-v1`, `P220-LEGACY-DATA-v1`). No write, no API call with any key, no row content read beyond category tests. No email, ID, name, username, URL, key value or other personal data is recorded here.

### L-1 — Identity and status ✅
- Name **`stagerz-app`**, ref `edxicnafggnnvcdvxemk`, region `eu-north-1`.
- **ACTIVE_HEALTHY**, PostgreSQL 17.6 (17.6.1.155).
- Created **2026-06-25 17:06 UTC**.
- Schemas: `auth`, `extensions`, `graphql`, `graphql_public`, `pgbouncer`, `public`, `realtime`, `storage`, `vault`.
- Extensions identical in set to `kbnmkyvbwkuvcklywdhk`.

### L-2 — Migration history ✅
- **No migration history exists**: `list_migrations` returns none, and the `supabase_migrations` schema does not exist.
- The schema was created outside the migration system, for example through the SQL editor.
- Its generation is identifiable from the schema itself (L-3): a **Telegram-era "v1" schema**, structurally unrelated to Foundation v2.

### L-3 — Table inventory ✅

`public` has **6 tables and no views**:

| Table | Rows |
|---|---|
| `users` | 3 |
| `wanted_posts` | 5 |
| `profiles` | 0 |
| `notifications` | 0 |
| `follows` | 0 |
| `likes` | 0 |

- `users.id` is a **`bigint`**, and all FKs reference it; the `users` columns (`username`, `first_name`, `last_name`, `photo_url`) mirror a Telegram user object.
- No `collaboration_*`, `wanted_applications`, `user_auth_accounts` or deletion-queue tables exist.
- No triggers on `public` or `auth`; only the standard `storage` triggers.
- No Realtime publication membership. No `cron` schema.

### L-4 — Auth aggregates ✅
- **2 accounts**: provider `email`, both created **2026-07-12**, none on test/example domains.
- 1 confirmed and 1 ever signed in, the last sign-in on 2026-07-12.
- 2 identities (email), 2 sessions (last update 2026-07-12). The Auth audit log is empty.
- Whose accounts these are is **not determinable without reading personal data**; the owner can confirm.

### L-5 — Application-data chronology ✅
- **`public.users`: 3 rows**, all created and last updated **2026-06-25**, the project's creation day.
  - All 3 have a username and a first name; 1 has a last name; 1 has a photo URL, on a Telegram host.
  - ID size: 1 row has an ID ≤ 1,000 (seed-like), and 1 has an ID > 1,000,000, the range of real Telegram user IDs.
  - **At least one row is therefore plausibly a real Telegram account's public profile data.** Whose it is was not examined. *Owner confirmation (§2A, O-7): tester data, not a known external user.*
- **`wanted_posts`: 5 rows**, all created 2026-06-25, one single author, all `open`.
- `profiles`, `notifications`, `follows`, `likes`: empty.
- **After the 2026-07-13 frontend switch: 0 new or updated application rows, 0 new auth accounts, 0 sign-ins.** The last recorded activity of any kind is **2026-07-12**.

### L-6 — Storage ✅
**0 buckets, 0 objects, 0 bytes, no Storage policies.** No user files exist.

### L-7 — Access-control posture ✅ — **exposure found**
- **Grants:** on **all 6** `public` tables, `anon` and `authenticated` hold **SELECT, INSERT, UPDATE, DELETE and TRUNCATE** (table level).
- **RLS:** enabled on all 6, none forced.
- **Policies:** every one applies to role `public` with expression **`true`**.

| Tables | Policies (all `true`) |
|---|---|
| `users`, `profiles`, `wanted_posts`, `notifications` | SELECT, INSERT, UPDATE; no DELETE policy, so row DELETE is denied by RLS |
| `follows`, `likes` | SELECT, INSERT, DELETE |

- **Consequence:** any holder of the project's anon credential can, through the REST API:
  - **read** all `users` rows (usernames, names, one Telegram photo URL) and all `wanted_posts`;
  - **insert and update** rows in all six tables.
- `TRUNCATE` is granted too, but no PostgREST or GraphQL route exposes it (latent only).
- **Function:** `public.rls_auto_enable()` is `SECURITY DEFINER` and executable by `anon` and `authenticated`. It is an **event-trigger function**, attached to the event trigger `ensure_rls`, that turns on RLS for new `public` tables. A direct RPC call cannot run a trigger function's body, so this is low risk.
- **Default privileges:** the `postgres` role's default privileges in `public` and `storage` still grant **everything** to `anon` and `authenticated` for tables, sequences and functions. This is the pattern remediated in `kbnmkyvbwkuvcklywdhk` as S-5, and it was never remediated here.

### L-8 — Advisors ✅
- **Security:**
  - `anon_security_definer_function_executable` WARN ×1 (`rls_auto_enable`);
  - `authenticated_security_definer_function_executable` WARN ×1 (same function);
  - `auth_leaked_password_protection` WARN ×1.
- **Performance:** `unindexed_foreign_keys` INFO ×5.
- The Advisor does **not** flag the always-true policies, because RLS is enabled. The exposure in L-7 is only visible from the grants and policy expressions.

### L-9 — Edge Functions ✅
**None deployed.**

### L-10 — Client-key status ✅ (established without using any key)
- Two client credentials are listed, **both enabled**: the **legacy `anon` JWT** and a newer `sb_publishable_` key. Values were not recorded.
- The legacy anon key in this repository's public git history (6 commits on `main` before `24609a8`) has the **same** `ref`, `role`, issued-at (**2026-06-25 17:06 UTC**, the project's creation minute) and expiry (**2036-06-25**) as the currently enabled legacy anon key. It is therefore the **same, still-valid credential**.
- The repository is public (Netlify deploy record `public_repo: true`).
- The newer publishable key appears nowhere in this repository.

### Answers to the owner's questions A–F

| # | Question | Answer |
|---|---|---|
| **A** | External-user activity? | **Not evidenced, not excluded.** The dataset is tiny and concentrated on the creation day: 3 users and 5 posts on 2026-06-25, plus 2 email accounts on 2026-07-12. That is consistent with early development. But at least one `users` row carries a Telegram-range ID and a Telegram photo URL, i.e. data from a **real Telegram account**, most plausibly the owner's own or a tester's. The owner can confirm. **Resolved (O-7): all of it is tester data; no external-user activity is known.** |
| **B** | Activity after 2026-07-13? | **No.** Zero writes and zero sign-ins after the switch; the last activity of any kind was 2026-07-12. |
| **C** | Does retained data need a decision? | **Yes, a small one.** 3 `users` rows (including plausibly real Telegram profile data), 5 `wanted_posts`, and 2 auth accounts with email addresses. This is personal data kept in a detached project, **publicly readable** (L-7). A retention or deletion decision is needed; no migration value is apparent. **Owner confirmation (O-7): it is tester data.** It is still personal data of real testers, so the retention decision and the exposure (LG-1) remain open for the follow-up containment phase. |
| **D** | Meaningful exposure from the old public credential? | **Yes — currently meaningful, moderate severity.** The credential is valid (L-10) and published in a public repository's history, and the grants and always-true policies (L-7) let anyone read the `users` and `wanted_posts` data and insert or update rows in all six tables. The data volume is small, but it includes personal data, and the write access lets anyone plant content in a project owned by STAGERZ. Assessed from catalog metadata only; **not** exercised. |
| **E** | Anything still depends on it? | **Nothing observable.** No repository, application, workflow or Netlify reference; no Edge Functions, cron or Realtime; no activity since 2026-07-12. External references outside this repository (for example old bookmarks, or a Telegram bot configuration pointing at an old deployment) are unknowable here. Any such client would load today's `stagerz.app`, which calls `kbnmkyvbwkuvcklywdhk`. |
| **F** | Reconsider classification C? | **No.** It confirms the legacy half: a detached, formerly-designated production project on a Telegram-era schema, holding a minimal early dataset and dormant since 2026-07-12. Nothing suggests it is, or could readily become, the production backend: its schema is incompatible with the current application. |

### Newly discovered issues (recorded, not remediated)

| ID | Issue | Severity | Note |
|---|---|---|---|
| **LG-1** | Legacy project publicly readable and writable through a valid anon credential published in public git history (L-7, L-10) | **Medium** | Small but personal data; unrestricted inserts/updates. Not exercised. |
| **LG-2** | `postgres` default privileges in `public`/`storage` grant everything to `anon`/`authenticated` | Low (latent) | The S-5 pattern, never remediated on this project |
| **LG-3** | `TRUNCATE` granted to `anon`/`authenticated` on all tables | Low (latent) | Not reachable through PostgREST / GraphQL |
| **LG-4** | `rls_auto_enable()` executable by `anon`/`authenticated` | Low | Event-trigger function; body not runnable by direct call |
| **LG-5** | Leaked-password protection disabled | Low | Same platform warning as `kbnmkyvbwkuvcklywdhk` |

### Disposition options for the legacy project — described only, none chosen or performed

| Option | What it would involve | Effect on LG-1 | Trade-offs |
|---|---|---|---|
| **1. Leave as is** | Nothing | Exposure continues | Zero effort; the personal data stays publicly readable and writable |
| **2. Lock down in place** | Revoke `anon`/`authenticated` grants, replace the always-true policies, disable the legacy anon key or legacy keys, remove the default privileges | Closed | Keeps the data and the project; several mutations |
| **3. Pause the project** | Platform pause | API unavailable while paused | Reversible; data retained; the platform's paused-project retention rules must be checked first |
| **4. Private export, then delete the data** | Owner-held private export (not in the repository), then row deletion | Closed | Removes the personal data; the project persists |
| **5. Private export, then delete the project** | As 4, then project deletion | Closed | Irreversible; ends billing and backups for a second environment |
| **6. Re-adopt as production** | — | — | **Not credible**: the Telegram-era v1 schema is incompatible with the Foundation v2 application; it would be a rebuild, not a re-adoption |

Each option except 1 would be its own separately approved phase or change, and would need the owner's answer on whose data the 3 `users` rows and 2 auth accounts hold.

---

## 3. Evidence matrix

| # | Source | Location | What it says / shows | Current or historical | Supports | Reliability / limits |
|---|---|---|---|---|---|---|
| E-1 | Served page | `https://stagerz.app`, 2026-09-19 | Byte-identical to `main`; calls only `kbnmkyvbwkuvcklywdhk`; redirect `https://stagerz.app` | Current | **Live wiring** (production role) | High — direct observation; a single fetch |
| E-2 | Served page | `aquamarine-puppy-beccd9.netlify.app` | Same app plus Netlify-injected meta; same project | Current | Live wiring | High |
| E-3 | DNS | `stagerz.app` → `185.199.108.153`; `www` → non-GitHub addresses | The apex is GitHub Pages | Current | Production domain served from `main` | High; `www` host role inferred |
| E-4 | Netlify deploy | production context, `main` @ `0c170ed`, automatic | Netlify treats this as the production deploy of `stagerz.app` | Current | Live wiring | High — platform record |
| E-5 | Supabase keys | active publishable key == key in served page | Binds the live page to this project | Current | Live wiring | High — exact match |
| E-6 | `index.html` | lines 330, 1403–1404 | "TEST ONLY — disposable project"; flow "differ[s] from production" | Current (written 2026-07-13) | **Test designation** | High as a statement of intent at the time; not proof of today's role |
| E-7 | Supabase metadata | project name | `stagerz-foundation-v2-test` | Current | Test designation | High as a label; labels can lag reality |
| E-8 | Migration `20260712100630` | header | "Applied to disposable test project … only" | Historical (2026-07-12) | Test designation | High for original intent |
| E-9 | Git history | commit `24609a8` | Frontend switched from `edxicnafggnnvcdvxemk` to `kbnmkyvbwkuvcklywdhk`, 2 lines | Historical | **Legacy environment exists** | High — exact diff |
| E-10 | Supabase account | project list | Second project "stagerz-app", healthy, unused by the app | Current | Legacy environment | High for existence; content unknown |
| E-11 | Aggregate data | `auth.*`, `public.*`, `storage.*` | 23/27 auth accounts synthetic; 4 genuine; 2 genuine content authors; content mostly in the build window | Current | **Test-like data**, low live usage | Medium–high; counts only; cannot identify who the 4 accounts are |
| E-12 | `PROJECT_CONTEXT.md` | Phases 21.6–21.8B | "COMPLETE IN PRODUCTION" for work on this project | Historical records | Operational production role | Medium — the label reflects the domain served, not a verified environment designation |
| E-13 | `PROJECT_CONTEXT.md` / O-1–O-3 and R-5 records | status rows | Same project called "test project" | Historical records | Test designation | Medium — inherited label |
| E-14 | Phase 21.2 record | N-7, P-1…P-7 | "the live project `kbnmkyvbwkuvcklywdhk`"; production validation on `stagerz.app` | Historical | Live wiring | High for wiring |
| E-15 | Phase 21.5 record | §"reasons to keep" item 3 | A formal 24-case security suite was run against it, "not how a purely disposable project gets treated" | Historical | Operational importance | Medium — inference by a prior phase |
| E-16 | Repository config | all history | No env, build or Supabase CLI config ever committed | Current and historical | No override, no staging split | High |
| E-17 | Edge Functions / migrations | Supabase plus repo | All backend engineering since 2026-07-12 targets this project | Current | The project is the working backend | High |
| E-18 | Auth configuration | — | Site URL, allow-list, template, SMTP not observed | — | UNKNOWN | Not accessible read-only with the available tooling |
| E-19 | Owner testimony | §2A, O-1 … O-5 | Created as a disposable Free-plan test project for Foundation v2; `edxicnafggnnvcdvxemk` then regarded as production; live role acquired without a formal decision | Historical intent, stated 2026-09-19 | **Test designation + de facto live role**; legacy project was designated production | High for intent (the owner is the authority); consistent with E-6 … E-10 and E-17 |
| E-20 | Owner testimony | §2A, O-6 | All 4 genuine accounts are owner-created test accounts | Current | **No known external users** | High for account ownership; not verifiable from data without reading personal data |
| E-21 | Legacy catalog | §2B L-2, L-3 | No migration history; Telegram-era v1 schema (bigint user IDs); 6 tables | Current | **Legacy, incompatible with the current app** | High — catalog |
| E-22 | Legacy aggregates | §2B L-4, L-5, L-6 | 3 users and 5 posts (2026-06-25), 2 auth accounts (2026-07-12); **no activity after 2026-07-12**; no Storage | Current | **Dormant since before the switch** | High — counts only; data ownership unknown |
| E-23 | Legacy access posture | §2B L-7, L-8 | `anon` holds full grants; all policies `true`; Advisor silent on it | Current | **Public read/write exposure (LG-1)** | High — catalog; not exercised |
| E-24 | Legacy key status | §2B L-10 | Enabled legacy anon key has the same claims as the key in public git history | Current | **Exposure is live** | High — claim comparison; key not used |

---

## 4. Classification

### **C — MIXED / LEGACY ENVIRONMENT** (proposed; accepted by the owner 2026-09-19)

**Strongest evidence:**
1. **It is functionally the production backend.** Every public surface — `stagerz.app` on GitHub Pages and the Netlify production deploy — is built from `main` and calls only `kbnmkyvbwkuvcklywdhk` with its active key. No override or alternative exists (E-1 … E-5, E-16).
2. **By creation, name and code labels it is a test environment.** It is named `stagerz-foundation-v2-test`, its first migration calls it "disposable test project … only", and the app still says "TEST ONLY" (E-6 … E-8).
3. **Its data looks like a development environment.** 23 of 27 accounts are synthetic, the seed profiles are fictional, only 2 genuine accounts ever authored content, and activity follows development and validation dates (E-11).
4. **A legacy environment exists alongside it.** The original project "stagerz-app" is still active and healthy, but has been detached from the frontend since 2026-07-13 (E-9, E-10).

**Why not A (confirmed production):** no evidence of a production designation or intent; no evidence of external users; the project's own name and migration header say "test".

**Why not B (confirmed test/development):** it is not isolated. It is the live backend of the production domain, reachable by anyone who opens `stagerz.app`. Genuine sign-ups exist, and this repository has repeatedly validated "in production" against it.

**Why not D (insufficient evidence):** the wiring, history, naming and data composition are established well enough to describe what the environment *is*. What remains unknown concerns intent and configuration, not classification.

**Confidence (as first proposed):**
- **High** that the live frontend uses only this project, that it was created as a test/foundation project, and that a second legacy project exists.
- **Medium** on the practical impact, because who owns the 4 genuine accounts, the Auth configuration and the role of "stagerz-app" were unknown.

### Reassessment after owner evidence (§2A) — C remains correct

The owner evidence **does not move the classification to A or B**. It confirms each half of "mixed":

- **Why still not A.** The owner confirms the project was created as a disposable test project, was never formally designated production, and holds no known external user. There is no production designation and no production data.
- **Why still not B.** Test intent and test-only data are now confirmed, but the environment is **not isolated**. It is the only backend of every public production surface: anyone who signs up at `stagerz.app` creates a real account in it, and every schema change applied there is live. A confirmed test environment would, by definition, not serve the production domain.
- **The "legacy" half is now stronger, not weaker.** `edxicnafggnnvcdvxemk` was the **designated production project** (O-3) and has been detached from the frontend since 2026-07-13. So the account holds a formerly-designated production project that serves nothing, and a test project that serves production.

**Refined statement of class C:** *a disposable test environment that has acquired a de facto production role by drift (not by decision) and currently contains only test, seed and synthetic data; alongside a detached, formerly designated production project of unknown content.*

**Confidence now:**
- **High** on the classification itself: wiring, history, intent (owner-confirmed) and the absence of known external users on `kbnmkyvbwkuvcklywdhk`.
- **Medium** only for the legacy half, whose contents are unobserved.

### Unresolved unknowns (after owner evidence)

1. ~~Owner intent at creation~~ — **resolved** (O-1 … O-5): created as a disposable test project; live role acquired without a decision. The **forward decision** — designate this project as production, or replace it — is still open. It is a product decision, not an evidence gap.
2. ~~Whether any genuine account belongs to an external user~~ — **resolved** (O-6): all four are owner test accounts.
3. **Auth configuration:** site URL, redirect allow-list, email template, SMTP, rate limits. Still unobserved.
4. **Plan tier: Free (O-1).** The backup / point-in-time-recovery posture is still unverified.
5. ~~Contents, exposure and intended role of `edxicnafggnnvcdvxemk`~~ — **contents and exposure resolved** by the authorized read-only inspection (§2B):
   - a dormant Telegram-era v1 project with 3 users, 5 posts and 2 auth accounts;
   - no activity after 2026-07-12;
   - publicly readable and writable through a still-valid anon key in public git history (LG-1).

   ~~Whose data the 3 `users` rows and 2 auth accounts hold~~ — **resolved (O-7): STAGERZ tester data.** **Still open:** the disposition decision (§2B options), carried to the follow-up containment phase (§8).

### Consequences for later STAGERZ work

- **Every backend change is a live change.** Migrations applied to `kbnmkyvbwkuvcklywdhk` take effect for the production domain immediately. Phases that called it the "test project" were, in operational terms, changing the live backend.
- **There is no test environment.** Nothing isolates experiments, validation fixtures or synthetic data from the production surface. The rollback-only validation technique used in Phases 21.3 and backend-integrity is currently the only safety mechanism.
- **Labels are misleading in both directions.** The code tells users "TEST ONLY", while governance records say "IN PRODUCTION". Documentation should state the adopted answer once the owner decides.
- **Recoverability remains weak.** There is no in-repo migration chain; the Phase 21.3 snapshots describe the schema but are not a runnable chain; Phases 21.4–21.7 were applied outside the migration history.

### Legacy project `edxicnafggnnvcdvxemk` — why inspecting it would materially improve the conclusion

**Performed 2026-09-19 under owner authorization. Results are in §2B.** The rationale below is kept as written when it was proposed.

The legacy half of class C is the only part still unobserved. Three concrete reasons make it material:

1. **It was the designated production project (O-3), and it is still ACTIVE_HEALTHY.** If it holds real users or content from 2026-06-25 to 2026-07-13, those users' data has been stranded since the frontend switch. That creates retention and deletion decisions, and it changes whether "designate `kbnmkyvbwkuvcklywdhk` as production" is the whole answer.
2. **Its client credential is public.** The git history of this repository, which is public according to the Netlify deploy record, contains `edxicnafggnnvcdvxemk`'s legacy **`anon`** JWT, in 6 commits on `main` before `24609a8`. Its non-secret claims are `role: anon`, `ref: edxicnafggnnvcdvxemk`, expiry **2036-06-25**. Unless that project's legacy keys have since been disabled or its JWT secret rotated, anyone can query its REST API as `anon`. Whatever its grants and RLS allow `anon` to reach is therefore potentially public today. Only an inspection can say whether that is harmless (empty, or properly restricted) or a live exposure of the formerly-production data.
3. **It decides between the forward options** in §5: re-adopt, archive, or delete.

It would **not** change the classification of `kbnmkyvbwkuvcklywdhk` itself, which is already established.

**Proposed read-only inspection.** Same privacy rules as this report: counts, dates, categories and configuration metadata only; no emails, IDs, names or content; no writes.

| # | Check | Tool / method | Answers |
|---|---|---|---|
| L-1 | Project metadata (status, version, region, created) | `get_project` | Confirms identity; already partly known from `list_projects` |
| L-2 | Migration history: count, names, first/last version and date | `list_migrations` | Which schema lineage it carries; whether work stopped on 2026-07-12/13 |
| L-3 | Table inventory with row counts, per schema | `list_tables` or aggregate `SELECT count(*)` | How much data exists and where |
| L-4 | `auth.users` aggregates: total, created date range, provider split, confirmed, ever signed in, last sign-in date, count on test/example domains | aggregate `SELECT` | Whether real users existed, and when activity stopped |
| L-5 | Application content aggregates: per table total, first/last `created_at` | aggregate `SELECT` | Whether real content exists; the last write date versus the 2026-07-13 switch |
| L-6 | Storage: bucket names, `public` flag, object counts, total bytes, date range | aggregate `SELECT` on `storage.*` | Whether user files exist; public-bucket exposure |
| L-7 | Anonymous exposure: `anon`/`authenticated` table and column privileges, RLS enabled / forced, policy count per table | catalog `SELECT` (the Phase 21.3 grants/RLS extraction method) | What the publicly known `anon` key can reach |
| L-8 | Security and performance Advisor | `get_advisors` (read) | Platform-flagged exposures |
| L-9 | Edge Functions: names, versions, dates | `list_edge_functions` | Whether anything still runs there |
| L-10 | Whether the legacy `anon` JWT and any publishable keys are still enabled | `get_publishable_keys` (compare, never record) | Whether the public key in git history is still live |

**Explicitly excluded:**
- calling the project's REST API with the public key (that would *use* the exposure, not inspect it);
- any write, key rotation or disabling;
- any data export;
- reading row content.

Any remediation — rotating or disabling keys, restricting grants, archiving or deleting the project — would be its own separately approved phase.

---

## 5. Implications (investigation only — nothing performed)

**Update after owner evidence:** `kbnmkyvbwkuvcklywdhk` holds **no known external-user data**: 23 synthetic accounts, 4 owner test accounts and 5 fictional seed profiles. Either forward path therefore carries **no user-data migration burden from this project**. The open data question has moved entirely to `edxicnafggnnvcdvxemk`.

Because the class is **C**, the problem is one of **separation and designation**. Each option below would be its own approved phase:

1. **Designate `kbnmkyvbwkuvcklywdhk` as production.**
   - Correct the "TEST ONLY" copy and comments in `index.html`.
   - Record the designation in `PROJECT_CONTEXT.md`.
   - Review production hardening: custom SMTP or OTP template, the leaked-password warning, backups/PITR, plan tier.
   - Decide what happens to the 23 synthetic accounts and the fixture content.
   - Create a **separate** test/development project for future validation.
2. **Establish a new, clean production project and migrate.**
   - Requires a reproducible schema: the Phase 21.3 snapshots plus a new runnable migration chain, since the current history is incomplete.
   - Requires a user and data migration decision for the 4 genuine accounts and their content and Storage objects.
   - Requires a frontend switch, like commit `24609a8`, with Auth reconfiguration.
3. **Resolve the legacy project** `edxicnafggnnvcdvxemk`: inspect under approval, then decide whether to archive, delete or re-adopt it. Until then, its existence means backups and billing cover two environments.

The data needed before choosing is exactly the list of unresolved unknowns above.

---

## 6. Items deliberately kept out of Phase 22.0

These were not examined for remediation and do not change the classification:

| Item | Status |
|---|---|
| 2 `collaboration_assets` rows whose Storage objects are missing | open data-integrity item |
| legacy pre-collaboration `accepted` applications | open |
| notification → Applicants routing | open |
| absent Content-Security-Policy | open |
| optional R-5 follow-ups (`status='open'` hardening, legacy `users` columns, avatar design, shared `'New Artist'` literal) | optional |
| remaining Phase 20.7 roadmap items | unscheduled |

---

## 7. Read-only activity log

| Action | Detail |
|---|---|
| Repository | `git grep` / `git log` across the tree and all 292 commits; no file modified except this phase's documents and `PROJECT_CONTEXT.md` |
| HTTP | 2 × `GET` of public pages |
| DNS | 2 × `nslookup` |
| Supabase | `list_projects`; `get_project` (`kbnmkyvbwkuvcklywdhk`); `list_edge_functions`; `get_publishable_keys` (compared only); 4 aggregate read-only `SELECT`s (markers `P220-ENV-v1`, `P220-ACTIVITY-v1`, `P220-MIGR-v1`, `P220-SEED-v1`). Two earlier attempts of the first `SELECT` failed with a null-key error and read nothing. |
| Netlify | `get-projects`, `get-project`, `get-deploy-for-site` — read-only |
| Legacy inspection (authorized 2026-09-19, read-only) | `get_project`, `list_migrations`, `list_edge_functions`, `get_advisors` (security, performance) and `get_publishable_keys` (claims compared, values not recorded) on `edxicnafggnnvcdvxemk`. 3 catalog/aggregate `SELECT`s (`P220-LEGACY-CATALOG-v1`, `P220-LEGACY-COLS-v1`, `P220-LEGACY-DATA-v1`). One earlier attempt of the catalog query failed because `supabase_migrations` does not exist, and read nothing. One local `git show` + base64 decode of the historical key's non-secret claims. |
| Not done | any write on either project; any API call using any key; any Auth-configuration read; any data export; reading row content beyond category tests |

---

## 8. Phase 22.0 closeout — COMPLETE / PASS (2026-09-19)

**Result: COMPLETE / PASS. Classification: C — MIXED / LEGACY ENVIRONMENT (owner-accepted).**

PASS records that the investigation objective was achieved: the question Phase 22.0 was created to answer (H-1 / R-4) now has an evidence-backed answer. It is **not** an acceptance of the current environment architecture, and it **does not** resolve any finding listed below.

### 8.1 Established conclusion

1. **`edxicnafggnnvcdvxemk` ("stagerz-app"):**
   - the former **Telegram-era STAGERZ backend** (O-8), formerly treated as production (O-3);
   - now **detached and dormant**: no frontend reference since 2026-07-13, no activity since 2026-07-12;
   - on an **incompatible legacy v1 schema**;
   - holds **tester / development data only** (O-7);
   - **no observable current STAGERZ dependency**;
   - still carries **LG-1** (public read/write through a valid anon key in public git history) and **LG-2 … LG-5**.
2. **`kbnmkyvbwkuvcklywdhk` ("stagerz-foundation-v2-test"):**
   - intentionally created as a **disposable Foundation v2 test environment** (O-1, O-2, O-4);
   - later became the backend of the public standalone STAGERZ frontend **by drift, not by formal designation** (O-5);
   - holds **seed, synthetic and tester data** with no known external users (O-6);
   - currently performs the **de facto live backend role**.
3. **No known external-user accounts or data exist in either environment** (O-6, O-7).
4. **The current architecture is not accepted as a long-term state.** Production/test separation, and the designation of a production environment, still need a **deliberate future decision** (see the §5 options).
5. **Telegram is not ruled out as a future direction** (O-9). Nothing in this phase, or in a follow-up that contains the legacy project, is a decision against future Telegram integration.

### 8.2 Exit criteria (phase-definition.md §6)

| # | Criterion | Result |
|---|---|---|
| 1 | Q1–Q9 answered with cited evidence, or marked UNKNOWN with a reason | **MET** — Q1–Q6 and Q8 established; Q7 partly established, with the remaining Auth-configuration items marked UNKNOWN and the reason given; Q9 answered by the classification |
| 2 | Evidence matrix with source, location, status, direction and reliability | **MET** — E-1 … E-24 (§3) |
| 3 | Exactly one class proposed, with strongest and contradicting evidence, unknowns and confidence | **MET** — class C (§4) |
| 4 | Implications described, not performed | **MET** — §4 consequences, §5 options, §2B disposition options |
| 5 | No Supabase, Netlify or application mutation; no secret or personal data recorded | **MET** — see the activity log (§7) and the privacy scan at closeout |
| 6 | Owner review and acceptance; `PROJECT_CONTEXT.md` updated to the accepted answer | **MET** — classification accepted 2026-09-19; `PROJECT_CONTEXT.md` updated in this closeout |

### 8.3 Remaining UNKNOWN items (non-blocking)

- `kbnmkyvbwkuvcklywdhk` Auth configuration: site URL, redirect allow-list, email template, SMTP, rate limits.
- Backup / point-in-time-recovery posture of `kbnmkyvbwkuvcklywdhk` (plan: Free, per O-1).
- References to `edxicnafggnnvcdvxemk` outside this repository (not observable here).

None of these affects the classification.

### 8.4 OPEN findings carried forward — **not remediated in Phase 22.0**

| ID | Finding | Severity | Status |
|---|---|---|---|
| **LG-1** | `edxicnafggnnvcdvxemk` publicly readable and writable through a still-valid anon key published in public git history | **Medium** | **OPEN** — priority for the immediate follow-up |
| **LG-2** | `postgres` default privileges in `public`/`storage` grant everything to `anon`/`authenticated` on `edxicnafggnnvcdvxemk` | Low (latent) | **OPEN** |
| **LG-3** | `TRUNCATE` granted to `anon`/`authenticated` on all `edxicnafggnnvcdvxemk` tables | Low (latent) | **OPEN** |
| **LG-4** | `rls_auto_enable()` executable by `anon`/`authenticated` on `edxicnafggnnvcdvxemk` | Low | **OPEN** |
| **LG-5** | Leaked-password protection disabled on `edxicnafggnnvcdvxemk` (the same warning exists on `kbnmkyvbwkuvcklywdhk`) | Low | **OPEN** |
| — | Production/test separation and production designation | Architecture decision | **OPEN** — needs a future decision |
| — | "TEST ONLY — disposable" labels in `index.html`, contradicting the de facto live role | Documentation / UX | **OPEN** — to be settled together with the designation decision |

**Unrelated items, unchanged and outside Phase 22.0:**
- the **2 `collaboration_assets` rows whose Storage objects are missing** — an open data-integrity item, **OPEN**;
- the legacy pre-collaboration `accepted` applications;
- notification → Applicants routing;
- the absent Content-Security-Policy;
- the optional R-5 follow-ups;
- the remaining Phase 20.7 roadmap items.

### 8.5 Immediate recommended follow-up (not numbered, not branched, not started)

**A separately scoped legacy-project containment / security phase for `edxicnafggnnvcdvxemk`**, primarily addressing **LG-1** and the related legacy access exposure (LG-2 … LG-5).

- **Starting point:** the §2B disposition options (lock down in place, pause, private export then data or project deletion). The choice is the owner's, made within that phase.
- **Scope boundary:** that phase concerns the legacy project's exposure and tester data. It must **not** be read as a decision about Telegram as a product direction (O-9), and it must **not** touch `kbnmkyvbwkuvcklywdhk`, the live application or Netlify unless its own approved scope says so.
- **Numbering, branch and plan** are to be assigned when the phase is authorized.
