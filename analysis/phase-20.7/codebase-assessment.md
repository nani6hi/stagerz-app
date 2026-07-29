# Phase 20.7 — Codebase Assessment & Roadmap

**Type:** Analysis only. No application code was modified, no commit was created, no push was performed.
**Branch:** `phase-20.7-codebase-assessment`
**Base:** `main` @ `275caf3944f1194434ca4924272731c03111bbd1` (Phase 20.6 merged)
**Date:** 2026-07-29

---

## 1. Objective

Evaluate the current STAGERZ web application after the completion of Phase 20.6 (Telegram runtime removal) and produce:

- an assessment of architecture, user experience, code quality, performance, technical debt, and production readiness;
- a ranked technical-debt register;
- a recommended sequence of the next 5–10 development phases, in priority order, each with objective, benefit, implementation risk, estimated complexity, and execution order.

Scope constraints observed:

- The current **single-file frontend architecture** (`index.html`) is treated as the intended design and is **retained**. No phase below proposes splitting the frontend into modules or introducing a build step.
- No refactoring is proposed unless it is tied to a concrete, observed defect, risk, or measurable cost.
- History is not rewritten; no existing phase decision is reversed.

### Documents read

| Requested path | Actual path | Status |
|---|---|---|
| `.apos/PROJECT_CONTEXT.md` | `.apos/PROJECT_CONTEXT.md` | Read |
| `README.md` | `README.md` | Read (2 lines — title only) |
| `VALIDATION_STANDARD.md` | `.apos/VALIDATION_STANDARD.md` | Read — **the file is under `.apos/`, not the repository root** |
| `WORKFLOW.md` | `.apos/WORKFLOW.md` | Read — **the file is under `.apos/`, not the repository root** |
| `index.html` | `index.html` | Read in full (4,942 lines) |

---

## 2. Findings

### 2.0 Baseline measurements

Measured against `index.html` at `275caf3` (working tree clean).

| Metric | Value |
|---|---|
| Total lines | 4,942 |
| File size | ~265 KB |
| CSS block | lines 9–286 (278 lines) |
| HTML body | lines 288–958 (671 lines) |
| JavaScript block | lines 960–4,940 (3,981 lines) |
| Screens defined | 20 (`#screen-*`) |
| Screens reachable via `goTo()` | 20 — no orphaned screen |
| Function declarations | 139 |
| Module-level `var` declarations | 47 |
| `document.getElementById(...)` calls | 194 |
| `document.querySelector/All(...)` calls | 13 |
| `.innerHTML` assignments | 81 |
| Inline `onclick=` HTML attributes | 132 |
| Programmatic `.onclick =` assignments | 54 |
| `supaSelect()` call sites | 41 |
| `supaRpc()` call sites | 21 (20 distinct server functions) |
| Distinct tables/views read | 14 |
| `showToast()` call sites | 89 |
| `console.log` / `console.error` | 34 / 47 |
| `window.confirm()` call sites | 8 |
| `@media` queries | **0** |
| `aria-*` attributes | **0** |
| Semantic `<button>` elements | 19 (against 186 total click handlers) |
| Automated tests / CI / lint config | **none present** |

---

### A. Architecture

#### A.1 Overall structure

`index.html` is a single self-contained document: a CSS block, a static markup block declaring all 20 screens up front, and one inline `<script>`. There is no build step, no bundler, no module system, and exactly one runtime dependency loaded from a CDN (`@supabase/supabase-js@2`, line 8). Deployment is a `git push` to `main`, served directly by GitHub Pages.

For an application of this size and team shape this is a defensible choice, and Phases 20.4–20.6 have demonstrably kept it clean: the file now contains zero NACKL and zero Telegram runtime code. The structure is not the problem. What it lacks is a **boundary at the edges** — dependency pinning, a startup failure path, and any record of the backend it talks to.

The JavaScript block is informally sectioned by banner comments in a consistent order:

| Region | Lines | Contents |
|---|---|---|
| Supabase transport | 961–1216 | `supaHeaders`, `supaSelect`, `supaSelectCount`, `supaInsert`, `supaUpsert`, `supaUpdate`, `supaUpdateMinimal`, `supaRpc` |
| Auth & identity | 1218–1323 | `sendOtp`, `logout`, `getMyDomainId`, `enterApp`, `checkSessionAndStart`, `onAuthStateChange` |
| Navigation / toast | 1326–1359 | `goTo`, `showToast` |
| Stage (demo data) | 1361–1515 | `stageData`, `buildStageFeed`, `buildCard`, `buildShort`, `openContent` |
| Search (demo data) | 1517–1651 | `artistDB`, `doSearch`, `renderArtists`, `openArtist`, `openArtistProfile` |
| Wanted | 1653–2047 | `loadWanted`, `renderWanted`, `submitWanted`, `applyToWanted`, `closeWantedPost` |
| Profile | 2049–2253 | `saveProfile`, `fetchMyProfile`, `loadMyProfile`, `loadMyWanted` |
| Applicants | 2255–2349 | `openApplicants`, `respondToApplication` |
| Board / notifications | 2351–2531 | `loadBoard`, `handleNotificationTap`, `updateUnreadBadge` |
| Collaboration | 2533–4881 | Workspace, participants, messages, tasks, assets, credits, realtime, presence |
| FameMaker / Backstage | 4883–4931 | `switchFMTab`, `toggleRec`, `switchBilling` |
| Init | 4933–4939 | `DOMContentLoaded` handler |

The Collaboration region is 2,349 lines — **59% of all JavaScript** — and is where essentially all real product value lives.

#### A.2 Separation of concerns

The **transport layer is genuinely well separated**. All eight Supabase helpers share one signature contract (`{ok, status, data, error}` for writes; `array | null` for reads), never throw, and never assume success. The distinction `supaSelect()` draws between `null` (real failure) and `[]` (legitimately empty) is correct and is respected at its call sites — Phase 20.3 hardened exactly this in `loadCollaborationMessages` (3332–3335) and `loadWanted` (1734–1744). This is the strongest part of the codebase.

Above the transport layer, separation is weaker but consistent. Almost every feature follows one recognisable shape:

```
open<X>()   → set state, set title, goTo(screen), apply read-only guard, await load<X>()
load<X>()   → supaSelect, build DOM imperatively, full container replace
create/edit/delete<X>() → busy-guard, supaRpc, toast, await load<X>()
```

Data fetching, business calculation, and DOM construction are interleaved inside the same functions rather than layered. That is inherent to the chosen architecture and is not, on its own, a defect. It becomes one only where a single function grows past the point of safe modification — see A.5.

Two genuine layering wins are worth recording because they were deliberate:

- **Server is the authority.** Every client-side permission check is paired with a comment stating that the RPC or RLS policy re-derives the same fact server-side (e.g. `applyToWanted` 1943–1951, `changeCollaborationStatus` 3068–3071, `applyCollaborationReadOnlyGuard` 3095–3099). The client never treats its own check as enforcement.
- **No fabricated data.** `openArtistProfile` (1617–1651) explicitly hides the verified badge and leaves the gallery empty rather than inventing values that have no schema equivalent. Dashboard metrics render `—` / "Unavailable" on failure rather than `0` (2734–2775).

#### A.3 Global state

47 module-level `var` declarations form the entire application state. They fall into four groups:

| Group | Count | Examples | Assessment |
|---|---|---|---|
| Configuration / client | 3 | `SUPA_URL`, `SUPA_KEY`, `supabaseClient` | Fine |
| Static demo data | 3 | `stageData`, `artistDB`, `wantedData` | See B.6 |
| Navigation / filter state | 9 | `currentStageTab`, `searchCat`, `apBackScreen`, `currentWantedCat` | Fine; 2 are dead (A.6) |
| Collaboration session state | 16 | `currentCollaborationId`, `currentCollaborationParticipants`, `currentCollaborationPublicById`, `currentCollaborationIsOwner`, `currentCollaborationStatus`, `activeCollaborationChannel`, `collaborationPresenceByUserId`, … | **The main coupling risk** |

The Collaboration cluster is effectively one implicit object spread across 16 independent variables, written by `openCollaboration()` and read by every Collaboration sub-screen. Concretely:

- `openCollaborationTasks()` (3646) builds its assignee chips from `currentCollaborationParticipants` + `currentCollaborationPublicById` — deliberately, to avoid re-querying. Same for `openCollaborationCredits()` (4685) and the uploader names in `loadCollaborationAssets()` (4315).
- That is efficient and intentional, but it means **the sub-screens are only correct if `openCollaboration()` ran first for the same collaboration**. There is no invariant enforcing that, only navigation convention: the sub-screens are reachable exclusively through the Workspace Modules cards (3052–3063).
- A notification tap goes through `navigateToCollaboration()` → `openCollaboration()` (2448–2450), so that path is safe too. The invariant currently holds — but it is upheld by call-site discipline, not by structure.

**Teardown is complete and correct.** `unsubscribeFromCollaborationRealtime()` (3994–4013) clears the channel, presence map, own-presence meta, typing state and all four debounce timers, and is invoked on logout (1259), on `SIGNED_OUT` (1318), and from `goTo()` whenever the target is outside the five Collaboration screens (1345–1348). This is one of the better-handled parts of the file.

**One state item is not reset on logout:** `myProfile` (2050) retains the previous user's name/role/location/bio/skills/username after `logout()` (1258–1265), which clears only `myDomainId`. In practice `loadMyProfile()` re-fetches on entering Profile, so the stale values are overwritten before display — but the object is a cross-user residue that should be cleared where `myDomainId` is.

#### A.4 Coupling

| Coupling | Where | Severity |
|---|---|---|
| Sub-screens ← `openCollaboration()` state | `currentCollaborationParticipants`, `currentCollaborationPublicById`, `currentCollaborationIsOwner`, `currentCollaborationStatus` | Medium — correct today, unenforced |
| Markup ← JavaScript, via string ids | 194 `getElementById` calls against ids declared only in the HTML block | Medium — renaming an id has no compile-time check; already broken in 6 places (A.6) |
| `goTo()` ← feature loaders | 1334–1339: `goTo` directly calls `renderArtists`, `loadWanted`, `loadMyProfile`, `loadBoard`, `loadMyCollaborations`, `populateEditProfile` | Low — a small, readable router table |
| App ← unpinned CDN SDK | line 8 | **Critical** — see A.7 |
| App ← backend contract with no repository record | 20 RPCs, 14 tables/views, RLS policies, Storage bucket | **Critical** — see A.8 |

