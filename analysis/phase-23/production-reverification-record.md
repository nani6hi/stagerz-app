# Phase 23.0 — Production Re-verification Record

**Capture date (UTC):** 2026-09-23, between 00:13:51Z and 00:16:40Z.
**Target:** production backend of record **`kbnmkyvbwkuvcklywdhk`** — addressed **by ref** for every
operation. Supabase name `stagerz-foundation-v2-test` is misleading and was not used for targeting.
**Repository state at capture:** branch `phase-23.0-production-reverification`, HEAD
`5f1fe651b2a1f3af84fda6862a39bfdd78d58021`, equal to its remote, working tree clean.
**Authority:** owner-approved stop gate SG-1, for the read-only capture defined in
`phase-definition.md` §D.

**Result: READ-ONLY CAPTURE COMPLETE. No production mutation was performed or observed.**
**Headline: production is byte-for-byte unchanged since the 2026-09-19 capture — fingerprint 20/20,
every recorded count identical.**

---

## 1. Execution log — every operation issued

All 11 operations were read-only. SQL was restricted to `SELECT` with catalog and aggregate reads;
no `INSERT`, `UPDATE`, `DELETE`, DDL, `GRANT`/`REVOKE`, RPC call or Edge Function invocation was
issued. The legacy project was never a target of any statement.

| # | Operation | Type | Target |
|---|---|---|---|
| 1 | Project inventory listing | platform read | org-wide (identity confirmation) |
| 2 | Project detail read | platform read | production ref |
| 3 | Fingerprint — opening (`fingerprint.sql`, all 20 `exact` categories + environment block) | SQL `SELECT` | production ref |
| 4 | Migration history listing | platform read | production ref |
| 5 | Edge Function listing | platform read | production ref |
| 6 | Security Advisor read | platform read | production ref |
| 7 | Performance Advisor read | platform read | production ref |
| 8 | Data inventory — per-table counts, Auth count, Storage counts/bytes, asset/object reconciliation | SQL `SELECT` (aggregates) | production ref |
| 9 | Maintenance queue state — depth, age, attempt distribution | SQL `SELECT` (aggregates) | production ref |
| 10 | Synthetic/test classification + authorship attribution | SQL `SELECT` (aggregates) | production ref |
| 11 | Auth-schema observable state + blocked-account context | SQL `SELECT` (aggregates) | production ref |
| 12 | Fingerprint + counts — closing comparison | SQL `SELECT` | production ref |

**Note on method (recorded deliberately):** `fingerprint.sql` had to be passed to the SQL tool as a
query string, because that tool accepts no file path. The statement body was **copied verbatim** from
`supabase/verify/fingerprint.sql` (SHA-256 `2b7f399729cadf98755c584852accf658bcc412c3260c64c2f3eeb5d3a25ec74`);
only the leading comment block was omitted, which is semantically inert. The canonical file was not
edited. The result marker returned was `STAGERZ-FINGERPRINT-v1`, as expected.

---

## 2. R-2 — Project identity

| Field | Production | Legacy |
|---|---|---|
| Ref | `kbnmkyvbwkuvcklywdhk` | `edxicnafggnnvcdvxemk` |
| Supabase name | `stagerz-foundation-v2-test` (misleading) | `stagerz-app` (misleading) |
| Status | **`ACTIVE_HEALTHY`** | **`INACTIVE`** — unchanged |
| Region | `eu-north-1` | `eu-north-1` |
| Postgres | 17.6.1.141 (engine 17, GA) | not inspected |
| Created | 2026-07-12 | 2026-06-25 |

- **Legacy: status read only. Its database was not queried, and it was not resumed, restored or
  altered in any way.**
- **T2 `kjhszwlddzqxcglkpzrn`: ABSENT from the project inventory** — confirming the 2026-09-22
  deletion. No replacement was created.
- Exactly two projects exist in the organisation. Identity is unambiguous.

**Provenance: TOOL-READ.**

---

## 3. R-3 — Fingerprint

