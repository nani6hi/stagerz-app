# Phase 23 — Controlled Beta Readiness

**Sub-phase defined for execution by this document: Phase 23.0 — Production Re-verification & Owner
Decisions.**

**Branch of this definition step:** `phase-23.0-production-reverification`, from `main` @
`0a5b7cb9598ee376244d48b15ecb82f51eaf30f2`.

**Status: DEFINITION ONLY — NOTHING HAS BEEN EXECUTED.** This document defines Phase 23.0. It does
not perform it. **No production re-verification has been executed**, no production query has been
issued, and no Supabase, GitHub, Netlify or DNS state has been read or changed by this step. Owner
approval to *begin Phase 23.0* is approval to write this definition — it is **not** approval to run
the capture defined in §5. That requires a separate owner go-ahead (§8, gate SG-1).

**Production backend of record:** `kbnmkyvbwkuvcklywdhk`. **Nothing in Phase 23.0 may mutate it.**

---

## A. Phase 23 umbrella objective

Phase 23 is the umbrella phase for **controlled beta readiness**: reaching a state in which a small,
deliberately chosen group of real external users can use STAGERZ safely, lawfully and honestly.

The owner approved **Option C — Controlled Beta Readiness** from the Phase 23 pre-planning review,
with this sequence:

| Sub-phase | Title | Approved to begin? |
|---|---|---|
| **23.0** | **Production Re-verification & Owner Decisions** | **YES — this document** |
| 23.1 | Backup & Restore Capability | No |
| 23.2 | Identity / Access / Storage Hardening | No |
| 23.3 | Privacy & Account Deletion | No |
| 23.4 | Production Test-Data Cleanup | No |
| 23.5 | Email, Signup & Abuse Protection | No |
| 23.6 | Beta Product Honesty & Core Funnel | No |
| 23.7 | Beta Operations / Deployment Cleanup | No |

**Explicit statements of record:**

- **Phase 22.5 remains COMPLETE / PASS** (closed 2026-09-22). Phase 23 does **not** reopen it, does
  not re-litigate its gates, and does not change its verdict.
- **Phase 22.5 COMPLETE / PASS did NOT establish production-readiness or public-beta readiness.** The
  closeout says so explicitly, and that qualification is carried forward unchanged (§9).
- **No later Phase 23.x sub-phase is approved by this definition.** The sequence above is the planned
  order, not an authorisation. Each sub-phase needs its own definition and its own owner approval.
- Phase 23.0 itself performs **no remediation of any kind**. It establishes facts and records
  decisions; it fixes nothing.

---

## B. Phase 23.0 objective

**Establish a fresh, dated, read-only production baseline, and capture the owner decisions that later
sub-phases depend on — before any beta-readiness mutation is planned or executed.**

The reason this is first: every production-side fact currently on record was captured between
2026-09-16 and 2026-09-20, much of it owner/dashboard-reported rather than tool-read, and none of it
has been re-verified since. The clean-room environment that proved the Phase 22.5 runtime gates was
permanently deleted on 2026-09-22. Planning a backup strategy, a data cleanup or an identity fix on
three-day-old unverified numbers would put the rest of Phase 23 on sand.

### Project identity — authoritative

| Role | Project ref | Notes |
|---|---|---|
| **Production backend of record** | **`kbnmkyvbwkuvcklywdhk`** | Its Supabase *name* is `stagerz-foundation-v2-test`, which is **misleading**. **The project ref is authoritative — never the name.** |
| Legacy, paused | `edxicnafggnnvcdvxemk` | Supabase name `stagerz-app`, also misleading. **NOT production.** Verified `INACTIVE` since 2026-09-20. **Must not be touched, queried, resumed or restored in Phase 23.0.** |
| Former disposable T2 | `kjhszwlddzqxcglkpzrn` | **Permanently deleted 2026-09-22.** It does **not** exist and must not be treated as available. No replacement T2 exists, and creating one is **not** authorised by this definition. |

Every read operation in §5 must be addressed to the production ref explicitly, and the identity must
be re-confirmed (gate R-2) before any other operation runs.

---

## C. Phase 23.0 acceptance criteria

Phase 23.0 may be recorded **COMPLETE / PASS** only when every gate below is either satisfied or
carries an **explicitly owner-accepted qualification** recorded in the closeout. A gate that cannot
be satisfied is not silently dropped: it is recorded as NOT MET with its reason.

