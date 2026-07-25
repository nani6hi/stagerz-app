# Phase 20.1 — Optimistic UI Implementation Points

**Target file:** `index.html` (single-file app, ~255 KB)
**Branch:** `phase-20.1-optimistic-ui`
**Status:** Read-only inspection. No source modified, no commits created.

---

## Objective

Locate and document every code path in `index.html` that Phase 20.1 (optimistic UI for collaboration messaging) would need to attach to, so that an implementation plan can be written against verified locations rather than assumptions.

Specifically:

1. The message-send entry point.
2. The composer input state and clearing logic.
3. The message render-model construction.
4. The network request and success handling.
5. The error/rollback handling.
6. Any loading state that replaces the whole conversation area.
7. Whether the identifiers `allocateProvisionalId`, `buildProvisionalRenderModel`, `provisional`, or `optimistic` already exist.

---

## Findings

### 1. Message-send entry point

`sendCollaborationMessage()` is the single send entry point. It is invoked from two inline handlers in the composer markup — the Enter key on the input, and the click on the Send button. There is no other caller and no intermediate dispatch layer.

Concurrency is guarded by the shared busy helpers `tryBeginCollaborationBusy(sendBtn)` / `endCollaborationBusy(sendBtn)`, which toggle `dataset.busy`, `disabled`, `style.pointerEvents`, and `style.opacity` on the passed control. `tryBeginCollaborationBusy` returns `false` when the control is already busy, and the send function early-returns on that.

### 2. Composer input state and clearing logic

There is **no JavaScript-side state variable for the composer**. `#cmInput` is a plain `<input type="text" maxlength="5000">`, and `inputEl.value` is the only source of truth.

The flow inside `sendCollaborationMessage()`:

- Read `rawBody` from the element, derive `trimmedBody`.
- Empty after trim → silent return (no toast).
- Length > 5000 → toast `"Message is too long (max 5000 characters)."` and return.
- Clear (`inputEl.value = ''`) happens **only inside the success branch**. An in-source comment states this is deliberate: a failure leaves the typed text intact for retry.
- Clearing is paired with `stopCollaborationTypingNow()`, which forces the realtime typing indicator off immediately rather than waiting for the 2500 ms idle timer.

Every keystroke also fires `handleCollaborationMessageInputChanged()`, which drives the realtime typing presence state off `input.value.trim().length > 0` and only calls `.track()` on an actual started/stopped transition.

### 3. Message render-model construction

**There is no separate render-model function.** The model is constructed inline, per row, inside the `messages.forEach(...)` loop within `loadCollaborationMessages(collaborationId)`.

Values derived inline per message:

| Value | Derived from |
|---|---|
| `pub` | `publicById[m.sender_id]`, defaulted to `{}` |
| `isOwn` | `!!(myId && m.sender_id === myId)` |
| `canDelete` | `isOwn \|\| currentCollaborationIsOwner` |
| `timeStr` | `new Date(m.created_at).toLocaleTimeString(...)`, empty string when `created_at` is falsy |
| `senderLine` | `escapeCollaborationHtml(display_name + ' · @' + username)` |
| `safeBody` | `escapeCollaborationHtml(m.body)` |
| `avatarStyle` / `avatarContent` | `pub.photo_url` present or fallback glyph |

The row DOM is produced by assigning a template string to `row.innerHTML`. The message body element carries `id="cmBodyText-<m.id>"` — the database id is baked directly into the DOM, and `beginEditMessage()` resolves its target through exactly that id.

Edit and Delete action links are appended only when `currentCollaborationStatus === 'active'`, and are attached via `row.querySelector('div[style*="max-width:75%"]')` — an attribute-substring selector against an inline style, not a class or data attribute.

Lookups assembled before the loop: `senderIds` (deduped, comma-joined), `publicProfiles` and `profiles` fetches, the `publicById` / `profileById` maps, and `myId = await getMyDomainId()` (module-level cached after first resolution).

### 4. Network request and success handling

The write is `supaRpc('create_collaboration_message', { p_collaboration_id, p_body })`.

`supaRpc()` is the shared RPC transport. It wraps `fetch` in try/catch and **never throws** — it resolves to `{ok:true, status, data}` on a 2xx, `{ok:false, status, error}` on a non-ok response, and a network-failure shape on a thrown fetch. Callers therefore branch on `result && result.ok`.

`sender_id` is deliberately never sent from the client; an in-source comment records that the RPC derives it server-side from the authenticated caller's resolved identity.