**20 of 20 `exact` categories PASS. Zero drift.** Compared against
`supabase/verify/expected-production.json` (captured 2026-09-19).

| Category | Expected | Observed | Result |
|---|---|---|---|
| relations | `2278f76d…` | `2278f76d…` | PASS |
| relation_count | 18 | 18 | PASS |
| columns | `fcd704c2…` | `fcd704c2…` | PASS |
| column_count | 141 | 141 | PASS |
| constraints | `ab65275e…` | `ab65275e…` | PASS |
| indexes | `55bc8b0a…` | `55bc8b0a…` | PASS |
| views | `5cae11e3…` | `5cae11e3…` | PASS |
| functions | `c501ddb3…` | `c501ddb3…` | PASS |
| function_count | 34 | 34 | PASS |
| triggers | `1e27344d…` | `1e27344d…` | PASS |
| trigger_count | 4 | 4 | PASS |
| policies | `4d967979…` | `4d967979…` | PASS |
| policy_count | 23 | 23 | PASS |
| relation_grants | `409b6162…` | `409b6162…` | PASS |
| column_grants | `32a364a9…` | `32a364a9…` | PASS |
| function_grants | `7cdd6702…` | `7cdd6702…` | PASS |
| default_privileges | `1abceade…` | `1abceade…` | PASS |
| realtime_members | 5 collaboration tables | identical | PASS |
| buckets | `collaboration-assets:false:-:-` | identical | PASS |
| app_extensions | `pgcrypto@extensions,uuid-ossp@extensions` | identical | PASS |

**Interpretation.** The application-owned schema, RLS policies, privileges, functions, triggers,
Realtime membership and bucket configuration are **unchanged since 2026-09-19**. This also
re-confirms, as live fact, several things previously read only from the repository: 34 functions, 23
policies, the `collaboration-assets` bucket still **private with no size limit and no MIME
allow-list** (`:false:-:-`), and the `public_profiles` view still carrying no `security_invoker`
option.

Environment block (reported, never compared): PostgreSQL 17.6; extensions
`pg_stat_statements 1.11, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, uuid-ossp 1.1`;
`migration_history_present` true; total app rows 536.

**Provenance: TOOL-READ.**

---

## 4. R-4 — Migration state

- **43 migration rows** — unchanged.
- **Latest: `20260917143322` `phase21_3_r5_w1_w3_w4`** — unchanged.
- **`20260919120000` (the canonical repository baseline) is ABSENT** — as designed.
- The chain runs from `20260712100630 web_identity_forward_and_rls` to `20260917143322`, and includes
  `20260712101119 web_identity_seed` (the origin of the five fictional seed profiles) and
  `20260916215204 backend_integrity_o1_o2_o3`.

**The deliberate distinction is preserved and unchanged:** the repository baseline and the production
migration history are separate by design. **No reconciliation was performed**; `supabase migration
repair` was not run, and remains a separate, metadata-only, owner-approved operation.

**Provenance: TOOL-READ.**

---

## 5. R-5 — Data inventory

| Relation | Count 2026-09-23 | Prior record (2026-09-16/19) | Change |
|---|---|---|---|
| `users` | 32 | 32 | — |
| `profiles` | 32 | 32 | — |
| `user_auth_accounts` | 27 | — | — |
| `wanted_posts` | 25 | 25 | — |
| `wanted_applications` | 18 | 18 | — |
| `collaborations` | 11 | 11 | — |
| `collaboration_participants` | 21 | — | — |
| `collaboration_messages` | 28 | 28 | — |
| `collaboration_tasks` | 14 | 14 | — |
| `collaboration_credits` | 10 | 10 | — |
| `collaboration_assets` | 15 | 15 | — |
| `collaboration_activity` | 175 | 175 | — |
| `notifications` | 128 | 128 | — |
| `follows` / `likes` | 0 / 0 | 0 / 0 | — |
| `pending_auth_deletions` | 0 | — | — |
| `pending_asset_deletions` | 0 | 0 | — |
| `public_profiles` (view) | 32 | — | — |
| `auth.users` | 27 | 27 | — |

