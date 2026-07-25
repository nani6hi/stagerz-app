# Validation Standard

Defines what "validated" means for STAGERZ under APOS. Referenced by the commit gate in `.apos/WORKFLOW.md`.

---

## 1. Purpose

To establish a single, unambiguous definition of successful validation, so that "validation passed" is a verifiable claim rather than an opinion.

Validation exists to confirm three things before any change is committed:

- The **approved scope** was implemented — exactly, and nothing more.
- The change **works**, on both its success path and its failure path.
- The repository is in a **clean, intended state**.

No commit may be justified by "it looks correct." Every commit is backed by a validation report.

---

## 2. Validation Levels

Levels are cumulative: each level assumes the ones below it have passed.

| Level | Name | What it establishes |
|---|---|---|
| **1** | Static review | The code is correct by inspection — approved scope, no syntax errors, no unrelated changes, diff reviewed |
| **2** | Targeted functional validation | The specific changed behavior works, including its failure and rollback path |
| **3** | Browser validation | The change behaves correctly in the running application, in a real browser |
| **4** | Release validation | The change is safe to deploy to production |

**Selecting a level.** Documentation and governance changes may stop at Level 1. Any change to `index.html` that affects behavior requires Level 3. Level 4 applies only when a release to `main` is proposed. When in doubt, escalate a level — never silently drop one.

---

## 3. Required Checks Before Commit

All of the following must pass. A commit is not permitted while any check is unmet or unverified.

| # | Check |
|---|---|
| 1 | Approved scope implemented |
| 2 | No unrelated refactors |
| 3 | No syntax errors |
| 4 | No unintended file changes |
| 5 | Relevant success path tested |
| 6 | Relevant failure and rollback path tested |
| 7 | Git branch verified |
| 8 | Git diff reviewed |
| 9 | Validation results documented |
| 10 | ChatGPT review completed |
| 11 | Explicit user approval received |

Checks 1–9 are performed by Claude Code. Check 10 is ChatGPT's. Check 11 is the user's alone and cannot be inferred, assumed, or substituted.

---

## 4. Browser Validation

Level 3. Perform each item **where relevant** to the change; explicitly record any item as *not applicable* rather than omitting it silently.

- No unexpected console errors
- No duplicate UI entries
- Correct immediate UI behavior
- Correct success reconciliation
- Correct failure rollback
- No whole-area loading flash unless explicitly approved
- Relevant slow-network behavior
- Relevant offline or failed-request behavior

Duplicate UI entries and reconciliation correctness matter most where a local update and a server or realtime update can both write the same region.

---

## 5. Git Validation

- Correct feature branch
- No direct implementation work on `main`
- Only approved files changed
- Untracked files reviewed
- No commit before validation passes
- No push without separate approval

Untracked files are reviewed, not ignored: an unexpected untracked file is a finding.

---

## 6. Review and Approval

Two distinct gates, in order, neither optional:

1. **ChatGPT review** — architecture, governance, and scope conformance. Confirms the implementation matches what was approved.
2. **Explicit user approval** — the user is the final authority for source changes and commits.

Approval is scoped to what was reviewed. Approval of an analysis is not approval to implement; approval of an implementation is not approval to commit; approval of a commit is not approval to push. Silence is never approval.

---

## 7. Commit Gate

A commit may be created **only when all** of the following hold:

- All required checks in Section 3 pass.
- The validation level appropriate to the change has passed.
- A validation report (Section 10) exists.
- ChatGPT review is complete.
- Explicit user approval has been received.

Additionally: no commits during analysis, ever. No commits on unvalidated or partially-working changes. Do not bypass repository safeguards.

If any condition is unmet, the correct action is to report — not to commit and flag it afterwards.

---

## 8. Push and Release Gate

Pushing is a **separate, optional step after a commit exists**. It is never automatic and never bundled into the commit step.

- Requires Level 4 release validation.
- Requires its own explicit user approval, distinct from the commit approval.
- `main` is the production branch and deploys via GitHub Pages — **a push to `main` is a production release** and must be treated as one.

---

## 9. Failure Handling

When a required validation fails:

1. **Stop.** Do not continue to the next step.
2. **Do not commit.**
3. **Do not silently change the approved design** — no substitute approach, no workaround, no partial application.
4. **Report** the exact failed check, the observed behavior, the affected files, and the recommended next decision.
5. **Preserve the working tree for review** unless explicitly instructed otherwise. Do not revert, reset, stash, or clean.

A failed validation is information, not an obstacle to route around.

---

## 10. Validation Report Format

Every validation produces a report with these sections:

| Section | Contents |
|---|---|
| **Scope** | What was approved and implemented |
| **Files changed** | Exact paths |
| **Checks performed** | Which checks ran, at which level |
| **Results** | Outcome per check — pass / fail / not applicable |
| **Failures or limitations** | What failed, what could not be verified, what was out of scope |
| **Git status** | Branch and working tree state |
| **Commit recommendation** | Commit / do not commit, with reasoning |
| **Release recommendation** | Push / do not push, with reasoning |

State results as observed. An unverified check is reported as unverified, never as passed.

---

## 11. Summary

Validation for STAGERZ runs at four cumulative levels — static review, targeted functional validation, browser validation, and release validation — with the level chosen to match the change and escalated when uncertain. Eleven checks must pass before a commit, ending in ChatGPT review and explicit user approval, neither of which may be assumed. Browser validation covers console errors, duplicate entries, immediate behavior, success reconciliation, failure rollback, unapproved loading flashes, and slow or failed network conditions. Git validation confirms branch, scope, and untracked files, and forbids committing before validation or pushing without separate approval. On any failure: stop, do not commit, do not alter the approved design, report precisely, and preserve the working tree. Every validation ends in a report carrying scope, files, checks, results, failures, git status, and explicit commit and release recommendations.
