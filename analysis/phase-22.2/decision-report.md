# Phase 22.2 — Production / Test Environment Decision Report

**Status:** **COMPLETE / PASS (2026-09-19). OWNER DECISION: OPTION A — APPROVED** (§11).
- PASS means the production/test architecture decision has been made and documented.
- It does **not** mean production-readiness hardening is complete.
- Nothing was implemented, and no environment change occurred.
- The sections below are the decision package as reviewed.
**Prepared:** 2026-09-19, branch `phase-22.2-production-test-environment-decision` @ `f423e59`.

**Evidence labels used in this document:**
- **[F]** = fact, with its source;
- **[D]** = Supabase documentation (read 2026-09-19);
- **[J]** = engineering judgment;
- **UNKNOWN** = not observable with the read-only tooling.

---

## 0. Answer in brief

**[J] Recommendation: Option A — formally designate `kbnmkyvbwkuvcklywdhk` as production.** Do it in this order:
1. first, make the backend **reproducible from the repository** (a schema baseline);
2. then create the test/development environment from that baseline;
3. before any real external user is invited, close the production-hardening gaps (custom SMTP, a backup strategy, captured Auth configuration).

**Why A:**
- The live project already *is* the only complete, security-validated instance of the backend.
- Much of that security state (Phases 21.4–21.7) exists **only in the live database**, not in any runnable migration chain.
- A clean rebuild (Option B) is not possible today without first doing the same reproducibility work. It would add a risky cutover whose main benefit is a clean name and clean data.
- Having no external users makes that benefit cheap to obtain later, if the owner still wants it.

**Strongest argument against A** (§7): production would inherit test-era history — synthetic accounts, fictional seed content, test uploads, a misleading project name, and a migration history that does not reproduce the schema. Option B's forced rebuild would prove reproducibility end-to-end, and it is cheapest **now**, while no real user exists.

**Is the decision blocking foundation completion?** **Important but deferrable** as a *label*. The **test environment / reproducibility** part is near-blocking for further **backend or schema** work, and production hardening is **blocking before real external users** (§8).

---

## 1. Current environment facts

