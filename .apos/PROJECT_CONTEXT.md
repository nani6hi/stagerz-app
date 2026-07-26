# Project Context

Confirmed stable facts only. Anything not established is marked **unknown** rather than inferred.

---

## Identity

| Field | Value |
|---|---|
| Project name | STAGERZ |
| Process | APOS |
| Role of this project | STAGERZ is the APOS reference implementation |
| Current APOS phase of record | Phase 20.2 — Messaging Hardening |

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