On success the handler clears the input, stops typing state, then `await loadCollaborationMessages(currentCollaborationId)` — a **full refetch and full DOM replace**, never an append.

#### Return value of `create_collaboration_message`

**The exact return value cannot be determined from the code on disk.** Specifically:

- **The RPC definition is not present in the repository.** There is no SQL file, no migration, and no `supabase/` directory anywhere in the tree — the repository contains only `index.html`, `README.md`, `CNAME`, and the `.apos/` governance baseline. The function body exists solely in the remote Postgres database.
- `create_collaboration_message` appears exactly once in the codebase, at line 3513, as an RPC name string.
- **`supaRpc()` already exposes any successful RPC response as `result.data`** — on a 2xx it returns `{ok:true, status, data: parsed}`, where `parsed` is `JSON.parse()` of the response body. Whatever the function returns is therefore already reaching the client; no transport change is needed to read it.
- **`sendCollaborationMessage()` currently ignores `result.data`** entirely. It branches only on `result && result.ok`.
- **No existing `supaRpc()` caller in `index.html` establishes a precedent for the RPC return shape.** Across all 21 `supaRpc()` call sites, not one reads `.data`. (The `.data` references at lines 4408, 4546, and 4571 belong to Supabase Storage and client calls, not to `supaRpc`.)

Determining the return value would require inspecting the function definition in the database, which is outside this repository. **Phase 20.1 does not need that answer** — see the approved strategy below.

#### Two reload paths after message creation

A single successful send triggers **two independent full reloads**, not one:

1. **The awaited reload.** `sendCollaborationMessage()` calls `await loadCollaborationMessages(currentCollaborationId)` directly in its success branch (3524).
2. **The debounced realtime echo reload.** The Phase 19.1 subscription listens to `postgres_changes` on `collaboration_messages` and routes through `scheduleCollaborationRealtimeReload()` (3882–3892) — a 300 ms debounced reload guarded on both `activeCollaborationChannelId` and `currentCollaborationId`. The sender's own INSERT echoes back through this path in addition to the direct reload.

Both paths call the same loader, which performs a full DOM replace. **Reconciliation must remain safe across both reloads and must never produce duplicate rows** — a provisional row must not survive alongside its confirmed counterpart after either reload, and must not be re-inserted by one path after the other has already reconciled it. Because the loader clears and rebuilds the entire list, the existing code cannot duplicate rows today; that guarantee is what an optimistic insertion must not break.

#### Realtime subscription lifecycle

`subscribeToCollaborationRealtime()` (3915) is initialized through **`openCollaboration()` (call site at line 2623), not directly through `openCollaborationMessages()`**. The messages screen inherits an already-established channel rather than creating its own; `subscribeToCollaborationRealtime()` also deliberately tolerates repeated calls for the same collaboration without creating a duplicate channel.

**This dependency must be preserved and must be considered during validation.** Any validation of reconciliation behavior is only meaningful when the channel is actually live, which means entering the messages screen through the Workspace as a real user does — not by isolating the messages screen.

### 5. Error / rollback handling

**There is currently no rollback, because nothing is mutated locally before the request.** The existing design is strictly server-confirmed-then-repaint.

The error branch logs the failure, unwraps the message through the file's standard chain — `result.error.message || .hint || .details || JSON.stringify(result.error)` — and toasts it, falling back to `'Could not send message.'`. The input retains its text and the list is left untouched. `endCollaborationBusy(sendBtn)` runs unconditionally after both branches, so the button is always re-enabled.

The identical unwrap-and-toast shape recurs in `saveMessageEdit()` and `deleteMessagePrompt()`, and is the established convention for write failures in this file.

### 6. Loading state that replaces the whole conversation area

**Yes, and it is unconditional.** The first statement of `loadCollaborationMessages()` overwrites the entire list container:

```js
listEl.innerHTML = '<div style="...">Loading...</div>';
```

This executes on *every* invocation of the loader, including:

- the post-send reload,
- the debounced realtime-echo reload,
- `cancelMessageEdit()`,
- the post-edit reload in `saveMessageEdit()`,
- the post-delete reload in `deleteMessagePrompt()`.

Consequence today: sending a message flashes the whole conversation to "Loading…" before repainting. This is the single most visible thing Phase 20.1 exists to remove.

Other whole-area writes in the same function: the empty state (`"No messages yet."`), the `listEl.innerHTML = ''` reset before the loop, and the trailing `listEl.scrollTop = listEl.scrollHeight`.

