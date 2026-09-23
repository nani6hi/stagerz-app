# Phase 23.0 — Closeout

**Phase:** 23.0 — Production Re-verification & Owner Decisions, the first sub-phase of the Phase 23
umbrella (Controlled Beta Readiness).
**Closed:** 2026-09-23.
**Verdict: COMPLETE / PASS.** All thirteen gates R-1 … R-13 are satisfied, two of them with
explicitly recorded qualifications that the owner has acknowledged.

**Branch:** `phase-23.0-production-reverification`, from `main` @ `0a5b7cb`.
**Evidence:** `phase-definition.md` (scope and gates), `production-reverification-record.md` (the
read-only capture), `owner-decision-register.md` (the seven decisions).

> **This verdict takes effect when this closeout is merged.** At the time of writing, the Phase 23.0
> evidence is written but **not committed**. Transition criteria §I.4 and §I.5 of the phase
> definition require the baseline to be committed and the closeout merged before Phase 23.1 may be
> proposed.

---

## 1. What Phase 23.0 achieved

A fresh, dated, read-only production baseline, and a complete set of owner decisions — the two things
every later sub-phase depends on.

- **Production is unchanged since 2026-09-19.** Fingerprint **20/20 exact categories, zero drift**;
  43 migrations with latest `20260917143322`; every row count identical; both maintenance queues
  empty and never attempted; Advisor state identical at 1 ERROR / 26 WARN / 2 INFO; four Edge
  Functions ACTIVE with the reaper bundle hash unchanged.
- **The open data-integrity item persists exactly as recorded:** 15 `collaboration_assets` rows vs 13
  Storage objects, **2** rows referencing missing objects, **0** orphaned objects.
- **Data classification is now reproducible by predicate** — 23 synthetic auth accounts, 4 owner/test
  accounts, 5 `is_system` seed profiles, and an **empty unknown class**.
- **Auth configuration is captured with explicit provenance** — database-observable state TOOL-READ,
  GoTrue settings OWNER/DASHBOARD-CAPTURED on 2026-09-23, never conflated.
- **All seven owner decisions are taken**, with the decision-to-current-state gaps recorded and
  assigned to later sub-phases.
- **No production mutation was issued or observed.**

### New facts established

1. **`blocked = 2` in production** — both synthetic, never signed in, both still collaboration
   participants. No live session exists for them, so the SEC-2 exposure is not currently realised;
   but `blocked` is in genuine use, which is what makes OD-23.0-6 load-bearing.
2. **Four auth accounts hold a password hash** in a magic-link/OTP product — **provenance
   unresolved** (§4).
3. **Three sessions and three unrevoked refresh tokens outstanding since August** — live corroboration
   that sessions do not expire under the current configuration.
4. **Both broken asset rows belong to never-signed-in uploaders**, so they fall inside the Phase 23.4
   cleanup rather than needing bespoke repair.
5. **Zero orphaned Storage objects** — no regression since the Phase 21.8B reaper run.
6. **Performance advisors recorded for the first time** — 12 unindexed foreign keys, 1 unused index,
   all INFO.

---

## 2. Gate matrix

| Gate | Status | Basis |
|---|---|---|
| **R-1** Repository base verified | **PASS** | Branch, HEAD `5f1fe65…`, remote equal, clean tree, verified before any operation |
| **R-2** Production identity verified | **PASS** | `kbnmkyvbwkuvcklywdhk` `ACTIVE_HEALTHY` by ref; legacy `INACTIVE` and never queried; T2 absent |
| **R-3** Fingerprint captured and compared | **PASS** | 20/20 categories, zero drift |
| **R-4** Migration state captured | **PASS** | 43 rows, latest `20260917143322`, baseline absent by design, nothing reconciled |
| **R-5** Data inventory captured | **PASS** | Full inventory; 15/13 mismatch confirmed still present |
| **R-6** Queues captured | **PASS** | Both empty, never attempted, no stranded soft-deletes |
| **R-7** Auth configuration captured | **PASS** *(qualified)* | TOOL-READ + OWNER/DASHBOARD-CAPTURED, provenance separate. CAPTCHA provider not captured — immaterial while CAPTCHA is OFF, becomes a 23.5 input |
| **R-8** Advisor state captured | **PASS** | Security unchanged; performance recorded |
| **R-9** Runtime inventory captured | **PASS** | 4 functions ACTIVE; reaper bundle hash matches |
| **R-10** Synthetic/test classification | **PASS** | All 59 rows across both identity tables classify; unknown class empty |
| **R-11** Owner decisions recorded | **PASS** | All seven DECIDED, 2026-09-23; provenance OWNER PRODUCT DECISION |
| **R-12** Findings reconciled | **PASS** | Reconciliation table in the capture record |
| **R-13** No production mutation | **PASS** *(qualified)* | Command-level read-only review **and** identical opening/closing state. **Not a mathematical proof** — see §3 |

---

## 3. Acceptance-criteria assessment

The phase definition permits COMPLETE / PASS only when **every gate is satisfied or carries an
explicitly owner-accepted qualification**. Both conditions are examined here rather than assumed from
the matrix.