Coupling *between* features is low. Wanted, Profile, Board and Collaboration interact only through `goTo()`, `getMyDomainId()`, and the transport helpers.

#### A.5 Maintainability

The file is unusually well commented for its type. Comments explain *why*, cite phase numbers, and record deliberate non-decisions (e.g. 3025–3026 "non-interactive by design … per the explicit instruction not to make an inert card look active"; 2492–2493 "Explicit exception: same target_type as 'created', deliberately different destination — not a gap, a genuine semantic difference"). This is real, durable institutional knowledge and should be preserved through any future change.

Working against that:

**Function size.** Ten largest functions:

| Lines | Function | Location |
|---|---|---|
| **489** | `openCollaboration` | `index.html:2584` |
| 100 | `loadCollaborationAssets` | `index.html:4291` |
| 93 | `renderWanted` | `index.html:1750` |
| 85 | `loadCollaborationTasks` | `index.html:3680` |
| 78 | `subscribeToCollaborationRealtime` | `index.html:4015` |
| 74 | `loadMyWanted` | `index.html:2189` |
| 73 | `uploadCollaborationAsset` | `index.html:4585` |
| 72 | `openApplicants` | `index.html:2263` |
| 71 | `sendCollaborationMessage` | `index.html:3575` |
| 62 | `loadCollaborationMessages` | `index.html:3316` |

`openCollaboration()` is the outlier by a factor of five. In one function it performs identity resolution, six concurrent metric queries, up to three additional sequential queries, health computation, a ~100-line HTML string build, participant rendering with owner-only controls, an extended-profile lookup for departed participants, activity sentence construction across 22 activity types, and Modules card rendering. It is also re-invoked *wholesale* by the realtime activity handler (4062–4064). This is the single hardest thing in the codebase to change safely.

**No verification net.** There are no tests, no linter, no type checking, and no CI. Every guarantee in the file rests on manual Level 3 browser validation per `.apos/VALIDATION_STANDARD.md`. That standard is rigorous and is clearly being followed — but it does not catch regressions in code paths a given phase did not touch.

#### A.6 Dead code and broken element references

Verified by reference counting across the whole file. Each item below is confirmed dead, not merely suspected.

| Item | Location | Evidence |
|---|---|---|
| `switchWantedTab()` | 1668–1688 | Defined once, called zero times. References `#wMyTab`, `#wCommTab`, `#wCatChips`, `#wTabMy`, `#wTabComm` — **none of these five ids exist in the document.** If ever invoked it throws `TypeError: Cannot read properties of null`. |
| `setWantedCat()` | 1690–1695 | Defined once, called zero times. Targets `#wCatChips` (does not exist). |
| `loadMyWantedTab()` | 1697–1725 | Reachable only from `switchWantedTab()`, which is never called. Targets `#wMyList` (does not exist) but is null-guarded, so it would fail silently rather than throw. |
| `setCat()` | 1432–1436 | Defined once, called zero times. Targets `#stageCats` (does not exist). |
| `currentWantedTab` | 1666 | Written only by the dead `switchWantedTab()`; never read. |
| `currentWantedCat` | 1665 | Written only by the dead `setWantedCat()`. `renderWanted()` (1754) reads it, so it is permanently `'all'` — the Wanted category filter is unreachable. |
| `NOTIFICATION_TARGET_TYPES` | 2360–2363 | Declared with a comment calling it "the single source of truth for the allowed vocabulary" — then **never referenced anywhere.** The actual routing uses `notificationTypeHandlers` keyed by `type`. |
| `#apAvatar` lookup | 1588 | `getElementById('apAvatar')` — the id does not exist in the document. Null-guarded (`if(apAv)`), so the branch is simply never taken. |
| `#searchCount` | 381 | Element exists in markup; no code ever writes to it. Permanently empty. |
| `#profileAvatar` | 533 | Element exists; never written. Shows a hardcoded 🎸 for every user. |
| `#profileVerified` | 540 | Element exists with `display:none`; never shown. |
| `#profileGallery` | 553 | Element exists containing three hardcoded demo tiles; never populated from data. |

This is roughly 90 lines of dead JavaScript plus five inert DOM elements. It is low-risk to remove and is the cheapest maintainability win available.

#### A.7 Vendor dependency and startup failure path — **Critical**

```html
<script src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'></script>
```
`index.html:8`

Three compounding problems:

1. **Floating major version.** `@2` resolves to whatever the newest v2.x is at request time. There is no lockfile, no build step, and no staging environment. A jsDelivr-served v2 minor release with a behaviour change reaches every production user immediately, with no review step and no rollback path other than editing this line and pushing.
2. **No Subresource Integrity, no `crossorigin`.** There is no integrity check on third-party code that holds the user's session token.
3. **No failure path.** The tag is synchronous and non-`defer`. Line 964 executes `supabase.createClient(...)` at top level. If the CDN is unreachable, blocked, or serves a broken build, `supabase` is undefined, line 964 throws a `ReferenceError`, **the entire inline script fails to evaluate**, and no function in the file is ever defined.

The consequence of (3) is worse than a degraded app. Because **no screen carries the `active` class in the static markup** (verified: zero occurrences of `class="screen active"`), and `.screen{display:none}` is the CSS default (line 17), the first thing that adds `active` is `goTo()` inside `checkSessionAndStart()` — which never runs. **The user sees a permanently blank black page with no error, no message, and no retry.**

The same blank-page window exists in the normal case, briefly: `checkSessionAndStart()` (1298) awaits `getSession()` before the first `goTo()`, so on a cold load the user sees an empty black viewport until that promise resolves.

#### A.8 The backend contract is not in the repository — **Critical (recoverability)**

The application depends on a substantial server-side surface that exists **only inside the Supabase project** and appears nowhere in version control:

- **20 RPC functions**: `close_own_wanted_post`, `create_wanted_application`, `respond_to_wanted_application`, `change_collaboration_status`, `invite_collaboration_participant`, `remove_collaboration_participant`, `transfer_collaboration_ownership`, `leave_collaboration`, `create_collaboration_message`, `edit_collaboration_message`, `delete_collaboration_message`, `create_collaboration_task`, `edit_collaboration_task`, `complete_collaboration_task`, `delete_collaboration_task`, `edit_collaboration_asset`, `delete_collaboration_asset`, `create_collaboration_credit`, `edit_collaboration_credit`, `delete_collaboration_credit`.
- **14 tables/views** read directly: `users`, `public_profiles`, `profiles`, `user_auth_accounts`, `wanted_posts`, `wanted_applications`, `notifications`, `collaborations`, `collaboration_participants`, `collaboration_messages`, `collaboration_tasks`, `collaboration_assets`, `collaboration_credits`, `collaboration_activity`.
- **RLS policies and column-level grants** that the client code is written *around* — `supaUpdateMinimal()` exists (1136–1189) purely because `authenticated` lacks SELECT on `users.blocked` / `anonymized_at` / `is_system`; `fetchMyProfile()` enumerates columns explicitly (2134) for the same reason.
- **Server-side error codes** the UI branches on as a contract: `23505`, `P0012`, `P0013` (1962–1980), `P0053` (4875).
- **A Storage bucket** `collaboration-assets` with an upload policy but deliberately **no DELETE policy** (documented at 4633–4637), which is why the orphaned-file cleanup path is best-effort and expected to fail.
- **A signup trigger** that creates exactly one `profiles` row per user (noted at 1080–1083), which is why no client-side insert path for `profiles` exists.

`index.html` is the only file in the repository containing executable code. If the Supabase project were lost, misconfigured, or needed to be rebuilt, **there is no artifact in this repository from which to reconstruct it.** The knowledge exists as prose comments inside `index.html` and in `analysis/` phase documents, which is better than nothing, but it is not reproducible.

This also blocks a staging environment: without captured schema, a second Supabase project cannot be stood up to match production, which is precisely why authenticated flows currently cannot be validated before merge (`.apos/PROJECT_CONTEXT.md`, Deployment section).

---

### B. User experience

#### B.1 Authentication flow

Two screens: email entry (`#screen-authemail`, 293) and a wait screen (`#screen-authwait`, 311). Passwordless magic link via `signInWithOtp` (1238). Session restore on load via `getSession()` (1300); automatic entry on return from the link via `onAuthStateChange` → `SIGNED_IN` (1312–1316).

Working well:

- Client-side email format validation before the network call (1233).
- Button feedback during send: `SENDING…` + reduced opacity (1236).
- Real Supabase error text surfaced rather than a generic message (1240).
- Resend affordance on the wait screen (323).
- `SIGNED_OUT` checks whether an auth screen is already active before navigating (1319–1321), avoiding a redundant transition.

Problems:

| # | Issue | Location | Impact |
|---|---|---|---|
| B.1.1 | `emailRedirectTo: 'https://stagerz.app'` is hardcoded | 1238 | A magic link requested from `localhost` returns the user to production. This is the documented reason authenticated flows cannot be validated pre-merge. |
| B.1.2 | The auth flow is annotated **"TEST ONLY"** and the Supabase project as **"disposable"** | 307–310, 1218–1225 | The production domain currently points at a project the code itself describes as disposable. Whether that is still accurate is **unknown from the repository** and must be confirmed, not assumed. |
| B.1.3 | `document.getElementById(isResend ? null : 'authEmailBtn')` | 1235 | On resend, `getElementById(null)` looks up the literal id `"null"` and returns null. Harmless (all uses are guarded) but the resend path gives **no button feedback at all** — the user gets only a toast. |
| B.1.4 | The wait screen has no way to reach a signed-in state if the user opens the link on a different device | 311–325 | No code-entry fallback. Acknowledged in-code as a consequence of the hosted email template. |
| B.1.5 | Both `checkSessionAndStart()` and the `SIGNED_IN` handler call `enterApp()` | 1301, 1315 | On magic-link return both can fire, producing a duplicate `goTo('stage')` + duplicate `updateUnreadBadge()` network call. Not user-visible, but wasteful. |

#### B.2 Onboarding

