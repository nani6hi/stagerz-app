# Project Context

Confirmed stable facts only. Anything not established is marked **unknown** rather than inferred.

---

## Identity

| Field | Value |
|---|---|
| Project name | STAGERZ |
| Process | APOS |
| Role of this project | STAGERZ is the APOS reference implementation |
| Current APOS phase of record | Phase 20.3 — Message Load Failure Visibility |

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
| Deployment | GitHub Pages |
| Production branch | `main` |
| Current development branch | `phase-20.1-optimistic-ui` |

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

### Planned phase sequence

| Phase | Title | Status |
|---|---|---|
| 20.1 | Optimistic Message Sending | Merged to `main` (PR #1) |
| 20.2 | Messaging Hardening | Merged to `main` (PR #2) |
| 20.3 | Message Load Failure Visibility | Current phase of record |
| 20.4 | Remove NACKL from the Full Web App | Planned |

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

STAGERZ is the APOS reference implementation: a single-page application contained primarily in `index.html`, deployed to GitHub Pages from the `main` branch, with development currently on `phase-20.1-optimistic-ui`. ChatGPT owns architecture, governance, reviews, and approval; Claude Code performs analysis and approved implementation; the user is the final authority for source changes and commits. Analysis output lives under `analysis/<phase>/` and governance rules under `.apos/`. Items listed under **Unknown** above are deliberately unrecorded rather than inferred.