**Every gate is satisfied.** Two carry qualifications, and both are explicitly acknowledged by the
owner in the authorisation for this closeout:

1. **R-7 — the CAPTCHA provider was not captured.** Recorded as *immaterial while CAPTCHA is OFF*,
   and as a required input at Phase 23.5. No value was invented to close the gate.
2. **R-13 — endpoint equality is not proof.** Identical opening and closing states would not reveal a
   change made and perfectly reverted inside the observation window, nor a change outside the
   observed surface. What is established is that **every command issued was read-only** and that
   **the observed state did not change**. R-13 rests on both legs, not on a claim of impossibility.

**R-11 deserves its own statement** because it was the last gate to close and because a decision is
not a fact: recording the seven decisions closes the gate, and it does **not** mean the implementation
complies with them. Eight decision-to-current-state gaps (G-1 … G-8) are recorded in the register and
assigned to sub-phases 23.1 … 23.6.

**Nothing in the phase definition's scope remains unperformed.** Phase 23.0 was defined to establish
facts and record decisions, and to remediate nothing; it remediated nothing.

**Verdict: COMPLETE / PASS is legitimate.**

---

## 4. What COMPLETE / PASS does NOT mean

- **It does NOT mean STAGERZ is ready for an external beta.** It is not. Email delivery does not
  exist for external users, no backup exists, there is no account-deletion path in the product, and
  the demo surfaces are unlabelled.
- It does not mean any finding was fixed. **Phase 23.0 changed nothing** — by design.
- It does not mean the owner decisions are implemented. They are decisions; G-1 … G-8 are the gaps.
- It does not mean production is *correct* — only that it is **unchanged** and now accurately
  described.
- It does not re-open, revise or strengthen anything from Phase 22.5, which **remains COMPLETE /
  PASS** with all of its own qualifications intact.

---

## 5. Preserved qualifications and unresolved observations

Carried forward unchanged. **None of these may be weakened, generalised or silently upgraded.**

- **Deleted-user JWT:** after deletion the database API still accepted the unexpired access token
  (HTTP 200), and **only the one tested lookup** — the user's own `user_auth_accounts` row — returned
  zero rows because the mapping was gone. **This must not be generalised** to "no identity resolves",
  "the deleted user can access nothing", "every RLS path is safe", or "the old JWT is harmless".
- **Authored-content retention was NOT runtime-demonstrated by E1/E2.** Both disposable accounts
  authored no content. Retention remains code-derived, and OD-23.0-2 does not change that.
- **The G4 immediate same-URL HTTP 200 after deletion has only a caching hypothesis.** Cache headers
  were not captured; the cause is unconfirmed and must not be described as benign CDN caching.
- **The public `/otp` magic-link sign-up endpoint was not exercised** in Phase 22.5, and was not
  exercised here. End-to-end public sign-up remains unverified until email delivery exists.
- **Orphan-reaper destructive mode was not run** in Phase 22.5, was not required, and was not run
  here.
- **Phase 22.5 COMPLETE / PASS does not imply beta readiness.**
- **R-13 endpoint equality is not mathematical proof** that no transient or reverted mutation
  occurred.
- **The provenance of the 4 production Auth password hashes remains unresolved.** The dashboard
  capture does not explain it. It is not evidence of password sign-up, not evidence the frontend uses
  password login, not a statement that the hashes are expected, and not a statement that they are
  unsafe.
- **The CAPTCHA provider remains immaterial while CAPTCHA is OFF** and becomes an input to Phase
  23.5.
- **SEC-2 (the liveness asymmetry) remains CODE/REPO-DERIVED.** SG-1 showed that blocked accounts
  exist; it did not test what they can reach.
- **Cross-user Realtime isolation is not established** — the Phase 22.5 control was inconclusive and
  was not Gate D evidence.
- **Supabase plan limits, pricing, PITR availability and the free-project-slot rule** were not
  verified and must be checked externally at Phase 23.1, never guessed.
- **All state recorded here is current as of 2026-09-23** and becomes historical thereafter.

---

## 6. Next phase

**Phase 23.1 — Backup & Restore Capability**, per the approved Phase 23 sequence and OD-23.0-5.

**It is NOT started, and this closeout does not authorise it.** The transition criteria in
`phase-definition.md` §I require, in addition to this COMPLETE / PASS verdict: that the fresh
production baseline is **committed**, that this closeout is **merged**, and that the owner
**explicitly approves** beginning 23.1. The first two are outstanding at the time of writing.

Scope reminders inherited by 23.1 from OD-23.0-5: database **and** Storage objects; Auth/backend
dependencies considered in the restore design; **a restore actually tested in an isolated
environment**; backups held outside production with no secret committed; and **no Pro upgrade solely
for backup** — the Pro question is separate and should weigh backup, session controls and
leaked-password protection together.

The remaining sequence is unchanged and unapproved: 23.2 Identity/Access/Storage Hardening · 23.3
Privacy & Account Deletion · 23.4 Production Test-Data Cleanup · 23.5 Email, Signup & Abuse
Protection · 23.6 Beta Product Honesty & Core Funnel · 23.7 Beta Operations / Deployment Cleanup.