| Gate | Requirement | Satisfied by |
|---|---|---|
| **R-1** | Authoritative repository base verified — root, branch, HEAD, `origin/main`, clean tree | Recorded at capture time |
| **R-2** | Production project identity verified **by ref**, and its status re-read; legacy confirmed untouched | Project listing / project read |
| **R-3** | Production fingerprint captured and compared against `supabase/verify/expected-production.json`; any drift identified per category | `supabase/verify/fingerprint.sql` (read-only) |
| **R-4** | Migration state captured — current row count and latest version; the deliberate baseline/history distinction preserved | Migration listing |
| **R-5** | Production data inventory captured — per-table row counts, Auth user count, Storage bucket/object counts and total size, `collaboration_assets` count, and whether the **15 metadata / 13 object** mismatch still holds | Aggregate SQL |
| **R-6** | Maintenance / deletion queues captured — `pending_auth_deletions`, `pending_asset_deletions`: depth, oldest `requested_at`, `attempt_count` distribution | Aggregate SQL |
| **R-7** | Auth configuration freshly captured (§5 E), including which values are tool-read and which remain owner/dashboard-reported | Owner capture + tool reads where available |
| **R-8** | Security / Advisor state captured where safely obtainable read-only; deltas against the recorded baseline identified | Advisor read |
| **R-9** | Deployed backend / runtime inventory captured — Edge Function inventory and deployed versions where safely obtainable read-only | Function listing |
| **R-10** | Synthetic / test-data classification updated against **current** rows, using the privacy-conscious method in §5 H | Classification query + owner confirmation |
| **R-11** | **All seven owner decisions (§F) recorded** — each either decided, or explicitly deferred with the deferral recorded | Owner Decision Register |
| **R-12** | Findings reconciled against the Phase 23 pre-planning report: each ACC/SEC/PRV/DAT/PRD/OPS finding marked CONFIRMED, CHANGED, RESOLVED or STILL-UNVERIFIED | Reconciliation table |
| **R-13** | **No production mutation occurred** — proven, not asserted: every statement executed is listed, and the fingerprint plus row counts are unchanged end-to-end | Execution log + closing re-read |

**R-13 is the phase's hard invariant.** If any mutation occurs, intended or not, Phase 23.0 is a
FAIL and the incident is recorded in full regardless of impact.

---

## D. Approved read-only production operations

**Approved *in principle by this definition*, and individually gated on SG-1 (§8) before execution.**
Every operation below is read-only. Each capture must record the exact statement or call issued, its
timestamp (UTC), and its result summary.

### D.1 Governing rules

1. **SQL is restricted to `SELECT` and read-only catalog queries.** No `INSERT`, `UPDATE`, `DELETE`,
   `TRUNCATE`, `ALTER`, `CREATE`, `DROP`, `GRANT`, `REVOKE`, `COPY`, `VACUUM`, `SET` outside a
   read-only transaction, or any RPC that writes — including the five `admin_*` functions and the
   four Edge Functions.
2. **Every statement is reviewed before it is sent.** The tool that executes SQL against Supabase is
   mutation-capable by nature; the restriction to reads is a discipline enforced by review, not by
   the tool. Any statement whose read-only nature is not obvious on inspection is **not run** — it is
   reported instead (§8, SG-3).
3. **No statement may be run against `edxicnafggnnvcdvxemk`.**
4. **Key material is never captured.** Operations that return API keys or secrets are excluded;
   where a tool returns a key as a side effect, the key is **not** recorded in any file.

### D.2 A — Backend fingerprint

- Execute the existing production-safe `supabase/verify/fingerprint.sql` (marker
  `STAGERZ-FINGERPRINT-v1`) against production. It is pure `pg_catalog` `SELECT`s and reads no row
  content, no user data and no secret.
- Compare all 20 `exact` categories against `supabase/verify/expected-production.json` (captured
  2026-09-19).
- Record per-category PASS / DRIFT. Any drift is **recorded and investigated read-only, never
  corrected** in Phase 23.0.

### D.3 B — Migration history

- List production migrations; record the row count and the latest version.
- Compare against the recorded state: **43 rows, latest `20260917143322`**.
- **Preserve the deliberate distinction:** the canonical repository baseline `20260919120000` is
  *intentionally absent* from production migration history. That is a documented state, not a
  defect, and Phase 23.0 does **not** reconcile it. `supabase migration repair` is prohibited (§E).
- Confirm the repository remains unlinked to any Supabase project.

