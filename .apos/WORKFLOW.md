# Project Workflow

Agreed working agreement for the STAGERZ project. Applies to all phases.

Relocated from `analysis/WORKFLOW.md` — governance rules belong under `.apos/`.

---

## Roles

| Actor | Responsibilities |
|---|---|
| **ChatGPT** | Architecture, APOS governance, reviews, implementation approval |
| **Claude Code** | Analysis, and implementation *after* approval |
| **User** | Grants approval; final authority on all source changes and commits |

ChatGPT decides *what* and *whether*. Claude Code investigates and executes. Neither role crosses into the other without an explicit handoff.

---

## Phase Sequence

```
Architecture / governance   →  ChatGPT
        ↓
Analysis (read-only)        →  Claude Code  →  analysis/<phase>/*.md
        ↓
Review + approval           →  ChatGPT / User
        ↓
Implementation              →  Claude Code
        ↓
Validation                  →  Claude Code
        ↓
Commit                      →  after validation AND explicit user approval
        ↓
Push / release              →  separate, optional step (see below)
```

---

## Analysis Rules

Analysis is strictly read-only investigation. When an analysis is requested:

- **Never modify application source code.**
- **Never create commits.**
- Write results as Markdown into `analysis/`, under a phase subdirectory (e.g. `analysis/phase-20.1/`).
- Use a descriptive filename based on the topic.
- Do not propose or apply edits in the same turn unless explicitly asked.

### Required document structure

1. Objective
2. Findings
3. File locations
4. Function names
5. Risks
6. Recommendations
7. Short summary

Keep every section present even when brief.

---

## Design and Scope Rules

Two standing rules govern what gets built and how. They apply to analysis, planning, and implementation alike.

### Pattern decision rule — Reuse → Extend → Create

Before introducing a new pattern:

1. **Reuse** an existing pattern if it already solves the problem.
2. **Extend** an existing pattern if the requirement is closely related.
3. **Create** a new pattern only when reuse or extension would produce incorrect or confusing behavior.

State which of the three was chosen, and why, whenever a new pattern is introduced.

### STAGERZ scope rule

A feature belongs in the current roadmap only if it directly helps a team complete a project, or removes a concrete reliability problem from that workflow.

Ideas that do not satisfy this rule must be documented for a later phase instead of being added to the current implementation scope. Recording an idea is not deferring it forever — it is keeping the current phase coherent.

---

## Implementation Rules

- **Source code changes require explicit user approval.** An approved analysis is not itself approval to edit.
- Implement only the approved scope — no opportunistic refactors, no widened scope.
- Follow the approved implementation exactly as specified.

### Stop-and-report rule

If an approved implementation **cannot be followed exactly** — the plan conflicts with the actual code, a referenced construct does not exist, a step would break something, or the approved approach turns out to be unworkable — then:

1. **Stop.** Do not improvise, substitute an alternative approach, or partially apply the plan.
2. Leave the working tree in a clean, known state.
3. Report precisely: which step could not be followed, what was found instead, and what options exist.
4. Wait for a new decision before continuing.

Deviating silently from an approved plan is never acceptable, even when the deviation looks like an improvement.

---

## Reporting Rules

Every report must be accurate and verifiable:

- State plainly what was **created, modified, moved, or deleted** — by exact path.
- Explicitly confirm which files were **not** modified when that matters.
- If validation fails, say so and include the actual output. Never describe unvalidated work as working.
- If a step was skipped, blocked, or only partially completed, say so and say why.
- Distinguish **verified facts** from **assumptions** and mark unknowns as unknown.
- Do not claim completion until the work is genuinely finished.

---

## Commit Rules

- **Commits require successful validation AND explicit user approval.** Both, not either. Successful validation is defined by `.apos/VALIDATION_STANDARD.md`.
- No commits during analysis, ever.
- No commits on unvalidated or partially-working changes.
- Do not bypass repository safeguards.

---

## Push / Release

Pushing and releasing are a **separate, optional step performed after a commit exists** — never bundled into the commit step and never automatic.

- Requires its own explicit user approval.
- A commit being approved does not imply approval to push.
- The production branch is `main`; deployment is via GitHub Pages, so a push to `main` is a production release and must be treated as such.

---

## Summary

ChatGPT owns architecture, governance, and approval. Claude Code performs read-only analysis into `analysis/`, then implements only once approved, stopping to report whenever the approved plan cannot be followed exactly. Analysis never touches source and never commits; source changes need explicit approval; commits require both successful validation and explicit user approval; pushing and releasing are a separate optional step requiring approval of their own.
