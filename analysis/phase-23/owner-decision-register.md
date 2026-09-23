# Phase 23.0 — Owner Decision Register

**Decisions taken by the product owner on 2026-09-23.** All seven OD-23.0 items are **DECIDED**; none
is deferred.

**Provenance of everything in this file: OWNER PRODUCT DECISION.** A decision states *intended
product semantics*. It is **not** a runtime-demonstrated fact, not a code-derived observation, and
not evidence that the current implementation already behaves this way. Where a decision differs from
current behaviour, that gap is recorded in §8 and assigned to a later sub-phase.

**Evidence classes referenced below**

| Label | Meaning |
|---|---|
| **OWNER DECISION** | The owner's product intent, recorded here |
| **TOOL-READ** | Read from production by tooling during SG-1 (2026-09-23) |
| **OWNER/DASHBOARD-CAPTURED** | Read by the owner from the Supabase dashboard (2026-09-23); never tool-read |
| **CODE/REPO-DERIVED** | Established by reading repository source; not runtime-proven |
| **RUNTIME-DEMONSTRATED** | Observed at runtime, with its recorded scope and qualifications |
| **FUTURE IMPLEMENTATION REQUIREMENT** | Work a later sub-phase must perform and prove |

---

## OD-23.0-1 — Seed / showcase content · **DECIDED**

**Decision: KEEP + CLEARLY LABEL AS DEMO / SHOWCASE FOR BETA.**

- Keep the 5 `is_system` profiles and their showcase content for the initial beta.
- Before external beta users are admitted, the UI must clearly identify them as **Demo / Showcase**.
- They must not imply real artists, real user activity or real verification.
- Final removal can be reconsidered later.
- **No production data mutation is authorised by this decision.**
- Product/UI treatment belongs to **Phase 23.6**.

**Supporting evidence.** TOOL-READ (SG-1): 5 `is_system` domain users, unmapped to any auth account,
authoring 5 of the 25 Wanted posts; they originate from migration `20260712101119 web_identity_seed`
and classify cleanly by predicate. CODE/REPO-DERIVED: the client additionally ships its own
fabricated datasets (`stageData`, `artistDB`, `wantedData`) that are distinct from these production
seed rows — those are OD-23.0-7's subject, not this one.

**Not asserted:** that labelling exists today (it does not), and that the production seed rows are
the only demo content a beta user would see (they are not).

---

## OD-23.0-2 — Account deletion / authored-content retention · **DECIDED**

**Decision: DELETE IDENTITY, ANONYMISE RETAINED SHARED HISTORY, DELETE PERSONAL/PRIVATE CONTENT
WHERE APPROPRIATE.**

- Delete Auth access and the personal account mapping.
- Anonymise the public identity so the former user is no longer publicly identifiable.
- Personal / non-shared content should be deleted or removed from public presentation where
  appropriate.
- Collaboration messages, tasks and shared project history **may** be retained where deletion would
  damage the context of other participants.
- Retained authored history must identify the author only as **Deleted User**, never the former
  identity.
- **A deleted account must not retain active collaboration access or membership.**
- Historical relationship records may be retained only where required for coherent shared history.
- **Personal assets should be deleted where possible.**
- Shared assets may be retained only where needed for an ongoing/shared collaboration, and require a
  **defined retention rule**.
- Credits / transaction-like history must not be blindly deleted where needed for historical
  consistency; identity should be removed or anonymised where the model permits.

**Supporting evidence.** RUNTIME-DEMONSTRATED (Phase 22.5 E1/E2, on the since-deleted T2): auth user
removed, mapping removed by FK cascade, `public.users` row retained and anonymised, profile
`display_name` set to `Deleted User`, `public_profiles.is_deleted` true, queue entry cleared.
CODE/REPO-DERIVED: the deletion path contains **no content-deletion step**, and
`collaboration_participants` rows are **not** removed. TOOL-READ (SG-1): 0 accounts are currently
anonymised in production, so no precedent exists.

**Explicitly preserved qualification: Phase 22.5 E1/E2 did NOT runtime-demonstrate authored-content
retention.** Both disposable accounts authored no content, so the retention path was never exercised.
Retention remains **CODE/REPO-DERIVED**. This decision must not be read as confirming it.

**FUTURE IMPLEMENTATION REQUIREMENT (Phase 23.3):** this decision defines desired semantics only.
Implementation must define the per-category rules (personal vs shared, assets, credits), must remove
collaboration membership on deletion, and must be **proved at runtime on an account that has actually
authored content** — the test Phase 22.5 could not run.

---

## OD-23.0-3 — Public data model · **DECIDED**

**Decision: PUBLIC DISCOVERY, AUTHENTICATED INTERACTION.**

- Public profiles intended for discovery may be publicly readable through the **designated
  public-profile surface**.