Separately, `applyCollaborationReadOnlyGuard('cmComposerRow', 'cmReadOnlyNotice', 'new messages')` hides the composer entirely and shows a notice whenever `currentCollaborationStatus !== 'active'`.

### 7. Identifier availability

| Identifier | Present? | Detail |
|---|---|---|
| `allocateProvisionalId` | **No** | Zero occurrences |
| `buildProvisionalRenderModel` | **No** | Zero occurrences |
| `provisional` | **No** | Zero occurrences, case-insensitive |
| `optimistic` | **No identifier** | One prose-only hit in a comment describing `respondToApplication()` as reloading from the database "rather than optimistically mutating the DOM locally" |

All four names are free to claim.

---

## File locations

All references are to `index.html`.

### Markup

| Element | Line(s) |
|---|---|
| `#cmList` — conversation container | 740 |
| `#cmReadOnlyNotice` | 741 |
| `#cmComposerRow` | 743 |
| `#cmInput` — composer input, Enter handler, `oninput` hook | 744 |
| `#cmSendBtn` — Send button, `onclick` handler | 745 |

### Messaging logic

| Concern | Line(s) |
|---|---|
| Send entry point (whole function) | 3498–3532 |
| Input read + validation | 3499–3507 |
| Busy gate acquired | 3509 |
| RPC call | 3513–3516 |
| Success branch (clear, stop typing, reload) | 3519–3524 |
| Input cleared | 3522 |
| Error branch (log, unwrap, toast) | 3525–3529 |
| Busy gate released | 3531 |
| Loader (whole function) | 3339–3420 |
| **"Loading…" whole-area replace** | 3340–3341 |
| Empty state | 3350–3353 |
| Profile lookups + `myId` | 3355–3368 |
| Render loop (inline render model) | 3371–3417 |
| Row `innerHTML` template | 3385–3391 |
| `id="cmBodyText-<id>"` body element | 3389 |
| Edit/Delete action attach | 3393–3414 |
| Scroll-to-bottom | 3419 |

### Supporting infrastructure

| Concern | Line(s) |
|---|---|
| `supaSelect()` | 994–1019 |
| `supaRpc()` | 1210–1231 |
| `getMyDomainId()` | 1290–1302 |
| `respondToApplication()` — "not optimistic" comment | 2354–2373 |
| `applyCollaborationReadOnlyGuard()` | 3125–3134 |
| `openCollaborationMessages()` | 3329–3337 |
| `beginEditMessage()` | 3427–3446 |
| `cancelMessageEdit()` | 3448–3450 |
| `saveMessageEdit()` | 3452–3476 |
| `deleteMessagePrompt()` | 3478–3496 |
| `tryBeginCollaborationBusy()` | 3839–3847 |
| `endCollaborationBusy()` | 3849–3855 |
| `scheduleCollaborationRealtimeReload()` | 3882–3892 |
| Realtime `collaboration_messages` subscription | 3939–3941 |
| `handleCollaborationMessageInputChanged()` | 4119–4139 |
| `stopCollaborationTypingNow()` | 4143–4149 |
| `escapeCollaborationHtml()` | 4151–4159 |

---

## Function names

Directly in scope for Phase 20.1:

- `sendCollaborationMessage()` — send entry point
- `loadCollaborationMessages(collaborationId)` — loader, render model, and the whole-area "Loading…" replace

Adjacent, affected or reused:

- `openCollaborationMessages(collaborationId, collaborationTitle)`
- `handleCollaborationMessageInputChanged()`
- `stopCollaborationTypingNow()`
- `escapeCollaborationHtml(str)`
- `tryBeginCollaborationBusy(control)` / `endCollaborationBusy(control)`
- `applyCollaborationReadOnlyGuard(composerElId, noticeElId, noticeVerb)`
- `scheduleCollaborationRealtimeReload(forCollaborationId, area, reloadFn)`
- `supaRpc(fnName, params)` / `supaSelect(table, filters, columns)`
- `getMyDomainId()`
- `beginEditMessage(messageId, currentBody)`, `cancelMessageEdit()`, `saveMessageEdit(messageId)`, `deleteMessagePrompt(messageId, btnEl)`

---

## Risks

**1. Two independent reloads race any local insertion.**
Every successful send produces both the awaited `loadCollaborationMessages()` call and, roughly 300 ms later, a debounced realtime echo reload — see *Two reload paths after message creation* above. Any provisional row placed in the DOM can be destroyed by either, on a timeline the send function does not control and which its own `await`ed reload does not suppress. Reconciliation must be safe under both, in either order, and must not leave a duplicate row behind. This is the highest-risk interaction in the phase.