**Storage:** 1 bucket, **13 objects**, **14,944,564 bytes (≈14.9 MB)** — matching the recorded
"13 objects, about 14.9 MB".

**Asset / object reconciliation — the open data-integrity item:**

| Measure | Value |
|---|---|
| `collaboration_assets` rows, total | **15** |
| of which live (`deleted_at IS NULL`) | 15 |
| of which soft-deleted | 0 |
| **rows whose Storage object does not exist** | **2** |
| Storage objects with no metadata row (orphans) | **0** |

**The 15 metadata rows / 13 objects condition STILL EXISTS, unchanged.** Exactly 2 rows reference
missing objects, and there are **no orphaned objects** — confirming the Phase 21.8B reaper's work has
not regressed.

**No emails, user identifiers, display names, message bodies or Storage paths were read or recorded.**

**Provenance: TOOL-READ (aggregates only).**

---

## 6. R-6 — Maintenance / deletion queues

| Queue | Depth | Oldest request | Ever attempted | Max attempts |
|---|---|---|---|---|
| `pending_auth_deletions` | **0** | — | 0 | 0 |
| `pending_asset_deletions` | **0** | — | 0 | 0 |

Also: **0** soft-deleted `collaboration_assets` rows lacking a queue entry — the asset pipeline has
no stranded work.

**Both queues are empty and no row has ever recorded a failed attempt.** The absence of a scheduler
for `process-pending-deletions` has therefore caused no visible backlog **to date** — but that is
because nothing has been enqueued, not because the gap is closed. The finding stands.

**Provenance: TOOL-READ (aggregates only).**

---

## 7. R-7 — Auth configuration

### 7.1 Freshly TOOL-READ (from the `auth` schema)

| Observation | Value | Relevance |
|---|---|---|
| Users with a password set | **4** | The app is passwordless, yet the four sign-in-capable accounts carry a password hash. Needs owner confirmation. |
| Users with phone | 0 | Phone provider unused |
| Anonymous users | 0 | Consistent with anonymous sign-ins OFF |
| Banned users (`banned_until`) | 0 | Platform-level ban unused |
| MFA factors enrolled | 0 | Consistent with the prior record |
| Distinct identity providers | 1 | Email only |
| **Active sessions** | **3** | Newest created 2026-08-24; last refresh activity 2026-08-18 |
| Refresh tokens, total / unrevoked | 20 / **3** | Three usable refresh tokens outstanding |

**Sessions created a month before this capture are still present and unrevoked.** That is the direct,
live corroboration of the recorded session policy (no time-box, no inactivity timeout): sessions do
not expire on their own.

### 7.2 OWNER/DASHBOARD-CAPTURED — completed 2026-09-23

The available tooling **cannot read GoTrue configuration**. The owner performed the manual read-only
Supabase Authentication dashboard capture on **2026-09-23**. Every value in this section is
**OWNER/DASHBOARD-CAPTURED — it was not tool-read, and must never be presented as tool-read.**

**Sign-in / providers**

| Setting | Value |
|---|---|
| Allow new users to sign up | **ON** |
| Confirm email | **ON** |
| Allow manual linking | OFF |
| Allow anonymous sign-ins | **OFF** |
| Email provider | **ENABLED** |
| All other providers visible in the dashboard | DISABLED |

*Recorded exactly as captured: the statement covers the providers actually represented in the
captured dashboard state, and is not generalised to any provider not visible there.*

**Sessions and tokens**

| Setting | Value |
|---|---|
| Enforce single session per user | **OFF** |
| Time-box user sessions | **0 = never** |
| Inactivity timeout | **0 = never** |
| Access-token (JWT) expiry | **3600 s** |
| Detect and revoke compromised refresh tokens | **ON** |
| Refresh-token reuse interval | **10 s** |

**The dashboard states that the user-session controls (single session, time-box, inactivity timeout)
are available only on the Pro Plan and above** — owner-observed dashboard text, recorded as such; no
pricing or plan-limit claim is asserted here.