- Published Wanted posts may be publicly readable.
- **Must not be public:** private account data, Auth/email data, applications, collaboration
  membership and details, messages, tasks, credits, assets, and other private collaboration content.
- Follow / like **aggregate counts** may be public.
- **Full "who follows/likes whom" relationship lists are NOT approved as a public product surface for
  the beta.**
- Follow, like, application, collaboration and similar interactions require an **authenticated active
  user**.

**Supporting evidence.** TOOL-READ (SG-1, fingerprint 20/20): `public_profiles` is a definer view
granted to `anon`; `profiles`, `wanted_posts`, `follows` and `likes` each carry a `USING (true)`
SELECT policy with `anon` grants; the Security Advisor still reports the accepted
`security_definer_view` ERROR. TOOL-READ: `follows` and `likes` currently hold **0 rows**, so the
relationship-list exposure is **latent, not currently realised**.

**FUTURE IMPLEMENTATION REQUIREMENT (Phase 23.2):** reconcile RLS, grants, the API surface and
Storage policies to this decision. The `follows`/`likes` full-row public readability is the concrete
divergence to resolve — aggregates public, relationship lists not.

---

## OD-23.0-4 — Beta audience · **DECIDED**

**Decision: SMALL INVITATION-ONLY EXTERNAL BETA.**

- Approximately **10–20 real external testers**.
- No broad public launch; **no uncontrolled public sign-up** as the first-beta access model.
- Testers should exercise the real core funnel: **login → profile → discovery/Wanted → application →
  collaboration**.
- This does not require building a complex invite system.
- **Phase 23.5** determines the smallest safe access-control mechanism.

**Supporting evidence.** OWNER/DASHBOARD-CAPTURED (2026-09-23): sign-ups **ON**, confirm-email ON,
CAPTCHA **OFF**, custom SMTP **OFF** with a **2 emails/hour** limit. CODE/REPO-DERIVED: the client
calls `signInWithOtp` with `shouldCreateUser: true`, so any visitor who reaches the app can create an
account. TOOL-READ: 27 auth accounts exist, only 4 can sign in; last sign-in 2026-09-20.

**FUTURE IMPLEMENTATION REQUIREMENT (Phase 23.5):** the current configuration is *open* public
sign-up, which contradicts "no uncontrolled public sign-up". Closing that gap, and providing email
delivery for 10–20 external testers, are both 23.5's problem.

---

## OD-23.0-5 — Backup direction · **DECIDED**

**Decision: INDEPENDENT BACKUP + TESTED RESTORE FIRST; PRO REMAINS A SEPARATE DECISION.**

- Before external beta, establish a **reproducible independent backup capability** for relevant
  production data.
- Account at minimum for **PostgreSQL/database data and Supabase Storage objects**.
- **Auth/backend dependencies must be explicitly considered in the restore design.**
- **A backup is not operationally sufficient until a restore has been successfully tested in an
  isolated environment.**
- Backups are held **outside production**, and **secrets must never be committed to the repository**.
- **Do not upgrade to Supabase Pro solely because of this decision.**
- A Pro-plan decision remains **separate**, and should later weigh the combined value and cost of
  backup, session controls, leaked-password protection and other capabilities.
- **Phase 23.1** owns implementation and investigation.

**Supporting evidence.** TOOL-READ (SG-1): 13 Storage objects, ≈14.9 MB, 536 application rows, 27
auth accounts — none of it reproducible from the repository. CODE/REPO-DERIVED: the canonical
baseline reproduces the **schema contract only** ("no data, users or secrets"). OWNER/DASHBOARD-
CAPTURED: the dashboard shows session controls and leaked-password protection as **Pro Plan and
above** — recorded as owner-observed dashboard text, with **no pricing or plan-limit claim asserted**.

**Standing constraint preserved:** Supabase plan limits, pricing, PITR availability and the
free-project-slot rule **must be verified externally at 23.1 and must never be guessed**.

---

## OD-23.0-6 — Moderation semantics · **DECIDED**

**Decision: BLOCKED MEANS ACCESS SUSPENDED, NOT CONTENT DELETED.**

- `blocked` represents a **global STAGERZ usage suspension** for the beta.
- A blocked account **must not obtain normal protected application access even if authentication or
  session material still exists**.
- A blocked user must not create posts, applications, follows/likes, messages, tasks, collaborations,
  uploads or other protected mutations.
- **A blocked user must not read protected collaboration or Storage content merely because an Auth
  JWT or account mapping remains valid.**
- Existing content is **not** automatically deleted solely because the account is blocked; it remains
  subject to normal moderation/deletion rules.
- `blocked` is **distinct from** deleted/anonymised.
- **No multiple suspension levels** are introduced in Phase 23.0.
- **Phase 23.2** must reconcile identity helpers, RLS, Storage policies and protected access with
  this decision.