There is effectively **no onboarding**. After sign-in the user lands directly on Stage (1290–1293), which is populated entirely with seven hardcoded demo works by fictional artists (`stageData`, 1362–1370). The user's own profile is empty — `#profileName` reads "Your Name" and `#profileRole` reads "Set up your artist profile" (539–542) — but nothing prompts them to fill it in.

`username` is **required** by `saveProfile()` (2073–2082) and is a hard precondition for being findable in the Collaboration invite picker (`runInviteUserSearch` searches `public_profiles.username`, 3161–3165). A user who never visits Edit Profile therefore **cannot be invited to any collaboration** and has no way to learn this. That is a genuine funnel break, not a cosmetic gap.

#### B.3 Navigation

`goTo()` (1327–1349) is a clean 23-line router: clear all `.active`, set one, reset the target's scroll position, dispatch a per-screen loader, and tear down Collaboration realtime when leaving the Collaboration area. For 20 screens this is entirely adequate and should not be replaced.

Weaknesses:

- **No browser history integration.** No `pushState`, no `hashchange`, no `popstate`. On mobile the hardware/gesture Back button exits the app rather than navigating back. Every screen carries its own in-app back affordance, so the app is never a dead end, but the platform Back gesture is actively wrong.
- **No deep linking.** Every URL is `https://stagerz.app` — a collaboration, a Wanted post, or an artist profile cannot be linked to or shared. For a collaboration product this is a substantive product limitation.
- **Back destinations are stateful, not structural.** `apBackScreen` (1664) is set by whichever function opened the Artist screen. It works, but two of the three back buttons in the static markup hardcode `goTo('stage')` (837, 898) and are then overwritten programmatically at 1513, 1605 and 1649 — three separate places rebinding the same two elements.

#### B.4 Responsiveness

**There are zero `@media` queries in the file.** The layout is a fixed mobile phone layout with no adaptation:

- `html,body { width:100%; height:100%; overflow:hidden; }` (14) — the document never scrolls; only `.sa` regions do.
- `.screen { position:fixed; inset:0; }` (17) — screens fill the viewport at any width.
- Base type sizes run 7–13 px throughout; the smallest UI text is **7 px** (`.p-stat-label`, `.card-badge`, `.short-action-cnt`, and numerous inline styles).

On a desktop or tablet viewport the entire UI stretches edge to edge with no max-width and 7–11 px type. There is no breakpoint, no container constraint, and no larger-screen type scale. The app is usable only on a phone-sized viewport.

Two accessibility problems compound this:

- `<meta name='viewport' content='width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no'>` (5) — **pinch-zoom is disabled.** Combined with 7 px type, users who need magnification have no recourse. This fails WCAG 1.4.4.
- `user-select:none` on `html,body` (14) — **text cannot be selected or copied anywhere in the app**, including collaboration messages, asset filenames, and credits. For a messaging and collaboration product this removes an expected capability.

#### B.5 Loading states

Loading treatment is deliberate and, in the areas most recently worked, genuinely good.

Handled well:

- Nine list screens show an explicit "Loading…" placeholder before their fetch (`waList` 2268, `mcList` 2539, `cdContent` 2586, `boardList` 2396, `ctList` 3682, `caList` 4293, `ccList` 4721, `cmList` 3319, `inviteSearchResults` 3158).
- **Optimistic message send (Phase 20.1)** is a strong pattern: `insertProvisionalCollaborationMessage()` (3476) paints the message immediately at 55% opacity with a `data-provisional-id` marker; the confirmed reload replaces it; a failure removes it and restores the typed text (3628–3632), preserving text typed while the request was in flight (3629).
- **`skipLoadingState` (Phase 20.1)** keeps the whole-area blanking for the initial load only. Every reconciliation reload repaints in place, so an open conversation never flashes empty.
- **Distinguishing failure from emptiness (Phase 20.3)** — `showCollaborationMessagesLoadError()` (3378–3391) appends a notice *below* existing rows rather than destroying history, and only replaces the container when nothing but a placeholder was showing.
- The busy-state helpers `tryBeginCollaborationBusy` / `endCollaborationBusy` (3939–3955) are applied consistently across ~18 mutation paths and correctly handle both `<button>` and styled `<div>` controls.

Not handled:

| Gap | Location |
|---|---|
| **Cold-start blank screen** — nothing is visible until `getSession()` resolves | 1298–1305 + zero `class="screen active"` in markup |
| Stage / Search / Wanted have no skeleton — feeds pop in | 4934–4938 |
| No global "you are offline" indicator; each failure is an isolated toast | — |
| No indication that realtime disconnected; `CHANNEL_ERROR` is logged only (4070–4074) | 4069–4075 |
| `openCollaboration()` shows one "Loading…" for a ~12-round-trip sequence with no progressive reveal | 2584–2640 |

#### B.6 Demo content presented as real — **High**

Three static datasets are rendered to signed-in users as if they were live platform content:

| Dataset | Location | Rendered where |
|---|---|---|
| `stageData` — 7 fictional works | 1362–1370 | Stage feed, all tabs (`buildStageFeed`, 1374) |
| `artistDB` — 19 fictional artists | 1518–1538 | Search results (`renderArtists`, 1555) |
| `wantedData` — 7 fictional posts | 1654–1662 | Wanted feed, **interleaved with real database rows** (`renderWanted`, 1750–1759) |

The Wanted case is the most consequential: `renderWanted()` unshifts real rows on top of the demo array, so a live post from a real user appears in the same list, in the same card style, as "Guitarist for Afrobeat EP · Leila Mensah · 🔵 verified". The demo cards even carry a blue verification badge (1765) that **no real user can obtain** — `openArtistProfile()` explicitly hides the badge because no verified concept exists in the schema (1632–1634).

Applying to a demo card is handled honestly (1800–1803: "Applications are available for live Wanted posts"), and the "coming in full version" toasts are honest about FameMaker, Backstage and playback. But the underlying situation stands: a signed-in production user cannot distinguish platform content from placeholder content, and the Search screen searches **only the fictional array** — real registered users are unreachable from Search entirely (see B.7).

#### B.7 Search does not search real users — **High**

`doSearch()` (1543) → `renderArtists()` (1555) filters `artistDB` only. Meanwhile `runInviteUserSearch()` (3155–3209) performs a real, correct, debounced, case-insensitive `ilike` search against `public_profiles`, filters out system/deleted/self/already-participant, and renders live results.

The capability exists and works. It is wired only into the Collaboration invite overlay, not into the app's primary Search screen. A real signed-up artist is therefore undiscoverable through the feature named "Find Artists" (376).

The Search input also carries a workaround: `readonly onfocus="this.removeAttribute('readonly')"` (379) — a mobile-keyboard-suppression trick that has the side effect of requiring an extra tap and breaking keyboard-only focus.

#### B.8 Error handling

Error handling is, at the transport layer, close to exemplary. All eight helpers catch their own network errors, log structured diagnostics, and return a normalised result. **No unhandled promise rejection can originate from the transport layer.** Callers uniformly surface the real Supabase message rather than a generic one, and specific Postgres error codes are translated into human sentences (`23505` → "You already applied", `P0012` → "This Wanted is no longer open", `P0013` → "You cannot apply to your own Wanted", `P0053` → "This participant already has a credit").

Weaknesses:

| # | Issue | Detail |
|---|---|---|
| B.8.1 | **Raw server errors shown to end users** | The fallback chain `error.message \|\| error.hint \|\| error.details \|\| JSON.stringify(error)` appears ~20 times. The final branch can put a raw JSON payload into a toast. |
| B.8.2 | **No global error handler** | No `window.onerror`, no `unhandledrejection` listener. A throw outside the transport layer (e.g. from a null DOM reference) is silent to the user. |
| B.8.3 | **Toast is the only error channel** | A single `#toast` element with a 3-second timeout (1353–1359). Errors are not dismissible, not persistent, not stackable — a second error replaces the first before it can be read. |
| B.8.4 | **`window.confirm()` for 8 destructive actions** | Leave collaboration, remove participant, transfer ownership, delete message/task/asset/credit, complete-with-open-tasks. Functional, but a native modal against a fully custom dark UI. |
| B.8.5 | **Console noise in production** | 81 `console.log` / `console.error` statements ship to users, including `supaSelect` logging every request's full raw response body (987–997). Session-adjacent data lands in the browser console on every page. |

#### B.9 Accessibility

| Check | Result |
|---|---|
| `aria-*` attributes | 0 |
| `role` attributes | 0 |
| Semantic `<button>` | 19, against 186 total click handlers — most interactive controls are `<div onclick>` |
| Keyboard operability | `<div>` controls are not focusable and not activatable by Enter/Space |
| Focus indicators | None defined; `outline:none` on all inputs (103, 160, 239, 241) |
| Pinch zoom | Disabled (5) |
| Text selection | Disabled globally (14) |
| Alt text | No `<img>` in static markup; dynamically created preview `<img>` (4516) has no `alt` |
| Colour contrast | Extensive `rgba(255,255,255,.2)`–`.35` text on `#08080f`/`#111118` at 7–9 px — well below WCAG AA |
| Live regions | Toasts and typing indicators are not announced |

The app is not usable with a screen reader and is not operable by keyboard.

---

### C. Code quality

#### C.1 Duplicated logic

**C.1.1 — Error-message extraction, ~20 occurrences.** The identical four-branch chain appears in `closeWantedPost` (1926), `applyToWanted` (1983), `submitWanted` (2030, 2044), `respondToApplication` (2346), `changeCollaborationStatus` (3090), `performCollaborationInvite` (3226), `removeParticipant` (3245), `transferOwnership` (3264), `promptLeaveCollaboration` (3289), `saveMessageEdit` (3550), `deleteMessagePrompt` (3569), `sendCollaborationMessage` (3630), `saveCollaborationTaskTitle` (3808), `deleteCollaborationTaskPrompt` (3827), `createCollaborationTask` (3859), `completeCollaborationTask` (3876), `saveCollaborationAssetEdit` (4436), `deleteCollaborationAssetPrompt` (4455), `saveCollaborationCreditEdit` (4823), `deleteCollaborationCreditPrompt` (4842), `createCollaborationCredit` (4876).