> **Interpretation guard — do not conflate these two.** The **3600 s access-token expiry is not a
> session expiry.** A refresh-token-backed session may continue well beyond 3600 s, and with
> time-box and inactivity timeout both at *never*, it continues indefinitely until the refresh token
> is revoked or reuse is detected. The three live sessions in §7.1, created in August and still
> unrevoked at this capture, are that behaviour observed in production.

**Rate limits**

| Limit | Value |
|---|---|
| Sending emails | **2 emails / hour** |
| Sending SMS | 30 SMS / hour |
| Token refreshes | 150 requests / 5 min / IP |
| Token verifications (OTP and magic-link verification) | 30 requests / 5 min / IP |
| Anonymous users | 30 requests / hour / IP |
| Sign-ups and sign-ins | 30 requests / 5 min / IP |
| Web3 sign-ups and sign-ins | 30 requests / 5 min / IP |
| IP address forwarding | OFF |

**URL configuration**

| Setting | Value |
|---|---|
| Site URL | `https://stagerz.app` |
| Redirect URL allow-list | **exactly 1 visible entry**, `https://stagerz.app` |

*No additional redirect URL and no wildcard was visible in the captured dashboard.*

**Attack protection**

| Setting | Value |
|---|---|
| CAPTCHA protection | **OFF** |
| Prevent use of leaked passwords | **DISABLED** |

**The dashboard states leaked-password protection is available on the Pro Plan and above** —
owner-observed dashboard text. This item has a second, independent source: the Security Advisor
still reports `auth_leaked_password_protection` (§8).

**Email / SMTP**

| Setting | Value |
|---|---|
| Enable custom SMTP | **OFF** |
| Templates page | displayed "Set up custom SMTP"; the default templates / default sending setup is in use |

*No SMTP host, provider or credential was configured or exposed, and none is inferred or recorded.*

**Email provider details**

| Setting | Value |
|---|---|
| Enable email provider | ON |
| Secure email change | ON |
| Secure password change | OFF |
| Require current password when updating | OFF |
| Prevent use of leaked passwords | OFF |
| Minimum password length | **6 characters** |
| Password requirements | no additional option selected |
| Email OTP expiration | 3600 s |
| Email OTP length | 6 digits |

### 7.3 R-7 verdict

**R-7 — PASS.** The gate required the Auth configuration to be freshly captured *and* each value
labelled by provenance. Both halves are now satisfied: §7.1 is TOOL-READ from the `auth` schema,
§7.2 is OWNER/DASHBOARD-CAPTURED on 2026-09-23, and the two are kept explicitly separate. Every
setting enumerated in `phase-definition.md` §D.6 has a captured value.

One item is recorded as immaterial rather than missing: §D.6 names "CAPTCHA state **and provider**",
and the capture records CAPTCHA as **OFF** without naming a provider selection. While CAPTCHA is OFF
no provider is in effect, so nothing is outstanding for the current state; **the provider choice
becomes a required input at Phase 23.5**, when enabling CAPTCHA is considered. No value has been
invented to close this gate.

### 7.4 Unresolved Auth observation — carried forward

**Four production Auth accounts hold a password hash** (§7.1, TOOL-READ). **The dashboard capture
does not explain why.** This is recorded as an **unresolved observation requiring provenance**, and
explicitly **not** as any of the following:

- **not** evidence that those accounts were created through password sign-up;
- **not** evidence that password login is used by the STAGERZ frontend;
- **not** a statement that the hashes are expected;
- **not** a statement that the hashes are unsafe.

The application's auth surface remains separately established as **magic-link / OTP based**. Closing
this needs owner provenance, not further inference.

---

## 8. R-8 — Security and performance advisors

**Security — identical to the recorded baseline: 1 ERROR, 26 WARN, 2 INFO.**

| Level | Lint | Count | Status |
|---|---|---|---|
| **ERROR** | `security_definer_view` — `public.public_profiles` | 1 | Known, **accepted** Phase 21.4 design. Unchanged. |
| WARN | `authenticated_security_definer_function_executable` | 25 | Unchanged. The 25 RPCs callable by `authenticated`. |
| WARN | `auth_leaked_password_protection` — disabled | 1 | Unchanged. Corroborates §7.2. |
| INFO | `rls_enabled_no_policy` — `pending_asset_deletions`, `pending_auth_deletions` | 2 | **By design** — RLS on, zero policies, service-role-only grants. |

