# Phase 22.2 — Production / Test Environment Decision

**Branch:** `phase-22.2-production-test-environment-decision`, created from `main` @ `f423e597aa3e2e3f31281475780b3226b5c470b2` (the PR #24 merge of Phase 22.1; `main` = `origin/main`). A remote branch with the same name already existed at the same commit (0 ahead / 0 behind); the local branch matches it and nothing has been pushed.
**Assigned:** 2026-09-19 by the product owner. It follows Phase 22.0 conclusion 4 (production/test separation and production designation still need a deliberate decision) and Phase 22.1 (legacy containment, COMPLETE / PASS).
**Mode:** **DECISION PREPARATION ONLY — strictly read-only.**
**Status:** **COMPLETE / PASS (2026-09-19). Owner decision: OPTION A — APPROVED.** `kbnmkyvbwkuvcklywdhk` is formally selected as the intended STAGERZ production backend (`decision-report.md` §11).
- PASS means the production/test architecture decision has been made and documented.
- It does **not** mean production-readiness hardening is complete.
- Opening STAGERZ to real external users remains **blocked** until the required production-readiness items are addressed.
- No environment change occurred in this phase.

---

## 1. Objective

Produce an evidence-backed **owner decision package** for the future STAGERZ environment architecture:
- which Supabase project should be production;
- how a separate test/development environment should exist;
- what each path costs in work, risk and money.

The phase ends with a decision by the owner, not with an implementation.

## 2. Current known state (entering the phase)

| Project | Role today | Notes |
|---|---|---|
| `kbnmkyvbwkuvcklywdhk` "stagerz-foundation-v2-test" | **De facto live backend** of `stagerz.app` (GitHub Pages and Netlify, both built from `main`) since 2026-07-13, **by drift** | Created 2026-07-12 as a disposable Foundation v2 test project. Holds the modern schema (43 migrations), 4 Edge Functions, Storage and all security work of Phases 21.x. Seed, synthetic and tester data only; no known external users |
| `edxicnafggnnvcdvxemk` "stagerz-app" | Former Telegram-era backend; detached | Phase 22.1 containment COMPLETE / PASS. Not a credible production target (incompatible v1 schema). Its disposition is a **separate** decision |

## 3. Options to evaluate

- **Option A** — formally designate `kbnmkyvbwkuvcklywdhk` as production, and create a separate test/development environment later.
- **Option B** — create a new clean production project, reproduce the backend there, migrate only intentionally retained data and configuration, switch the frontend, and keep `kbnmkyvbwkuvcklywdhk` as test/development or retire it.
- **Option C** — any materially better architecture supported by evidence. It is not forced if A and B cover the real options.

## 4. Questions to answer

D-1 … D-15, as assigned:
- **D-1 … D-5:** what designation would change; misleading labels; remaining production hardening; reproducibility today; migration requirements.
- **D-6 … D-10:** the burden removed by having no external users; which option minimizes risk and which minimizes work; long-term cleanliness; development/testing support.
- **D-11 … D-15:** costs and paid-plan dependencies; the GitHub Pages / Netlify impact; the Telegram idea; synthetic data; rollback paths.

The answers are in `decision-report.md`.

## 5. Read-only boundary

**Permitted:**
- repository and git inspection;
- read-only Supabase metadata, advisors and aggregate catalog/`SELECT` queries on `kbnmkyvbwkuvcklywdhk` (counts, categories, timestamps only);
- read-only checks that the Phase 22.1 state of `edxicnafggnnvcdvxemk` is intact;
- read-only Netlify metadata;
- public HTTPS `GET` of the live URLs;
- Supabase documentation.

**Not permitted:**
- creating a Supabase project or branch;
- any schema or data migration;
- Auth, Storage, API-key or Edge Function changes;
- changes to `index.html`, Netlify, DNS or GitHub workflows;
- data cleanup or deletion;
- any mutation of either project;
- any cost-confirmation workflow that requires organization confirmation (identified only);
- commit, push or PR.

**Privacy:** no keys, tokens, emails, user identifiers or row content are recorded; counts and metadata only.

## 6. Acceptance / exit criteria

1. D-1 … D-15 answered with cited evidence, or marked UNKNOWN with the reason.
2. A decision matrix comparing the options on the assigned dimensions, without arbitrary numeric scoring.
3. A technical recommendation that separates facts from judgment and states the strongest argument against it.
4. A statement of whether the decision blocks completion of the STAGERZ foundation, evaluated against planned UI, feature, integration and backend work.
5. Verified: no Supabase, Netlify or application mutation; Phase 22.1 legacy state intact; live project unchanged; no secrets or personal data recorded.
6. The owner has reviewed the package and taken (or deferred) the decision. `PROJECT_CONTEXT.md` records the outcome. This happens after review.

**Outcome (2026-09-19): criteria 1–6 all MET.** Option A approved by the owner. Closeout validation (read-only):
- live backend unchanged: 43 migrations, latest `20260917143322`;
- Phase 22.1 legacy state intact;
- no Supabase, Netlify, application, workflow or DNS change;
- no secrets or personal data recorded.

## 7. Non-goals

- Implementing any option.
- Deciding the disposition of `edxicnafggnnvcdvxemk`, although its effect on the free-project limit is noted.
- Changing the "TEST ONLY" labels (identified only).
- Product decisions such as Telegram integration.
- Remediating the open data-integrity item (2 `collaboration_assets` rows with missing Storage objects) or any Advisor finding.
