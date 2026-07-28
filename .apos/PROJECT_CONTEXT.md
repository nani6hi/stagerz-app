# Project Context

Confirmed stable facts only. Anything not established is marked **unknown** rather than inferred.

---

## Identity

| Field | Value |
|---|---|
| Project name | STAGERZ |
| Process | APOS |
| Role of this project | STAGERZ is the APOS reference implementation |
| Current APOS phase of record | Phase 20.6 — Remove Telegram Runtime from Full Web App |
| Current phase status | Implementation complete; static verification passed; local pre-merge browser validation passed; committed and pushed to `phase-20.6-remove-telegram-runtime`; **not merged — authenticated production validation outstanding** (`analysis/phase-20.6/phase-definition.md` §15) |

---

## APOS Phases

| # | Phase |
|---|---|
| 0 | Project Initialization |
| 1 | Requirements Analysis |
| 2 | Architecture Review |
| 3 | ADR |
| 4 | Technical Specification |
| 5 | Implementation Plan |
| 6 | Task Specification |
| 7 | Implementation |
| 8 | Documentation Update |
| 9 | Review Support |
| 10 | Release Preparation |
| 11 | Maintenance |

---

## Application

| Field | Value |
|---|---|
| Main application file | `index.html` |
| Architecture | Single-page application, contained primarily in `index.html` |

---

## Repository and Deployment

| Field | Value |
|---|---|
| Repository remote | https://github.com/nani6hi/stagerz-app.git |
| Deployment | GitHub Pages, serving the `main` branch directly (no `.github/workflows`, no `netlify.toml`) |
| Production domain | `stagerz.app` (`CNAME`) |
| Pull-request previews | **None.** GitHub Pages provides no per-PR preview environment. Pre-merge Level 3 validation runs against a local server on `localhost`; authenticated flows that depend on the Supabase magic-link redirect to `https://stagerz.app` can only be validated after merge and deployment |
| Production branch | `main` |
| Current development branch | `phase-20.6-remove-telegram-runtime` |

---

## Roles and Authority

| Actor | Responsibility |
|---|---|
| **ChatGPT** | Architecture, governance, reviews, implementation approval |
| **Claude Code** | Analysis and approved implementation |
| **User** | Final authority for source changes and commits |

---

## Directory Conventions

| Path | Contents |
|---|---|
| `analysis/<phase>/` | Analysis results |
| `.apos/` | Governance rules |

---

## Product Roadmap Decisions

Permanent product decisions. These constrain scope regardless of what the code currently contains.

### NACKL is excluded from the current full web app

**Decision:** NACKL does not belong in the current full STAGERZ web application.

NACKL was intended for a later, reduced **Light version**, after the real full app/web version is established. The NACKL implementation currently present in `index.html` is **premature** and creates unnecessary runtime errors, state, and maintenance burden inside the main app.

Consequences:

- Do **not** repair `nacklVal` as a standalone cosmetic fix.
- Do **not** expand NACKL.
- Do **not** integrate NACKL further into Profile or any other module.
- Complete removal of NACKL from the current full web app is scheduled as **Phase 20.4**.
- The NACKL product idea is **preserved as a deferred concept for a future Light version**.

**Removal from the full app does not mean deletion of the product idea.** It means the idea returns in the Light version, on purpose, rather than persisting here by accident.

### Telegram runtime integration is excluded from the current full web app

**Decision:** Telegram Mini App / Telegram-specific runtime integration does not belong in the current full STAGERZ web application.

Like NACKL, it is preserved as a concept for a future STAGERZ Light / Mini App version. Removal from the full app does **not** mean deletion of the product idea.

**Product-owner decision recorded 2026-07-28 (resolves the Phase 20.6 prerequisite gate):**

> STAGERZ is currently being developed as an **independent web application**. The current product must be built, tested, and completed **without any Telegram dependency or Telegram-specific runtime behavior**. A separate Telegram light version may be developed later, **only after** the main web application is technically complete, stable, and user-friendly. The existing Telegram Mini App configuration is **not part of the currently supported product scope and must not block this removal**.

Scope boundary: Phase 20.6 removes the Telegram runtime **from this repository only**. External BotFather / Telegram Mini App configuration is deliberately **not** inspected or modified by this phase.

Telegram removal is deliberately **not** bundled with NACKL removal. NACKL is fully repository-provable and isolated; Telegram's true impact depends on whether an external Mini App entry point exists — configuration outside this repository — and `haptic()` has 28 call sites. The sequence below separates the two so a zero-risk cleanup is not blocked behind an unverifiable one.

**Call-site count of record: 28.** Pre-20.5 documentation recorded `haptic(` as occurring 29 times (1 definition + 28 calls). Phase 20.5 added three explanatory comment mentions, so the current raw count in `index.html` is **32** = 28 call sites + 1 function definition + 3 comment mentions. The number of **executable call sites is unchanged at 28**.

### Locked removal sequence