### D.4 C — Data inventory

Aggregate counts only:

- Row count per `public` table (all 17), plus the view.
- Auth user count, and the split by confirmation / sign-in status **as counts, not identities**.
- Storage: bucket list, object count, total bytes.
- `collaboration_assets` count vs `storage.objects` count for the bucket — explicitly determine
  whether the recorded **15 metadata rows / 13 objects** mismatch still holds, and whether the count
  of rows referencing missing objects is still exactly 2.
- Realtime publication membership count.

**No email addresses, user IDs, display names, message bodies, file names or Storage paths are
recorded.** Where a specific row must be identified for later remediation, record a stable
non-reversible reference (for example a salted hash, or a count-plus-predicate description), not the
raw identifier.

### D.5 D — Deletion / maintenance queues

- `pending_auth_deletions`: depth, oldest `requested_at`, `attempt_count` distribution, count with
  `attempt_count > 0`.
- `pending_asset_deletions`: the same.
- Any other maintenance queue discovered during the capture.
- Counts and status only. Identifiers only if a stuck row genuinely requires one for later
  remediation, and then by non-reversible reference.

### D.6 E — Auth configuration

Re-verify the live settings, recording for **each value** whether it is *tool-read* or
*owner/dashboard-reported*:

- custom SMTP state; sender domain if configured
- email rate limit (emails/hour) and the other rate limits
- CAPTCHA state and provider
- JWT / access-token expiry
- session time-box, inactivity timeout, single-session enforcement
- refresh-token rotation and reuse interval
- sign-ups enabled, confirm-email, anonymous sign-ins, manual linking
- enabled providers, Site URL, redirect allow-list
- password settings and leaked-password protection

**The current record — to be treated as HISTORICAL until re-verified by this gate:** custom SMTP
**OFF** (default service, delivers only to organisation team members), email rate limit **2
emails/hour**, CAPTCHA **OFF**, JWT expiry **3600 s**, **no** session time-box, **no** inactivity
timeout, single-session **OFF**. These were owner/dashboard-confirmed on 2026-09-19 and were never
tool-read. Phase 23.0 must not restate them as current without re-verification.

### D.7 F — Security / Advisor state

- Fresh Security Advisor read (security and performance) where safely obtainable read-only.
- Compare against the recorded baseline: **1 ERROR** (`security_definer_view` on `public_profiles` —
  the known, accepted design), 26 WARN, 2 INFO.
- **Nothing is remediated.** A new finding is recorded and classified, not fixed.

### D.8 G — Deployment / runtime inventory

- Edge Function inventory and deployed versions / status where safely obtainable read-only.
- Confirm the four expected functions and note any version change since the recorded state.
- The scheduled asset-drainer workflow's recent run history, read-only.
- **No deploy, no re-deploy, no secret read or write, no invocation of any function** — including
  dry-run modes. The reaper's dry-run is a *write-capable code path's* read mode and is **out of
  scope for 23.0**.

### D.9 H — Synthetic / test-data classification

Design and execute a **privacy-conscious** classification of current rows into:

- **confirmed owner/test** — the accounts the owner has identified as their own test accounts
- **known synthetic** — inserted fixtures (the recorded pattern: NULL `created_at`, no auth
  provider, example/test/invalid email domains, never signed in)
- **seed / showcase** — the fictional profiles and posts originating from migration
  `20260712101119 web_identity_seed`, plus anything matching the repository's `is_system` /
  `showcase_` / `fixture_` / `@stagerz.test` markers
- **unknown** — everything the predicates cannot classify

Method rules: classify by **predicate and count**, not by listing rows; report the four class sizes
per table; record the predicates used so the classification is reproducible; and surface the
**unknown** class prominently, because it is the class that needs owner judgement.

**The historical counts (23 synthetic Auth accounts, 4 owner test accounts, 5 fictional seed
profiles, 25 Wanted posts of which 10 synthetic and 5 seed, 15 assets of which 2 synthetic) must not
be assumed current.** They are the prior, not the answer.

**Nothing is deleted, altered, anonymised or "cleaned" in Phase 23.0.** Cleanup is Phase 23.4, and it
is not approved.

---

## E. Prohibited operations

Phase 23.0 must not, under any circumstance:

- write to production in any way — `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, DDL, `GRANT`/`REVOKE`
- execute any destructive or write-capable RPC, including the five `admin_*` functions
- invoke any Edge Function, in any mode, including dry-run
- change Auth configuration, SMTP, CAPTCHA, session settings or rate limits
- change, upload to, download from or delete anything in Storage
- deploy or re-deploy an Edge Function; create, read, change or rotate any secret
- change Netlify configuration, DNS records, or the GitHub repository configuration
- delete, modify or "clean" any test, synthetic or seed data
- run `supabase link`, `supabase db push`, or `supabase migration repair`
- execute the canonical baseline against any existing database
- restore, resume, unpause, query or otherwise touch the legacy project
- create or delete any Supabase project, branch or disposable environment
- configure SMTP or any email provider
- begin Phase 23.1 or any later sub-phase

---

## F. Owner decisions required

**These are the owner's decisions. This document must not answer them, and no later sub-phase may
proceed on an assumed answer.** Each is recorded in the Owner Decision Register with its date and, if
deferred, the deferral reason.

**OD-23.0-1 — Seed / showcase content.** Should the five fictional seed profiles and their associated
showcase content remain for the beta, remain but be clearly labelled as demo/showcase, or be removed
before the beta? *Blocks:* 23.4, 23.6.

**OD-23.0-2 — Account deletion and authored-content retention.** What should happen to authored
content when an account is deleted? Decide **per category, not once for all** — the current
implementation retains everything: Wanted posts · collaboration messages · tasks · credits ·
collaboration assets · collaboration membership. Note that participant rows are currently retained,
so a deleted user stays a listed member of every collaboration they joined. *Blocks:* 23.3.

**OD-23.0-3 — Public data model.** Confirm whether anonymous / public readability of
`profiles` and `public_profiles`, `wanted_posts`, `follows` and `likes` is intentional for the beta.
All four are currently world-readable by design, and `public_profiles` is a definer view granted to
`anon` that deliberately bypasses `users` RLS. *Blocks:* 23.2, 23.3.

**OD-23.0-4 — Beta audience.** Which is intended: owner-only / internal testing, a small
invitation-only external beta, or broader public sign-up? Record an approximate target size **only if
the owner chooses to state one**. *Blocks:* 23.5, and the risk calculus of 23.2.

**OD-23.0-5 — Backup direction.** **No product or plan is chosen now.** Record only that Phase 23.1
must compare **managed Supabase backup capability** against an **independent scheduled database +
Storage backup**, using current plan features, limits and costs **verified at that time**. Supabase
plan limits and pricing must be re-verified externally and must not be asserted from the existing
record. *Blocks:* 23.1.

**OD-23.0-6 — Moderation semantics.** What is `blocked` intended to mean? Specifically, should a
blocked account: lose write access only · lose private collaboration read access · lose Storage
access · retain public-read access · have existing sessions revoked or invalidated where the platform
allows it? **This decision is required before SEC-2 remediation can be designed**, because the
current behaviour is an asymmetry (writes are blocked, participant reads and Storage upload are not)
rather than a stated policy. *Blocks:* 23.2.

**OD-23.0-7 — Demo and incomplete product surfaces.** For each of: FameMaker · Backstage pricing ·
demo "verified" badges · the demo artist search · the inert "Collab request sent!" control · the
inert share control — choose **implement**, **hide/remove for beta**, or **clearly label as
preview/demo**. *Blocks:* 23.6.

---

## G. Stop gates

Execution **stops and reports** — it does not proceed on judgement — at each of these:

- **SG-1 — Before the first production read.** This definition authorises the *plan*, not the
  capture. The capture begins only on an explicit owner go-ahead.
- **SG-2 — Before any command not listed in §D.** New operations are proposed and approved first.
- **SG-3 — If a supposedly read-only command is discovered to have mutation potential.** Stop before
  execution and report it. This includes any statement whose effect is not obvious on inspection, and
  any tool whose read-only behaviour is assumed rather than established.
- **SG-4 — On any evidence of unexpected production state:** fingerprint drift, a migration-history
  change, a queue with stuck rows, a new Advisor ERROR, or a changed Edge Function version. Record
  and report; do not investigate by mutation and do not remediate.
- **SG-5 — If any production mutation is observed or suspected,** including an accidental one. Stop
  immediately, preserve the evidence, report in full. Gate R-13 fails.
- **SG-6 — Before anything in §E.** Every item there requires its own separate, explicit owner
  approval and, where appropriate, its own sub-phase.
- **SG-7 — Before Phase 23.1 or any later sub-phase.** Phase 23.0 ends at its closeout.

---

## H. Evidence requirements

1. **Committed evidence must contain no secrets and no personal data.** Specifically excluded:
   access tokens, JWTs, API keys (publishable, legacy or service-role), maintenance secrets, email
   addresses, user IDs, display names, message bodies, file names, private Storage paths, and
   production row identifiers that are not genuinely required.
2. **Prefer counts, hashes, classifications and configuration states over raw data.** This is the
   same rule the earlier phases applied, and it is why the two broken `collaboration_assets` rows
   have never had identifiers recorded.
3. **Every operation is logged** with its exact statement or call, UTC timestamp, and result summary,
   so that R-13 can be demonstrated rather than claimed.
4. **Each captured value is labelled by provenance:** tool-read, owner/dashboard-reported, or
   derived. A value that is owner-reported must never be presented as tool-verified.
5. **Committed documentation uses `<USERPROFILE>`**, never a user-specific Windows account name.
6. **Evidence files for Phase 23.0** live under `analysis/phase-23/` — at minimum a
   `production-reverification-record.md` (the capture), an `owner-decision-register.md` (§F), and a
   `closeout.md` (verdict and reconciliation).

---

## I. Transition criteria to Phase 23.1

Phase 23.1 (Backup & Restore Capability) may be defined and proposed only when **all** of the
following hold:

1. Phase 23.0 is recorded **COMPLETE / PASS**, with every gate R-1 … R-13 satisfied or carrying an
   explicitly owner-accepted qualification.
2. **R-13 is satisfied** — no production mutation occurred.
3. The **Owner Decision Register is complete** in the sense of R-11: every decision is either taken
   or explicitly deferred, and **OD-23.0-5 in particular is recorded**, since it governs 23.1.
4. The fresh production baseline is committed, and any drift found under R-3, R-4, R-8 or R-9 is
   documented and classified — drift does not have to be *fixed* to leave 23.0, but it must be
   *known*.
5. The Phase 23.0 closeout is merged, and the owner explicitly approves beginning 23.1.

Phase 23.0 does **not** authorise 23.1, and the presence of this section is not an approval.

---

## J. Preserved evidence qualifications

These are carried forward unchanged. **No Phase 23 work may weaken, erase or silently upgrade any of
them.**

- **Phase 22.5 COMPLETE / PASS does not mean STAGERZ is production-ready or public-beta-ready.**
- The public `/otp` magic-link **sign-up endpoint was NOT exercised** (AC6, owner-accepted). Sessions
  in Phase 22.5 came from admin-generated links; end-to-end public sign-up remains unverified until
  email delivery exists.
- **Orphan-reaper destructive mode was NOT run**, and was not required.
- **Authored-content retention was NOT runtime-demonstrated by E1/E2** — it is inferred from code.
  Both disposable accounts authored no content, so the retention path was never exercised.
- **Deleted-user JWT safety was NOT proven globally.** It is not demonstrated that the deleted user
  can access no data, that every RLS path, view, RPC or Storage endpoint is safe, or that the old JWT
  is harmless.
- **Only one post-deletion lookup was tested** — the user's own `user_auth_accounts` mapping, which
  returned 0 rows because the mapping was gone. No other endpoint was tested.
- **The G4 immediate same-URL HTTP 200 was observed; caching remains only a hypothesis.** Cache
  headers were not captured, so the cause is unconfirmed and must not be upgraded to "benign CDN
  caching".
- **The extra cross-user Realtime control was inconclusive and was NOT Gate D evidence.** Its
  positive control failed, so cross-user Realtime isolation is **not established**.
- **SEC-2 (the liveness asymmetry) is currently code-derived and NOT runtime-proven.** The reading is
  that `is_collaboration_participant()`, five read policies and both Storage policies resolve
  identity through the mapping-only helper rather than the active-identity helper. It has not been
  exercised against a running system.
- **All production state recorded before Phase 23.0 is HISTORICAL until freshly re-verified**,
  including the Auth configuration values in §D.6 and the data counts in §D.9.

---

## K. Out of scope for Phase 23.0

Remediation of any finding; backup implementation; identity, access or Storage hardening; privacy or
account-deletion work; test-data cleanup; SMTP, CAPTCHA or rate-limit changes; product or UX change;
CI, monitoring, Netlify retirement or DNS work; migration-history reconciliation; legacy-project
disposition beyond confirming it stays untouched; creation of any disposable environment.

Each belongs to a later sub-phase, and none of them is approved.