**No new security finding. Nothing was remediated.**

**Performance (first time recorded):** 12 × `unindexed_foreign_keys` (INFO) and 1 × `unused_index`
(INFO, `idx_likes_post`). Both INFO-level, neither a beta blocker at current data volumes; recorded
for completeness.

**Provenance: TOOL-READ.**

---

## 9. R-9 — Deployed runtime inventory

| Function | Status | Version | `verify_jwt` | Bundle SHA-256 |
|---|---|---|---|---|
| `delete-account` | ACTIVE | 8 | false | `79b2fa66…0e74` |
| `process-pending-deletions` | ACTIVE | 9 | false | `66f3c27a…6e9d` |
| `process-pending-asset-deletions` | ACTIVE | 11 | false | `d3c3f1b5…af81` |
| `reap-orphaned-collaboration-assets` | ACTIVE | **4** | false | **`b0663090cefb06aad9d062d1d9c2cc30b6a14fee5a3cf7ce686842162c559397`** |

- All four expected functions are present and ACTIVE.
- **The reaper bundle hash matches the Phase 21.8B recorded value `b0663090…9397` exactly**, and it
  is still at **v4** — no redeploy since.
- `verify_jwt = false` on all four is the recorded, intended configuration: `delete-account`
  validates the caller's JWT itself, and the other three are maintenance-secret gated.
- **No function was invoked, in any mode, including dry-run. No secret value was read.**

**Provenance: TOOL-READ (listing metadata only).**

---

## 10. R-10 — Synthetic / test-data classification

Classification by predicate and count. **No identity was listed or recorded.**

### 10.1 Auth accounts (27 total)

| Class | Predicate | Count |
|---|---|---|
| **Known synthetic** | `created_at IS NULL`, no `auth.identities` row, never signed in | **23** |
| **Confirmed owner/test** | has identity row, email confirmed, signed in ≥ once | **4** |
| Reserved-TLD fixtures (`@stagerz.test`) | email matches | **0** |

The three predicates for the synthetic class agree exactly (23 / 23 / 23), which is a strong
signal — these are inserted fixtures, not sign-ups. Newest account creation 2026-08-24; most recent
sign-in **2026-09-20** (the Phase 22.4 production smoke). **The repository's `fixtures.sql`
`@stagerz.test` accounts are confirmed ABSENT from production** — the fixture seed never ran there.

### 10.2 Domain users (32 total)

| Class | Predicate | Count |
|---|---|---|
| **Seed / showcase** | `is_system = true`, unmapped to any auth account | **5** |
| Mapped to a synthetic auth account | mapping exists → never-signed-in auth user | **23** |
| Mapped to a confirmed owner/test account | mapping exists → signed-in auth user | **4** |
| **Unknown** | — | **0** |
| Anonymised (`anonymized_at`) | | **0** |
| **Blocked (`blocked = true`)** | | **2** |
| `username IS NULL` | | 24 |
| Repository seed usernames (`showcase%` / `fixture%`) | | 0 |

**Every one of the 32 rows classifies cleanly. The `unknown` class is empty.**

### 10.3 Authorship attribution

| Content | Total | By signed-in (owner/test) authors | By `is_system` seed authors | Remainder (synthetic) |
|---|---|---|---|---|
| `wanted_posts` | 25 | **10** | **5** | 10 |
| `collaboration_messages` | 28 | **20** | — | 8 |
| `collaboration_assets` | 15 | **13** | — | 2 |

This reproduces the Phase 22.0 split exactly (10 genuine / 10 synthetic / 5 seed posts; 20 genuine /
8 synthetic messages; 13 genuine / 2 synthetic assets).