**C.1.2 — RPC → toast → reload, ~18 occurrences.** Every Collaboration mutation follows byte-identical structure:

```js
if(!tryBeginCollaborationBusy(btn)) return;
var result = await supaRpc('<name>', {…});
console.log('<name> result:', result);
if(result && result.ok){ showToast('<success>'); await load<Area>(currentCollaborationId); }
else { console.error(…); var realMsg = <C.1.1 chain>; showToast(realMsg || '<fallback>'); endCollaborationBusy(btn); }
```

This consistency is a strength — it is trivially auditable. But a change to the shape (e.g. adding retry, adding an offline queue, changing how errors are surfaced) currently requires 18 identical edits, which is exactly the kind of change most likely to be applied inconsistently.

**C.1.3 — `toggleRemote()` duplicates `setRemoteToggle()`.** Lines 1986–1993 and 1843–1850 contain the same four DOM writes; the only difference is `pwRemoteOn = !pwRemoteOn` versus `pwRemoteOn = !!value`. `toggleRemote()` could be `setRemoteToggle(!pwRemoteOn)`.

**C.1.4 — Inline edit widget, 4 near-identical implementations.** `beginEditMessage` (3506), `beginEditCollaborationTaskTitle` (3765), `beginEditCollaborationAsset` (4391), `beginEditCollaborationCredit` (4780) each build "replace static text with input + Save/Cancel, wire handlers by id-suffix, focus". They differ in field count, element type, and maxlength. The pattern is explicitly acknowledged in comments as intentional mirroring ("mirrors the Task/Asset/Credit pattern exactly", 3503).

**C.1.5 — Avatar block, 5 occurrences.** The `photo_url ? background-image : neutral glyph` pair appears at 2832–2835, 3010–3013, 3191–3194, 3408–3411, and in a fixed form at 4744.

**C.1.6 — Chip-picker deselect-all-then-select, 7 occurrences.** `pickChip` (1994), `pickRole` (2052), `setSearchCat` (1548), `setStageCat` (1459), `setStageTab` (1441), `setCat` (1432, dead), plus the inline versions inside `openCollaborationTasks` (3667) and `openCollaborationCredits` (4706).

**C.1.7 — Profile-lookup fan-out, 5 occurrences.** "collect ids → `supaSelect('public_profiles', 'id=in.(…)')` → `supaSelect('profiles', …)` → build two lookup maps" appears in `openApplicants` (2278–2285), `openCollaboration` (2604–2612), `loadCollaborationMessages` (3342–3353), plus partial forms at 2933 and 3161.

#### C.2 Oversized functions

`openCollaboration()` at 489 lines is the only one that materially threatens maintainability. Its internal shape:

| Responsibility | Lines | Approx. |
|---|---|---|
| Fetch collaboration, subscribe realtime, fetch participants + profiles | 2584–2625 | 42 |
| Six concurrent dashboard queries + derived metric computation | 2627–2686 | 60 |
| Owner status controls + read-only notice | 2688–2705 | 18 |
| ~100-line HTML string for header, description, overview, dashboard, health, members | 2707–2812 | 106 |
| `renderParticipantRow` closure + owner/member sections | 2814–2891 | 78 |
| Leave control | 2893–2902 | 10 |
| Extended profile lookup for departed participants | 2904–2935 | 32 |
| Activity sentence construction, 22 branches | 2937–3023 | 87 |
| Modules cards | 3025–3065 | 41 |

The activity-sentence block (87 lines, 22 `else if` branches) is a self-contained pure function with no dependency on anything but `item`, `publicById`, `extendedPublicById` and `escapeCollaborationHtml`. It is the clearest extraction candidate in the file and can be lifted with essentially zero behavioural risk.

#### C.3 Repeated DOM access

194 `getElementById` calls with no caching. Individually cheap; the pattern-level costs are:

- **`openCollaboration()` alone** performs ~15 lookups plus a full `contentEl.innerHTML` replace followed by ~30 `appendChild` calls into the live DOM — each append triggering layout in the worst case.
- **No element references are cached** even within a single function. `applyCollaborationReadOnlyGuard` (3100) re-resolves both elements on every call, as does every mutation's post-success reload.
- **Id strings are string-concatenated at 12 sites** (`'cmBodyText-'+m.id`, `'ctTitleText-'+t.id`, `'caTitleText-'+a.id`, `'ccRoleText-'+c.id`, and the Save/Cancel button ids in each inline editor). These are unverifiable statically; a typo fails silently.

#### C.4 Repeated Supabase calls

**C.4.1 — `supaHeaders()` calls `auth.getSession()` on every single request.** Lines 970–978 are invoked by all 41 `supaSelect`, 21 `supaRpc`, and every insert/update. `getSession()` reads local storage and may refresh — it is not free, and it is awaited before every fetch. `openCollaboration()` triggers it ~12 times for one screen open.

**C.4.2 — `openCollaboration()` performs ~12 round trips**, only 6 of which are concurrent:

```
1  collaborations                    (sequential)
2  user_auth_accounts                (first getMyDomainId — cached after)
3  collaboration_participants        (sequential)
4  public_profiles                   (sequential)
5  profiles                          (sequential)
6-11 Promise.all: messages count, last message, tasks, assets, credits, activity
12 wanted_posts                      (sequential, conditional)
13 public_profiles (extended)        (sequential, conditional)
```

Steps 3–5 could run concurrently with 6–11 in most cases. The realtime activity handler re-runs this entire sequence on every activity INSERT (4062–4064), debounced to 300 ms.

**C.4.3 — `updateUnreadBadge()` fetches rows to count them.** Line 2523 selects the `id` of every unread notification and counts client-side, while `supaSelectCount()` (1010–1032) exists specifically to do this with `Prefer: count=exact` and `Range: 0-0`. `supaSelectCount` is used exactly once in the file (2634).

**C.4.4 — `getMyDomainId()` is called 20+ times** but is correctly memoised (1274–1276) and reset on logout (1262). Only the first call hits the network. Not a defect; recorded for completeness. `openCollaboration()` still calls it twice (2598, 2618) where once would do.

**C.4.5 — Duplicate profile fetches across sub-screens.** `loadCollaborationMessages()` re-fetches `public_profiles` and `profiles` for message senders (3347–3348) even though `openCollaboration()` already populated `currentCollaborationPublicById` for all participants — and message senders are, by definition, participants (or former participants).

#### C.5 Repeated event handling

- **132 inline `onclick=` attributes** in the HTML block plus **54 programmatic `.onclick =` assignments**. Two idioms for the same job.
- **`.onclick =` rather than `addEventListener`** everywhere except two places (`inviteSearchInput` 3136, `DOMContentLoaded` 4934). Single-handler assignment means a second binding silently replaces the first — which is relied upon at 1513, 1605 and 1649 where the same back button is rebound by three different callers.
- **No event delegation.** Every list render attaches one handler per row. A 200-message conversation creates up to 400 individual closures (Edit + Delete per own message); a full reload discards and recreates all of them.
- **The closure-factory idiom `(function(x){ return function(){…}; })(x)`** appears ~25 times to capture loop variables — necessary given `var`-scoped loops and `forEach` callbacks, and applied correctly, but verbose.

#### C.6 Output escaping is incomplete — **Critical**

`escapeCollaborationHtml()` (4251–4259) is a correct five-character escaper and is applied at 32 sites — messages, tasks, credits, assets, activity, board notifications, and invite search results are all properly escaped.

**It is not applied on several paths that interpolate user-controlled database values directly into `innerHTML`:**

| # | Value | Location | Source is user-controlled via |
|---|---|---|---|
| 1 | `c.title` (collaboration title) | `loadMyCollaborations`, **2576** | Collaboration creation |
| 2 | `collab.title` | `openCollaboration` header, **2715** | Collaboration creation |
| 3 | `wantedTitle` | `openCollaboration`, **2719** | `submitWanted()` → `wanted_posts.title` |
| 4 | `pub.display_name` | `openApplicants`, **2313** | `saveProfile()` → `profiles.display_name` |
| 5 | `metaParts.join()` (username, role, location) | `openApplicants`, **2314** | `saveProfile()` |
| 6 | `pub.display_name` | `renderParticipantRow`, **2841** | `saveProfile()` |
| 7 | `metaParts.join()` | `renderParticipantRow`, **2842** | `saveProfile()` |
| 8 | `item.title`, `item.role`, `item.cat`, `item.comp` | `renderWanted`, **1773–1779** | `submitWanted()` |
| 9 | `pub.photo_url` inside `background-image:url('…')` | **2833, 3011, 3192, 3409** | Profile photo URL |

Items 1–8 are stored-XSS vectors: a user sets their display name or a Wanted title to `<img src=x onerror=…>`, and the payload executes in the browser of every other user who opens the applicant list, the participant list, the collaboration workspace, or the Wanted feed. Item 9 is an attribute-injection vector — a `'` in `photo_url` closes the `url()` and the `style` attribute.

The RLS model limits *who* sees the payload (co-participants, post owners), but does not prevent it. Escaping is already the established convention in this file with a working helper — these sites simply were not brought along.

Two related observations:

- `openArtistProfile()` (1617–1651) correctly uses `textContent` throughout and is not affected.
- `loadMyWanted()` (2189) and `loadMyWantedTab()` (1697) build rows with `createElement` + `textContent` and are not affected. The safe pattern is already present in the codebase alongside the unsafe one.

#### C.7 Ineffective guards

`loadCollaborationTasks()` (3697) and `loadCollaborationAssets()` (4308) contain:

```js
if(!listEl.isConnected) return; // screen was left mid-load
```

