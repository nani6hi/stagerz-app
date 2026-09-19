# Phase 22.0 — Production Environment Confirmation

**Branch:** `phase-22.0-production-environment-confirmation`, created from `main` @ `0c170ed2d88ba6ce1b101850f881e3892d75b97d`
**Assigned:** 2026-09-19 by the product owner, as the next regular APOS phase after Phase 21.3.
**Roadmap origin:** Phase 20.7 roadmap item "Production environment confirmation" (`analysis/phase-20.7/codebase-assessment.md` §6, execution order 4, register items **H-1** and **R-4**). The number 21.4 that roadmap proposed was later used for the S-1 remediation, so this phase is numbered 22.0.
**Mode:** **investigation only, strictly read-only.**
**Status:** **COMPLETE / PASS (2026-09-19). Classification: C — MIXED / LEGACY ENVIRONMENT**, accepted by the product owner.
- PASS means the investigation objective was achieved and all exit criteria in §6 are met (results in `investigation-report.md` §8.2).
- It does **not** mean the environment architecture is acceptable long-term, and it does **not** resolve findings LG-1 … LG-5, which remain **OPEN**.
- The immediate recommended follow-up is a separately scoped legacy-project containment / security phase for `edxicnafggnnvcdvxemk` (not yet numbered; `investigation-report.md` §8.5).

The sections below are the phase definition as written at assignment.

---

## 1. Objective

Establish from evidence, not labels, what Supabase environment STAGERZ actually uses, and classify project `kbnmkyvbwkuvcklywdhk` as exactly one of:

| Class | Meaning |
|---|---|
| **A** | Confirmed production |
| **B** | Confirmed test / development |
| **C** | Mixed / legacy environment |
| **D** | Insufficient evidence |

## 2. The known contradiction

- `index.html` calls `kbnmkyvbwkuvcklywdhk` and labels the auth flow "TEST ONLY — disposable project".
- `.apos/PROJECT_CONTEXT.md` records Phases 21.6–21.8B against that project as "COMPLETE IN PRODUCTION".
- The O-1/O-2/O-3 and R-5 records call the same project the "test project".
- No separate production Supabase project is documented, and the Phase 20.7 open question (H-1 / R-4) was never answered.

The answer may reorder or change the safety assumptions of all later roadmap work.

## 3. Read-only boundary

**Permitted:**
- repository and git-history inspection;
- public HTTPS `GET` of the deployed pages;
- DNS lookup;
- read-only Supabase metadata and aggregate `SELECT`s (counts, dates, categories);
- read-only Netlify site and deploy metadata.

**Not permitted:** any Supabase write (DDL, DML, migrations, Auth, Storage, Edge Function deploys or invocations); any Netlify change or redeploy; any application-code change; remediation of the 2 `collaboration_assets` rows with missing Storage objects; cleanup of legacy or synthetic data; access to or exposure of secrets.

**Privacy rule:** analysis files record counts, schema characteristics, timestamps and configuration metadata only — never emails, tokens, keys, user identifiers, names, message bodies or other row content.

**Standing target rule:** the other Supabase project in the account, `edxicnafggnnvcdvxemk` ("stagerz-app"), is covered by an earlier "never target" instruction. Only account-level metadata (name, region, status, creation date) was read for it. Its database was **not** queried; that would need separate approval.

## 4. Evidence sources

1. **Current repository:** `index.html`, `.apos/*`, `.github/workflows/*`, `supabase/functions/*`, `CNAME`, `.gitignore`, `README.md`, and all `analysis/*`.
2. **Git history:** all 292 commits on all refs, including every historical `index.html`.
3. **Public deployment:** the HTTP responses of `https://stagerz.app` and `https://aquamarine-puppy-beccd9.netlify.app`, plus DNS for `stagerz.app` and `www.stagerz.app`.
4. **Supabase (read-only):**
   - account project list;
   - project metadata;
   - migration history;
   - Edge Function list;
   - publishable-key match (compared, not recorded);
   - aggregate SELECTs on `auth`, `public` and `storage`.
5. **Netlify (read-only):** site metadata and the current production deploy record.

## 5. Investigation questions

| # | Question |
|---|---|
| Q1 | Which Supabase project(s) does the deployed frontend call, on every public surface? |
| Q2 | Can any configuration (environment variables, build step, second config) override the hard-coded project? |
| Q3 | Has STAGERZ ever used a different Supabase project, and when did that change? |
| Q4 | How was `kbnmkyvbwkuvcklywdhk` created, named and described at creation time? |
| Q5 | What is the character of its data: real usage, synthetic fixtures, or seed content (counts only)? |
| Q6 | Do its Edge Functions and migrations correspond to repository work? |
| Q7 | Is Auth configured toward a live deployment (redirect target, email flow)? |
| Q8 | Is any other backend or environment documented or observable? |
| Q9 | Given Q1–Q8, which class (A/B/C/D) does the evidence support, and with what confidence? |

## 6. Acceptance / exit criteria

Phase 22.0 is complete when **all** of these hold:

1. Q1–Q9 are each answered with cited evidence, or explicitly marked UNKNOWN with the reason.
2. An evidence matrix records source, location, current vs historical status, what the item supports, and its reliability.
3. Exactly one class (A/B/C/D) is proposed, with strongest evidence, contradicting evidence, unknowns and confidence.
4. The implications for later work (documentation, configuration, migration) are described **without being performed**.
5. No Supabase, Netlify or application mutation occurred, and no secret or personal data was recorded.
6. The product owner has reviewed and accepted the classification, and `PROJECT_CONTEXT.md` has been updated to reflect the accepted answer. This last step comes after review, not in this preparation.

## 7. Unknowns at the start

- The owner's intent for `kbnmkyvbwkuvcklywdhk`.
- Whether real external users exist.
- Auth site URL, redirect allow-list, email template and SMTP configuration.
- The state and role of `edxicnafggnnvcdvxemk`.
- The Supabase plan tier and the backup / point-in-time-recovery posture.

## 8. Explicit non-goals

Phase 22.0 does **not**:
- migrate, clone, rename or reconfigure any project;
- change the "TEST ONLY" comments or the auth flow in `index.html`;
- create a production project;
- clean synthetic or legacy data;
- remediate the 2 `collaboration_assets` rows with missing Storage objects;
- act on the legacy accepted applications, the notification → Applicants routing issue, the absent Content-Security-Policy, the optional R-5 follow-ups or any other Phase 20.7 roadmap item.

Each of those needs its own approved phase or decision.