**New, and directly useful for Phase 23.4:** the **2 asset rows whose Storage objects are missing
were uploaded by accounts that have never signed in** (`assets_missing_object_by_signed_in_uploader =
0`). Both broken rows are therefore in the synthetic class, and would be removed by a synthetic-data
cleanup rather than needing separate repair.

### 10.4 Blocked-account context (new finding)

| Measure | Count |
|---|---|
| Blocked domain users | **2** |
| of which still mapped to an auth account | 2 |
| of which have ever signed in | **0** |
| of which are `is_system` | 0 |
| `collaboration_participants` rows belonging to blocked users | **2** |

Both blocked accounts are synthetic and have never signed in, so **no live session exists for
them** and the SEC-2 exposure is not currently being realised in production. But `blocked` is
demonstrably **in use**, and both blocked users remain listed participants of collaborations, which
is exactly the surface SEC-2 describes.

**Provenance: TOOL-READ (aggregates only). Attribution of the 4 owner/test accounts to the owner
personally remains OWNER TESTIMONY (Phase 22.0, O-6) and is not independently verifiable here.**

---

## 11. R-13 — Closing non-mutation evidence

The fingerprint and the aggregate counts were re-read at the end of the capture window
(2026-09-23 00:16:40Z) and compared with the opening read (00:13:51Z).

**Identical across the window:**

- All **20** `exact` fingerprint categories — byte-identical hashes, closing composite
  `e7a15e547189b9c3d32704f84112121a`.
- Every captured count: `auth.users` 27 · `users` 32 · `profiles` 32 · `wanted_posts` 25 ·
  `wanted_applications` 18 · `collaborations` 11 · `collaboration_messages` 28 ·
  `collaboration_assets` 15 · `collaboration_activity` 175 · `notifications` 128 ·
  `storage.objects` 13 · Storage bytes 14,944,564 · both queues 0 · assets-missing-object 2.

**Differences: none.**

**Two-part support for R-13, as required:**

1. **Command-level review.** Every one of the 12 operations was inspected before issue and is a read:
   platform listing/detail reads, Advisor reads, and `SELECT`-only SQL. No DML, DDL, RPC or function
   invocation was issued at any point.
2. **Closing state comparison.** Opening and closing states are identical, as above.

**Deliberate limitation — this is not a mathematical proof.** External concurrent change remains
theoretically possible: an identical opening and closing state would not reveal a change that was
made and perfectly reverted within the window, nor a change outside the observed surface. What is
recorded is that **all commands issued were read-only**, and that **the observed state did not
change**. R-13 is satisfied on that basis, not on a claim of impossibility.

---

## 12. Gate matrix

| Gate | Result | Note |
|---|---|---|
| **R-1** | **PASS** | Branch, HEAD `5f1fe65…`, remote equal, tree clean — verified before any operation |
| **R-2** | **PASS** | Production `ACTIVE_HEALTHY` by ref; legacy `INACTIVE`, database untouched; T2 absent |
| **R-3** | **PASS** | 20/20 categories, zero drift |
| **R-4** | **PASS** | 43 rows, latest `20260917143322`, baseline absent by design, no reconciliation performed |
| **R-5** | **PASS** | Full inventory captured; 15/13 asset-object mismatch confirmed still present |
| **R-6** | **PASS** | Both queues empty, never attempted, no stranded soft-deletes |
| **R-7** | **PASS** | Two provenances, kept separate: DB-observable auth state **TOOL-READ** (§7.1); GoTrue settings **OWNER/DASHBOARD-CAPTURED 2026-09-23** (§7.2). Verdict and the one immaterial item in §7.3 |
| **R-8** | **PASS** | Security 1 ERROR / 26 WARN / 2 INFO, unchanged; performance advisors recorded |
| **R-9** | **PASS** | 4 functions ACTIVE; reaper bundle hash matches the recorded value |
| **R-10** | **PASS** | All 32 domain users and 27 auth accounts classify; unknown class empty |
| **R-11** | **PASS** | All seven decisions **DECIDED by the owner on 2026-09-23** — `owner-decision-register.md`. Provenance: OWNER PRODUCT DECISION; a decision is not evidence of implementation compliance |
| **R-12** | **PASS** | Reconciliation in §13 |
| **R-13** | **PASS (with the §11 limitation recorded)** | No mutation issued; opening and closing states identical |