`#ctList` and `#caList` are declared in the static markup and are **never removed from the document**, so `isConnected` is permanently `true`. The guard never fires and provides no protection against the race it was written for. (The same idiom at 3166 `resultsEl.isConnected` and 4497 `container.isConnected` **is** effective, because those elements genuinely are removed — the invite overlay is detached on close, and the preview container is destroyed by the list's `innerHTML = ''`.)

The real race remains unaddressed: navigating away and back during a load leaves the earlier in-flight response able to paint into a screen the user has since re-entered.

#### C.8 Opportunities for modularization — within the single-file architecture

All of the following stay inside `index.html` and require no build step:

| Opportunity | Replaces | Est. lines saved |
|---|---|---|
| `extractSupabaseErrorMessage(result)` | C.1.1, 20 sites | ~40 |
| `runCollaborationMutation({rpc, params, control, success, reload})` | C.1.2, 18 sites | ~120 |
| `renderCollaborationActivitySentence(item, …)` extracted from `openCollaboration` | C.2, 87 lines | 0 net, large clarity gain |
| `buildAvatarMarkup(profile, size)` | C.1.5, 5 sites | ~15 |
| `fetchProfileMaps(ids)` | C.1.7, 5 sites | ~35 |
| `setActiveChip(container, el)` | C.1.6, 7 sites | ~15 |
| `toggleRemote()` → `setRemoteToggle(!pwRemoteOn)` | C.1.3 | ~7 |

None of these change behaviour, none introduce a new pattern (all are *Reuse* or *Extend* under the `.apos/WORKFLOW.md` pattern-decision rule), and each has a single, testable purpose.

---

### D. Performance

#### D.1 Startup cost

| Step | Cost |
|---|---|
| HTML + CSS + JS parse | ~265 KB, single request, no compression control (GitHub Pages gzips) |
| Supabase UMD SDK | ~120 KB from jsDelivr — **render-blocking**, synchronous, in `<head>` |
| Google Fonts `@import` inside `<style>` | 10 — **render-blocking and serialised**: the browser must parse the stylesheet before it discovers the font request. A `<link rel=preconnect>` + `<link>` would start it far earlier. |
| `DOMContentLoaded` work | `buildStageFeed('all')` builds 7 cards; `renderArtists()` builds 19 rows; `renderWanted(null)` builds 7 cards — **33 DOM subtrees constructed before it is known whether the user is even signed in** (4934–4938) |
| `checkSessionAndStart()` | Async `getSession()` — **nothing is visible until it resolves** (A.7) |

The three pre-auth renders (4935–4937) are pure waste on the unauthenticated path and are re-run anyway when the user navigates to those screens (`goTo` 1334–1335).

#### D.2 Rendering

- **Full-replace rendering everywhere.** Every loader does `container.innerHTML = ''` then appends. This is what makes realtime reconciliation duplicate-proof (documented at 3962–3965) and is a deliberate, defensible trade. The cost is that a single new message reconstructs up to 200 rows and up to 400 event handlers.
- **Layout thrash in `openCollaboration()`.** One large `innerHTML` write (2812) followed by ~30 sequential `appendChild` calls into the already-live container (participants, leave row, activity rows, module cards). A `DocumentFragment` would batch these into one reflow.
- **Unbounded message list.** `limit=200` (3323) with no pagination and no virtualisation. At 200 messages the list holds 200 rows and up to 400 handlers, all rebuilt on every reload. Conversations silently truncate at 200 with no indication to the user.
- **Unbounded activity list.** `limit=50` (2639), rebuilt on every Workspace open and every activity event.
- **No `will-change`, no compositor hints.** Screen switching is a `display:none` ↔ `display:flex` toggle, which forces full layout of the incoming screen. At this app's size that is fine.

#### D.3 Event listeners

- Handlers are attached per row with no delegation (C.5). Peak count is roughly `messages × 2 + tasks × 3 + assets × 4 + participants × 3`.
- **No listener leaks identified.** Because handlers are assigned as `.onclick` properties on elements that are discarded wholesale by `innerHTML = ''`, they are collected with their elements. The dynamically created overlays (`inviteUserPickerOverlay` 3131, fullscreen preview 4544) are explicitly removed from `document.body`.
- **Timers are correctly managed.** `toastTimer` is cleared before reset (1357); `inviteSearchTimeout` is cleared on close (3150); `collaborationTypingIdleTimer` has a dedicated clear function (4209) invoked from teardown; all four realtime debounce timers are cleared in `unsubscribeFromCollaborationRealtime()` (4007–4012). `recTimer` (4894) is cleared in `stopRec()` — but **not** if the user navigates away from FameMaker mid-recording, leaving a 1 Hz interval running indefinitely.
- **Object URLs are correctly revoked.** `revokeCollaborationAssetObjectUrls()` (4261–4267) runs on leaving and on re-entering the Assets screen; the download path revokes immediately after the click (4675).

#### D.4 Network usage

| Pattern | Cost |
|---|---|
| `getSession()` before every request (C.4.1) | 60+ awaited local-storage reads per session, with possible refresh |
| `openCollaboration()` ~12 round trips (C.4.2) | Dominates Workspace open latency |
| `updateUnreadBadge()` transfers rows to count them (C.4.3) | O(unread) instead of O(1) |
| Message-sender profiles re-fetched (C.4.5) | 2 avoidable queries per message load |
| Realtime → full area reload | Each event re-fetches the whole area, 300 ms debounced |
| No HTTP caching strategy | `supaSelect` sends no `Cache-Control`; no client-side result cache |
| No request cancellation | Navigating away does not abort in-flight fetches (no `AbortController` anywhere) |

None of this is pathological at current scale. `openCollaboration()`'s serial chain is the one that will be felt first on a slow connection.

#### D.5 Unnecessary work

1. Three feeds rendered before auth is known (4935–4937).
2. `renderWanted()` builds the 7 demo cards on every Wanted load and then unshifts real rows (1754–1759) — the demo work is redone every time.
3. `enterApp()` can run twice on magic-link return, duplicating `updateUnreadBadge()` (B.1.5).
4. `getMyDomainId()` called twice inside `openCollaboration()` (2598, 2618).
5. `openCollaboration()` re-runs in full on every realtime activity INSERT (4062–4064) when only the Activity section changed.
6. 81 `console.log`/`console.error` statements execute on every user action in production, including full response-body logging (987–997).

---

### E. Technical debt register

Ranked by risk to users and to the project's ability to continue safely.

#### Critical

| ID | Item | Location | Why critical |
|---|---|---|---|
| **C-1** | **Incomplete output escaping — stored XSS** | 1773–1779, 2313–2314, 2576, 2715, 2719, 2841–2842, 2833, 3011, 3192, 3409 | User-controlled `display_name`, `username`, `role`, `location`, Wanted `title`, and collaboration `title` are interpolated unescaped into `innerHTML`. A working escaper already exists and is used elsewhere in the same file. |
| **C-2** | **Unpinned CDN dependency with no failure path** | line 8, line 964 | `@supabase/supabase-js@2` floats across all v2 releases with no SRI, no lockfile, no staging. If the CDN fails, the whole inline script throws and — because no screen is `active` in the markup — the user gets a permanently blank black page with no message. |
| **C-3** | **Backend contract exists only inside Supabase** | 20 RPCs, 14 tables/views, RLS policies, Storage bucket, signup trigger | Nothing in the repository can reconstruct the server. Blocks disaster recovery, blocks a staging environment, and is the root cause of authenticated flows being unverifiable before merge. |

#### High

| ID | Item | Location | Impact |
|---|---|---|---|
| **H-1** | Production may point at a project the code calls "disposable / TEST ONLY" | 307–310, 1218–1225, 962 | Unknown from the repository. If accurate, real user data sits on a project not intended to persist. **Must be confirmed, not assumed.** |
| **H-2** | Demo content presented as real platform content | 1362–1370, 1518–1538, 1654–1662, 1750–1759 | Fictional artists and Wanted posts render alongside real rows with a verification badge no real user can earn. |
| **H-3** | Search cannot find real users | 1543–1582 vs. 3155–3209 | The working `public_profiles` search is wired only into the invite overlay. Real artists are undiscoverable from the Search screen. |
| **H-4** | ~90 lines of dead code, incl. 3 functions targeting 6 nonexistent element ids | 1432–1436, 1665–1666, 1668–1725, 2360–2363, 1588 | `switchWantedTab()` would throw immediately if ever wired up; `currentWantedCat` is permanently `'all'`, silently disabling the Wanted category filter. |
| **H-5** | No browser history, no deep linking | 1327–1349 | Hardware Back exits the app. No collaboration, post, or profile can be linked or shared. |
| **H-6** | No automated verification of any kind | repository-wide | No tests, lint, type check, or CI. Every guarantee rests on manual Level 3 validation of the changed path only. |
| **H-7** | Pinch-zoom and text selection disabled | line 5, line 14 | 7–9 px text that cannot be magnified; collaboration messages that cannot be copied. |

#### Medium

| ID | Item | Location |
|---|---|---|
| M-1 | `openCollaboration()` at 489 lines, re-invoked wholesale by realtime | 2584–3066, 4062–4064 |
| M-2 | Error-extraction chain duplicated ~20×; RPC-mutation shape duplicated ~18× | see C.1.1, C.1.2 |
| M-3 | `openCollaboration()` performs ~12 round trips, only 6 concurrent | 2584–2673 |
| M-4 | `getSession()` awaited before every request | 970–978 |
| M-5 | Zero `@media` queries — unusable above phone width | CSS block 9–286 |
| M-6 | Message list capped at 200 with no pagination and no indication | 3323 |
| M-7 | `isConnected` guards on permanently-mounted elements never fire | 3697, 4308 |
| M-8 | 81 `console` statements ship to production, incl. full response bodies | 987–997 and throughout |
| M-9 | No global `window.onerror` / `unhandledrejection` handler | — |
| M-10 | Raw server error text (incl. `JSON.stringify(error)`) shown in toasts | ~20 sites |
| M-11 | `updateUnreadBadge()` transfers rows to count them; `supaSelectCount()` unused for it | 2523 vs 1010 |
| M-12 | Cold-start blank screen until `getSession()` resolves | 1298–1305 |
| M-13 | No onboarding; required `username` is never prompted, silently blocking invitability | 2073–2082, 3161–3165 |

#### Low

| ID | Item | Location |
|---|---|---|
| L-1 | `toggleRemote()` duplicates `setRemoteToggle()` | 1843–1850, 1986–1993 |
| L-2 | `getElementById(isResend ? null : 'authEmailBtn')` — resend gives no button feedback | 1235 |
| L-3 | `myProfile` not cleared on logout | 1258–1265, 2050 |
| L-4 | `enterApp()` can run twice on magic-link return | 1301, 1315 |
| L-5 | `recTimer` keeps running if the user leaves FameMaker mid-recording | 4906 |
| L-6 | Three feeds rendered before auth state is known | 4935–4937 |
| L-7 | Search input `readonly`/`onfocus` workaround costs an extra tap and breaks keyboard focus | 379 |
| L-8 | Google Fonts loaded via render-blocking `@import` rather than `<link>` | 10 |
| L-9 | Inert markup: `#searchCount`, `#profileAvatar`, `#profileVerified`, `#profileGallery` never populated | 381, 533, 540, 553 |
| L-10 | `README.md` is two lines and documents nothing | `README.md` |
| L-11 | 132 inline `onclick` vs 54 programmatic — two idioms for one job | throughout |
| L-12 | Dynamic element ids built by string concatenation at 12 sites | throughout |

---

### F. Production readiness

#### F.1 Stability — **Moderate**

Strengths: the transport layer cannot throw; every write path is null-checked; teardown of realtime, timers and object URLs is thorough; the busy-state guard prevents double-submission across ~18 mutation paths; Phases 20.1–20.3 hardened the messaging path specifically against duplicate rows, whole-area flashes, and failure-as-emptiness.

Weaknesses: one uncaught throw anywhere outside the transport layer is invisible to the user (no global handler, M-9); a CDN failure produces a blank page (C-2); three dead functions would throw immediately if ever wired up (H-4).

#### F.2 Reliability — **Moderate**

Strengths: server-side authority is consistently respected; specific Postgres error codes are translated to human sentences; the `null` vs `[]` distinction is honoured; metrics render `—` rather than a wrong `0`; the Storage-upload-then-metadata-insert failure path attempts cleanup and reports honestly when cleanup itself fails (4632–4652).

Weaknesses: no retry on any transient failure; no offline detection or queueing; realtime disconnection is logged but never surfaced (4070–4074); no request cancellation, so navigation races can paint stale data; raw server errors can reach the user as JSON.

#### F.3 Recoverability — **Weak**

This is the weakest dimension, and the gap is structural rather than incidental.

| Capability | Status |
|---|---|
| Roll back a frontend release | Possible — `git revert` + push (GitHub Pages redeploys `main`) |
| Reconstruct the backend | **Not possible from this repository** (C-3) |
| Reproduce production in a staging environment | **Not possible** — no captured schema, no second project, no environment configuration |
| Validate authenticated flows before merge | **Not possible** — `emailRedirectTo` is hardcoded to production (1238); documented in `PROJECT_CONTEXT.md` |
| Detect a production failure | **No mechanism** — no error reporting, no uptime check, no analytics |
| Recover orphaned Storage files | Best-effort only; the bucket has no DELETE policy by design (4633–4637) |
| Confirm the production data store is durable | **Unknown** — the code describes it as disposable (H-1) |

The frontend is recoverable. The system is not.

#### F.4 Maintainability — **Moderate to good**

Strengths: exceptionally good comments that record intent and prior decisions; a consistent, auditable pattern for every feature; genuine separation at the transport boundary; a rigorous validation standard that is being followed; a clean phase history with each change traceable to an analysis document.

Weaknesses: one 489-line function; ~200 lines of mechanical duplication across ~40 sites; no automated verification net; 194 unchecked string-id DOM couplings, 6 of which are already broken; the single largest body of project knowledge (the backend contract) lives outside version control.

#### F.5 Overall verdict

**The application is a well-built, carefully governed prototype approaching production quality, and it is not yet production-ready.**

The blockers are specific and finite, not architectural:

1. Complete the escaping that the file already establishes as its own convention (C-1).
2. Pin the vendor dependency and give the app a startup failure path (C-2).
3. Get the backend contract into the repository (C-3).
4. Confirm what production is actually running against (H-1).

None of these require abandoning the single-file architecture, and none require a build step. The architecture is not what is holding the project back.

---

## 3. File locations

| Path | Role | Modified by this phase |
|---|---|---|
| `index.html` | Entire application: CSS 9–286, markup 288–958, JavaScript 960–4940 | **No** |
| `.apos/PROJECT_CONTEXT.md` | Governance — identity, roadmap decisions, phase history | No |
| `.apos/VALIDATION_STANDARD.md` | Governance — four validation levels, eleven pre-commit checks | No |
| `.apos/WORKFLOW.md` | Governance — roles, analysis rules, required document structure | No |
| `README.md` | 2 lines; no technical content | No |
| `CNAME` | `stagerz.app` | No |
| `analysis/phase-20.1/` … `analysis/phase-20.6/` | Prior phase records | No |
| `analysis/phase-20.7/codebase-assessment.md` | **This document** | Created |

---

## 4. Function names

Referenced in this assessment, by region.

**Transport (961–1216):** `supaHeaders`, `supaSelect`, `supaSelectCount`, `supaInsert`, `supaUpsert`, `supaUpdate`, `supaUpdateMinimal`, `supaRpc`

**Auth & identity (1218–1323):** `sendOtp`, `logout`, `getMyDomainId`, `enterApp`, `checkSessionAndStart`

**Navigation & feedback (1326–1359):** `goTo`, `showToast`

**Stage (1362–1515):** `buildStageFeed`, `buildCard`, `buildShort`, `setCat` *(dead)*, `setStageTab`, `setStageCat`, `buildFollowingFeed`, `openContent`

**Search & artist (1543–1651):** `doSearch`, `setSearchCat`, `renderArtists`, `openArtist`, `openArtistProfile`

**Wanted (1668–2047):** `switchWantedTab` *(dead)*, `setWantedCat` *(dead)*, `loadMyWantedTab` *(dead)*, `loadWanted`, `renderWanted`, `setRemoteToggle`, `selectChipByValue`, `normalizeCategoryText`, `normalizeCompensationText`, `resetPostWantedForm`, `cancelPostWanted`, `openEditWanted`, `closeWantedPost`, `applyToWanted`, `toggleRemote`, `pickChip`, `submitWanted`

**Profile (2052–2253):** `pickRole`, `normalizeUsername`, `saveProfile`, `fetchMyProfile`, `loadMyProfile`, `restoreRoleSelection`, `populateEditProfile`, `loadMyWanted`

**Applicants (2263–2349):** `openApplicants`, `respondToApplication`

**Board (2383–2531):** `boardTimeAgo`, `loadBoard`, `navigateToWantedPostApplicants`, `navigateToCollaboration`, `handleNotificationTap`, `markNotificationRead`, `markAllNotificationsRead`, `updateUnreadBadge`

**Collaboration — workspace (2537–3109):** `loadMyCollaborations`, `openCollaboration`, `renderParticipantRow` *(inner closure)*, `requestMarkCollaborationCompleted`, `changeCollaborationStatus`, `applyCollaborationReadOnlyGuard`

**Collaboration — participants (3119–3293):** `openInviteUserPicker`, `closeInviteUserPicker`, `runInviteUserSearch`, `performCollaborationInvite`, `removeParticipant`, `transferOwnership`, `promptLeaveCollaboration`

**Collaboration — messages (3300–3636):** `openCollaborationMessages`, `loadCollaborationMessages`, `showCollaborationMessagesLoadError`, `buildCollaborationMessageRow`, `allocateProvisionalId`, `buildProvisionalRenderModel`, `insertProvisionalCollaborationMessage`, `removeProvisionalCollaborationMessage`, `beginEditMessage`, `cancelMessageEdit`, `saveMessageEdit`, `deleteMessagePrompt`, `sendCollaborationMessage`

**Collaboration — tasks (3646–3880):** `openCollaborationTasks`, `loadCollaborationTasks`, `beginEditCollaborationTaskTitle`, `saveCollaborationTaskTitle`, `deleteCollaborationTaskPrompt`, `createCollaborationTask`, `completeCollaborationTask`

**Collaboration — assets (3888–4677):** `classifyCollaborationAssetType`, `sanitizeCollaborationAssetFileName`, `formatCollaborationFileSize`, `revokeCollaborationAssetObjectUrls`, `leaveCollaborationAssets`, `openCollaborationAssets`, `loadCollaborationAssets`, `beginEditCollaborationAsset`, `saveCollaborationAssetEdit`, `deleteCollaborationAssetPrompt`, `toggleCollaborationAssetPreview`, `renderCollaborationAssetPreviewMedia`, `openCollaborationAssetFullscreenPreview`, `beginCollaborationAssetUploadClick`, `handleCollaborationAssetFileSelected`, `releaseCollaborationAssetUploadGuard`, `uploadCollaborationAsset`, `downloadCollaborationAsset`

**Collaboration — credits (4685–4881):** `openCollaborationCredits`, `loadCollaborationCredits`, `beginEditCollaborationCredit`, `saveCollaborationCreditEdit`, `deleteCollaborationCreditPrompt`, `createCollaborationCredit`

**Collaboration — shared helpers (3939–4259):** `tryBeginCollaborationBusy`, `endCollaborationBusy`, `isCollaborationWorkspaceScreenActive`, `scheduleCollaborationRealtimeReload`, `unsubscribeFromCollaborationRealtime`, `subscribeToCollaborationRealtime`, `announceCollaborationPresence`, `renderCollaborationPresenceFromChannel`, `renderCollaborationOnlineIndicator`, `renderCollaborationTypingIndicator`, `setCollaborationTypingState`, `clearCollaborationTypingIdleTimer`, `handleCollaborationMessageInputChanged`, `stopCollaborationTypingNow`, `escapeCollaborationHtml`

**FameMaker & Backstage (4884–4931):** `switchFMTab`, `toggleRec`, `startRec`, `stopRec`, `switchBilling`

---

## 5. Risks

### 5.1 Risks in the current application

| # | Risk | Likelihood | Impact | Basis |
|---|---|---|---|---|
| R-1 | Stored XSS via display name, username, role, location, Wanted title, or collaboration title | Medium | High — session token theft, account takeover within the RLS blast radius | C-1, 10 confirmed unescaped sites |
| R-2 | Total outage from a CDN failure or a breaking `@2` release, presenting as a blank page | Low–Medium | High — app is completely unusable with no message | C-2 |
| R-3 | Backend cannot be reconstructed or reproduced | Low | Severe — unrecoverable if the Supabase project is lost | C-3 |
| R-4 | Production data sits on a project the code calls "disposable" | **Unknown** | Severe if true | H-1 |
| R-5 | Regression in an untouched code path goes undetected | Medium | Medium — no automated net; Level 3 validation covers the changed path | H-6 |
| R-6 | New users cannot be found or invited because `username` was never set | High | Medium — silent funnel break | M-13 |
| R-7 | Real users mistake demo content for platform content | High | Medium — trust damage on first use | H-2 |
| R-8 | A conversation exceeding 200 messages silently truncates | Low today | Medium — history appears lost | M-6 |
| R-9 | Navigation race paints stale data into a re-entered screen | Low | Low–Medium | C-7 |
| R-10 | Response bodies logged to the browser console in production | Certain | Low–Medium | M-8 |

### 5.2 Risks introduced by the recommended work

| Phase | Principal risk | Mitigation |
|---|---|---|
| 21.1 Escaping | Double-escaping a value already escaped upstream; escaping a value that legitimately carries markup | The affected values are all plain text; verify each site individually against Level 3 |
| 21.2 Startup resilience | Pinning to an exact SDK version could surface a behaviour difference from the floating version currently served | Pin to the version currently resolved in production; verify before changing it |
| 21.3 Backend capture | Reading schema/policies from production; risk of *writing* by mistake | Read-only extraction; no migration is applied by this phase |
| 21.4 Environment confirmation | None — investigation only | — |
| 21.5 Dead-code removal | Removing something believed dead that is reachable by a path not found | Reference counts are already verified; re-verify at implementation time |
| 21.6 Demo boundary | Over-correcting into an empty, discouraging app | Label rather than delete; keep Stage populated with a clear "Sample" marker |
| 21.7 Write-path consolidation | Behaviour drift across 18 converted call sites | Convert in small, individually validated batches; require byte-identical toast text |
| 21.8 `openCollaboration()` decomposition | The highest-risk item in the roadmap — one function drives the whole Workspace | Extract pure functions only; no reordering of network calls in the same phase |
| 21.9 Real search | Exposing profile fields more broadly than intended | Reuse `runInviteUserSearch()`'s existing `public_profiles` query and filters verbatim |
| 21.10 Responsive & a11y | Wide CSS surface; regressions on phone width | Additive `@media` at a single breakpoint; phone layout must remain byte-identical |

---

## 6. Recommendations — Roadmap

Ten phases, listed in **priority order**, which is also the **recommended execution order**. Dependencies are noted where the order is forced rather than merely preferred.

Numbering is proposed as 21.1–21.10 so that it does not collide with the completed 20.x removal sequence. Final numbering is ChatGPT's decision.

**Standing constraints for all phases below:** the single-file frontend architecture is retained; no build step, no bundler, no framework, no module system is introduced; no phase widens scope beyond what is stated.

---

### Phase 21.1 — Complete Output Escaping

**Objective.** Apply the existing `escapeCollaborationHtml()` at the ten confirmed sites that interpolate user-controlled database values into `innerHTML` unescaped (C-1), and make `photo_url` safe where it is injected into an inline `style` attribute.

**Expected benefit.** Closes the only confirmed security vulnerability class in the application. Makes escaping universal rather than area-specific, so the convention is checkable by inspection instead of by memory.

**Implementation risk.** **Low.** The helper exists, is correct, and is already used at 32 sites. Each change is a single wrapped expression. The `photo_url` sites need a slightly different treatment (attribute context, not HTML-text context) — the safest option is to set `backgroundImage` via `element.style` rather than via a concatenated attribute string, which removes the injection surface entirely.

**Estimated complexity.** **Low.** ~10 line-level edits plus 4 avatar sites. Level 3 validation on Applicants, Collaboration Workspace, Wanted feed, My Collaborations, and any screen showing a member avatar.

**Execution order.** **1** — no dependencies. Do this first regardless of everything else.

---

### Phase 21.2 — Startup Resilience and Vendor Dependency Pinning

**Objective.** Eliminate the blank-page failure mode and remove the floating dependency:

1. Pin the SDK to the exact version currently resolved in production and add Subresource Integrity + `crossorigin`.
2. Guard `supabase.createClient()` so a missing SDK does not abort the entire script.
3. Render a visible, honest failure screen when the SDK cannot load — not a blank page.
4. Mark one screen `active` in the static markup (or show a minimal branded splash) so something is visible before `getSession()` resolves.

**Expected benefit.** Removes the highest-impact availability risk (R-2). Turns an unpinned third-party major-version range into a reviewed, deliberate upgrade. Eliminates the cold-start blank window (M-12).

**Implementation risk.** **Low–Medium.** Pinning could surface a difference from whatever floating version is currently served — which is precisely the point, and is better discovered deliberately. Adding an initial `active` screen must not cause a flash of the wrong screen when a session already exists; the splash approach avoids this.

**Estimated complexity.** **Low.** Line 8, line 964, a small failure-state block, and one markup change.

**Execution order.** **2** — independent of 21.1; ordered second because it is availability rather than security.

---

### Phase 21.3 — Capture the Backend Contract in the Repository

**Objective.** Extract the complete server-side contract from the Supabase project into version-controlled SQL and documentation: table and view definitions, the 20 RPC function bodies, RLS policies, column-level grants, the signup trigger, and the `collaboration-assets` Storage bucket policies. Record the error-code contract (`23505`, `P0012`, `P0013`, `P0053`) that the frontend branches on.

This is **read-only extraction into files**. No migration is authored, applied, or proposed by this phase.

**Expected benefit.** Converts the project's largest body of undocumented knowledge into a reviewable artifact. Makes the backend reconstructable (C-3, F.3). Is the hard prerequisite for a staging environment, and therefore for ever validating authenticated flows before merge — the single most cited limitation in `PROJECT_CONTEXT.md`.

Adding SQL files does **not** violate the single-file constraint: that constraint governs the frontend, and this content does not exist in `index.html` at all.

**Implementation risk.** **Low.** Read-only. The only real risk is accidental writes during extraction, avoided by using read-only introspection.

**Estimated complexity.** **Medium.** 14 tables/views, 20 functions, and the associated policies — a substantial amount of material to extract and organise, but mechanical.

**Execution order.** **3** — no code dependency, but it unblocks 21.4 and any future staging work. Every phase after this one becomes safer once it exists.

---

### Phase 21.4 — Production Environment Confirmation

**Objective.** Answer, on the record, questions the repository cannot currently answer:

- Is `kbnmkyvbwkuvcklywdhk.supabase.co` still the "disposable test project" the code describes (307–310, 1218–1225), or is it now the intended production data store?
- Is the hosted email template still sending a magic link rather than a numeric code, and is `emailRedirectTo: 'https://stagerz.app'` the intended permanent configuration?
- Are there real users with real data on it today?
- If a separate production project is intended, what is the migration path?

Then update the "TEST ONLY" comments and `PROJECT_CONTEXT.md` to state whichever answer is true.

**Expected benefit.** Resolves H-1 / R-4 — currently the highest-*impact*, lowest-*known* risk in the register. Either it is a non-issue and the misleading comments are corrected, or it is a serious data-durability problem that needs a plan. Both outcomes are better than the present uncertainty.

**Implementation risk.** **None for investigation.** Any resulting migration would be a separate, separately approved phase.

**Estimated complexity.** **Low** to answer. **Unknown** to act on, pending the answer.

**Execution order.** **4** — benefits from 21.3's captured schema, but can run in parallel with it if convenient. Do not defer past this point; the answer may reorder everything below.

---

### Phase 21.5 — Dead Code Removal

**Objective.** Remove the verified-dead code and reconcile the broken element references (H-4): `switchWantedTab()`, `setWantedCat()`, `loadMyWantedTab()`, `setCat()`, `currentWantedTab`, `NOTIFICATION_TARGET_TYPES`, and the `#apAvatar` lookup.

Two items need a decision rather than deletion:

- `currentWantedCat` is read by `renderWanted()` (1754), so the Wanted category filter exists but is unreachable. Either restore the filter UI or remove the filter branch — **do not leave it half-present**.
- `#searchCount`, `#profileAvatar`, `#profileVerified`, `#profileGallery` are inert markup. Either populate them or remove them; the current state advertises capability that does not exist.

**Expected benefit.** Removes ~90 lines that would throw if wired up. Eliminates six string-id couplings that already point at nothing. Makes the remaining code honest about what exists — directly improving the reliability of every future analysis of this file.

**Implementation risk.** **Low.** Reference counts are verified above and should be re-verified at implementation time. The two decision items must be raised for approval rather than resolved unilaterally.

**Estimated complexity.** **Low.**

**Execution order.** **5** — do this before 21.7 and 21.8 so that consolidation and decomposition are not applied to code that is about to be deleted.

---

### Phase 21.6 — Demo Content Boundary

**Objective.** Make the boundary between placeholder content and real platform content unmistakable to a signed-in user (H-2). Specifically:

- Label the seven `wantedData` demo cards visibly as samples, or stop interleaving them with real rows in `renderWanted()` (1750–1759).
- Remove the blue verification badge from demo cards (1765) — no real user can obtain it, and `openArtistProfile()` explicitly refuses to fabricate it.
- Label the Stage feed's `stageData` as sample content.

**Expected benefit.** Removes the most damaging first-run impression: a new user currently cannot tell which posts are real, and the first thing they see is fictional. This is the highest-leverage UX fix available and costs almost nothing.

**Implementation risk.** **Low.** The main risk is over-correcting into an empty, discouraging app. Labelling rather than deleting avoids that.

**Estimated complexity.** **Low.** Presentation only; no data-flow change.

**Execution order.** **6** — independent; ordered here because it is cheap and high-visibility.

---

### Phase 21.7 — Write-Path Consolidation

**Objective.** Introduce two helpers inside `index.html` and convert the existing call sites:

- `extractSupabaseErrorMessage(result)` — replaces the four-branch chain at ~20 sites (C.1.1). Additionally, stop putting `JSON.stringify(error)` in front of users (M-10): log the raw object, show a readable sentence.
- `runCollaborationMutation({rpc, params, control, successToast, reload, fallback})` — replaces the identical ~18-site mutation shape (C.1.2).

Under `.apos/WORKFLOW.md`'s pattern rule this is **Extend** — it factors an existing, already-uniform pattern rather than creating a new one.

**Expected benefit.** Removes ~160 lines of mechanical duplication. Makes future cross-cutting changes to write behaviour (retry, offline queueing, error presentation) a one-place edit instead of an 18-place edit applied inconsistently. Fixes M-10 across all sites at once.

**Implementation risk.** **Medium.** The failure mode is behaviour drift across converted sites. Mitigations: convert in small batches; require every toast string to remain byte-identical; validate each batch at Level 3 before starting the next. Note that several sites deliberately differ — `promptLeaveCollaboration()` navigates instead of reloading (3285–3286), `createCollaborationCredit()` maps `P0053` to a friendly message (4875), `applyToWanted()` handles four distinct codes. **These exceptions must be preserved, not normalised away.**

**Estimated complexity.** **Medium.** Two small helpers, ~38 converted call sites.

**Execution order.** **7** — after 21.5 so that dead code is not converted.

---

### Phase 21.8 — `openCollaboration()` Decomposition

**Objective.** Reduce the 489-line `openCollaboration()` (M-1) by extracting **pure functions only**, with no change to network call order and no change to rendered output:

- `renderCollaborationActivitySentence(item, publicById, extendedPublicById)` — the 87-line, 22-branch block at 2937–3008, which already depends on nothing else.
- `computeCollaborationHealth(taskRows, activityRows, participantsWithoutCredits, status)` — the metric derivation at 2650–2686.
- `buildCollaborationDashboardHtml(metrics)` — the ~100-line string build at 2707–2810.
- Also address the ineffective `isConnected` guards at 3697 and 4308 (M-7) — either implement a real staleness check or remove the misleading comment; do not leave a guard that reads as protection but provides none.

**Justification.** This is not stylistic. `openCollaboration()` is re-invoked in full by the realtime activity handler (4062–4064), is the entry point for every notification tap, and is the sole writer of the 16 Collaboration state variables every sub-screen reads. It is simultaneously the most-executed, most-coupled, and least-modifiable function in the codebase. The three extractions above are pure and independently verifiable.

**Explicitly out of scope for this phase:** reordering or parallelising the ~12 round trips (M-3). That is a behavioural change and belongs in its own phase, after decomposition has made it safe.

**Expected benefit.** Makes the Workspace safely modifiable. Each extracted piece becomes independently reviewable. Creates the precondition for later fetch optimisation.

**Implementation risk.** **Medium–High** — the highest in this roadmap. It touches the function driving the entire Collaboration product. Mitigations: extract one function per validation cycle; require rendered output to be identical; do not combine with any network change.

**Estimated complexity.** **Medium–High.**

**Execution order.** **8** — after 21.5 and 21.7, so it operates on cleaned, consolidated code.

---

### Phase 21.9 — Real Artist Search

**Objective.** Make the Search screen search real users (H-3) by reusing `runInviteUserSearch()`'s existing, working `public_profiles` query (3155–3209) — same table, same `ilike` filter, same system/deleted exclusions. Present real results alongside (or in place of) the `artistDB` demo rows, consistent with whatever boundary Phase 21.6 establishes. Route result taps to `openArtistProfile()` (1617), which already renders live profile data correctly.

Also populate `#searchCount` (381), which currently exists and is never written, or remove it per 21.5.

**Expected benefit.** Closes the largest functional gap in the product: real registered artists are currently undiscoverable through the feature named "Find Artists". Every component needed already exists and is proven in the invite overlay.

**Implementation risk.** **Low–Medium.** The query, filters, and profile screen are all existing, validated code. The main risk is exposing profile fields more broadly than the invite context intended — mitigated by reusing the existing column list verbatim rather than widening it, and by confirming against the RLS policies captured in 21.3.

**Estimated complexity.** **Medium.** One new async path in `renderArtists()`, debouncing, empty/failure states, and a decision on how real and demo results coexist.

**Execution order.** **9** — after 21.6 (which sets the demo/real boundary this phase must follow) and after 21.3 (which confirms what `public_profiles` exposes).

---

### Phase 21.10 — Responsiveness and Accessibility Baseline

**Objective.** Establish a minimum baseline, additively:

- Add a single desktop/tablet `@media` breakpoint that constrains the app to a phone-width column, centred, on larger viewports. **The phone layout must remain byte-identical** (M-5).
- Re-enable pinch-zoom by removing `maximum-scale=1,user-scalable=no` (line 5) (H-7).
- Scope `user-select:none` to chrome elements only, so message bodies, filenames and credits become selectable (line 14) (H-7).
- Add visible focus indicators to inputs and primary controls.
- Convert the highest-traffic `<div onclick>` controls — bottom navigation, Send, Save, and destructive actions — to real `<button>` elements with accessible names.

**Expected benefit.** Makes the app usable outside a phone-sized viewport, restores magnification for users who need it, and restores copy/paste in a messaging product. The `<button>` conversions establish keyboard operability on the paths that matter most.

**Implementation risk.** **Medium.** Broad CSS surface. A `<div>` → `<button>` conversion changes default styling and layout behaviour, so each conversion needs individual visual verification. Restricting the breakpoint to additive rules keeps the phone layout untouched.

**Estimated complexity.** **Medium–High** if the `<button>` conversions are included; **Medium** for the CSS and viewport work alone. Splitting into 21.10a (CSS/viewport/selection) and 21.10b (semantic controls) is reasonable if scope proves large.

**Execution order.** **10** — last among these ten. It is the broadest surface and benefits from every preceding cleanup.

---

### Roadmap summary

| Order | Phase | Objective | Risk | Complexity | Addresses |
|---|---|---|---|---|---|
| 1 | 21.1 | Complete output escaping | Low | Low | C-1, R-1 |
| 2 | 21.2 | Startup resilience + dependency pinning | Low–Med | Low | C-2, M-12, R-2 |
| 3 | 21.3 | Capture backend contract in repository | Low | Medium | C-3, R-3, F.3 |
| 4 | 21.4 | Production environment confirmation | None (investigation) | Low | H-1, R-4 |
| 5 | 21.5 | Dead code removal | Low | Low | H-4, L-9 |
| 6 | 21.6 | Demo content boundary | Low | Low | H-2, R-7 |
| 7 | 21.7 | Write-path consolidation | Medium | Medium | M-2, M-10 |
| 8 | 21.8 | `openCollaboration()` decomposition | Med–High | Med–High | M-1, M-7 |
| 9 | 21.9 | Real artist search | Low–Med | Medium | H-3 |
| 10 | 21.10 | Responsiveness + accessibility baseline | Medium | Med–High | M-5, H-7, B.9 |

**Deliberately not proposed** (recorded per the `.apos/WORKFLOW.md` scope rule, for a later phase):

- Splitting `index.html` into modules or introducing a build step — the single-file architecture is working and no compelling technical reason to change it was found.
- A frontend framework, a state-management library, or a router library.
- Message pagination beyond the current 200-row cap (M-6) — real, but not yet reached in practice.
- Automated tests / CI (H-6) — high value, but a process change that needs its own governance decision rather than being folded into a code phase.
- Deep linking and browser history (H-5) — genuinely valuable, but it touches all 20 screens and should follow the structural cleanups above.
- Reordering `openCollaboration()`'s network calls (M-3) — depends on 21.8 landing first.
- Onboarding flow (M-13) — a product design decision, not purely technical.

---

## 7. Short summary

STAGERZ is a 4,942-line single-file SPA (`index.html`) served from GitHub Pages, backed by Supabase across 14 tables/views and 20 RPCs, with a fully realised Collaboration product — messages with optimistic send, tasks, assets with preview and download, credits, participant management, notifications, realtime, presence and typing indicators. Phases 20.4–20.6 have left it genuinely clean: no NACKL, no Telegram, normal browser runtime only.

**Strengths.** The Supabase transport layer is well designed — eight helpers that never throw, return a uniform result shape, and correctly distinguish a failed read (`null`) from an empty one (`[]`). Server-side authority is respected everywhere, with every client-side check explicitly documented as presentation-only. No data is fabricated: unavailable metrics render `—`, and absent schema concepts are hidden rather than invented. Realtime teardown, timer cleanup and object-URL revocation are thorough. The comments are unusually good and record real institutional knowledge.

**Top findings — three Critical.** **(1)** Output escaping is incomplete: a correct escaper exists and is used at 32 sites, but ten sites interpolate user-controlled `display_name`, `username`, `role`, `location`, Wanted `title` and collaboration `title` unescaped into `innerHTML`, plus four `photo_url` injections into inline `style` attributes — a stored-XSS class the codebase already knows how to prevent. **(2)** The Supabase SDK is loaded from a CDN at a floating `@2` major with no SRI and no failure path; because no screen carries `active` in the static markup, a CDN failure produces a permanently blank black page. **(3)** The entire backend contract — 20 RPCs, 14 tables, RLS policies, grants, triggers, Storage policies — exists only inside the Supabase project and is unreconstructable from this repository, which is also why no staging environment can exist and why authenticated flows cannot be validated before merge.

**High findings.** Production may be running against a project the code itself calls "disposable / TEST ONLY" (unknown from the repository, must be confirmed). Fictional demo artists and Wanted posts render interleaved with real rows, carrying a verification badge no real user can earn. The Search screen searches only a hardcoded array — real registered artists are undiscoverable, while a working `public_profiles` search already exists in the invite overlay. Roughly 90 lines of dead code target six element ids that do not exist. There is no automated verification of any kind.

**Production readiness.** Stability and reliability are moderate; maintainability is moderate-to-good; **recoverability is weak** — the frontend can be rolled back, the system cannot be rebuilt. The application is a well-built, carefully governed prototype approaching production quality, held back by four specific and finite blockers, none of which is architectural.

**Roadmap.** Ten phases in priority order: complete escaping (21.1) → startup resilience and dependency pinning (21.2) → capture the backend contract (21.3) → confirm the production environment (21.4) → remove dead code (21.5) → establish the demo/real boundary (21.6) → consolidate write paths (21.7) → decompose `openCollaboration()` (21.8) → real artist search (21.9) → responsiveness and accessibility baseline (21.10). The first four are the critical path. The single-file architecture is retained throughout; no build step, framework, or module system is proposed, and no refactoring is recommended that is not tied to a specific observed defect.

---

**End of Phase 20.7 assessment. No application code was modified. No commit was created. No push was performed.**