| Phase | Title | Scope |
|---|---|---|
| **20.4** | **Remove Premature NACKL Integration** | **Completed** — merged in Pull Request #4 (`31dc073af588d1664d0991b98e6b0995d5174660`). All NACKL UI, CSS, and JavaScript removed; misleading NACKL feature claim removed; `nacklVal is not defined` ReferenceError eliminated |
| **20.5** | **Evaluate and Isolate Telegram Runtime** | **Completed** — merged in Pull Request #5 (`155b029cdfcd752104849f1d52f84c0aa645ce61`). Every Telegram runtime reference collapsed into one contiguous, marker-delimited compatibility block (`index.html` 962–1001); `tg` renamed to `telegramWebApp`; single detection point; `haptic()` given a documented platform-agnostic contract. No behavior change, no call site changed |
| **20.6** | **Remove Telegram Runtime from Full Web App** | **Complete Telegram runtime removal, including all 28 `haptic(...)` call sites.** Remove the Telegram SDK script tag (line 8), the compatibility block (962–1001) with `window.Telegram`, `telegramWebApp`, `ready()`, `expand()`, `HapticFeedback`, and the `haptic()` function, plus every `haptic(...)` call site and all Telegram-specific comments. Deletion only — no substitute (no `navigator.vibrate`, no sound, no animation). Preserve authentication, sessions, identity, navigation, messaging, and all collaboration workflows unchanged |

### Final intended full-app architecture

On completion of Phase 20.6, the current full STAGERZ web application will have:

- no NACKL runtime;
- no Telegram SDK;
- no Telegram initialization;
- no Telegram haptics;
- normal browser runtime only;
- Supabase-only authentication and session management.

NACKL and Telegram are preserved **only as future Light-version concepts**. The full web app must remain fully functional using normal browser and Supabase behavior alone.

**Achieved in the working tree (pending Level 3 validation and commit).** `index.html` now contains **zero** occurrences of `telegram`, `window.Telegram`, `telegramWebApp`, `HapticFeedback`, `ready()`/`expand()` Telegram initialization, and `haptic` in any form. `index.html` is the only file in the repository containing executable code, so **the main web app is Telegram-independent.** Details in `analysis/phase-20.6/phase-definition.md` §14.

### Guardrail — a future Telegram Light version must not reintroduce coupling

**Any future Telegram light version must be implemented separately and must not silently reintroduce runtime coupling into the main web application.**

Binding rules:

1. **Separate delivery artifact** — its own entry point, build target, or repository. **Not** a conditional branch inside the main app's `index.html`.
2. **No conditional platform code in the main app** — no `if (window.Telegram)`, no platform sniffing, no "harmless" SDK script tag, no `haptic()`-style wrapper kept "just in case". A guard that is inert today is still coupling.
3. **No shared mutable runtime** — reusing Supabase schema and API contracts is fine; requiring the main app to carry Telegram-aware code is not.
4. **Sequencing is fixed** — Light-version work begins only after the main web application is technically complete, stable, and user-friendly.
5. **Explicit governance** — reintroducing any Telegram runtime into the main app requires a new APOS phase and a recorded reversal of this roadmap decision. It may not arrive as an incidental part of unrelated work.

Phases 20.4, 20.5, and 20.6 exist because Telegram and NACKL runtime code accumulated inside the main app without a boundary. The removed implementation is preserved in git history at `155b029cdfcd752104849f1d52f84c0aa645ce61` and documented in `analysis/phase-20.5/phase-definition.md`, so the Light version can recover it deliberately from a clean base.

### Phase history

| Phase | Title | Status |
|---|---|---|
| 20.1 | Optimistic Message Sending | Merged to `main` (PR #1) |
| 20.2 | Messaging Hardening | Merged to `main` (PR #2) |
| 20.3 | Message Load Failure Visibility | Merged to `main` (PR #3) |
| 20.4 | Remove Premature NACKL Integration | Merged to `main` (PR #4) |
| 20.5 | Evaluate and Isolate Telegram Runtime | Merged to `main` (PR #5) |
| 20.6 | Remove Telegram Runtime from Full Web App | **Current phase** — implementation complete; 69 lines deleted + 1 in-place edit in `index.html`; SDK script, compatibility block, and all 28 `haptic(...)` call sites removed; static verification passed; local pre-merge browser validation passed; pushed to `phase-20.6-remove-telegram-runtime`; **not merged — authenticated production validation outstanding** |

### Phase 20.6 prerequisite — RESOLVED

Phase 20.6 carried one gate that this repository could not answer:

> Does a live external Telegram Bot / Mini App entry point exist that points at STAGERZ, and do real users currently open the app inside Telegram?

**Resolved by the product-owner decision recorded above (2026-07-28):** the existing Telegram Mini App configuration is outside the currently supported product scope and does not block removal. Implementation proceeded on that basis. Full record at `analysis/phase-20.6/phase-definition.md` §13.1.

---

## Governance Gates

- Source changes require explicit approval.
- Commits require successful validation **and** explicit user approval.
- Validation procedure is defined in `.apos/VALIDATION_STANDARD.md`.

---

## Unknown

The following are **not** established and must not be assumed:

- APOS acronym expansion — unknown.
- Release procedure beyond "deployed via GitHub Pages from `main`" — unknown.
- Runtime dependencies, backend services, and third-party integrations — unknown from this document's scope.
- Branching and merge policy (how development branches reach `main`) — unknown.
- Definitions of the individual APOS phase deliverables — unknown.

---

## Summary

STAGERZ is the APOS reference implementation: a single-page application contained primarily in `index.html`, deployed to GitHub Pages from the `main` branch, with development currently on `phase-20.6-remove-telegram-runtime`. ChatGPT owns architecture, governance, reviews, and approval; Claude Code performs analysis and approved implementation; the user is the final authority for source changes and commits. Analysis output lives under `analysis/<phase>/` and governance rules under `.apos/`. Items listed under **Unknown** above are deliberately unrecorded rather than inferred.
