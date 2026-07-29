# Phase 20.6 — Remove Telegram Runtime from Full Web App

**Branch:** `phase-20.6-remove-telegram-runtime`
**Base commit:** `155b029cdfcd752104849f1d52f84c0aa645ce61` (`main`, merge of Pull Request #5 — Phase 20.5)
**Status:** **Implementation complete. Static verification passed. Local pre-merge browser validation passed. Authenticated production validation outstanding (§15) — committed and pushed to the feature branch with product-owner approval; not merged.**
**Validation level required:** Level 3 (browser validation) — this is a behavior-affecting change to `index.html`.

> **Implementation record:** see **§13 Implementation record** and **§14 Verification results** at the end of this document. Sections 1–12 are the approved definition and are preserved unmodified as the record of what was planned; §13–§14 record what was actually done.

---

## 1. Goal

Remove the remaining Telegram WebApp runtime **completely** from the full STAGERZ web application, while preserving **all** normal web-app behavior.

Phase 20.5 collapsed every Telegram runtime reference into one contiguous, clearly delimited compatibility block plus one script tag in the document head. Phase 20.6 deletes that block, that script tag, and the 28 consumer call sites that depend on it.

**End state:** no Telegram SDK, no `window.Telegram` access, no `telegramWebApp` variable, no `ready()`, no `expand()`, no `haptic()` function, no `haptic(...)` call, and no Telegram-specific comment anywhere in the repository's runtime code. Normal browser runtime and Supabase only.

This implements the permanent roadmap decision recorded in `.apos/PROJECT_CONTEXT.md` → *"Telegram runtime integration is excluded from the current full web app."* Telegram remains preserved as a **deferred concept for a future STAGERZ Light / Mini App version**. Removal from the full app is not deletion of the product idea.

---

## 2. Confirmed Telegram reference inventory

Verified against the working tree at base commit `155b029c`. `index.html` is **5011 lines**.

### 2.1 Repository-wide scope

| File | Telegram runtime references | Action in 20.6 |
|---|---|---|
| `index.html` | **Yes** — all of them | Modify (only source file changed) |
| `README.md` | None | No change |
| `CNAME` | None | No change |
| `.apos/VALIDATION_STANDARD.md` | None | No change |
| `.apos/WORKFLOW.md` | None | No change |
| `.apos/PROJECT_CONTEXT.md` | Governance prose only — not runtime | Update phase status (documentation) |
| `analysis/phase-20.1…20.6/` | Historical analysis prose only — not runtime | **No change — history is not rewritten** |

**Tracked files in the repository (12 total):** `.apos/PROJECT_CONTEXT.md`, `.apos/VALIDATION_STANDARD.md`, `.apos/WORKFLOW.md`, `CNAME`, `README.md`, `analysis/phase-20.1/optimistic-ui-implementation-points.md`, `analysis/phase-20.1/optimistic-ui-validation-report.md`, `analysis/phase-20.2/phase-definition.md`, `analysis/phase-20.3/phase-definition.md`, `analysis/phase-20.4/phase-definition.md`, `analysis/phase-20.5/phase-definition.md`, `index.html`.

**There is no service worker, no manifest, no separate JavaScript file, no build config, no `netlify.toml`, and no second HTML entry point.** `index.html` is the only file containing executable code. Confirmed: `git ls-files` returns exactly one file matching `*.js|*.json|*.html|*.webmanifest|*.toml|*.yml|*.yaml` — `index.html`.

### 2.2 Token counts in `index.html` (current state)

| Token | Occurrences | Breakdown |
|---|---|---|
| `telegram.org` | 1 | SDK script `src` (line 8) |
| `window.Telegram` | **2** | Both on line 977 — `window.Telegram && window.Telegram.WebApp` |
| `telegramWebApp` | **9** | 1 in comment (969) + 8 in code (977 ×1, 982, 983, 984, 995 ×2, 996, 997) |
| `HapticFeedback` | 4 | 1 in comment (988) + 3 in code (995, 996, 997) |
| `haptic(` | **32** | **28 call sites** + 1 function definition (993) + 3 comment mentions (968, 972, 973) |
| `initData`, `initDataUnsafe`, `themeParams`, `colorScheme`, `BackButton`, `MainButton`, `openTelegramLink`, `setHeaderColor`, `setBackgroundColor`, `safeArea` | **0** | Absent entirely — reconfirmed |

> **Correction carried forward.** Pre-20.5 documentation recorded `haptic(` as occurring **29** times (1 definition + 28 calls). Phase 20.5 added three explanatory comment mentions, so the current count is **32**. The number of executable call sites is **unchanged at 28** — this is the number that matters. `.apos/PROJECT_CONTEXT.md` is corrected in this phase.

### 2.3 Confirmed: no other Telegram runtime references exist

Exhaustive scan for `telegram`, `tg`, `haptic`, `WebApp`, `initData`, `HapticFeedback` across all tracked files, case-insensitive:

- **No** `onclick='haptic(...)'` or any other Telegram/haptic reference inside an HTML attribute. All 28 call sites are inside the inline `<script>` block.
- **No** bare `tg` identifier remains — Phase 20.5 renamed it to `telegramWebApp`. Zero occurrences.
- **No** `<link rel='preconnect'>`, `dns-prefetch`, or CSP directive referencing `telegram.org`.
- **No** Telegram identity, authentication, session, or data integration of any kind.
- **No** Telegram reference in CSS.

**The inventory in §2.4–§2.6 is complete. Nothing else is in scope.**

### 2.4 Removal target A — SDK script tag (1 line)

**`index.html` line 8**, inside `<head>`:

```html
<script src='https://telegram.org/js/telegram-web-app.js'></script>
```

Classic, non-`defer`, non-`async`, render-blocking by placement. Sits between `<title>` (line 7) and the Supabase SDK (line 9).

> **Line 5 — `<meta name='viewport' …>` — is NOT Telegram-specific** and must never be touched. It is a standard responsive-web meta tag required by every mobile browser. Same for line 6 (`<meta name='version'>`) and line 9 (Supabase SDK).

### 2.5 Removal target B — Telegram compatibility block (40 lines)

**`index.html` lines 962–1001**, the first content inside the inline `<script>` that opens at line 961. Delimited by explicit Phase 20.5 markers, making this a contiguous, self-contained deletion:

| Lines | Content |
|---|---|
| 962–973 | `// ===== BEGIN TELEGRAM COMPATIBILITY BLOCK (Phase 20.5) =====` header comment |
| 974 | blank |
| 975–976 | detection comment |
| **977** | `var telegramWebApp = window.Telegram && window.Telegram.WebApp;` |
| 978 | blank |
| 979–981 | initialization comment |
| **982–985** | `if(telegramWebApp){ try{ telegramWebApp.ready(); }catch(e){} try{ telegramWebApp.expand(); }catch(e){} }` |
| 986 | blank |
| 987–992 | `haptic()` contract comment |
| **993–1000** | `function haptic(t){ … }` — reads `telegramWebApp.HapticFeedback`, calls `notificationOccurred` / `impactOccurred` |
| 1001 | `// ===== END TELEGRAM COMPATIBILITY BLOCK =====` |

Line 1002 is blank; line 1003 begins `// --- SUPABASE ---`. The blank separator at 1002 may be removed with the block or retained — either leaves valid, readable code. **The block boundary is exact: nothing before 962 and nothing after 1001 inside the script is Telegram-related.**

This single block accounts for `telegramWebApp` (all 9), `window.Telegram` (both), `HapticFeedback` (all 4), `ready()`, `expand()`, the `haptic()` definition, and every Telegram-specific comment inside the script.

### 2.6 Removal target C — all 28 `haptic(...)` call sites

All 28, with enclosing function and feature area. **Argument distribution:** `haptic('success')` ×26, `haptic('light')` ×1, `haptic('heavy')` ×1.

| # | Line | Enclosing function | Feature area | Call |
|---|---|---|---|---|
| 1 | 1289 | `sendOtp(isResend)` | Authentication | `haptic('success')` |
| 2 | **1358** | `checkSessionAndStart()` | Authentication | `haptic('success')` — **inline, see note** |
| 3 | 1377 | `goTo(id)` | Navigation | `haptic('light')` |
| 4 | 1966 | `closeWantedPost(id)` | Wanted | `haptic('success')` |
| 5 | 2003 | `applyToWanted(postId, ownerId, btnEl)` | Wanted | `haptic('success')` |
| 6 | 2071 | `submitWanted()` | Wanted | `haptic('success')` |
| 7 | 2089 | `submitWanted()` | Wanted | `haptic('success')` |
| 8 | 2167 | `saveProfile()` | Profile | `haptic('success')` |
| 9 | 2389 | `respondToApplication(applicationId, newStatus)` | Wanted | `haptic('success')` |
| 10 | 3137 | `changeCollaborationStatus(newStatus)` | Collaboration | `haptic('success')` |
| 11 | 3274 | `performCollaborationInvite(userId, displayName)` | Collaboration | `haptic('success')` |
| 12 | 3294 | `removeParticipant(userId, name, btnEl)` | Collaboration | `haptic('success')` |
| 13 | 3314 | `transferOwnership(userId, name, btnEl)` | Collaboration | `haptic('success')` |
| 14 | 3335 | `promptLeaveCollaboration()` | Collaboration | `haptic('success')` |
| 15 | 3602 | `saveMessageEdit(messageId)` | Messaging | `haptic('success')` |
| 16 | 3622 | `deleteMessagePrompt(messageId, btnEl)` | Messaging | `haptic('success')` |
| 17 | 3862 | `saveCollaborationTaskTitle(taskId)` | Tasks | `haptic('success')` |
| 18 | 3882 | `deleteCollaborationTaskPrompt(taskId, title, btnEl)` | Tasks | `haptic('success')` |
| 19 | 3915 | `createCollaborationTask()` | Tasks | `haptic('success')` |
| 20 | 3933 | `completeCollaborationTask(taskId, btnEl)` | Tasks | `haptic('success')` |
| 21 | 4494 | `saveCollaborationAssetEdit(assetId)` | Assets | `haptic('success')` |
| 22 | 4514 | `deleteCollaborationAssetPrompt(assetId, fileName, btnEl)` | Assets | `haptic('success')` |
| 23 | 4694 | `uploadCollaborationAsset(file)` | Assets | `haptic('success')` |
| 24 | 4884 | `saveCollaborationCreditEdit(creditId)` | Credits | `haptic('success')` |
| 25 | 4904 | `deleteCollaborationCreditPrompt(creditId, roleLabel, btnEl)` | Credits | `haptic('success')` |
| 26 | 4937 | `createCollaborationCredit()` | Credits | `haptic('success')` |
| 27 | 4979 | `startRec()` | FameMaker | `haptic('heavy')` |
| 28 | 4990 | `stopRec()` | FameMaker | `haptic('success')` |

**Structural facts verified for every call site:**

- **27 of 28 are the sole statement on their own line** → whole-line deletion, no syntax risk.
- **1 of 28 is inline — line 1358:**
  ```js
  if(confirmedSession){ haptic('success'); enterApp(); }
  ```
  This requires an **in-place edit**, not a line deletion. Result: `if(confirmedSession){ enterApp(); }`. The `if` body is **braced**, so removal cannot orphan a control statement.
- **No call site is the unbraced body of an `if`/`for`/`while`/arrow function.** There is no dangling-block hazard anywhere.
- **The return value is never used** — no assignment, no `return haptic(...)`, no chaining, no `await`. Every call is fire-and-forget.
- **No call site is inside a `try` block that exists solely for `haptic()`** — every surrounding `try` guards Supabase or DOM work.
- **No call site sits between a variable declaration and its first use**, so deletion cannot change hoisting or evaluation order.

### 2.7 Line-count impact

| Change | Lines |
|---|---|
| SDK script tag (line 8) | −1 |
| Compatibility block (962–1001) | −40 |
| Optional blank separator (1002) | −1 (optional) |
| 27 whole-line call-site deletions | −27 |
| Line 1358 in-place edit | ±0 |
| **Total** | **−68 to −69 lines** |

`index.html`: **5011 → 4942–4943 lines**. Expected diff: **1 file changed, 0 insertions, 68–69 deletions** (plus one modified line at 1358, shown as 1 insertion + 1 deletion).

---

## 3. Behavior-preservation requirements

Phase 20.6 removes **only** tactile feedback and Telegram host viewport hints. Everything else must be **bit-for-bit identical in observable behavior**.

### 3.1 What must not change (hard requirements)

| Area | Requirement |
|---|---|
| **Authentication** | OTP send, magic-link email, resend, session restoration, sign-in, sign-out — unchanged. `sendOtp()` and `checkSessionAndStart()` must complete identically, including `enterApp()` being called on a confirmed session |
| **Session & identity** | Supabase session storage, access-token attachment to REST helpers, `getMyDomainId()`, `fetchMyProfile()`, `loadMyProfile()` — unchanged |
| **Navigation** | `goTo(id)` must still switch views, and must still run the `if(id==='search') setTimeout(renderArtists, 50)` branch. Only the `haptic('light')` line is removed |
| **Toasts** | Every `showToast(...)` adjacent to a removed `haptic(...)` must still fire, with identical text and ordering |
| **Wanted** | Create, edit, submit, close, apply, accept/reject application — unchanged |
| **Profile** | Save, visibility, profile rendering — unchanged |
| **Collaboration** | Status change, invite, remove participant, transfer ownership, leave — unchanged, including the deliberate no-reload behavior on leave (line ~3335 comment) |
| **Messaging** | Phase 20.1/20.2/20.3 behavior fully preserved: optimistic send, reconciliation, edit, delete, message-load failure visibility, `skipLoadingState` reloads |
| **Tasks / Assets / Credits** | Create, edit, delete, complete, upload — unchanged, including every `loadCollaboration*()` refresh call that immediately follows a removed `haptic(...)` |
| **FameMaker** | `startRec()` / `stopRec()` must retain their recording logic, the `setTimeout(…,1000)`, and the wave-element display toggle |
| **Layout & CSS** | Zero CSS changes. `<meta name='viewport'>` untouched |
| **Supabase** | Zero changes to URL, key, client creation, REST helpers, RLS interaction |

### 3.2 What is intentionally lost

| Behavior | Where it applied | Impact |
|---|---|---|
| Device haptic vibration on 28 actions | **Telegram host only** | None in any normal browser — `telegramWebApp` was already falsy there, so `haptic()` was already a silent no-op |
| `ready()` — signals init to Telegram host | **Telegram host only** | None in any normal browser |
| `expand()` — expands Mini App to full height | **Telegram host only** | None in any normal browser |
| One render-blocking external request to `telegram.org` | All environments | **Improvement** — one fewer blocking third-party fetch on every page load |
| `Telegram.WebApp HapticFeedback is not supported in version 6.0` console warning | Telegram host only | **Improvement** — warning originates inside the SDK and disappears with it |

**Net effect in a normal browser: zero visible behavior change.** Phase 20.5 established that `haptic()` was already a silent no-op outside Telegram, and that `ready()`/`expand()` were guarded and inert. Removing dead-in-browser code cannot alter browser behavior.

### 3.3 Post-removal contract

After Phase 20.6, `haptic` is **undefined**. Any future call to it would throw `ReferenceError: haptic is not defined`. Acceptance therefore requires proving **zero** remaining references — see §7 and §9.

---

## 4. Prerequisite gate — external Mini App entry point

Phase 20.5 §10 recorded an explicitly **unknown**, decision-blocking question that this repository cannot answer:

> Does an external Telegram Bot / Mini App entry point exist that points at STAGERZ, and do real users currently open the app inside Telegram?

**Status: still unknown. Not inspectable from this repository.** No BotFather configuration, bot token, or Mini App URL is stored here.

**Resolution path — product-owner decision, not a code inference:**

| Answer | Consequence for Phase 20.6 |
|---|---|
| **No entry point exists** (expected) | Proceed as specified. Zero user impact |
| **An entry point exists but Telegram support is being retired** | Proceed. Accept that inside Telegram the app will no longer auto-expand or signal `ready()`, and haptics stop. The app still **functions** — nothing throws |
| **An entry point exists and must keep working as a Mini App** | **Stop.** The premise of the roadmap decision changes and must be re-recorded before any implementation |

The permanent roadmap decision in `.apos/PROJECT_CONTEXT.md` already excludes Telegram from the full web app, which authorizes removal in principle. This gate exists to confirm that removal does not silently degrade a **live** deployment surface. **Implementation must not begin until the product owner answers.**

---

## 5. Risks

| # | Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|---|
| 1 | **Orphaned `haptic(...)` call survives deletion** → `ReferenceError` at runtime, breaking the enclosing action mid-flow | Low | **High** | Verification command V3 must return **0**. This is a hard acceptance gate, not a spot check |
| 2 | **Line 1358 mishandled** — whole-line deletion instead of in-place edit would delete `enterApp()`, breaking sign-in entry into the app | Medium | **Critical** | Called out explicitly in §2.6. Dedicated checklist item B2 and verification command V6 |
| 3 | **Adjacent statement deleted with the haptic line** — e.g. a `showToast(...)` or `await loadCollaboration*(...)` | Low | High | Diff must show **0 insertions** outside line 1358. Every deleted line must contain `haptic(`. Verification command V5 |
| 4 | **Line numbers shift during editing**, causing later edits to hit wrong lines | **High** (28 edits in one file) | High | Edit **bottom-up** (line 4990 → 8) so pending targets never shift, or match on exact unique string content rather than line number |
| 5 | **Script block boundary miscut** — deleting past line 1001 removes the Supabase section header or client creation | Low | **Critical** | Block is explicitly delimited by BEGIN/END markers. Delete marker-to-marker, never by line count alone |
| 6 | **`<meta name='viewport'>` (line 5) or Supabase SDK (line 9) removed** while deleting the head script tag | Low | **Critical** | Explicit non-goal (§8). Line 8 only — match on the exact `telegram.org` `src` string |
| 7 | **Syntax error in the 5000-line inline script** → the entire app fails to boot with a blank page | Low | **Critical** | Level 3 browser validation is mandatory. Verification command V7 (brace/paren balance) plus a real page load |
| 8 | **Telegram Mini App users lose auto-expand** | Unknown | Medium | Gated by §4. Accepted only on explicit product-owner decision |
| 9 | **A user perceives "missing feedback"** on mobile web | Very low | Low | Haptics never fired in a normal browser. Toasts remain the actual feedback channel and are untouched |
| 10 | **Scope creep** — refactoring the surrounding call sites while deleting | Medium | Medium | Deletion only. No renaming, no reformatting, no reindentation of surviving lines. §8 non-goals |
| 11 | **Analysis history rewritten** to "clean up" Telegram mentions | Low | Medium | `analysis/phase-20.1…20.5/` are historical records and must not be edited. §8 non-goals |

**Aggregate risk assessment: LOW.** Phase 20.5 deliberately shaped the code so that this deletion is mechanical — one contiguous block, one script tag, and 28 fire-and-forget statements whose return value is never used. Risks 1, 2, and 4 are the ones that require discipline; all three are fully covered by the verification commands in §7.

---

## 6. Implementation plan

**Editing order is bottom-up** so that unedited targets keep their line numbers.

| Step | Action | Target |
|---|---|---|
| 1 | Delete 27 whole-line call sites, **descending**: 4990, 4979, 4937, 4904, 4884, 4694, 4514, 4494, 3933, 3915, 3882, 3862, 3622, 3602, 3335, 3314, 3294, 3274, 3137, 2389, 2167, 2089, 2071, 2003, 1966, 1377, 1289 | 27 lines |
| 2 | Edit line 1358 in place: `if(confirmedSession){ haptic('success'); enterApp(); }` → `if(confirmedSession){ enterApp(); }` | 1 line modified |
| 3 | Delete the compatibility block, marker to marker: lines 962–1001 (optionally the blank at 1002) | 40–41 lines |
| 4 | Delete the SDK script tag: line 8 | 1 line |
| 5 | Run every verification command in §7 | — |
| 6 | Run the browser/manual checklist in §8 on a deploy preview | — |
| 7 | Produce a validation report per `.apos/VALIDATION_STANDARD.md` §10 | — |
| 8 | ChatGPT review → explicit user approval → **then** commit. No push without separate approval | — |

Steps 1–4 are the entire source change. **No other line of `index.html` is touched.**

---

## 7. Verification commands

Run from the repository root. **All must pass before the change is considered valid.**

### V1 — Zero Telegram references in the runtime file
```bash
grep -c -i "telegram" index.html
```
**Expected: `0`** (grep exits 1 with no match; that is success here).

### V2 — Zero Telegram tokens of any kind
```bash
grep -n -i -E "telegram|haptic|WebApp|HapticFeedback|initData|impactOccurred|notificationOccurred" index.html
```
**Expected: no output.**

### V3 — Zero `haptic` references anywhere in the repository's runtime code
```bash
git grep -n "haptic" -- index.html
```
**Expected: no output.** *(This is the single most important check — it proves no orphaned call can throw `ReferenceError`.)*

### V4 — Confirm only the intended files changed
```bash
git status --short
git diff --stat
```
**Expected:** `index.html`, `.apos/PROJECT_CONTEXT.md`, and `analysis/phase-20.6/` only. `git diff --stat` on `index.html`: **1 file changed, 1 insertion(+), 69 deletions(-)** (±1 on the optional blank line).

### V5 — Every deleted line was Telegram-related
```bash
git diff -U0 -- index.html | grep "^-" | grep -v "^---" | grep -v -i -E "telegram|haptic" 
```
**Expected: no output** — except the single line 1358, which appears as a removal **and** a re-addition. Verify that pair by eye.

### V6 — `enterApp()` survived the line-1358 edit
```bash
grep -n "confirmedSession" index.html
```
**Expected:** the `if(confirmedSession){ enterApp(); }` line is present, with `enterApp()` intact and no `haptic`.

### V7 — Structural sanity of the inline script
```bash
grep -c "showToast(" index.html      # must equal the pre-change count
grep -c "function " index.html       # must be exactly 1 lower than pre-change (haptic removed)
wc -l index.html                     # expect 4942 or 4943 (was 5011)
```

### V8 — Head section integrity
```bash
sed -n '1,12p' index.html
```
**Expected:** `<meta name='viewport'>` (line 5), `<meta name='version'>`, `<title>STAGERZ</title>`, and the Supabase SDK `<script>` all present; **no** `telegram.org` script.

### V9 — No `telegram.org` network request remains
```bash
git grep -n "telegram.org" -- index.html
```
**Expected: no output.**

### V10 — Branch and cleanliness
```bash
git branch --show-current    # phase-20.6-remove-telegram-runtime
git status                   # no unexpected untracked files
```

---

## 8. Browser / manual test checklist

**Level 3 validation on a local server serving the working tree, pre-merge.** Record every item as **PASS / FAIL / N/A** — never omit one silently (`.apos/VALIDATION_STANDARD.md` §4).

> **Corrected 2026-07-28 — there is no PR preview environment.** This section originally specified *"a deploy preview from the Pull Request"*, an assumption inherited from `analysis/phase-20.5/phase-definition.md` §11, which presumed Netlify. **That assumption is wrong for this repository.** There is no `netlify.toml` and no `.github/workflows`; `CNAME` is `stagerz.app` and **GitHub Pages serves the `main` branch directly**. GitHub Pages provides **no per-pull-request preview deployment**.
>
> Pre-merge Level 3 validation therefore runs against a **local server serving the working tree** — VS Code Live Server, or any static server on `localhost`. `localhost` is a secure context, so `getUserMedia` (FameMaker, items K1–K2) behaves as in production.
>
> **Known limit of local validation:** the Supabase magic-link redirect is configured to `https://stagerz.app`. A magic link opened during local testing therefore lands on **production**, not on localhost. Items requiring an authenticated session (B2, and everything behind sign-in — D, E, F, G, H, I, J, K) **cannot be completed locally** and must run **after merge and GitHub Pages deployment**. See §14.4.

### A. Boot and console
- [ ] A1 — Page loads; the inline script parses; no blank screen
- [ ] A2 — Console shows **no** `ReferenceError: haptic is not defined`
- [ ] A3 — Console shows **no** `Telegram is not defined` or `telegramWebApp is not defined`
- [ ] A4 — Network tab shows **no** request to `telegram.org`
- [ ] A5 — The `HapticFeedback is not supported in version 6.0` warning is **gone**
- [ ] A6 — No new console error of any kind versus the pre-change baseline

### B. Authentication — highest-risk area (call sites 1, 2)
- [ ] B1 — Enter email → OTP / magic-link sends; the "Check your email and tap the sign-in link." toast appears; view advances to `authwait`
- [ ] B2 — **Critical:** tap the magic link → session confirms → `enterApp()` runs → the app opens. *(This proves the line-1358 edit was done correctly.)*
- [ ] B3 — Resend flow works
- [ ] B4 — Reload with an existing session → session restores and the app opens directly
- [ ] B5 — Sign out → returns to the auth view cleanly

### C. Navigation (call site 3)
- [ ] C1 — Navigate to every view: Stage, Wanted, FameMaker, Profile, Collaboration, Backstage
- [ ] C2 — `goTo('search')` still triggers `renderArtists()` after the 50 ms timeout — the artist list populates

### D. Wanted (call sites 4–7, 9)
- [ ] D1 — Create/submit a Wanted post → toast → navigates to `wanted`
- [ ] D2 — Edit an existing post → "Your WANTED has been updated." toast → list reloads
- [ ] D3 — Close a post → "Post closed." toast → list reloads
- [ ] D4 — Apply to a post → "Application sent." toast → button flips to `APPLIED` and disables
- [ ] D5 — Accept an application → correct toast; applicants list refreshes
- [ ] D6 — Reject an application → correct toast

### E. Profile (call site 8)
- [ ] E1 — Save profile → "Profile saved! You are now visible to artists worldwide." toast → navigates to `profile`

### F. Collaboration (call sites 10–14)
- [ ] F1 — Change collaboration status → toast → workspace reloads
- [ ] F2 — Invite a user → "<name> was added…" toast → workspace reloads
- [ ] F3 — Remove a participant → "<name> was removed." toast → workspace reloads
- [ ] F4 — Transfer ownership → toast → workspace reloads
- [ ] F5 — Leave a collaboration → "You left the collaboration." toast → **does not** reload the same workspace (deliberate existing behavior)

### G. Messaging — Phase 20.1/20.2/20.3 regression (call sites 15, 16)
- [ ] G1 — Optimistic send: message appears immediately, then reconciles with the server copy
- [ ] G2 — No duplicate message entries after reconciliation
- [ ] G3 — Edit a message → "Message updated." toast → reload runs with `skipLoadingState` (no full-area loading flash)
- [ ] G4 — Delete a message → "Message deleted." toast → reload with no flash
- [ ] G5 — Message-load failure state still renders correctly (Phase 20.3)
- [ ] G6 — Failed send rolls back correctly

### H. Tasks (call sites 17–20)
- [ ] H1 — Create a task → toast → task list reloads
- [ ] H2 — Edit a task title → toast → reloads
- [ ] H3 — Complete a task → toast → reloads
- [ ] H4 — Delete a task → toast → reloads

### I. Assets (call sites 21–23)
- [ ] I1 — Upload a file → "File uploaded." toast → asset list reloads
- [ ] I2 — Edit an asset → toast → reloads
- [ ] I3 — Delete an asset → toast → reloads

### J. Credits (call sites 24–26)
- [ ] J1 — Add a credit → "Credit added." toast → credits reload
- [ ] J2 — Edit a credit → toast → reloads
- [ ] J3 — Delete a credit → toast → reloads

### K. FameMaker (call sites 27, 28)
- [ ] K1 — `startRec()` — recording starts; the 1000 ms timeout behavior is unchanged
- [ ] K2 — `stopRec()` — recording stops; the wave element hides (`wave.style.display = 'none'`)

### L. Responsive / mobile
- [ ] L1 — Repeat C, D, and G at mobile width; no layout overflow
- [ ] L2 — Confirm the viewport meta still applies — no unintended zooming
- [ ] L3 — Test on a real mobile browser (iOS Safari or Android Chrome), not only a device emulator

### M. Telegram WebView — conditional
- [ ] M1 — **Only if** §4 confirms an entry point exists: open inside Telegram, confirm the app still loads and functions (no auto-expand, no haptics — expected)
- [ ] M2 — If no entry point exists, record as **NOT VERIFIED — no Telegram entry point**. **Do not create a Telegram bot solely to test.**

---

## 9. Acceptance criteria

Phase 20.6 is complete **only when all of the following hold**:

| # | Criterion |
|---|---|
| 1 | `git grep -i telegram -- index.html` returns **nothing** |
| 2 | `git grep haptic -- index.html` returns **nothing** — zero definitions, zero calls, zero comments |
| 3 | `window.Telegram`, `telegramWebApp`, `HapticFeedback`, `ready()`, `expand()`, `impactOccurred`, `notificationOccurred` — **zero** occurrences in `index.html` |
| 4 | The SDK `<script src='https://telegram.org/…'>` tag is gone; no request to `telegram.org` on page load |
| 5 | All **28** call sites removed — 27 line deletions + 1 verified in-place edit at line 1358 |
| 6 | `enterApp()` on the former line 1358 is **intact** and sign-in still enters the app |
| 7 | `<meta name='viewport'>` (line 5), `<meta name='version'>`, `<title>`, and the Supabase SDK script are **unchanged** |
| 8 | Diff is **deletion-only** apart from the single modified line 1358 — 0 net insertions |
| 9 | Only `index.html`, `.apos/PROJECT_CONTEXT.md`, and `analysis/phase-20.6/` are changed. `analysis/phase-20.1…20.5/` untouched |
| 10 | Zero changes to authentication, Supabase configuration, REST helpers, RLS interaction, CSS, or messaging logic |
| 11 | Every checklist item in §8 recorded as PASS, or explicitly justified as N/A |
| 12 | No new console error, and no new failed network request, versus the pre-change baseline |
| 13 | A validation report exists in the format of `.apos/VALIDATION_STANDARD.md` §10 |
| 14 | §4's external-entry-point question has been **answered by the product owner** and the answer recorded |
| 15 | ChatGPT review complete **and** explicit user approval received before any commit |

---

## 10. Rollback approach

**Trigger:** any acceptance criterion in §9 fails, any checklist item in §8 fails, or a `ReferenceError` appears in production.

**Method — in order of preference:**

1. **Pre-merge (working tree):** `git checkout -- index.html` restores the file. Zero consequence.
2. **Post-commit, pre-merge:** `git revert <commit>` on the branch, or drop the branch entirely. The Pull Request is simply not merged.
3. **Post-merge to `main` (production):** `git revert -m 1 <merge-commit>` and push. GitHub Pages redeploys from `main`, restoring the Telegram runtime in full.

**Rollback properties:**

- **No database migration.** No schema, RPC, RLS policy, or Supabase configuration change — nothing to reverse server-side.
- **No external configuration change.** No BotFather, DNS, CNAME, or hosting change.
- **No data migration.** No user data is written, transformed, or deleted.
- **Fully reversible by a single git operation.** The change is deletion-only in one file.
- **No state to reconcile.** Because the removed code was already inert in browsers, reverting cannot leave users in a partially-migrated state.

**Recovery time:** minutes — bounded only by GitHub Pages redeployment.

**Reference copy:** the complete pre-removal Telegram implementation is preserved permanently in git history at `155b029cdfcd752104849f1d52f84c0aa645ce61`, and its design is documented in `analysis/phase-20.5/phase-definition.md`. A future STAGERZ Light / Mini App version can recover it from either source.

---

## 11. Non-goals

Explicitly **out of scope** for Phase 20.6:

- Replacing haptics with any substitute — no Web Vibration API, no `navigator.vibrate()`, no CSS animation, no sound. **Removal only.**
- Adding a platform-abstraction layer or feature-flag system
- Refactoring, renaming, reformatting, or reindenting any surviving line
- Changing any `showToast(...)` text, timing, or placement
- Changing `goTo()` beyond deleting its one `haptic('light')` line
- Authentication, magic-link configuration, session storage, user identity
- Supabase URL, key, client creation, REST helpers, schema, RPC, RLS, policies
- Messaging behavior, optimistic UI, loaders, message limits, failure visibility
- `photo_url` hardening
- The `<meta name='viewport'>` tag — standard responsive web, not Telegram
- The `<meta name='version' content='3.0'>` tag
- The Supabase SDK script tag (line 9)
- Hosting, CNAME, GitHub Pages, or deployment configuration
- Registering, configuring, or deleting a Telegram bot
- Rewriting historical phase reports in `analysis/phase-20.1…20.5/`
- Building or scoping the future STAGERZ Light / Mini App version
- Any performance work beyond the incidental gain of one fewer blocking script

---

## 12. Stop conditions

**Stop and report** rather than proceeding if any of the following occurs:

1. §4 is answered with *"a live Telegram Mini App entry point exists and must keep working."* The roadmap premise changes and must be re-recorded first.
2. A Telegram or `haptic` reference is found **outside** the inventory in §2 — the inventory is then incomplete and must be re-derived before editing.
3. Removing a `haptic(...)` call would require changing any adjacent statement, or would orphan a control-flow block.
4. Any call site turns out to consume `haptic()`'s return value, or to depend on it for sequencing.
5. Deleting the compatibility block cannot be done cleanly marker-to-marker without touching the Supabase section.
6. Any behavior in §3.1 changes during browser validation.
7. The inline script fails to parse, or the app fails to boot, after any edit.
8. The change cannot be kept to `index.html` alone (excluding phase documentation).
9. Any messaging regression from Phase 20.1, 20.2, or 20.3 reappears.

Per `.apos/VALIDATION_STANDARD.md` §9: on a stop condition, **do not commit**, **do not** substitute a different approach, and **preserve the working tree** for review.

---

## Summary

Phase 20.5 did its job: the entire Telegram runtime is now **one contiguous 40-line block (`index.html` 962–1001)** plus **one script tag (line 8)** plus **28 fire-and-forget `haptic(...)` call sites**. Nothing else in the repository references Telegram in runtime code — confirmed exhaustively across all 12 tracked files, with `index.html` the only file containing executable code.

Phase 20.6 deletes exactly those three things: **68–69 deleted lines and one in-place edit, in a single file, with zero net insertions.** Because `haptic()` was already a proven silent no-op in every normal browser and `ready()`/`expand()` were inert outside a Telegram host, **removal cannot change browser behavior** — the only losses are Telegram-host-only haptics and viewport hints, plus one render-blocking third-party request that goes away as a benefit.

Two items demand discipline: the **inline call at line 1358**, which must be edited in place so `enterApp()` survives, and **editing bottom-up** so 28 edits in one file never shift a pending target. Both are covered by dedicated verification commands. One gate remains open and is not answerable from this repository: whether a live Telegram Mini App entry point exists (§4). That is a product-owner decision, and **implementation must not begin until it is answered.**

---

## 13. Implementation record

### 13.1 Product-owner decision resolving the §4 gate

The gate in §4 was **answered by the product owner** before implementation began:

> STAGERZ is currently being developed as an **independent web application**. The current product must be built, tested, and completed **without any Telegram dependency or Telegram-specific runtime behavior**. A separate Telegram light version may be developed later, **only after** the main web application is technically complete, stable, and user-friendly. The existing Telegram Mini App configuration is **not part of the currently supported product scope and must not block this removal**.

This maps to §4 outcome row 2 — *"an entry point exists but Telegram support is being retired"* — and authorizes the removal as specified. Recorded in `.apos/PROJECT_CONTEXT.md`.

**Scope boundary honoured:** this phase changed **only the repository's runtime**. No BotFather configuration, bot token, Mini App URL, DNS, `CNAME`, or hosting setting was inspected, modified, or deleted. External Telegram configuration is untouched and out of scope.

### 13.2 Method — semantic, content-matched edits

Per requirement 4, the implementation used **content matching, not recorded line numbers**. A single-pass AWK transform matched each target by its literal content and structural pattern:

| Target | Match rule used | Line numbers used? |
|---|---|---|
| SDK script tag | line contains `<script` **and** `telegram-web-app.js` | No |
| Compatibility block | from the line containing `BEGIN TELEGRAM COMPATIBILITY BLOCK` to the line containing `END TELEGRAM COMPATIBILITY BLOCK`, inclusive | No |
| Blank separator | the single blank line immediately following the END marker | No |
| 27 standalone calls | regex `^[[:space:]]*haptic\('[a-z]+'\);[[:space:]]*$` — a whole-line haptic statement | No |
| 1 inline call | literal substring `{ haptic('success'); enterApp(); }` → `{ enterApp(); }` | No |

Because every target was matched by content, the line-shift risk identified in §5 (risk 4) could not occur — no bottom-up ordering was required.

**Line-ending preservation.** `index.html` uses **CRLF** on disk (5011 CR characters, one per line) under `core.autocrlf=true`. The first transform run silently stripped CR (GNU AWK text mode), which would have produced a whole-file diff. This was caught before the file was written, and the transform was re-run with `BINMODE=3`. Final file: **4942 lines, 4942 CR characters** — CRLF fully preserved, so the diff contains only genuine changes.

**Pre-flight gate.** The transform wrote to a staged scratch file. The diff was audited *before* the real `index.html` was touched, confirming exactly 1 added line and 70 removed lines. Only then was the file replaced.

### 13.3 Actual removals performed

| # | Removal | Planned | Actual | Match |
|---|---|---|---|---|
| A | Telegram WebApp SDK script tag | 1 line | **1 line** | ✅ |
| B | Telegram compatibility block (BEGIN→END markers, inclusive) | 40 lines | **40 lines** | ✅ |
| B′ | Blank separator after the block | 1 line (optional) | **1 line** | ✅ |
| C1 | Standalone `haptic(...)` statement lines | 27 lines | **27 lines** | ✅ |
| C2 | Inline `haptic('success')` — in-place edit | 1 edit | **1 edit** | ✅ |
| — | **Total executable call sites removed** | **28** | **28** | ✅ |

**Everything named in the removal scope is gone:**

- ✅ Telegram WebApp SDK script (`https://telegram.org/js/telegram-web-app.js`)
- ✅ `window.Telegram` access — both occurrences
- ✅ `telegramWebApp` variable — all 9 occurrences (8 code + 1 comment)
- ✅ `ready()` — Telegram host initialization
- ✅ `expand()` — Telegram viewport expansion
- ✅ `HapticFeedback` — all 4 occurrences, including `notificationOccurred` and `impactOccurred`
- ✅ `haptic()` function definition
- ✅ All **28** executable `haptic(...)` call sites
- ✅ All Telegram-specific comments belonging to the removed runtime (including the 3 comment mentions of `haptic(`)

### 13.4 Actual final counts

| Metric | Before | After | Delta |
|---|---|---|---|
| `index.html` lines | 5011 | **4942** | **−69** |
| `index.html` bytes | 267,564 | **265,058** | −2,506 |
| CR characters (CRLF integrity) | 5011 | **4942** | matches line count ✅ |
| `telegram` (case-insensitive) | 15 | **0** | −15 |
| `window.Telegram` | 2 | **0** | −2 |
| `telegramWebApp` | 9 | **0** | −9 |
| `HapticFeedback` | 4 | **0** | −4 |
| `haptic(` | 32 | **0** | −32 |
| `haptic` (any form) | 32 | **0** | −32 |
| `function ` declarations | 146 | **145** | **−1** (exactly `haptic()`) |
| `showToast(` | 89 | **89** | **0** — every toast preserved ✅ |
| `enterApp(` | 3 | **3** | **0** — preserved ✅ |
| Blocking third-party requests in `<head>` | 2 | **1** | −1 (Supabase SDK only) |

**Diff:** `1 file changed, 1 insertion(+), 70 deletions(-)` — 69 pure deletions plus the single line 1358 rewritten in place (counted as 1 deletion + 1 insertion).

### 13.5 Files changed

| File | Change |
|---|---|
| `index.html` | Telegram runtime removed — 1 insertion, 70 deletions |
| `.apos/PROJECT_CONTEXT.md` | Phase status, product-owner decision, Light-version guardrail |
| `analysis/phase-20.6/phase-definition.md` | §13–§14 implementation record appended |

**No other file was touched.** `analysis/phase-20.1` … `analysis/phase-20.5` are unmodified — history is not rewritten. `README.md`, `CNAME`, `.apos/VALIDATION_STANDARD.md`, and `.apos/WORKFLOW.md` are unmodified.

---

## 14. Verification results

### 14.1 Static verification — Level 1

All commands run from the repository root against the modified working tree.

| # | Command | Expected | Actual | Result |
|---|---|---|---|---|
| **V1** | `grep -c -i "telegram" index.html` | `0` | `0` | ✅ **PASS** |
| **V2** | `grep -n -i -E "telegram\|haptic\|WebApp\|HapticFeedback\|initData\|impactOccurred\|notificationOccurred" index.html` | no output | no output | ✅ **PASS** |
| **V3** | `git grep -n "haptic" -- index.html` | no output | no output | ✅ **PASS** |
| **V4** | `git status --short` / `git diff --stat` | only expected files | `index.html`, `.apos/PROJECT_CONTEXT.md`, `analysis/phase-20.6/` | ✅ **PASS** |
| **V5** | removed lines all Telegram-related | all accounted for | 70 removed: all are the SDK tag, block internals (comments/braces), or `haptic(...)` statements. 1 added: the rewritten `confirmedSession` line | ✅ **PASS** |
| **V6** | `grep -n "confirmedSession" index.html` | `enterApp()` intact | `if(confirmedSession){ enterApp(); }` at line 1315 | ✅ **PASS** |
| **V7** | structural counts | `showToast(` unchanged; `function ` −1; lines 4942 | `showToast(` 89→89; `function ` 146→145; 4942 lines | ✅ **PASS** |
| **V8** | `sed -n '1,12p' index.html` | viewport/version/title/Supabase present, no Telegram | all present, no Telegram | ✅ **PASS** |
| **V9** | `git grep -n "telegram.org" -- index.html` | no output | no output | ✅ **PASS** |
| **V10** | `git branch --show-current` / `git status` | correct branch, no stray files | `phase-20.6-remove-telegram-runtime`, clean | ✅ **PASS** |

### 14.2 Structural integrity

Bracket balance, whole file, before vs after:

| Delimiter | Before (HEAD) | After | Balanced before? | Balanced after? |
|---|---|---|---|---|
| `{` / `}` | 1068 / 1068 | 1059 / 1059 | ✅ | ✅ |
| `(` / `)` | 2939 / 2939 | 2896 / 2896 | ✅ | ✅ |
| `[` / `]` | 177 / 177 | 177 / 177 | ✅ | ✅ |

Every delimiter class is **balanced after the change exactly as it was before**, and each removal was structurally neutral (−9 `{` with −9 `}`; −43 `(` with −43 `)`). No control-flow block was orphaned.

**Head section verified intact:** `<meta charset>`, `<meta name='viewport'>`, `<meta name='version' content='3.0'>`, `<title>STAGERZ</title>`, and the Supabase SDK `<script>` all present and unmodified. Only the Telegram `<script>` is gone.

**Script boundary verified:** `<script>` is now immediately followed by `// --- SUPABASE ---`, with `SUPA_URL`, `SUPA_KEY`, and `supabase.createClient(...)` intact. Nothing past the END marker was removed.

**Spot-checked regions post-edit:** `sendOtp()` (toast + `goTo('authwait')` intact), `checkSessionAndStart()` (`enterApp()` intact), `goTo()` (`renderArtists()` timeout and all view branches intact), `startRec()`/`stopRec()` (1000 ms interval and `recWave` display toggle intact).

> **Tooling limitation, recorded honestly:** no JavaScript runtime (`node`, `deno`, `bun`) and no Python interpreter is available in this environment, so **no true JS parser was run**. Structural confidence rests on the bracket-balance delta above plus the audited diff. **A real parse is confirmed only by loading the page in a browser** — see §14.4.

### 14.3 `enterApp()` — explicit confirmation

The single inline call was edited in place, exactly as specified.

**Before:**
```js
if(confirmedSession){ haptic('success'); enterApp(); }
```

**After (`index.html:1315`):**
```js
if(confirmedSession){ enterApp(); }
```

`enterApp(` occurrences: **3 before, 3 after** — the definition (`function enterApp(){`), the session-restore call (`if(session){ enterApp(); } else { goTo('authemail'); }`), and this `SIGNED_IN` branch. **`enterApp()` was not removed, and the statement was not deleted.** Magic-link sign-in still enters the app.

### 14.4 Browser validation — Level 3

**Status: local pre-merge validation PASSED. Authenticated production validation OUTSTANDING (environment-blocked pre-merge).**

#### 14.4.1 Environment

| Field | Value |
|---|---|
| Served from | **Local working tree** via VS Code Live Server (`localhost`) |
| Commit under test | Working tree on `phase-20.6-remove-telegram-runtime` (uncommitted at time of test) |
| Why not a PR preview | No PR preview environment exists — GitHub Pages serves `main` directly. See the §8 correction |
| Date | 2026-07-28 |

**Diagnostic note preserved for the record.** Before this validation, a browser console still showed `telegram-web-app.js` and Telegram `postEvent` logs. Root cause was determined: the browser was loading **production `stagerz.app`**, which serves `main` at `155b029c` — the pre-removal Phase 20.5 code. The Phase 20.6 change existed only as uncommitted working-tree modifications and had never been published. This was **not** a cache fault, not a stray build artifact, and not a wrong checkout — verified by `git log main..HEAD` returning empty, by the absence of any local server on ports 3000–9000, and by `find` locating exactly one HTML file in the repository. Serving the working tree on `localhost` resolved it immediately.

#### 14.4.2 Observed results — local, unauthenticated

| # | Check | Observed | Result |
|---|---|---|---|
| A1 | Page loads; inline script parses; no blank screen | Local page loaded successfully | ✅ **PASS** |
| A2 | No `ReferenceError: haptic is not defined` | No `haptic` ReferenceError | ✅ **PASS** |
| A3 | No `Telegram is not defined` / `telegramWebApp is not defined` | No `window.Telegram` or `telegramWebApp` error | ✅ **PASS** |
| A4 | No request to `telegram.org` | **No Telegram SDK logs appeared locally** | ✅ **PASS** |
| A5 | `HapticFeedback … version 6.0` warning gone | Absent | ✅ **PASS** |
| A6 | No new console error vs baseline | Console contained **only** `Live reload enabled.` (emitted by Live Server, not by the app) | ✅ **PASS** |
| — | Login page renders and remains usable | Rendered and usable | ✅ **PASS** |
| B1 | Magic-link request sends | Supabase magic link **successfully requested** | ✅ **PASS** |

**A clean console containing only the dev-server's own `Live reload enabled.` message is the strongest available evidence that the inline script parses and executes end-to-end.** A syntax error from a mis-cut deletion, or an orphaned `haptic(...)` call, would have surfaced here. Neither did. This also serves as the JavaScript parse check that could not be run statically (no `node`/`deno`/`bun`/Python in the environment — see §14.2).

#### 14.4.3 Environment-blocked — full magic-link callback

**Status: BLOCKED, not failed. Not evidence against the change.**

The Supabase magic-link redirect is configured to `https://stagerz.app`. Opening the link generated during local testing redirected to **production**, which currently serves `main` at `155b029c` — the pre-removal code. Production therefore still showed the Telegram runtime.

**This production Telegram output is expected and is not evidence against the Phase 20.6 working tree.** It is the old deployment behaving exactly as it should. The local page under test contains zero Telegram references, statically and at runtime.

Consequence: the authenticated half of the checklist could not be exercised locally, because the session never lands on `localhost`.

| Blocked items | Reason |
|---|---|
| **B2** — magic link → `enterApp()` → app opens | Redirect returns to production, not localhost |
| B3–B5 — resend, session restore, sign-out | Require an authenticated session on the tested origin |
| C1–C2 — navigation | Behind sign-in |
| D, E, F, G, H, I, J, K — Wanted, Profile, Collaboration, Messaging, Tasks, Assets, Credits, FameMaker | Behind sign-in |
| L1–L3 — responsive checks of authenticated views | Behind sign-in |

**Not retried:** Supabase is currently rate-limiting magic-link requests. No further link was requested. Changing the Supabase redirect allow-list to point at `localhost` was **not** attempted — that is a production authentication configuration change and is an explicit non-goal of this phase (§11).

| M1–M2 | Telegram WebView check | **NOT VERIFIED** — no supported Telegram entry point in scope per the product-owner decision (§13.1). No Telegram bot was created for testing |

#### 14.4.4 Required after merge and deployment — NOT YET PERFORMED

The authenticated checks above **must** be completed on production after this branch is merged to `main` and GitHub Pages has redeployed. Until then they are recorded as **outstanding**.

**These checks are explicitly NOT marked as passed.** No claim is made about authenticated behavior on the deployed build. The exact list is in **§15**.

#### 14.4.5 Product-owner approval to proceed

The product owner reviewed the static verification (§14.1–§14.3) and the local smoke test (§14.4.2) and **approved proceeding to commit and push** on that basis, accepting that the authenticated production checks in §15 remain outstanding and will be performed after deployment.

This approval covers **commit and push of the feature branch only.** It is not approval to merge, and not a substitute for the post-deployment validation in §15. Per `.apos/VALIDATION_STANDARD.md` §6, approval is scoped to what was reviewed.

### 14.5 Acceptance criteria status (§9)

| # | Criterion | Status |
|---|---|---|
| 1 | No `telegram` in `index.html` | ✅ PASS |
| 2 | No `haptic` in `index.html` | ✅ PASS |
| 3 | No `window.Telegram` / `telegramWebApp` / `HapticFeedback` / `ready()` / `expand()` / `impactOccurred` / `notificationOccurred` | ✅ PASS |
| 4 | SDK script tag gone; no `telegram.org` request | ✅ PASS |
| 5 | All 28 call sites removed (27 deletions + 1 verified in-place edit) | ✅ PASS |
| 6 | `enterApp()` intact in the `confirmedSession` branch | ✅ PASS |
| 7 | viewport / version / title / Supabase script unchanged | ✅ PASS |
| 8 | Deletion-only apart from line 1358; 0 net insertions | ✅ PASS |
| 9 | Only `index.html`, `.apos/PROJECT_CONTEXT.md`, `analysis/phase-20.6/` changed; 20.1–20.5 untouched | ✅ PASS |
| 10 | Zero changes to auth, Supabase config, REST helpers, RLS, CSS, messaging logic | ✅ PASS |
| 11 | §8 checklist recorded | ⚠️ **PARTIAL** — unauthenticated items (A1–A6, B1) PASS locally; authenticated items environment-blocked pre-merge and recorded as outstanding (§14.4.3–§14.4.4) |
| 12 | No new console error / failed request vs baseline | ✅ PASS (local) — console contained only `Live reload enabled.`; no request to `telegram.org` |
| 13 | Validation report per `VALIDATION_STANDARD.md` §10 | ✅ PASS — §13–§14 constitute the report |
| 14 | §4 external-entry-point question answered by product owner | ✅ PASS — recorded in §13.1 |
| 15 | ChatGPT review + explicit user approval before commit | ✅ PASS for **commit and push of the feature branch** — §14.4.5. **Not** approval to merge |

**13 of 15 criteria pass. Criterion 11 is partial by environment constraint, not by failure**, and criterion 12 is confirmed locally but must be reconfirmed on production. The authenticated remainder is enumerated in §15 and is **not** claimed as passed.

---

## 15. Post-merge production validation — REQUIRED, NOT YET PERFORMED

**Run only after this branch is merged to `main` and GitHub Pages has redeployed `stagerz.app`.** Before starting, hard-reload (Ctrl+Shift+R, *Disable cache* ticked) and confirm via view-source that the served HTML has **zero** `telegram` hits and DevTools → Network shows **no** request to `telegram.org`. Record each item PASS / FAIL / N/A.

### Gate — must pass first
- [ ] **P0** — Deployed page loads; view-source shows 0 `telegram` occurrences; no `telegram.org` request in Network
- [ ] **P1** — Console shows **no** `ReferenceError: haptic is not defined` and no `Telegram`/`telegramWebApp` error

### Authentication — highest risk (former call sites 1–2)
- [ ] **P2** — Request a magic link; the "Check your email and tap the sign-in link." toast appears; view advances to `authwait`
- [ ] **P3** — **CRITICAL:** open the magic link → session confirms → **`enterApp()` runs and the app opens.** *This is the single check that proves the in-place edit at the former line 1358 is correct in the deployed build. It is the only item that could not be exercised anywhere pre-merge.*
- [ ] **P4** — Resend flow works
- [ ] **P5** — Reload with an existing session → session restores, app opens directly
- [ ] **P6** — Sign out → returns cleanly to the auth view

### Navigation (former call site 3)
- [ ] **P7** — Every view reachable: Stage, Wanted, FameMaker, Profile, Collaboration, Backstage
- [ ] **P8** — `goTo('search')` still triggers `renderArtists()` — the artist list populates

### Feature sweep — every former haptic site still completes its primary effect
- [ ] **P9** — Wanted: create/submit, edit, close, apply, accept, reject (sites 4–7, 9)
- [ ] **P10** — Profile: save → toast → navigates to `profile` (site 8)
- [ ] **P11** — Collaboration: status change, invite, remove participant, transfer ownership, leave — including leave **not** reloading the same workspace (sites 10–14)
- [ ] **P12** — Messaging regression (Phases 20.1/20.2/20.3): optimistic send, reconciliation, no duplicates, edit, delete, no loading flash, load-failure state, failed-send rollback (sites 15–16)
- [ ] **P13** — Tasks: create, edit, complete, delete (sites 17–20)
- [ ] **P14** — Assets: upload, edit, delete (sites 21–23)
- [ ] **P15** — Credits: add, edit, delete (sites 24–26)
- [ ] **P16** — FameMaker: `startRec()` / `stopRec()` — recording starts and stops, wave element toggles (sites 27–28)

### Cross-cutting
- [ ] **P17** — Every toast adjacent to a removed `haptic(...)` still fires, with unchanged text
- [ ] **P18** — Mobile width and a real mobile browser (iOS Safari / Android Chrome): layout intact, no overflow, viewport meta still applies
- [ ] **P19** — No new console error and no new failed network request versus the pre-change production baseline

**If any item fails, apply the rollback in §10** — `git revert -m 1 <merge-commit>` on `main`, which restores the Telegram runtime on redeploy. No database, schema, or external configuration change is involved, so rollback is a single git operation.

### 14.6 The main web app is now Telegram-independent

**Confirmed.** The full STAGERZ web application no longer contains any Telegram runtime dependency:

- **Zero** Telegram references in `index.html` — the only file in the repository containing executable code.
- **No** external script is loaded from `telegram.org`; the app no longer makes any request to Telegram infrastructure.
- **No** code path reads `window.Telegram`, and no code path depends on a Telegram host being present.
- The app now runs on **normal browser runtime and Supabase only**, matching the "Final intended full-app architecture" recorded in `.apos/PROJECT_CONTEXT.md`.
- Combined with Phase 20.4 (NACKL removal), the full web app is now free of **both** deferred Light-version concepts.

Behavior in a normal browser is unchanged. Phase 20.5 established that `haptic()` was already a silent no-op outside a Telegram host and that `ready()`/`expand()` were guarded and inert — removing code that never executed in a browser cannot change browser behavior. The only losses are Telegram-host-only, and they are intentional. One render-blocking third-party request was eliminated as a side benefit, and the SDK-originated `HapticFeedback is not supported in version 6.0` console warning is gone with it.

### 14.7 Guardrail for a future Telegram Light version

**Any future Telegram light version must be implemented separately and must not silently reintroduce runtime coupling into the main web application.**

This is a standing constraint, not a preference. Phases 20.4, 20.5, and 20.6 exist because Telegram and NACKL runtime code accumulated inside the main app without a boundary, producing dead code paths, a misleading feature claim, an SDK console warning, and a 28-call-site cleanup that had to be planned across three phases. Reintroducing that coupling would repeat the same cost.

Binding rules for any future Light / Mini App work:

1. **Separate delivery artifact.** The Light version must be its own entry point — a separate file, build target, or repository. It must **not** be a conditional branch inside the main app's `index.html`.
2. **No conditional platform code in the main app.** No `if (window.Telegram)`, no platform sniffing, no "harmless" SDK script tag, no `haptic()`-style wrapper "just in case". A guard that is inert today is still coupling, and it is exactly what Phase 20.5 had to spend a phase isolating.
3. **No shared mutable runtime.** The Light version may reuse Supabase schema and API contracts. It must not require the main app to carry Telegram-aware code, variables, or initialization.
4. **Sequencing is fixed by product decision.** Light-version work begins only after the main web application is technically complete, stable, and user-friendly.
5. **Explicit governance.** Reintroducing any Telegram runtime into the main app requires a new APOS phase and an explicit, recorded reversal of the roadmap decision in `.apos/PROJECT_CONTEXT.md`. It may not arrive as an incidental part of unrelated work.

The removed implementation is preserved for reuse in git history at `155b029cdfcd752104849f1d52f84c0aa645ce61` and documented in `analysis/phase-20.5/phase-definition.md`. **Removal from the full app was never deletion of the product idea** — the Light version recovers it deliberately, from a clean base, rather than inheriting it by accident.
