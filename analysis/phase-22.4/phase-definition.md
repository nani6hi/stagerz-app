# Phase 22.4 — Current-Epoch Production Smoke & Deployment Surface Reconciliation

**Branch:** `phase-22.4-current-epoch-production-smoke`, from `main` @ `3b38e6b849a88e46aa0fd67c0f7040e761b274b5` (the PR #28 merge of the Phase 22.3 closeout).
**Assigned:** 2026-09-20 by the product owner, as the next Foundation phase defined in `analysis/phase-22.3/closeout.md` §5.
**Production backend of record:** `kbnmkyvbwkuvcklywdhk`.
**Status:** **ACTIVE — production smoke EXECUTED and PASSED at reduced scope (2026-09-20); Netlify architecture APPROVED IN PRINCIPLE and repository Step 2 IMPLEMENTED (2026-09-20); all DNS and Netlify mutations NOT EXECUTED.** The only production data mutation was the single approved reversible profile edit, which was restored. `www.stagerz.app` still depends on Netlify until the DNS step is executed, so the Netlify site must be retained. See `netlify-surface-diagnosis.md` §9.

## 1. Objective

Validate the **current combined frontend/backend epoch** in production, and reconcile the
divergent public deployment surfaces.

The phase exists because the newest application-runtime evidence before it was **2026-09-12**,
while the schema had since advanced through `20260916215204` and `20260917143322` and
`index.html` had changed twice (Phase 21.9 error contract, Phase 22.3 environment selection).
Nothing validated that combination.

This phase is deliberately **small**. It is **not** the clean-room runtime phase.

## 2. Scope

**In scope:**
- read-only preflight: epoch definition, test design, tester-data safety, write boundary;
- a minimal manual production smoke on `https://stagerz.app`;
- read-only verification of the scheduled maintenance workflow;
- read-only diagnosis of the stale Netlify deployment surface;
- preparing (not making) the decision on the intended role of the Netlify surface;
- recording the evidence;
- **(added by owner decision, 2026-09-20)** the repository half of the approved architecture —
  removing the two site-level `*.netlify.app` hostnames from the production environment mapping
  (migration Step 2). DNS and Netlify steps stay out of scope.

**Out of scope:**
- gates **D, E, G and C3** — they remain deferred to the proposed Phase 22.5 and are **not**
  converted to PASS by anything in this phase;
- T2 creation, legacy-project pause or delete, a Supabase Pro upgrade;
- migration-history reconciliation; project rename;
- custom SMTP, backups, CAPTCHA, synthetic-data cleanup, the 2 broken `collaboration_assets` rows;
- any Netlify, DNS or domain change.

## 3. Safety boundary (as executed)

**Permitted and used:** exactly one reversible application-data mutation — the signed-in tester
account's `profiles.bio`, set to a temporary marker and then restored to its original value. The
`saveProfile()` code path also re-writes the unchanged `users.username`; that is inherent to the
existing UI save path and was accepted in advance.

**Not permitted, and not done:** creating users, Wanted posts or collaborations; sending or
deleting collaboration messages; modifying `collaboration_activity`; intentionally creating
notifications; touching `collaboration_assets` or opening a collaboration's Assets tab; any
Storage object upload, download or delete; any Edge Function invocation; any Supabase, Netlify,
DNS, Auth, SMTP, API-key or migration-history change; Docker/WSL; T2; legacy-project disposition.

**Reduction from the approved plan:** P22.4-6 (collaboration message write/delete) was **skipped
by owner decision** because it is not residue-free, and P22.4-7 became **N/A** as its dependant.
See `production-smoke-record.md` §4.

**Addition by owner decision (2026-09-20):** one **repository** change is approved and implemented —
migration **Step 2**, removing `aquamarine-puppy-beccd9.netlify.app` and
`main--aquamarine-puppy-beccd9.netlify.app` from `STAGERZ_HOST_ENVIRONMENT` in `index.html`, with
the matching test updates. **No DNS, Netlify, domain, redirect, `CNAME` or deployment change was
made**, and the Netlify site is explicitly **retained** — `www.stagerz.app` still depends on it.

## 4. Deliverables

| File | Content |
|---|---|
| `analysis/phase-22.4/phase-definition.md` | This file |
| `analysis/phase-22.4/preflight.md` | Read-only preflight: epoch, test design, tester-data safety, write boundary, workflow check, GO/NO-GO |
| `analysis/phase-22.4/production-smoke-record.md` | The executed manual smoke: per-test results with evidence scope, residue check, findings |
| `analysis/phase-22.4/netlify-surface-diagnosis.md` | Read-only Netlify diagnosis and classification, architecture options, the owner decision of 2026-09-20 and the implementation status of each migration step |

## 5. Acceptance criteria

1. The current epoch is defined and independently confirmed, not assumed. **MET.**
2. The live `stagerz.app` build is proven to match `origin/main`. **MET** (byte-identical).
3. The core authenticated paths of the current epoch are exercised in production. **MET at reduced
   scope** — startup, auth, session restore, Stage read, own-profile read, profile write with
   persistence and exact restoration, sign-out. See §6 for what was not covered.
4. Production data is left as found. **MET** — the one edit was restored and verified.
5. The scheduled maintenance workflow's health is established read-only. **MET.**
6. The stale Netlify surface is diagnosed on evidence, without being changed. **MET.**
7. The Netlify role decision is prepared for the owner. **MET — and the owner APPROVED the target architecture in principle on 2026-09-20.** Repository **Step 2 is IMPLEMENTED** (no `*.netlify.app` host is accepted as production); **all DNS and Netlify steps remain NOT EXECUTED**, and `www.stagerz.app` still depends on Netlify until the DNS step. See `netlify-surface-diagnosis.md` §9.
8. Deferred gates D/E/G/C3 remain recorded as deferred, not converted. **MET.**
9. `PROJECT_CONTEXT.md` updated. **MET.**

## 6. Known coverage limits of this phase

- **Other-artist profile read (P22.4-4) NOT EXECUTED** — the Stage UI exposed no direct navigation
  path to another artist's profile, and no deep link or DevTools bypass was fabricated. Recorded as
  a **UI/product finding**, explicitly **not** as backend evidence. The `public_profiles` read
  contract is therefore **not** re-verified on the current epoch.
- **Collaboration write path NOT EXERCISED** (P22.4-6 skipped, P22.4-7 N/A), so message create,
  delete, the Realtime `postgres_changes` path and the Phase 21.9 error contract remain
  **unverified on the current epoch**.
- **No network-level audit.** The smoke was observed through the browser Console, not the Network
  panel. Claims are scoped accordingly throughout `production-smoke-record.md`.
- Gates **D, E, G, C3** are untouched by this phase.