**R-7 closed on 2026-09-23 by the owner/dashboard capture (§7.2); R-11 closed the same day when the
owner decided all seven items (`owner-decision-register.md`). All thirteen gates are satisfied, R-7
and R-13 with their recorded qualifications, and Phase 23.0 is assessed **COMPLETE / PASS** in
`closeout.md`. That verdict means the facts are established and the decisions are recorded — **it
does not mean STAGERZ is ready for an external beta, and it does not mean any decision is
implemented** (see the G-1 … G-8 gap table in the register).

---

## 13. R-12 — Reconciliation against the Phase 23 pre-planning report

| Finding | Prior status | Now | Change |
|---|---|---|---|
| DAT-4 evidence currency | All production facts unverified since 2026-09-20 | **RESOLVED** — fresh capture 2026-09-23 | **Closed** |
| DAT-1 synthetic data | 23 synthetic / 4 owner-test / 5 seed, counts from 2026-09-19 | **CONFIRMED unchanged**, and now reproducible by predicate | Strengthened |
| DAT-2 two broken asset rows | 15 rows vs 13 objects, both "synthetic" | **CONFIRMED still present**; both uploaded by never-signed-in accounts; **0 orphaned objects** | Strengthened |
| DAT-5 migration reconciliation | 43 rows, baseline absent | **CONFIRMED unchanged** | — |
| SEC-3 unbounded uploads | No size/MIME limit (repo-derived) | **CONFIRMED live** — bucket fingerprint `:false:-:-` | Upgraded to live fact |
| SEC-5 public read surface | Definer view + world-readable tables | **CONFIRMED live** — views and policies hashes unchanged; Advisor ERROR persists | Upgraded to live fact |
| SEC-2 liveness asymmetry | Code-derived only | **STILL code-derived.** But `blocked = 2` in production, both still collaboration participants | **Newly material**, still unproven at runtime |
| ACC-5 session policy | No time-box (owner-reported) | **CORROBORATED** — 3 sessions alive from 2026-08, 3 unrevoked refresh tokens | Second source found |
| ACC-4 password posture | Password API reachable (reasoned) | **NEW: 4 accounts carry a password hash** | New fact, needs owner explanation |
| PRV-3 deletion queue | No scheduler, no dead-letter | **CONFIRMED** — queue empty, nothing ever attempted | Unchanged; no backlog yet |
| OPS reaper state | v4, bundle `b0663090…` | **CONFIRMED identical** | — |
| ACC-1/ACC-2 SMTP and sign-up | Owner-reported OFF; `/otp` never exercised | **UNCHANGED — still not tool-verifiable** | Still open |

**Nothing found in this capture contradicts the pre-planning report.** Two items gained a second,
independent source (ACC-5, SEC-5), two were upgraded from repository-derived to live fact (SEC-3,
SEC-5), and two new facts appeared (§14).

---

## 14. New findings from this capture

1. **`blocked = 2` in production.** Two domain users are blocked, both still mapped to auth accounts
   and both still listed in `collaboration_participants`. Neither has ever signed in, so no live
   session exists for them and the SEC-2 exposure is **not currently being realised**. It confirms
   `blocked` is in real use, which makes **OD-23.0-6 (moderation semantics) load-bearing** rather
   than theoretical.
2. **Four auth accounts carry a password hash** although the application's auth surface is
   magic-link / OTP based. **The 2026-09-23 owner/dashboard capture does not explain this**, and it
   remains an **unresolved observation requiring provenance** — see §7.4 for the four inferences that
   are explicitly *not* being drawn from it.
3. **Three sessions and three unrevoked refresh tokens are still outstanding**, the newest created
   2026-08-24 with last refresh activity 2026-08-18. With time-box and inactivity timeout both at
   *never*, a refresh-token-backed session continues indefinitely; the 3600 s access-token expiry
   bounds the token, **not the session** (§7.2).