**2. The render model is inline and not callable.**
The per-row model lives entirely inside a `forEach` closure. A provisional row cannot reuse it without extracting it into a function. Two rendering paths — one for provisional, one for server rows — would guarantee visual drift between the optimistic bubble and its confirmed replacement.

**3. Message `id` is load-bearing in the DOM.**
`id="cmBodyText-<m.id>"` is how `beginEditMessage()` finds its target. A provisional row needs an id that is unique, non-colliding with real database ids, and either excluded from the edit/delete affordances or safely resolvable — otherwise editing an unconfirmed message will target a nonexistent server row.

**4. Reconciliation has no server-side join key, and must not require one.**
`create_collaboration_message` is called without a client-supplied correlation id, and the success branch only inspects `result.ok`. Whether the RPC returns a database row id **cannot be determined from the code on disk** — see *Return value of `create_collaboration_message`* above. Rather than treat this as a blocking unknown, **Phase 20.1 must not depend on the RPC returning a database row id at all**: reconciliation is by client-generated temporary id plus full-reload replacement, which is correct whether or not a server id is ever returned. If a returned id is later confirmed, it becomes an optimization, never a prerequisite.

**5. Removing the "Loading…" replace affects five callers, not one.**
Both the initial open and the edit/delete/cancel reloads depend on the current unconditional behavior. A change scoped only to the send path must not silently alter the first-open experience, where a loading indicator is genuinely correct.

**6. Failure semantics are currently "typed text is never lost."**
That guarantee is explicitly documented in-source. Any optimistic design must preserve a recovery path — retry affordance or text restoration — or it regresses a deliberate behavior.

**7. Scroll position.**
`listEl.scrollTop = listEl.scrollHeight` runs only at the end of a full reload. A provisional row appended without an equivalent scroll adjustment will render below the fold.

**8. Status guard timing.**
Edit/Delete affordances are gated on `currentCollaborationStatus === 'active'`. A provisional row must respect the same gate, and the composer itself may be hidden by `applyCollaborationReadOnlyGuard()`.

---

## Recommendations

Ordered by dependency. No edits proposed in detail — these are the shapes the implementation should take.

### Approved strategy: client-generated temporary IDs

**Phase 20.1 uses client-generated temporary IDs for provisional rows, and must not depend on `create_collaboration_message` returning a database row ID.**

This is the approved approach because it is correct regardless of what the RPC returns — an unknown that cannot be resolved from the repository (see Finding 4). It removes that unknown from the critical path entirely. A server-returned id, if one is later confirmed to exist, may be adopted as an optimization in a subsequent phase; it is never a prerequisite for this one.

1. **Extract the inline render model into a callable function** that accepts a message-shaped object and returns the row element. Both the server-loaded path and the provisional path must go through it, so there is exactly one renderer.

2. **Introduce `allocateProvisionalId()`** producing a namespaced, collision-proof id (a distinct prefix, not a numeric id) so provisional DOM nodes are identifiable and can never be confused with a database id by `beginEditMessage()` or `deleteMessagePrompt()`.

3. **Introduce `buildProvisionalRenderModel()`** that synthesizes the same field set the loader derives — `isOwn: true`, the current user's `pub` profile, a client-side timestamp, escaped body — so the provisional row is byte-identical in structure to its confirmed successor.

4. **Suppress edit/delete affordances on provisional rows** until confirmed, rather than rendering them against an id the server does not know.

5. **Reconcile by client-generated temporary id, not by server id.** Track provisional rows locally by the id from `allocateProvisionalId()` and clear them when a reload replaces the list. Do not read `result.data`, do not add a correlation id to the RPC signature, and do not make correctness contingent on the RPC's return value.

6. **Make both reload paths provisional-aware.** Reconciliation must hold for the awaited post-send reload *and* the debounced realtime echo reload, in either order, without leaving a duplicate row or a stranded provisional row. Do not leave the race unaddressed.

7. **Scope the "Loading…" replace by call reason.** Keep it for the initial open; skip it for post-send, post-edit, post-delete, and realtime-echo reloads. A parameter on the loader is preferable to a module-level flag.

8. **Preserve the retry guarantee.** On failure, keep the existing toast and either restore the body into `#cmInput` or attach a retry affordance to the failed row. Clearing the input optimistically without one of these regresses documented behavior.

9. **Scroll on provisional insert**, matching the loader's end-of-load behavior.