| Fact | Evidence |
|---|---|
| Frontend backend is hard-coded: `SUPA_URL` = `kbnmkyvbwkuvcklywdhk`; publishable key constant; `createClient` with no options | [F] `index.html:1013-1014, 1037` |
| **No environment switching**: no hostname or query checks, no build step, no config file | [F] `index.html` (survey); `analysis/phase-22.0/investigation-report.md:43-48` |
| Hosting: `stagerz.app` apex on GitHub Pages (`CNAME`), plus Netlify site `aquamarine-puppy-beccd9` (primary URL `https://stagerz.app`), both built from `main`; Netlify PR previews call the same backend | [F] `CNAME`; `.apos/PROJECT_CONTEXT.md:67-71`; Netlify metadata (current deploy `6aae826b…`, ready) |
| Only redirect in the app: `emailRedirectTo: 'https://stagerz.app'` (magic-link / OTP sign-in, `shouldCreateUser: true`) | [F] `index.html:1423` |
| `kbnmkyvbwkuvcklywdhk`: name `stagerz-foundation-v2-test`, ACTIVE_HEALTHY, PG 17.6.1.141, `eu-north-1`, created 2026-07-12 | [F] `get_project` |
| Organisation `STAGERZ`: **Free plan**; **2 active projects** (`kbnmkyvbwkuvcklywdhk` and the contained legacy `edxicnafggnnvcdvxemk`) | [F] `get_organization`; `get_project` ×2 |
| Backend size: 14 MB database; 17 public tables, 1 view, 34 functions, 21 public policies; 3 public triggers and 1 `auth` trigger (`on_auth_user_created`); 1 private bucket, 2 storage policies; 5 tables in `supabase_realtime`; extensions pgcrypto, uuid-ossp, pg_stat_statements, supabase_vault; no pg_cron; 0 Vault secrets; 43 migrations | [F] `P222-PROFILE-v1` (aggregates) |
| Data: 27 `auth.users` (4 with an email identity, and confirmed = the owner's test accounts; 23 synthetic without identities); 32 `users`/`profiles` (including 5 fictional seed profiles); 25 wanted posts; 11 collaborations; 15 asset rows / 13 Storage objects (~15 MB; the 2 missing objects are the known open item); last sign-in 2026-08-24 | [F] `P222-PROFILE-v1`; Phase 22.0 O-6 |
| Edge Functions: `delete-account` v8, `process-pending-deletions` v9, `process-pending-asset-deletions` v11, `reap-orphaned-collaboration-assets` v4; **all `verify_jwt: false`** (each does its own auth) | [F] `list_edge_functions`; `analysis/phase-21.8a/phase-definition.md:83,91` |
| Scheduler: one GitHub Actions workflow, daily 03:17 UTC plus manual dispatch, POSTs to the `kbnmkyvbwkuvcklywdhk` function URL with secret `STAGERZ_MAINTENANCE_SECRET` | [F] `.github/workflows/process-pending-asset-deletions.yml:24-27,44-45` |
| Security Advisor: 1 ERROR (`security_definer_view` on `public_profiles`, the known accepted S-1 design), 26 WARN (25 authenticated-executable SECURITY DEFINER RPCs, which are the app's designed API, plus leaked-password protection), 2 INFO (RLS without policies on the two service-only queue tables) | [F] `get_advisors` 2026-09-19 |
| Auth configuration (site URL, redirect allow-list, SMTP, templates, rate limits, sign-up setting) | **UNKNOWN**: not readable by tooling; `analysis/phase-21.3/backend-contract.md:743` |
| Legacy `edxicnafggnnvcdvxemk`: Phase 22.1 state intact (6 deny policies / 24; ACL fingerprint `c719d075…`; 0 client default privileges; `rls_auto_enable()` restricted; legacy key `disabled: true`; counts 3/5/0/0/0/0, Auth 2/2, Storage 0/0) | [F] `P222-LEGACY-INTACT-v1`, `get_publishable_keys` (state only) |

**Platform facts:**
- **[D]** Free projects are **paused after 7 days of low activity**; paid projects are never paused.
- **[D]** **Daily backups exist only on Pro and higher** (7 days on Pro). Free projects are advised to make their own `db dump`. PITR is a Pro+ add-on (~$100/month for 7 days) and needs at least Small compute.
- **[D]** The **default SMTP only delivers to organisation team members**, is rate-limited and is "not meant for production". Custom SMTP is required for all other recipients.
- **[D]** Free plan: **2 active free projects** per owner/admin, counted across organisations; paused projects don't count.
- **[D]** Pro: $25/month per organisation, including $10 compute credit; each additional project on Micro is ~$10/month. Branching is billed by usage (Micro branch from $0.01344/hour).
- **[D]** Leaked-password protection is available on Pro and higher.

---

## 2. Answers D-1 … D-15

### D-1 — What would change if `kbnmkyvbwkuvcklywdhk` were formally designated production?

**Technically: nothing has to change for the app to keep working.** It is already the live backend. The designation changes documentation, labels and obligations:

1. **Documentation:**
   - Record the designation in `.apos/PROJECT_CONTEXT.md`, replacing the "classification C / by drift" wording and the open question at `:298`.
   - Stop calling it the "test project" in new records. Historical records stay as they are.
2. **Labels:** reword the "TEST ONLY / disposable project" code comments (`index.html:330-332, 1403-1410, 1440`, see D-2). The project **name** is a dashboard setting; the project **ref** `kbnmkyvbwkuvcklywdhk` is permanent and stays in every URL. **[J]** Renaming is cosmetic but removes the most visible contradiction.
3. **Operating rules that follow from "production":**
   - every schema change needs a rehearsal target that is not production, which does not exist today (D-4);
   - a backup strategy (D-3);
   - Auth configuration becomes something to record and change-control.
4. **Data policy:** decide whether the synthetic, seed and test data stays or is cleaned before real users (D-14). Cleanup would be its own approved phase.
5. **Hardening before real users (D-3):** custom SMTP is a hard prerequisite for any non-team user to sign in at all.

### D-2 — Misleading test-only labels and assumptions

| Location | Text (short) | Kind |
|---|---|---|
| `index.html:330-332` | "AUTH: MAGIC LINK WAIT (TEST ONLY -- disposable project's hosted email template …)" | HTML comment (not user-visible) |
| `index.html:1403-1410` | "AUTH: EMAIL MAGIC LINK (TEST ONLY)", "The disposable test project's hosted email template …", "only the post-send UI … differ from production" | JS comment |
| `index.html:1440` | "verifyOtpCode() removed in the test version" | JS comment |
| Supabase project name | `stagerz-foundation-v2-test` | Dashboard metadata; appears in every analysis header ("(stagerz-foundation-v2-test)") |
| `.apos/PROJECT_CONTEXT.md:16-17, 185, 298` | "test project only", "production / test status is not established", the open question quoting "disposable test project" (with stale line refs 307–310 and 1218–1225; now 330 and 1403) | Docs |
| `analysis/phase-21.4|21.5|21.7/migration.sql:18-21` versus `PROJECT_CONTEXT.md:24-27` | "the ONLY permitted production mutation" / "COMPLETE IN PRODUCTION" versus "test project" | Docs contradict each other (Phase 22.0 §4: "misleading in both directions") |
| `analysis/backend-integrity-remediation/migration.sql` and `analysis/phase-21.3-r5-remediation/migration.sql` headers | "PREPARED, NOT APPLIED", although both were applied (migrations `20260916215204`, `20260917143322`) | Stale headers |
| `PROJECT_CONTEXT.md:71`, `backend-contract.md:272` | cite `index.html:1329` for `emailRedirectTo` (now `:1423`) | Stale line references |

- **User-visible UI:** no string says test, demo or beta. The demo card text at `index.html:1815-1816, 2010` is local UI demo content, not a backend label.
- **Assumption embedded in code** [F]: the magic-link flow is built around the **hosted default email template and default SMTP** (`index.html:330-332, 1404-1406`). That is the part that is genuinely test-grade (D-3).

### D-3 — Production-hardening items that remain (under either option)

| Item | State | Needed for production? |
|---|---|---|
| **SMTP / email** | Default SMTP (implied by `index.html:330-332`; custom SMTP not configured) | **Yes, blocking before real users.** [D] The default SMTP refuses non-team addresses, so magic-link sign-in cannot work for any external user. Needs a custom SMTP provider and ideally SPF/DKIM/DMARC on a sending domain |
| **Auth configuration** (site URL, redirect allow-list, sign-up setting, OTP expiry, rate limits, CAPTCHA) | **UNKNOWN** | Yes: read and record it (owner dashboard), then change-control it. [D] CAPTCHA is the recommended anti-abuse control once email sending is open |
| **Redirect URLs** | App sends users to `https://stagerz.app`; the allow-list is UNKNOWN; Netlify previews and `www` resolve elsewhere | Confirm the allow-list contains exactly the intended origins |
| **Leaked-password protection** | Disabled (WARN); Pro-only [D] | **[J] Low relevance:** the app uses passwordless magic links (`index.html:1423`). It matters only if password sign-in is enabled at the Auth level (UNKNOWN). Enable on upgrade to Pro, or accept |
| **Backup / PITR** | **None on Free** [D] | Yes. Either Pro (7 daily backups), or a scheduled off-site `db dump` (the CLI needs an access token and the database password; the local `db dump` normally runs in Docker, which is not installed). Storage objects are **not** in database backups [D] and need a separate plan |
| **Free-plan constraints** | 7-day inactivity pause [D]; 500 MB database / 1 GB Storage / 5 GB egress quotas [D]; 2 active free projects | [J] The daily GitHub Actions call probably keeps the project active (not guaranteed). A pause of production is an availability risk; Pro removes it |
| **Monitoring** | None configured in the repo; the platform logs and Advisor exist | Minimum: scheduled Advisor review plus alerting on workflow failure. Log drains are a paid add-on |
| **Key model** | Frontend uses a publishable key [F]; legacy JWT key state on the live project not examined in this phase; functions use `SUPABASE_SERVICE_ROLE_KEY` via environment variables | Confirm whether the legacy JWT keys of the live project are still needed, and plan to disable them. The workflow secret and function secrets live outside the repo (correct) but are undocumented as an inventory |
| **Test strategy** | Validation today runs against the live project via rollback-only probes (Phases 21.x) | A non-production rehearsal target is needed (D-4); rollback-only probes remain a good pattern for production verification |
| **Known Advisor items** | 1 ERROR (accepted S-1 view design), 25 WARN (designed RPC surface), 2 INFO (designed) | Documented and accepted in Phases 21.x; review again before launch |
| **Open data-integrity item** | 2 `collaboration_assets` rows without Storage objects | Resolve or accept before production data matters |

### D-4 — Can a test environment be reproduced from the repository today?

**No.** A faithful copy cannot be rebuilt from the repository alone.

| Component | In the repo? | Runnable? |
|---|---|---|
| Schema, functions, triggers, policies, grants | Yes, as **descriptive snapshots** (`analysis/phase-21.3/*.sql`, all six marked "DESCRIPTIVE SNAPSHOT — NOT A MIGRATION … must never be executed", 0 executable lines) plus `backend-contract.md` | **No** |
| Migration chain | Only 2 of 43 migrations have SQL in the repo (`20260916215204`, `20260917143322`). The 41 earlier ones exist only as names in comments (`schema.sql:971-1018`). Phases 21.4–21.7 were applied with `execute_sql` and are **not in the migration history** at all | **No.** `backend-contract.md:754-766` states that replaying history would **not** reproduce the backend |
| Seeds | None. Seed content exists only inside the live migration `web_identity_seed` | **No** |
| Edge Functions | Yes, source for all 4 (`supabase/functions/**`) | **Yes**, deployable. `verify_jwt: false` is recorded only in docs (no `config.toml`) |
| Secrets / config | Names only: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `STAGERZ_ALLOWED_ORIGIN`, `STAGERZ_MAINTENANCE_SECRET`, `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED`; values correctly not in the repo | Must be set by hand |
| Storage setup | Described only (`storage-policies.sql`, 1 private bucket, 2 policies) | **No** |
| Auth config | Not captured (`backend-contract.md:743`) | **No** |
| Realtime publication | Described (5 tables) | **No** |

**[J] What would make it reproducible** (a future phase, not done here):
- a **schema baseline** generated from the live project (for example `supabase db dump`, or a catalog-driven generator like the Phase 21.3 one, emitting executable DDL);
- verified by building a fresh environment from it and comparing catalog fingerprints with production (the Phase 21.3 verifier already produces such fingerprints);
- plus a seed script and an Auth/Storage/secrets runbook.

This is the **common prerequisite of Option B and of any good test environment under Option A.**

- **[F] No frontend test switch:** because `SUPA_URL` is hard-coded and there is no build step, the frontend can point at a test backend only by editing `index.html` (and merging to `main` deploys to production). A test frontend needs either a hostname-based selection in `index.html` or a separate deploy. That is a design item for the test-environment phase.

### D-5 — What a new production project (Option B) would require

1. **Project creation.** [D] On Free, the organisation is at its 2-active-project limit, so it needs **either** pausing/deleting the legacy project (the separate disposition decision) **or** Pro.
2. **Schema:** executable baseline DDL for 17 tables, 1 view (`security_invoker` choice, S-1), 34 SECURITY DEFINER functions, 3+1 triggers (including `auth.users` → `handle_new_auth_user`), 21 RLS policies, and exact table/column/function grants.
   - Includes the hardened privileges of S-5/S-6/S-7 and the R-5 fixes: default ACLs, `MAINTAIN` revocations, `EXECUTE` revocations on trigger functions.
   - Plus the `supabase_realtime` membership (5 tables) and 4 extensions.
   - **[J] This is the highest-risk step:** the project's history (S-1 … S-7, R-5) shows how easily privilege drift arises.
3. **Storage:** create the private `collaboration-assets` bucket and its 2 policies. Objects: 13 (~15 MB) of test uploads. [J] Do not migrate them; start empty.
4. **Auth users:** 27 test accounts. [J] Do not migrate them. The owner recreates the 4 test accounts by signing in. That avoids hash, identity and `user_auth_accounts` mapping migration entirely.
5. **Application rows:** [J] none, apart from the intended seed content (if the 5 fictional seed profiles and posts are wanted in production, they need a seed script).
6. **Edge Functions:** deploy the 4 functions with `verify_jwt: false`.
7. **Secrets:**
   - set `STAGERZ_MAINTENANCE_SECRET` and `STAGERZ_ALLOWED_ORIGIN` (and `STAGERZ_ORPHAN_REAPER_DELETE_ENABLED` if used) in the new project;
   - update the GitHub Actions secret and the workflow's function URL (`.yml:45`).
8. **Auth configuration:** site URL, redirect allow-list (`https://stagerz.app`, plus others as decided), custom SMTP, templates, rate limits, sign-up setting — all of which are unknown on the current project, so they must first be read by the owner.
9. **Frontend switch:** change `SUPA_URL`/`SUPA_KEY` in `index.html` (2 constants), plus the documented localStorage key name. Merging to `main` switches both GitHub Pages and Netlify at once. All sessions end, because the storage key includes the project ref.
10. **Validation:**
    - catalog fingerprint comparison with the old project;
    - rollback-only behavioural probes (the Phase 21.x / 22.1 pattern);
    - an authenticated end-to-end regression (sign-in, profile, wanted, applications, collaborations, messages, tasks, uploads, credits, delete-account);
    - workflow dispatch;
    - Security Advisor parity.
11. **Rollback:** revert the `index.html` commit (both hosts redeploy), restore the workflow URL and secret. Keep `kbnmkyvbwkuvcklywdhk` untouched until the new project has run stably.

### D-6 — What migration burden disappears because there are no external users

- **Auth user migration** (password hashes, identities, the `user_auth_accounts` mapping, MFA): **gone**. Test accounts are simply recreated.
- **Data migration** of application rows, activity history, notifications and Storage objects: **gone**. Start clean, or with an intentional seed.
- **Downtime or cut-over windows:** gone. Forced logout is harmless.
- **User communication, re-consent, privacy obligations for the move:** gone.
- **Dual-running and data sync between old and new:** gone.

What **remains** under B: schema, privileges, functions, secrets, Auth config, Storage setup and validation — i.e. **the reproducibility work of D-4.**

### D-7 — Which option minimizes risk?

**[J] Option A.**
- It changes nothing that runs, and it keeps the only instance whose security state has been validated end-to-end.
- B's main risk is **silent privilege or behaviour drift** when rebuilding from a baseline. The documented S-1 … S-7 and R-5 history shows these defects are subtle and were found only by dedicated catalog and behavioural validation.
- B's cut-over risk itself is low, because there are no users.

### D-8 — Which option minimizes work/time?

**[J] Option A**, by a wide margin:
- the designation itself is a documentation change plus comment edits;
- hardening items (SMTP, backups, Auth config) are the same under both options;
- B adds the whole D-5 list on top.

### D-9 — Which option gives the cleanest long-term architecture?

**[J] Option B**, in the narrow sense: a production project with a proper name, clean data, and state created entirely from source control.

**However**, the long-term cleanliness that matters most — **reproducibility from the repository** — is the same work under both options. Once a baseline exists, A can reach nearly the same cleanliness by:
- renaming the project;
- a separately approved data cleanup;
- treating the baseline as the source of truth.

The permanent ref `kbnmkyvbwkuvcklywdhk` and the test-era migration history are the residue A cannot remove.

### D-10 — Which option best supports future development/testing?

**[J] Neutral between A and B.** Both need the same enablers:
- a reproducible baseline;
- a test environment built from it;
- a way to point a frontend at the test backend (D-4);
- the rule that schema changes are rehearsed there first.

B leaves the old project as a ready-made (but non-reproducible) test environment. A needs one created. With a baseline, either is straightforward.

### D-11 — Costs and paid-plan dependencies

Figures are Supabase documentation list prices, not quotes. **Exact costs for creating a project or branch require the organisation's cost confirmation, which was deliberately not queried.**

| Scenario | Plan need | Indicative cost [D] |
|---|---|---|
| A, production stays on Free | none | $0; no backups, inactivity pause possible, default SMTP unusable for real users (custom SMTP provider costs are external; UNKNOWN) |
| A plus production on Pro | Pro for the organisation | $25/month, including $10 compute credit, which covers one Micro project; **each additional active project in the organisation ~$10/month** (the legacy project, and any test project) |
| A plus test environment as a second **free** project | Free slot | Needs a free slot: pause or delete the legacy project first (disposition decision), because the organisation is at 2/2 |
| A plus test environment via **branching** | Pro | Usage-based, from $0.01344/hour per Micro branch; not covered by the spend cap [D] |
| A plus **local** test stack | none | $0 platform cost; needs Docker (not installed) and the CLI (installed, 2.117.0) |
| B on Free | Free slot for the new project | Needs a legacy pause or delete; production and test both without backups |
| B on Pro | Pro | ~$25 + (projects − 1) × $10 per month, e.g. ~$35 with new production plus `kbnm…` as test, ~$45 if the legacy project also stays active |
| PITR (optional) | Pro + Small compute | ~$100/month for 7 days, plus compute [D] |

### D-12 — Would GitHub Pages / Netlify need to change?

- **Under A:** no.
- **Under B:** hosting is unchanged; only the two constants in `index.html` change (deployed through the normal merge to `main`), plus the workflow URL and secret.
- **Under either:** two production surfaces serve `main` (GitHub Pages and Netlify), and Netlify PR previews call the production backend. **[J]** That duality, and a way to give previews or test builds a test backend, is a **separate** hosting decision that a test environment will force. It is independent of A versus B.

### D-13 — Effect on the future Telegram idea

**None directly.**
- Environment architecture (which project is production, how testing works) is independent of product integration.
- A future Telegram Light version would be built against whichever project is production, and would benefit from a test environment under either option.
- The legacy Telegram-era project is **not** a prerequisite (its v1 schema is incompatible), and its disposition does not constrain Telegram.
- Telegram remains a separate product decision and is not prohibited (`PROJECT_CONTEXT.md:18-19, 127, 154-168`).

### D-14 — What happens to current synthetic/test data?

- **Under A:** it stays in production (23 synthetic accounts, 5 fictional seed profiles and posts, test collaborations and uploads, 2 orphan asset rows) until a **separately approved cleanup phase** decides what to keep as seed and what to delete. **[J]** Do this before inviting real users. Some seed content may be intentionally desirable.
- **Under B:** the new production starts clean, plus an intentional seed. The data stays in `kbnmkyvbwkuvcklywdhk`, which becomes the test/development environment (useful realistic fixtures) or is later retired.

### D-15 — Reversible rollback path

**Option A:**
- The designation is documentation, reversible by editing docs.
- Comment and label edits are reverted with git.
- Hardening steps are individually reversible dashboard settings (SMTP, sign-up, CAPTCHA). A plan upgrade can be downgraded (Supabase grants credits; no refunds [D]).
- A later data cleanup would be **the only hard-to-reverse part**; it needs its own backup-first plan.

**Option B:**
- Revert the frontend commit to point back at `kbnmkyvbwkuvcklywdhk`, and restore the workflow URL and secret. Both are quick.
- Data written to the new project after the switch would be stranded; it is negligible without users.
- The old project must stay unchanged until the new one is proven.
- Deleting the new project is irreversible, but nothing depends on it at that point.

---

## 3. Option C?

**No materially different architecture is justified.** The real variation is **how the test environment is provided**, which is a sub-choice under A (and B):

| Test-environment variant | Pros | Cons |
|---|---|---|
| **T1 — local Supabase stack** (CLI plus Docker) built from the baseline | $0; no free-slot problem; fast resets | Docker not installed; not cloud-reachable for device or preview testing; Edge Functions and Auth emails behave differently locally |
| **T2 — second cloud project** (Free) built from the baseline | Realistic; shareable URL | Needs a free slot (legacy pause or delete) or Pro; manual sync |
| **T3 — Supabase branching** (Pro) | Integrated; ephemeral per PR | Pro plus usage cost; needs the migration-based workflow (a baseline in `supabase/migrations`) and the GitHub integration |

**[J]** Start with T1 or T2, whichever the owner prefers on cost. T3 becomes attractive only after a Pro upgrade and a migration-based workflow.

---

## 4. Decision matrix (qualitative)

| Dimension | Option A — designate `kbnm…` production | Option B — new clean production project |
|---|---|---|
| Implementation complexity | Low: docs, labels, hardening | High: full rebuild (D-5), plus the same hardening |
| Downtime risk | None | Low (no users); a forced logout at switch |
| Data migration complexity | None | None needed (start clean); optional seed script |
| Auth migration complexity | None | None needed (recreate 4 test accounts); Auth config must be re-entered, and it is currently UNKNOWN |
| Rollback difficulty | Trivial | Easy (revert one frontend commit and the workflow) while the old project is kept |
| Production cleanliness | Inherits test-era data, name and migration history (cleanable except ref and history) | Clean name, data and origin |
| Test-environment quality | Needs creating (baseline required) | Old project becomes a realistic but non-reproducible test environment immediately; a reproducible one still needs the baseline |
| Cost implications | $0 on Free; Pro recommended before real users (~$25/month plus ~$10 per extra active project) | Same Pro argument; plus a project slot problem on Free (legacy disposition) or an extra ~$10/month |
| Future maintenance | Good once a baseline exists; the permanent test-era ref and history remain | Good; starts from a source-controlled baseline |
| Time estimate [J] | Designation about 0.5 day; baseline and test environment about 2–4 days; hardening about 1–2 days (plus the owner's SMTP/domain setup) | Baseline 2–4 days, plus build, deploy and configure 1–2 days, plus validation and regression 1–2 days, plus hardening 1–2 days |
| Major failure modes | Production changed without a rehearsal target until the test environment exists; production paused (Free); no backups (Free); real users unable to sign in without custom SMTP | Privilege or behaviour drift in the rebuilt project (S-1 … S-7-type regressions); forgotten secrets or config (workflow, allowed origin, SMTP); Auth config mismatch breaking magic links |

---

## 5. Migration and reproduction readiness (summary)

| Element | Ready? |
|---|---|
| Edge Function source | ✅ in repo |
| Executable schema / privileges / policies | ❌ (snapshots only) |
| Migration chain | ❌ (2 of 43; plus 4 `execute_sql` phases outside history) |
| Seed | ❌ |
| Storage bucket and policy setup | ❌ (described only) |
| Auth config | ❌ UNKNOWN |
| Secrets inventory | ⚠️ names known from code; values correctly outside the repo |
| Frontend environment switching | ❌ (hard-coded) |
| Validation tooling | ✅ Phase 21.3 fingerprint verifier and rollback-only probe pattern exist |

## 6. Known blockers

- **B1:** no runnable baseline; this blocks B and blocks a faithful test environment.
- **B2:** default SMTP; this blocks real external users under either option.
- **B3:** Auth configuration UNKNOWN; needs owner dashboard capture.
- **B4:** Free-plan 2-project limit; this blocks a new cloud project (B, or test environment T2) until the legacy project is paused or deleted, or the organisation goes Pro.
- **B5:** no frontend environment switch; this blocks testing a frontend against a test backend without editing `index.html`.
- **Not blockers:** hosting (unchanged), Telegram (independent), Edge Function code (present).

## 7. Recommendation

**Facts** (§1): the live project is the only complete instance; its hardened state is partly outside any migration chain; there are no external users; the organisation is Free at 2/2 projects; the default SMTP cannot serve real users.

**[J] Recommendation: Option A**, sequenced:
1. **Designate** `kbnmkyvbwkuvcklywdhk` as production. Update the docs, reword the TEST ONLY comments, and optionally rename the project in the dashboard.
2. **Capture the unknowns** (owner, read-only): the Auth configuration and the legacy-key state of the live project.
3. **Build a reproducible baseline** from production (executable DDL, grants, policies, Storage, Realtime; plus a seed and a secrets/config runbook) and **prove it** by building a test environment (T1 or T2) and comparing fingerprints. This is also exactly what Option B would need, so it keeps B open.
4. **Production hardening before real users:** custom SMTP (plus SPF/DKIM/DMARC), a backup strategy (Pro, or scheduled dumps plus a Storage copy), a decision on Pro, CAPTCHA and rate limits, and a data-cleanup phase for synthetic content.
5. **Revisit B only if** the owner still wants a clean-origin production after step 3. At that point B is a low-risk rebuild from a proven baseline.

**Why:** it minimises risk and work now, it does not discard validated security state, and it keeps every later option open. The one piece of long-term value B forces — reproducibility — is scheduled explicitly instead.

**Strongest argument against A:**
- Production would carry the fingerprints of its accidental origin:
  - a name ending in "-test" and a permanent ref shared with months of test history;
  - 23 synthetic accounts and fictional seed content mixed with whatever real data arrives;
  - a migration history that is known **not** to reproduce the schema.
- The "we will build the baseline later" promise is exactly the kind of step that drifts. **B makes reproducibility unavoidable**, and it is cheapest **right now**, before any real user or data exists.
- If the owner values a clean, fully source-derived production over speed, B is defensible, provided the baseline is built and verified first (B1) and the project-slot question (B4) is settled.

## 8. Foundation context — is this decision blocking?

**Overall: important but deferrable**, with two parts that become blocking at specific points.

| Planned work | Effect of the decision |
|---|---|
| **UI changes** | **Not blocking.** Frontend-only changes don't depend on which project is production. Note: every merge to `main` already ships to the live backend. |
| **Feature additions (frontend plus existing RPCs)** | Not blocking while they use the existing backend API. |
| **Backend / schema work** | **Near-blocking.** Without a rehearsal environment, every migration is tested on the live backend (the Phase 21.x rollback-only pattern mitigates, but does not replace, a test environment). Recommendation step 3 should precede substantial new schema work. |
| **New tools / integrations** (webhooks, third-party services, a future Telegram Light) | **Near-blocking** for anything needing secrets, callbacks or email: needs a test environment and the SMTP/Auth-config decisions. |
| **Opening to real external users** | **Blocking:** custom SMTP, backups, Auth config and data cleanup must be done first, under either option. |

The **label** decision (A versus B) can be made at any time. The **reproducibility / test environment** and **production hardening** items are the real gates.

## 9. Proposed next action after the owner decision

- **If A:** a Phase 22.3 "Production designation and reproducible baseline". Scope:
  - designation docs and label rewording;
  - owner capture of the Auth config;
  - an executable baseline generator plus verification against production (read-only on production);
  - a test-environment choice (T1/T2/T3), with its cost confirmed by the owner before creation.
  
  Hardening and data cleanup follow as separate phases.
- **If B:** the same baseline phase first. Then:
  - a decision on the legacy disposition or Pro (for the project slot);
  - owner cost confirmation;
  - build and validate the new project;
  - the frontend switch as its own approved release.
- **Either way:** no Supabase or Netlify change until the specific step is approved.

---

## 10. Read-only activity log (Phase 22.2)

- **Supabase `kbnmkyvbwkuvcklywdhk`:**
  - `get_project`, `list_edge_functions`, `get_advisors` (security);
  - migration history read by `SELECT` (43 rows, latest `20260917143322`, unchanged since the Phase 21.3 close);
  - `P222-PROFILE-v1` (aggregates and catalog counts only).
- **Supabase `edxicnafggnnvcdvxemk`:** `get_project`; `P222-LEGACY-INTACT-v1`; `get_publishable_keys` (state only; values not recorded).
- **Organisation:** plan from Phase 22.0/22.1 `get_organization` (Free).
- **Docs:** project pausing, backups/PITR, custom SMTP, branching usage, billing FAQ, billing overview, project transfers.
- **Netlify:** site metadata (Phase 22.1 closeout, same deploy id).
- **Repository:** a read-only survey (labels, frontend backend selection, reproducibility inventory, deployment, Telegram), with key claims spot-checked.
- **Local:** Supabase CLI version, and the presence of Docker and `pg_dump`.
- **No mutation of any kind.**

---

## 11. Owner decision — recorded 2026-09-19

### OPTION A — APPROVED

**`kbnmkyvbwkuvcklywdhk` is formally selected as the intended STAGERZ production backend architecture**, and will be treated as the intended production backend going forward.

This decision **does not authorize any environment change** in Phase 22.2. Not done, and each would need its own approved phase:
- project rename;
- Auth or SMTP change;
- key change;
- Storage change;
- Edge Function deploy;
- `index.html`, Netlify or DNS change;
- test project or branch creation;
- data migration or deletion;
- legacy pause or delete.

**Why A:**
1. It is the **only complete and security-validated** modern STAGERZ backend. Part of its hardened state (Phases 21.4–21.7) exists only in the live database.
2. It **minimises migration risk and unnecessary work**: no rebuild, no cut-over, and no risk of re-introducing S-1 … S-7 / R-5-type privilege drift.
3. A **runnable, reproducible backend baseline is required under both Option A and Option B**, so it is scheduled explicitly rather than forced by a rebuild.
4. **Option B remains technically possible later**, once reproducibility is established, as a low-risk rebuild from a proven baseline.

**Strongest downside, accepted with this decision:**
- The project **originated as a test environment**.
- Its **name, history and test data still reflect that origin**: the name `stagerz-foundation-v2-test`, the permanent ref, 23 synthetic accounts, fictional seed content and test uploads.
- The backend **cannot yet be faithfully rebuilt from repository artifacts alone**: descriptive snapshots, 2 of 43 migrations as SQL, and Phases 21.4–21.7 outside the migration history.

**Next required foundation phase (expected scope; not started):**
- formal production-designation documentation cleanup (the TEST ONLY comments, stale labels and references of D-2);
- Auth settings capture (owner dashboard read: site URL, redirect allow-list, sign-up, OTP, rate limits, SMTP state);
- a runnable, reproducible backend baseline (executable schema, privileges, policies, functions, triggers, Realtime), verified against production by fingerprint comparison;
- Storage, Auth and Edge Function configuration capture (bucket and policies, `verify_jwt`, secrets inventory by name);
- a test-environment strategy (T1 local / T2 second project / T3 branching, with the owner confirming cost before any creation, and a frontend way to target a test backend);
- production-readiness items needed before real external users.

**Gate:** **opening STAGERZ to real external users remains BLOCKED** until the required production-readiness items are addressed. At minimum:
- custom SMTP (the default SMTP delivers only to organisation team members);
- a backup strategy;
- captured and reviewed Auth configuration;
- a decision on test and synthetic data;
- review of the open data-integrity item and the accepted Advisor findings.

### Closeout validation (read-only, 2026-09-19)

- **Live backend unchanged:** `kbnmkyvbwkuvcklywdhk` ACTIVE_HEALTHY; migration history 43 rows, latest `20260917143322`.
- **Phase 22.1 state intact** on `edxicnafggnnvcdvxemk` (see the closeout report).
- **No Supabase, Netlify, application, workflow or DNS change** was made in Phase 22.2. No secrets or personal data were recorded.

**Phase 22.2 — COMPLETE / PASS.**