4. **Both broken asset rows belong to never-signed-in (synthetic) uploaders**, so they fall inside
   the Phase 23.4 cleanup rather than needing a bespoke repair.
5. **Zero orphaned Storage objects**, confirming no regression since the Phase 21.8B reaper run.
6. **Performance advisors recorded for the first time:** 12 unindexed foreign keys and 1 unused
   index, all INFO.
7. **Session controls and leaked-password protection are shown by the dashboard as Pro Plan and
   above** (owner-observed dashboard text). Remediating the session policy may therefore depend on a
   plan decision, which links it to **OD-23.0-5**. No pricing or plan-limit claim is asserted here.

### 14.1 Beta-readiness implications, stated conservatively

Recorded for Phase 23 planning. **Nothing here is remediated, and none of it is an owner decision.**

- **Custom SMTP OFF combined with a 2 emails/hour limit remains a beta-readiness blocker** — the
  magic link is the only way in.
- **CAPTCHA OFF remains an abuse-protection gap**, to be addressed with Phase 23.5 alongside SMTP.
- **Sign-up is enabled and email confirmation is enabled**; **anonymous sign-in is disabled**.
- **Access-token expiry is 3600 s. There is no session time-box and no inactivity timeout, and
  single-session enforcement is OFF** — so sessions persist beyond the token lifetime.
- **Refresh-token compromise detection is ON** with a **10 s** reuse interval.
- **Site URL and the sole visible redirect URL are `https://stagerz.app`.**
- **Leaked-password protection is OFF; minimum password length is 6 with no additional complexity
  requirement.**

---

## 15. Still NOT verified

- ~~All GoTrue settings — owner dashboard capture required.~~ **CLOSED 2026-09-23** by the
  owner/dashboard capture (§7.2). They remain **OWNER/DASHBOARD-CAPTURED, never tool-read**, and are
  current as of that date only.
- **Why four Auth accounts hold a password hash** (§7.4) — unresolved; needs owner provenance, and
  no inference is drawn from it.
- **The CAPTCHA provider selection** — not captured, and immaterial while CAPTCHA is OFF; it becomes
  a required input at Phase 23.5 (§7.3).
- **Supabase plan tier, backup/PITR posture, pricing and the free-project-slot rule** — not read in
  this capture and must be verified externally at Phase 23.1, never guessed.
- **SEC-1 (deleted-user JWT), SEC-2 (liveness asymmetry), SEC-10 (cross-user Realtime isolation) and
  authored-content retention** — none can be closed by a read-only capture. They require a disposable
  environment, which Phase 23.0 is prohibited from creating.
- **Whether the 4 owner/test accounts are genuinely the owner's** — owner testimony (O-6), not
  independently verifiable.
- **Edge Function secrets, `STAGERZ_MAINTENANCE_SECRET` presence, and the resolved dependency
  versions behind the floating `@2` imports** — not inspected; secret values are out of scope by rule.
- **The stale Netlify surface and apex DNS** — outside this capture's scope.

---

## 16. Preserved qualifications

Carried forward unchanged by this record:

- **Phase 22.5 COMPLETE / PASS does not mean production- or public-beta readiness.**
- The public `/otp` magic-link **sign-up endpoint was not exercised**; end-to-end public sign-up
  remains unverified until email delivery exists.
- **Orphan-reaper destructive mode was not run** and was not required — and was not run here either.
- **Authored-content retention was not runtime-demonstrated by E1/E2** — it remains inferred from
  code.
- **Deleted-user JWT safety was not proven globally**; **only one post-deletion lookup was tested**.
- **The G4 same-URL HTTP 200 was observed; caching remains only a hypothesis.**
- **The extra cross-user Realtime control was inconclusive and was not Gate D evidence.**
- **SEC-2 remains code-derived until runtime-tested** — this capture did not test it, it only showed
  that blocked accounts exist.
- Production state recorded before this capture is historical; this record supersedes it **as of
  2026-09-23 00:16:40Z** and will itself become historical.