10. **Keep the busy gate.** `tryBeginCollaborationBusy` / `endCollaborationBusy` remain the correct double-send guard even once sending feels instant.

---

## Scope boundary

This document distinguishes three categories. They are not interchangeable, and only the first is work Phase 20.1 performs.

### 1. Behavior Phase 20.1 will implement

- A provisional message row rendered immediately on send, identified by a client-generated temporary id.
- A single shared row renderer used by both the provisional and server-loaded paths.
- Suppression of the whole-area loading replace on non-initial reloads, with the initial open unchanged.
- Rollback of the provisional row on failure, preserving the existing never-lose-typed-text guarantee.
- Scroll-to-bottom on provisional insert.

### 2. Risks Phase 20.1 must handle

These are not new features — they are correctness obligations of the work above, enumerated in **Risks** and addressed in **Recommendations**: the two-reload race, duplicate-row prevention, the load-bearing message id in the DOM, reconciliation without a server join key, the five callers of the loader, the retry guarantee, scroll position, and the status guard.

### 3. Pre-existing limitations explicitly deferred

Documented in the next section. They exist today, are independent of optimistic UI, and are **out of scope for Phase 20.1**. They are recorded so that reviewers and validators know they are known — not to expand this phase.

---

## Pre-existing limitations (out of scope for Phase 20.1)

Both items below are defects in the **current** code, present regardless of whether optimistic UI is implemented. Neither is a Phase 20.1 implementation task. Neither may be turned into one. They are recorded here for visibility and for future phase planning only.

### A. Message query limit and ordering

`loadCollaborationMessages()` queries with `order=created_at.asc&limit=200` (line 3345). Because the ordering is ascending, the limit selects the **oldest** 200 rows. In conversations above 200 messages, this may exclude newly created messages from every reload.

- **Status:** known pre-existing limitation.
- **Scope:** out of scope for Phase 20.1.
- **Not** a Phase 20.1 implementation task.
- **Relevance to this phase:** reconciliation by full-reload replacement inherits this behavior. In a conversation past the limit, a provisional row may be replaced by a reload that does not contain its confirmed counterpart. Phase 20.1 does not fix this and does not worsen it; validators should be aware of it when choosing test conversations.

### B. Fetch failure versus empty conversation

`supaSelect()` returns `null` on a non-ok response (line 1013) and on a network error (line 1017). `loadCollaborationMessages()` handles `null` and an empty array through the same guard — `if(!messages || !messages.length)` (line 3350) — rendering the same "No messages yet." state for both.

- **Status:** known pre-existing limitation.
- **Scope:** out of scope for Phase 20.1.
- **Not** a Phase 20.1 implementation task.
- **Relevance to this phase:** a transient fetch failure during a reload is presented as an empty conversation. Phase 20.1 does not fix this and does not worsen it; validators should distinguish this pre-existing behavior from an optimistic-UI reconciliation defect when interpreting results.

---

## Summary

Collaboration messaging in `index.html` is currently a strict server-confirmed-then-repaint design: `sendCollaborationMessage()` (3498–3532) awaits `create_collaboration_message` via `supaRpc()`, and only on success clears `#cmInput` and calls `loadCollaborationMessages()` (3339–3420), which unconditionally blanks the entire list to "Loading…" at line 3341 before refetching and rebuilding every row. There is no local mutation, therefore no rollback, and the file's own comments record both the no-optimistic-mutation convention and the deliberate preserve-typed-text-on-failure behavior.

None of the four Phase 20.1 identifiers exist — the only `optimistic` hit is prose in a comment at line 2357 — so all names are free.

Two structural obstacles dominate the work: the render model is inline inside a `forEach` and must be extracted before any provisional row can reuse it, and a single send triggers **two** independent full reloads — the awaited post-send call and the debounced realtime echo — either of which will destroy a locally-inserted row on a timeline the send path does not control. Reconciliation must be safe across both and must never leave a duplicate row.

The exact return value of `create_collaboration_message` cannot be determined from the code on disk: the RPC definition is not in the repository, `supaRpc()` already exposes any response as `result.data`, `sendCollaborationMessage()` ignores it, and no `supaRpc()` caller anywhere establishes a precedent. This is deliberately **not** a blocker — the approved strategy is client-generated temporary IDs, and Phase 20.1 must not depend on the RPC returning a database row ID.

Two pre-existing limitations are recorded as known and explicitly deferred: the ascending `limit=200` message query, and the conflation of fetch failure with an empty conversation. Both exist today, both are out of scope, and neither is a Phase 20.1 implementation task.