**Supporting evidence.** TOOL-READ (SG-1): **2 domain users are `blocked`**, both still mapped to
auth accounts, both still rows in `collaboration_participants`, neither has ever signed in — so no
live session exists for them and the exposure is **not currently being realised**.
CODE/REPO-DERIVED (SEC-2, **not runtime-proven**): `blocked` is evaluated only by
`current_active_stagerz_user_id()`, which every write policy uses; but `is_collaboration_participant()`,
five read policies and **both Storage policies** resolve identity through the mapping-only
`current_stagerz_user_id()`. On that reading, a blocked user with a live session retains participant
reads and Storage upload.

**This decision makes that divergence a defect to fix rather than a design.** It is the clearest
decision-to-implementation gap in the register.

**FUTURE IMPLEMENTATION REQUIREMENT (Phase 23.2):** reconcile the identity helpers and policies; and
address session material explicitly — note that the platform's session controls are shown as Pro-plan
features, so "must not obtain access even if session material exists" has to be satisfied at the
data-access layer, not only by session revocation.

---

## OD-23.0-7 — Demo / incomplete product surfaces · **DECIDED**

**Decision: NO FAKE SUCCESS / CLEARLY MARK DEMO OR DISABLE INCOMPLETE FEATURES.**

- Anything presented as a working beta feature **must actually perform its claimed operation**.
- **No fake success messages** for operations that do not persist or execute.
- Incomplete functionality must be **(1) completed, (2) clearly marked Demo / Coming Soon, or
  (3) disabled/hidden**.
- Demo/showcase data must be visibly identified as such.
- Fake artists, fake activity, local mock data and simulated success must not be presented as genuine
  production activity.
- The beta core funnel must use **real end-to-end behaviour**: login → profile → discovery/Wanted →
  application → collaboration.
- **Prefer a smaller real beta surface over a larger simulated one.**
- **Phase 23.6** owns the product/UI reconciliation.

**Supporting evidence (all CODE/REPO-DERIVED, from `index.html` at the current HEAD).** Three
fabricated datasets are rendered to signed-in users; real Wanted rows are unshifted in front of seven
fabricated posts in the same list and card style; demo artists carry a verification badge no real
user can obtain; "Collab request sent!" creates nothing; "Share link copied!" copies nothing;
FameMaker captures nothing and publishes nothing; the Backstage screen shows prices with no payment
path. RUNTIME-DEMONSTRATED (Phase 22.4, production): Stage exposes **no** navigation path to another
artist's profile.

---

## 8. Decision-versus-current-state gaps

Recorded so that later sub-phases inherit the work rather than rediscovering it. **Each is a gap
between an owner decision and observed/derived current behaviour — none is remediated here.**

| # | Decision | Current state | Evidence class | Owner |
|---|---|---|---|---|
| G-1 | OD-23.0-6: blocked users must not read protected content or upload | Blocked users retain participant reads and Storage upload while a session lives | CODE/REPO-DERIVED, not runtime-proven | 23.2 |
| G-2 | OD-23.0-2: a deleted account must not retain collaboration membership | `collaboration_participants` rows are not removed on deletion | CODE/REPO-DERIVED | 23.3 |
| G-3 | OD-23.0-2: personal content deleted, shared content anonymised under a defined rule | The deletion path deletes no content at all; no per-category rule exists | CODE/REPO-DERIVED | 23.3 |
| G-4 | OD-23.0-3: relationship lists not public | `follows` and `likes` are world-readable in full (currently 0 rows — latent only) | TOOL-READ | 23.2 |
| G-5 | OD-23.0-4: no uncontrolled public sign-up | Sign-ups ON and the client passes `shouldCreateUser: true` | OWNER/DASHBOARD-CAPTURED + CODE/REPO-DERIVED | 23.5 |
| G-6 | OD-23.0-4: 10–20 external testers must receive email | Custom SMTP OFF; 2 emails/hour; default sender reaches organisation members only | OWNER/DASHBOARD-CAPTURED | 23.5 |
| G-7 | OD-23.0-1 / OD-23.0-7: demo content must be labelled, no fake success | Unlabelled fabricated datasets and several no-op controls ship to signed-in users | CODE/REPO-DERIVED | 23.6 |
| G-8 | OD-23.0-5: tested restore before beta | No backup mechanism of any kind exists | CODE/REPO-DERIVED | 23.1 |

---

## 9. R-11 assessment

**R-11 — PASS.** The gate requires that *all seven owner decisions are recorded — each either decided
or explicitly deferred*. All seven are **DECIDED**, recorded above with their supporting evidence and
its provenance, and **OD-23.0-5 in particular is recorded**, which the transition criteria to Phase
23.1 require specifically.

**Provenance of the gate's closure: OWNER PRODUCT DECISION, 2026-09-23.** No decision was made,
inferred or pre-answered by anyone else, and recording a decision is not evidence that the
implementation complies with it.
