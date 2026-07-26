# Phase 20.3 — Message Load Failure Visibility

**Branch:** `phase-20.3-scope-analysis` (analysis/definition); implementation branch to be named separately
**Base commit:** `7cacc943339b915aaaf8d88e8d8ee25e7a1ee159` (`main`, merge of Pull Request #2)
**Status:** Scope locked. No application code written.

---

## Problem statement

`loadCollaborationMessages()` currently treats two fundamentally different results identically:

1. a **successful** request returning an empty array, and
2. a **failed** request returning `null`.

Both render the same thing:

```
No messages yet.
```

`supaSelect()` returns `null` on a non-ok HTTP response (`index.html:1013`) and on a network error (`index.html:1017`). The loader's single guard — `if(!messages || !messages.length)` (`index.html:3357`) — collapses both into the empty state.

**The user-visible consequence:** an existing conversation can appear erased when the request merely failed. After Phase 20.1 made sending feel instant and Phase 20.2 made failure recoverable, this is the remaining case where the messaging screen actively misreports reality.

**Phase 20.3 must ensure that the messaging screen does not lie about whether a conversation is empty.**

---

## State model

The loader must distinguish five states. Only the first three exist today; the last two are the phase.

| # | State | Condition | Today | Required |
|---|---|---|---|---|
| 1 | **Loading** | Request in flight, initial load | "Loading…" placeholder | Unchanged |
| 2 | **Successful empty** | HTTP 200, `[]` | "No messages yet." | **Unchanged** |
| 3 | **Successful populated** | HTTP 200, rows | Rows rendered, ascending | **Unchanged** |
| 4 | **Failed initial load** | `supaSelect()` → `null`, nothing rendered yet | "No messages yet." — **wrong** | Distinct load-failure state |
| 5 | **Failed reload, data visible** | `supaSelect()` → `null`, rows already on screen | "No messages yet." — **destroys history** | Rows preserved, failure surfaced minimally |

States 4 and 5 are distinct problems with distinct correct answers. State 4 has nothing to protect and needs an honest error. State 5 has visible conversation history that must survive.

**A global stale-data architecture is not part of this phase.** State 5 requires only that existing rows are not destroyed — not a general staleness model, cache, or freshness indicator.

---

## Exact scope

Only `loadCollaborationMessages()` is in scope.

### Initial successful empty load

- Preserve the existing `No messages yet.` state.
- Do not show an error.
- Do not change B26 behavior.

### Initial failed load

- Do **not** render `No messages yet.`
- Render a distinct, minimal message-load failure state.
- Do **not** invent a retry button, toast, modal, queue, or global error component.
- Do **not** claim the conversation is empty.

### Failed reload with existing rendered messages

- Preserve the existing rendered message rows.
- Do **not** replace them with `No messages yet.`
- Do **not** replace them with a full-area Loading state.
- Do **not** clear the message list.
- Expose failure minimally, without destroying currently visible conversation history.

---

## In-scope functions

| Function | Line(s) | Nature of change |
|---|---|---|
| `loadCollaborationMessages(collaborationId, options)` | 3345–3388 | Distinguish `null` from `[]`; preserve rows on failed reload |
| Minimal local helper or local state | — | Only if strictly required by that one loader |

**Reference locations (read, not modified):**

| Concern | Line(s) |
|---|---|
| `supaSelect()` null returns | 1013, 1017 |
| "Loading…" placeholder (`skipLoadingState`-gated) | 3348 |
| Message fetch | 3350–3354 |
| **The conflating guard** | 3357 |
| "No messages yet." placeholder | 3358 |
| Full list replace before render | 3377 |
| Render loop via shared renderer | 3378–3380 |
| Scroll to bottom | 3382 |
| Placeholder removal on provisional insert | 3474–3476 |
| Reload call sites (send / edit / delete / cancel / realtime) | 3601, 3527, 3547, 3567, 4038 |

**Do not pre-authorize changes to the other loaders.** The nine sibling loaders share the same defect and are explicitly excluded.

---

## Acceptance criteria

Observable PASS/FAIL only. No criterion may be satisfied by code inspection alone.

### A. Successful populated conversation

| # | Criterion | PASS |
|---|---|---|
| A1 | Existing messages render normally | all rows present |
| A2 | Current ascending render order unchanged | oldest first, as today |
| A3 | No new duplicate appears | one row per message |
| A4 | Send behavior unchanged | Phase 20.1/20.2 behavior intact |
| A5 | Edit behavior unchanged | edit opens, saves, reloads |
| A6 | Delete behavior unchanged | row disappears, no stale row |

### B. Genuine empty conversation

| # | Criterion | PASS |
|---|---|---|
| B1 | HTTP 200 with empty result shows `No messages yet.` | placeholder shown |
| B2 | B26 first-message behavior unchanged | unchanged |
| B3 | First provisional insertion removes the empty placeholder | no residue |
| B4 | Reconciliation produces exactly one confirmed message | exactly one row |

### C. Initial fetch failure

| # | Criterion | PASS |
|---|---|---|
| C1 | Failed request does not display `No messages yet.` | empty state absent |
| C2 | A distinct message-load error state appears | error state visible |
| C3 | No false empty state is shown | no "empty" claim |
| C4 | No message row is invented | zero rows rendered |

### D. Failed reload after messages are visible

| # | Criterion | PASS |
|---|---|---|
| D1 | Existing rows remain visible | all prior rows present |
| D2 | The list is not cleared | no wipe |
| D3 | No full-area Loading replacement appears | no Loading flash |
| D4 | No false empty state appears | no "No messages yet." |
| D5 | Failure represented without destroying visible data | failure visible, history intact |

### E. Recovery

| # | Criterion | PASS |
|---|---|---|
| E1 | A later successful load replaces the failure state appropriately | error state cleared |
| E2 | Populated results render normally | rows render |
| E3 | Empty successful results show the genuine empty state | `No messages yet.` |
| E4 | No manual page reload required | recovery without reload, unless technically unavoidable **and** explicitly justified in the validation report |

### F. Regression

| # | Criterion | PASS |
|---|---|---|
| F1 | Phase 20.1 optimistic UI functional | provisional row, no flash, one confirmed row |
| F2 | Phase 20.2 send guard functional | non-active → no RPC, no provisional row |
| F3 | Phase 20.2 failed-send rollback functional | text preserved per the two-newline rule |
| F4 | Completed collaboration read-only behavior functional | composer hidden, notice shown |
| F5 | No new collaboration-messaging console error | clean apart from known pre-existing entries |

**Known pre-existing console entries, excluded from F5:** the `nacklVal` ReferenceError and the Telegram HapticFeedback warnings. An entry counts against F5 only if its stack names a collaboration-messaging function.

---

## Non-goals

Explicitly out of scope:

- The other nine list/data loaders
- A unified application-wide error-state system
- Global stale-data handling
- Retry buttons
- Automatic retry
- Toast notifications
- Modals
- Queues
- New global components
- Backend changes
- Database changes
- Schema changes
- RPC changes
- RLS or policy changes
- Realtime architecture changes
- Collaboration message pagination
- Message ordering
- The current 200-message limit
- Message send behavior
- Optimistic insertion
- Reconciliation behavior beyond preserving rows on fetch failure
- Edit or delete behavior
- Unrelated styling
- NACKL repair
- NACKL removal
- `photo_url` security hardening
- Telegram warning maintenance
- Profile maintenance
- Deployment configuration

---

## Validation plan

**Level 3 authenticated runtime validation** is required, per `.apos/VALIDATION_STANDARD.md` §2.

**Environment:** Netlify deploy preview built from the implementation branch. The established workflow is: push the Phase 20.3 feature branch → open a Pull Request → Netlify creates the deploy preview through its GitHub integration. *(The integration is configured outside this repository, so it cannot be inferred from repository CI files; this is a note about where the configuration lives, not a limitation on preview availability.)*

Required test passes:

1. Successful populated load
2. Genuine empty load
3. Forced **initial** messages `GET` failure
4. Forced **reload/reconciliation** failure while rows are visible
5. Recovery after request blocking or offline mode is disabled
6. Active send / edit / delete regression
7. B26 regression
8. B27 regression
9. Console and network inspection

**Failure induction:** DevTools request blocking on the `collaboration_messages` GET, or an equivalent browser mechanism (offline mode mid-session). Blocking is preferred over offline for case 4, because it fails the read without disturbing the realtime socket.

**Network filters:** `collaboration_messages` (load path) and `rpc/create_collaboration_message` (send path), type Fetch/XHR, Preserve log, Disable cache.

**Data safety constraint:** do not alter production messages, ownership, collaboration status, or any other production data solely to manufacture a test state. If a required state is unavailable, record the affected criterion as **NOT VERIFIED** rather than creating it.

---

## Regression requirements

Phase 20.3 modifies the loader that every messaging flow depends on. Phase 20.1 and Phase 20.2 behavior is already runtime-validated and live in production; the purpose of this pass is to **confirm it remains intact after the loader change**. Each item must be re-confirmed, not assumed:

- Phase 20.1 optimistic send end-to-end (provisional row → exactly one confirmed row, no duplicate, no full-area Loading flash)
- Phase 20.2 non-active send guard (zero RPCs, no provisional row, Send button not left busy)
- Phase 20.2 failed-send rollback (empty input → verbatim restore; typed input → failed body, blank line, new text)
- Initial screen load still shows the existing "Loading…" state
- Edit and delete still function without a full-area flash
- Read-only collaborations still hide the composer
- Scroll still lands at the bottom after load

---

## Expected changed files

| File | Nature |
|---|---|
| `index.html` | Modified — `loadCollaborationMessages()` and any minimal local helper strictly required by it |
| `analysis/phase-20.3/phase-definition.md` | This document |
| `analysis/phase-20.3/validation-report.md` | To be created **after** runtime validation, not before |

---

## Backend / database impact

**None.** No backend, schema, RPC, RLS, policy, hosting, or deployment change. The phase is entirely client-side presentation of a result the client already receives.

---

## Relationship to Phase 20.1 and 20.2

| Phase | What it fixed | Remaining gap it left |
|---|---|---|
| 20.1 | Sending felt slow; the whole conversation flashed "Loading…" on every send | Send path had no status guard; failed-send could lose typed text |
| 20.2 | Non-active collaborations could still reach the send path; failed sends could discard the message body | Load failures still misreported as "empty" |
| **20.3** | **Load failures misreported as an empty conversation** | The other nine loaders share the defect — deferred |

Phases 20.1 and 20.2 both concerned the **send** path. Phase 20.3 is the first to address the **load** path, and it completes the messaging-reliability arc for the collaboration messages screen. It also establishes the loading / empty / error pattern that the remaining nine loaders may later adopt — proven first on the loader the team knows best.

**Validation status carried forward.** Phase 20.2 received complete authenticated manual runtime validation on the Netlify deploy preview before merge, documented in GitHub Pull Request #2 and merged into `main` as `7cacc943339b915aaaf8d88e8d8ee25e7a1ee159`. Verified results:

| Item | Result |
|---|---|
| Browser parse / load | PASS |
| Active collaboration regression | PASS |
| Objective 1 — restricted collaboration send guard | RUNTIME PASS |
| Objective 2 — failed-send concurrent typing preservation | RUNTIME PASS |
| B26 — genuine empty collaboration first-message flow | PASS |
| B27 — completed collaboration read-only behavior | PASS |
| New blocking collaboration-messaging console error | None |

Phases 20.1 and 20.2 are therefore fully validated and live in production. Phase 20.3 opens no validation debt and closes none: its regression pass (criteria F1–F5) exists to **confirm that this already-validated behavior remains intact after the loader change**, not to establish it for the first time.

---

## Phase 20.4 roadmap note — Remove NACKL from the Full Web App

**Recorded here; not implemented in Phase 20.3.**

**Purpose:** remove the prematurely included NACKL feature from the current full STAGERZ application while preserving it as a future Light-version concept.

**Product decision** (recorded permanently in `.apos/PROJECT_CONTEXT.md`): NACKL does not belong in the current full web app. It was intended for a later, reduced Light version, after the real full app/web version is established. Its present implementation is premature and creates unnecessary runtime errors, state, and maintenance inside the main app.

Therefore `nacklVal` will **not** be repaired as a standalone cosmetic fix, NACKL will not be expanded, and it will not be integrated further into Profile or other modules. Removal from the full app does **not** mean deletion of the product idea.

**Phase 20.4 must begin with a full read-only repository inventory before any removal.** That inventory must cover:

- all `nacklVal` references
- `tickNACKL()`
- the visible NACKL counter
- NACKL-related profile markup
- NACKL-specific CSS
- NACKL-specific navigation, event handlers, timers, storage, or backend references
- any indirect references using different capitalization
- documentation references that incorrectly imply NACKL belongs in the current full app

**Do not assume the two known `nacklVal` references are the complete NACKL footprint.** A preliminary read-only pass during Phase 20.3 scoping observed references beyond those two — including CSS rules, a keyframe animation, a profile stat element, and a feature-list mention — which is exactly why a full inventory precedes removal rather than following it.

---

## Implementation status

**Implemented. Statically validated. Runtime validation not yet performed.**

### Implemented behavior

- `supaSelect()` returning `null` (failed request) is now distinguished from `[]` (successful empty). The failure branch is evaluated **before** the empty-state branch, so a failed fetch can never render `No messages yet.`
- **Initial failure** (no rows on screen): the container is cleared of its placeholder and a single notice reading `Messages could not be loaded.` is rendered. No message row is invented.
- **Reload failure with rows visible**: the list is **not** cleared, replaced, or re-rendered. All confirmed and provisional rows remain exactly as they were, and one notice is appended below them.
- **Duplicate suppression**: the notice carries the stable id `cmLoadError`; if it already exists the helper returns immediately, so repeated failures never stack.
- **Recovery**: no special handling is required. A later successful populated load rebuilds the container (`listEl.innerHTML = ''`) and a successful empty load replaces it — either path removes the notice. No page reload, no stale placeholder, no duplicate notice.
- **Identity isolation**: the notice carries no `cmBodyText-` id, no `data-provisional-id`, and no `data-cm-placeholder`, so provisional insertion, placeholder removal, edit/delete lookups, and reconciliation all ignore it. Its text is a fixed literal; no fetched or user-provided content is ever placed in it.

### Exact changed code location

| Change | Location |
|---|---|
| Failure branch split from the empty branch | `index.html:3357-3366` |
| `showCollaborationMessagesLoadError(listEl)` helper | `index.html:3394-3421` |

Total: 38 insertions, 1 deletion in `index.html`, in two hunks. No CSS rule was added — the notice reuses the file's existing inline-style placeholder convention.

### Static validation result

| Check | Result |
|---|---|
| Only `index.html` changed (plus this definition) | PASS |
| No other loader changed | PASS |
| No NACKL source changed | PASS |
| `sendCollaborationMessage`, `saveMessageEdit`, `deleteMessagePrompt`, `beginEditMessage` byte-identical to `main` | PASS |
| `insertProvisionalCollaborationMessage`, `removeProvisionalCollaborationMessage`, `buildCollaborationMessageRow`, `allocateProvisionalId`, `buildProvisionalRenderModel` byte-identical | PASS |
| `supaSelect()` byte-identical | PASS |
| Fetch query and `limit=200` unchanged | PASS |
| `messages === null` distinguished from `messages.length === 0` | PASS |
| Failure handled before empty-state rendering | PASS |
| Helper defined exactly once; no duplicate function name in file | PASS |
| Notice text is a fixed literal — no injection surface | PASS |
| No new CSS rule; no change after `</style>` (line 294) | PASS |
| No formatting churn — 2 hunks only | PASS |
| JavaScript parses | **NOT VERIFIED** — no JS runtime available in the environment |

### Runtime validation still required

Level 3 authenticated runtime validation on a Netlify deploy preview has **not** been performed. All of acceptance criteria A–F remain unverified, including recovery (E) and the Phase 20.1/20.2 regression pass (F). **No runtime PASS is claimed for any Phase 20.3 behavior.**

---

## Summary

Phase 20.3 — Message Load Failure Visibility makes `loadCollaborationMessages()` stop reporting a failed fetch as an empty conversation. It defines five distinct loader states, preserves the genuine empty state and all existing render behavior, adds a minimal load-failure state for an initial failure, and preserves already-rendered rows when a reload fails. Scope is one function. Thirty non-goals are named explicitly, no backend or database surface is touched, and Level 3 authenticated runtime validation on a Netlify deploy preview is required before commit approval. Phase 20.4 — full-app NACKL removal — is recorded as the next phase, beginning with a complete read-only inventory.
