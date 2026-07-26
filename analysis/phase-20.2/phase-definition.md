# Phase 20.2 — Messaging Hardening

**Branch:** `phase-20.2-messaging-hardening`
**Base commit:** `bc85097b8d17d8fa75e38acd57f0cdec37f8fc72` (`main`, merge of Pull Request #1)
**Status:** Scope locked. No application code written.

---

## Background

Phase 20.1 shipped optimistic collaboration-message sending and was merged to `main` via Pull Request #1. Its validation recorded **48 PASS · 0 FAIL · 13 NOT VERIFIED · 0 NOT APPLICABLE**, and a production smoke test confirmed the app loads, messages open, and send, edit, and delete all work.

Phase 20.1 closed deliberately, leaving four items on the record:

- **B26** — first-message behavior in a genuinely empty conversation was never exercised at runtime, although Phase 20.1 introduced the code that handles it.
- **B27** — the read-only / restricted-collaboration guard was never exercised at runtime.
- A **defence-in-depth gap**: `sendCollaborationMessage()` carries no client-side status check. The read-only guard is purely presentational.
- An **accepted risk (B25)**: on a failed send, the failed message body is discarded if the user typed new text while the request was pending.

Phase 20.2 closes exactly these four items. It adds no features.

Two pre-existing console entries remain and are **not** Phase 20.2 concerns: the `nacklVal` ReferenceError and the Telegram HapticFeedback warnings.

---

## Locked scope

### Objective 1 — Restricted collaboration send guard

Extend `sendCollaborationMessage()` with a client-side defence-in-depth guard.

Required behavior when `currentCollaborationStatus` is **not** `'active'`:

- Return **before** acquiring the busy gate.
- Do **not** clear the input.
- Do **not** insert a provisional row.
- Do **not** call `create_collaboration_message`.
- Do **not** change the existing message list.
- Do **not** leave the Send button disabled or busy.

Active collaborations must behave **exactly** as in Phase 20.1.

**Pattern decision: Reuse.** The predicate `currentCollaborationStatus === 'active'` already exists in five places. No new permission system is introduced. Server-side RPC and RLS remain the real enforcement; this guard is defence in depth only.

### Objective 2 — Preserve concurrent typing during failed-send rollback

**Current known risk.** The sent text is cleared on send. If the user begins typing a new message while the request is pending and the original send then fails, rollback restores the failed body **only when the input is empty** — so the failed message text may be lost.

**Required product behavior:**

- Never overwrite text typed after the original send started.
- Never silently discard the failed message body.
- If the input is **still empty** when the failure occurs: restore the failed body normally (unchanged from Phase 20.1).
- If the user **has typed new text** while the request was pending:
  - preserve the new text,
  - prepend the failed body above it,
  - separate the two with **exactly two newline characters**,
  - place the failed body **first**,
  - do not duplicate either body.

**Example.** Failed body `First message`, newly typed body `Second message`, result after rollback:

```
First message

Second message
```

— one empty line between them.

**Excluded from this objective:** no retry button, no toast system, no draft store, no queue, no modal, no new component.

### Objective 3 — B26 runtime validation

Validate first-message behavior in a genuinely empty collaboration:

- the empty response is **HTTP 200 with `[]`**,
- "No messages yet." is initially visible,
- the placeholder disappears **before** provisional insertion,
- the provisional message appears,
- no full-area Loading flash occurs,
- reconciliation leaves **exactly one** confirmed row,
- no duplicate,
- no new messaging-path console error.

If no genuinely empty collaboration exists without destructive data changes: **record B26 as NOT VERIFIED.** Do not delete messages. Do not create artificial production data solely for the test.

### Objective 4 — B27 runtime validation

Validate a **completed** or **archived** collaboration:

- composer hidden,
- correct read-only notice visible,
- existing messages readable,
- no edit/delete controls,
- **zero** `create_collaboration_message` requests,
- no provisional row.

If no suitable collaboration exists without changing status or permissions: **record B27 as NOT VERIFIED.** Do not change production data to manufacture the test.

A non-owner **active** collaboration may be documented as **partial ownership coverage**. It does **not** count as a full B27 PASS.

---

## Explicit non-goals

Every item below is out of scope for Phase 20.2:

- Fetch-error versus empty-state handling
- Changes to any loader
- `nacklVal` fix
- Telegram warnings
- `photo_url` escaping
- Security review
- Pagination or message ordering
- Backend changes
- Schema changes
- RPC changes
- RLS or policy changes
- Realtime architecture changes
- New UI components
- Retry interface
- Toast notifications
- Activity timeline work
- Unrelated styling
- Deployment configuration

---

## Exact relevant code locations

All line numbers refer to `index.html` at base commit `bc85097`.

### Objective 1 — send guard

| Concern | Line(s) |
|---|---|
| `sendCollaborationMessage()` — whole function | 3573–3618 |
| Empty / 5000-char validation (must stay first) | 3576–3579 |
| **Busy gate — guard must return before this** | 3580 |
| Provisional insert | 3585 |
| Input cleared | 3586 |
| RPC call | 3592–3595 |
| `applyCollaborationReadOnlyGuard()` — presentational guard | 3125–3134 |
| Guard call site for messages | 3334 |
| `currentCollaborationStatus` declaration / assignment | 1833 / 2640 |
| Existing `=== 'active'` predicate occurrences | 3128, 3416, 3704, 4342, 4738 |

### Objective 2 — rollback text preservation

| Concern | Line(s) |
|---|---|
| Failure branch | 3604–3612 |
| Provisional row removal | 3608 |
| **Text restore — the line to change** | 3609 |
| `rawBody` captured (untrimmed original) | 3575 |
| `trimmedBody` (the body actually sent) | 3576 |
| Focus restore | 3611 |
| Busy gate released | 3617 |

### Objectives 3 and 4 — validation targets (read-only)

| Concern | Line(s) |
|---|---|
| Placeholder removal before provisional insert | 3474–3476 |
| "Loading…" placeholder | 3348 |
| "No messages yet." placeholder | 3358 |
| Empty-state branch | 3357–3360 |
| Edit/Delete gating in shared renderer | 3416 |
| Composer markup (`#cmComposerRow`, `#cmInput`, `#cmSendBtn`) | 743–745 |
| Read-only notice element | 741 |
| Non-active statuses reachable via UI (`completed`, `archived`) | 2721–2724, 3103 |

---

## Acceptance criteria

Observable PASS/FAIL only. No criterion may be satisfied by code inspection alone.

### Objective 1

| # | Criterion | PASS | FAIL |
|---|---|---|---|
| 1.1 | On a non-active collaboration, invoking the send path produces **zero** `create_collaboration_message` requests | zero requests | any request |
| 1.2 | No provisional row is inserted | list unchanged | any row appears |
| 1.3 | Input is not cleared | typed text remains | text cleared |
| 1.4 | Send button is not left disabled or busy | normal state | stuck disabled/busy |
| 1.5 | Existing messages unchanged | identical list | list altered |
| 1.6 | On an **active** collaboration, send behaves exactly as Phase 20.1 | full 20.1 behavior | any deviation |

### Objective 2

| # | Criterion | PASS | FAIL |
|---|---|---|---|
| 2.1 | Failure with **empty** input → failed body restored verbatim | exact restore | altered or missing |
| 2.2 | Failure with **new text typed** → result is failed body, blank line, new text | exact three-part result | any other result |
| 2.3 | Separator is exactly two newline characters | exactly `\n\n` | more, fewer, or other whitespace |
| 2.4 | Neither body is duplicated | each appears once | any duplication |
| 2.5 | Failed body is never silently discarded | always present | missing |
| 2.6 | Newly typed text is never overwritten | preserved verbatim | overwritten |
| 2.7 | Provisional row still removed on failure | removed | orphaned row |

### Objective 3 (B26)

PASS requires **all**: response is HTTP 200 with `[]`; "No messages yet." visible before send; placeholder gone after send with no residue; provisional row appears; no full-area Loading flash; exactly one confirmed row after reconciliation; no duplicate; no new messaging-path console error.
FAIL: any of the above violated.
NOT VERIFIED: no genuinely empty collaboration available without destructive change, or the empty list resulted from a fetch failure rather than genuine emptiness.

### Objective 4 (B27)

PASS requires **all**: composer hidden; correct read-only notice visible; existing messages readable; no edit/delete controls; zero `create_collaboration_message` requests; no provisional row.
FAIL: any of the above violated.
NOT VERIFIED: no completed/archived collaboration available without changing data.
PARTIAL: only the non-owner active variant was tested — ownership branch covered, status guard NOT VERIFIED.

### All objectives

No new console error whose stack trace names a messaging function (`sendCollaborationMessage`, `loadCollaborationMessages`, `buildCollaborationMessageRow`, `insertProvisionalCollaborationMessage`, `removeProvisionalCollaborationMessage`, `allocateProvisionalId`, `buildProvisionalRenderModel`). Entries naming `tickNACKL`, `loadMyProfile`, or `HapticFeedback` are pre-existing and excluded.

---

## Validation plan

**Level 3 (Browser validation)** per `.apos/VALIDATION_STANDARD.md` §2 — Objectives 1 and 2 change behavior in `index.html`.

**DevTools setup.** Network: filter `rpc/create_collaboration_message`, type Fetch/XHR, ☑ Preserve log, ☑ Disable cache. Console: Errors + Warnings, plus the `sendCollaborationMessage result:` log line.

**Objective 1.** On a completed/archived collaboration, confirm the composer is hidden and no send is reachable; confirm zero create RPCs for the visit. On an active collaboration, run a full Phase 20.1 regression: send, edit, delete.

**Objective 2.** With DevTools Network set to **Offline**, two runs: (a) send, do not type, confirm the failed body is restored verbatim; (b) send, immediately type new text while the request is pending, confirm the result is failed body + blank line + new text, in that order, each appearing once. Throttling to Slow 3G widens the pending window and makes case (b) reliably reproducible.

**Objective 3.** Per the B26 procedure: genuinely empty collaboration, Slow 3G throttling to make the provisional window observable, evidence captured.

**Objective 4.** Per the B27 procedure: completed or archived collaboration, no throttling, evidence captured.

**Regression coverage** made newly relevant by these changes: initial screen load still shows "Loading…"; edit and delete still function without a full-area flash; read-only collaborations still hide the composer; scroll lands at the bottom.

---

## Implementation order

Safest incremental order. Validation precedes code so the two unknowns are resolved before anything is modified.

1. **Objective 4 (B27) first** — read-only, no code, no data change. Establishes whether the UI guard actually holds, and whether Objective 1 closes a real or theoretical hole.
2. **Objective 3 (B26)** — read-only apart from one test message. Establishes a baseline for the placeholder path.
3. **Objective 1** — smallest change, isolated guard clause, lowest regression risk. Validate. Commit.
4. **Objective 2** — modifies the rollback branch; do it on a known-good baseline so any regression is unambiguously attributable. Validate. Commit.
5. **Validation report**, then Pull Request.

---

## Future-phase notes

Recorded, not implemented, per the STAGERZ scope rule.

1. **Unified Loading / Empty / Error states** — messages, tasks, assets, credits, and all other affected loaders. The null-versus-empty conflation exists in ten loaders; fixing one leaves nine inconsistent, so this belongs in a dedicated phase.
2. **Profile / NACKL maintenance** — the `nacklVal` ReferenceError, plus validation of the profile code that becomes newly reachable once `loadMyProfile()` stops aborting.
3. **Security hardening** — review of the `photo_url` interpolation into a style attribute, which is not passed through `escapeCollaborationHtml()`.
4. **Message history** — `created_at` ascending with `limit=200`; pagination and ordering require a product decision.

---

## Release risk

**Merging Phase 20.2 will affect production.** `main` deploys via GitHub Pages, and both code objectives change behavior on a live user-facing screen.

- **Objective 1** — near-zero risk. A guard clause that returns early on a state the UI already prevents reaching.
- **Objective 2** — low-to-moderate risk, confined to the failure branch of `sendCollaborationMessage()`. It cannot affect the success path, but it can affect what the user sees after a failed send.

Neither objective touches the loader, the renderer, the realtime subscription, or any backend surface.

**Mandatory manual tests before any merge to `main`:** send, edit, and delete on an active collaboration; restricted collaboration shows a hidden composer and zero create RPCs; failed send with empty input restores text; failed send with concurrent typing produces the exact three-part result; optimistic send still yields exactly one confirmed row with no duplicate and no Loading flash; console clean apart from the two known pre-existing entries.

If schedule pressure appears, ship Objective 1 alone and defer Objective 2 — Objective 1 is independently valuable and carries materially less risk.

---

## Summary

Phase 20.2 — Messaging Hardening closes the four items Phase 20.1 knowingly left open: a client-side defence-in-depth guard on the send path (Reuse), deterministic preservation of both message bodies on failed-send rollback, and runtime validation of B26 and B27. Scope is locked to two small code objectives in one function and two read-only validations. Eighteen non-goals are named explicitly, and four ideas are recorded for future phases rather than absorbed into this one.
