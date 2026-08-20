# Phase 21.2 — Startup Resilience and Dependency Pinning

**Branch:** `phase-21.2-startup-resilience`
**Base commit:** `780d6f92263d51874d660fff53801899f4fff2de` (`main`, merge of Pull Request #8 — Phase 21.1)
**Addresses:** Phase 20.7 register item **C-2** (Critical) — *Unpinned CDN dependency with no failure path*, recorded at `analysis/phase-20.7/codebase-assessment.md` §A.7 and §E; plus **M-12** (cold-start blank screen) and risk **R-2**.
**Status:** **Approved and implemented.** The decisions in §0 were approved by the user on 2026-08-06; `index.html` was modified accordingly. Static and headless validation pass; **browser and production validation are outstanding**. Not committed, not pushed. Full record: `analysis/phase-21.2/validation.md`.
**Validation level required:** Level 3 — the change affects behaviour in `index.html` (`.apos/VALIDATION_STANDARD.md` §2). **Not yet satisfied** — see `validation.md` §8.

---

## 0. Approved decisions (2026-08-06)

The seven questions this document left open in §11 were answered by the user. Sections 1–12 below are the **pre-approval analysis and are preserved unedited** as the record of what was proposed; where a decision narrowed or overrode a proposal, this section governs.

| Decision | Resolution |
|---|---|
| **Q-1** — which version to pin | **2.112.1**, at the exact URL `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.1/dist/umd/supabase.js` |
| **Q-2** — regenerate the hash | **Yes.** Recompute the SHA-384 immediately before editing and confirm the fetched asset self-identifies as 2.112.1. Done, from two independent downloads — `validation.md` §2 |
| **Q-3** — script position (§6.7) | **In scope.** The SDK tag moves out of `<head>` to sit after the boot markup and before the application inline script |
| **Q-4** — watchdog (§6.6) | **Excluded.** No watchdog and no startup timeout in this phase. F2, F9 and F10 are therefore reduced to a branded splash rather than closed — `validation.md` §5 and §9.1 |
| **Q-6 / Q-7** — copy | **One** fixed, concise, generic user-facing message for every failure code, with a single Reload control. No per-code distinction in the visible text |
| **Q-5** — process to keep the pin current | **Still unanswered.** Recorded as a standing maintenance obligation, out of scope here |

Also approved, restating and confirming the analysis: `integrity` plus `crossorigin='anonymous'` together; **no** `async` or `defer`; guarded initialisation via `typeof`; catch synchronous initialisation and session-start failures; fixed text only, with no raw error, stack, URL or key; **Reload only**, no retry-initialization; and no CSP, service worker, offline mode, auth redesign, backend change, or broad error-handling refactor.

### 0.1 What was implemented

Five edits to `index.html`, applied in the binding order of §6.8 — boot screen first, guards second, pin and hash last:

| # | Location (post-edit) | Edit |
|---|---|---|
| 1 | 303–311 | `#screen-boot` added, the only screen carrying `active` in static markup |
| 2 | 1030–1055 | Guarded initialiser replaces the bare `createClient()`; `showStartupFailure()` added |
| 3 | 1414–1432 | `onAuthStateChange` registration wrapped in `if(supabaseClient){…}` **and a `try/catch` (defect D-1, §0.3)**; callback body unchanged |
| 4 | 5123–5134 | `DOMContentLoaded` checks `startupFailure` first, then runs inside `try/catch` |
| 5 | 1007–1009 | SDK tag removed from `<head>`; re-added pinned, with `integrity` and `crossorigin` |

**Measured and verified at implementation time (2026-08-06):** SHA-384 `0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV`, SHA-256 `ed01c1c20daec4e06a08dbbf4fdc7d4a613091f7032a408faee2d6df45acad58`, 210,842 bytes, `x-jsd-version: 2.112.1`. Both hashes match the values recorded in §6.1 below, which were measured on 2026-08-05 — but they were recomputed rather than copied, as Q-2 requires.

**One §6 proposal was narrowed by the approved decisions.** §6.5 proposed that `showStartupFailure()` branch its visible text on the failure code; Q-7 replaced that with a single fixed message. The `code` parameter is retained, but is used only for `console.error`.

### 0.2 Verification summary

| Suite | Result |
|---|---|
| `analysis/phase-21.2/static-check.sh` — 57 source invariants | **57/57 pass** |
| Headless guard verification against the live source — 42 assertions | **42/42 pass** |
| `startup-failure-harness.html` in Edge — 48 assertions | **48/48 pass** |
| Browser tests B-1…B-12 (Edge 151, headless) | **10 PASS, B-2 partial, B-7 not runnable** |
| Regression N-1…N-7 | **Not run** — need a real authenticated session |
| Production checks P-1…P-7 | **Not run** — need a deployment |

### 0.3 Defect D-1 — found by browser validation, approved, fixed

Browser testing disproved a claim this document made in §6.4: `if(supabaseClient){…}` closes only the **null-client** case. If the client is created successfully but `supabaseClient.auth.onAuthStateChange(…)` **throws** — the shape an incompatible or partial SDK build produces — the uncaught `TypeError` aborted the rest of the inline script, the `DOMContentLoaded` listener was never registered, and the user was stranded on `#screen-boot` showing "Starting…" with no message and no Reload control.

Reported under the `.apos/WORKFLOW.md` stop-and-report rule rather than fixed unilaterally, since it changes an approved design decision. **Approved 2026-08-06** as in-scope for Phase 21.2 startup resilience, with the fix constrained to the smallest possible change.

**Applied:** the registration call — and only the registration call — is wrapped in a `try/catch` whose handler logs to the console and sets `startupFailure = 'client-init-failed'`, the code the `createClient`-throws path already uses. No new failure code, no new message, no new DOM node, no watchdog, no retry, no change to the callback body or to normal-path auth behaviour.

**Consequence for the §6.3 invariant, worth recording:** `supabaseClient` can now be non-null while `startupFailure` is set. The invariant "a failed startup never leaves the boot screen" is therefore carried by `startupFailure` alone, not by the client being null. Static invariant **S-23b** was added to prevent a silent regression.

---

## 1. Objective

Eliminate the permanently-blank-page failure mode at application startup, and replace the floating CDN dependency with an exact, integrity-checked version.

Phase 20.7 identified three compounding problems on a single line and a single expression: the Supabase SDK is loaded at a floating major version with no Subresource Integrity, `supabase.createClient()` runs at the top level of the one inline script, and no screen carries `active` in the static markup. Together these turn any CDN failure into a black page with no message and no recovery.

This document defines the problem precisely, records what was measured, and proposes an implementation. **It approves nothing.** Implementation requires ChatGPT review and explicit user approval per `.apos/WORKFLOW.md`.

**Pattern decision (`.apos/WORKFLOW.md`): Reuse → Extend.** The failure screen **reuses** the existing `.screen` / `.screen.active` mechanism unchanged — it is a 21st screen, deactivated automatically by the existing `goTo()`. The guarded initialiser **extends** the file's existing "try/catch, return an explicit failure value, never throw" idiom, already used by `supaSelect()`, `supaHeaders()` and `safeImageUrl()`. No new pattern is created, no framework, no build step, no module system.

---

## 2. Method

The startup path was traced statically from the first byte of `index.html` to the first visible screen, in execution order rather than in file order. Every point at which control can be lost before a screen becomes visible was enumerated.

The dependency was then measured live rather than assumed: the jsDelivr resolver API, the actual bytes served by both the floating and the pinned URL, the embedded version constant inside each build, and the HTTP response headers were all captured on 2026-08-05. That measurement produced the phase's most important finding (§4.2), which contradicts an assumption in the Phase 20.7 proposal.

---

## 3. Exact current startup sequence

Verified against `index.html` at `780d6f9`. Line numbers are exact at that commit.

| # | Step | Location | Blocking? |
|---|---|---|---|
| 1 | `<!DOCTYPE html>`, `<head>` parsing begins | 1–7 | — |
| 2 | **Supabase UMD SDK requested** — classic script, no `defer`, no `async`, no `integrity`, no `crossorigin` | **8** | **Render-blocking.** HTML parsing halts here until the script loads and executes, or fails |
| 3 | SDK executes, creating the global binding `var supabase = …` | (vendor) | — |
| 4 | `<style>` block parsed, including a render-blocking Google Fonts `@import` | 9–286 | Blocks first paint |
| 5 | `<body>` parsed — **20 `.screen` divs, none carrying `active`** | 288–958 | Nothing is displayable: `.screen{display:none}` (17) |
| 6 | Inline `<script>` begins executing during parse | 960 | — |
| 7 | `SUPA_URL`, `SUPA_KEY` assigned | 962–963 | — |
| 8 | **`var supabaseClient = supabase.createClient(SUPA_URL, SUPA_KEY);`** — top level | **964** | **Single point of total failure** |
| 9 | ~4,000 lines of function declarations evaluate | 966–5018 | — |
| 10 | **`supabaseClient.auth.onAuthStateChange(…)`** registered — top level | **1312** | Second top-level failure point |
| 11 | `DOMContentLoaded` listener registered | **5020** | — |
| 12 | Parsing completes; `DOMContentLoaded` fires | — | — |
| 13 | `buildStageFeed('all')` → `renderArtists()` → `renderWanted(null)` | 5021–5023 | All three are DOM-guarded (`if(!feed) return;` 1751, `if(!r) return;` 1562) |
| 14 | `checkSessionAndStart()` invoked | 5024 | — |
| 15 | `await supabaseClient.auth.getSession()` | 1300 | **The blank window: nothing is visible until this resolves** |
| 16 | `enterApp()` → `goTo('stage')`, or `goTo('authemail')` | 1301 / 1290–1293 | — |
| 17 | **`goTo()` adds `active` — first visible pixel of application UI** | **1327–1331** | — |
| 18 | Screen-entry data loads fire (`loadWanted`, `loadMyProfile`, `loadBoard`, …) | 1334–1339 | — |

**Step 17 is the first moment anything is visible.** Steps 2–16 all render a black viewport (`html,body{background:#08080f}`, line 14).

There are exactly **three** top-level executable statements in the inline script — lines 964, 1312 and 5020. Everything else is a declaration. This was verified by scanning for column-0 non-declaration statements across 960–5026.

---

## 4. Findings

### 4.1 The dependency is unpinned, unverified, and has no failure path

```html
<script src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'></script>
```
`index.html:8`

| Property | Current state |
|---|---|
| Version specifier | `@2` — floating across every 2.x release |
| Subresource Integrity | **Absent** |
| `crossorigin` | **Absent** |
| `defer` / `async` | Absent — synchronous and render-blocking |
| Load-failure handler | **Absent** — no `onerror` attribute, no global `error` listener anywhere in the file (verified: zero occurrences of `window.onerror`, `addEventListener('error'`, `unhandledrejection`) |
| Lockfile / build step | None exist |

### 4.2 The floating URL is not merely unpinned — it is **non-deterministic across users**, measured

This is the finding that most changes the shape of the phase, and it was not visible to Phase 20.7.

Measured 2026-08-05:

| Source | Reports |
|---|---|
| jsDelivr resolver API (`data.jsdelivr.com/v1/…/resolved?specifier=2`) | **2.112.1** |
| npm registry `latest` | **2.112.1** |
| **Bytes actually served by the `@2` URL** (Frankfurt edge, `x-cache: HIT`, `age: 34115`) | **2.112.0** — 210,770 bytes |
| Bytes served by the pinned `@2.112.1` URL | **2.112.1** — 210,842 bytes |
| Bundle observed during Phase 21.1 validation, 2026-08-04 | **2.111.0** (`analysis/phase-21.1/validation.md` §6.1) |

The embedded client-header constant inside each downloaded build confirms the divergence independently of the HTTP headers: the `@2` build self-identifies as `supabase-js/2.112.0`, the pinned build as `supabase-js/2.112.1`.

Three consequences follow, and none of them are theoretical:

1. **The version served depends on edge-cache state, not on the URL.** A user behind a warm Frankfurt PoP currently receives 2.112.0. A user hitting a cold edge receives 2.112.1. **Two users can be running different SDK versions at the same moment,** and neither matches what the resolver reports.
2. **The dependency drifted twice inside the observation window** — 2.111.0 during Phase 21.1 validation on 2026-08-04, 2.112.0 and 2.112.1 on 2026-08-05. No review step, no approval, no record.
3. **The Phase 20.7 instruction "pin to the version currently resolved in production" is unsatisfiable as written.** There is no single such version. This is a genuine conflict with the approved 20.7 proposal text and is raised, not silently resolved — see §11, unresolved question **Q-1**.

A fourth consequence is decisive for the SRI question: **Subresource Integrity is impossible on the floating URL by construction.** A hash cannot be pinned to content that changes. SRI and version pinning are not two independent improvements; the pin is a prerequisite for the hash.

### 4.3 A single expression aborts the entire application

```js
var supabaseClient = supabase.createClient(SUPA_URL, SUPA_KEY);
```
`index.html:964`

The vendor bundle begins `var supabase=(function(e){…` — a classic-script global binding. If the script tag at line 8 does not execute, the identifier `supabase` is **not declared at all**, so line 964 raises a `ReferenceError`, not a comparison against `undefined`. (This distinction matters for the detection design in §6.3: `typeof supabase === 'undefined'` is safe; `if (!supabase)` would itself throw.)

An uncaught error terminates execution of the containing `<script>` element. There is exactly **one** inline script element in the file, spanning 960–5026. Therefore a throw at line 964 means:

- None of the ~139 function declarations after line 964 are ever created.
- `onAuthStateChange` (1312) is never registered.
- The `DOMContentLoaded` listener (5020) is never registered.
- `checkSessionAndStart()` never runs, so `goTo()` never runs.
- **No element ever receives `active`.**

Combined with `.screen{display:none}` (17) and zero occurrences of `class="screen active"` in the markup (verified: 0), the result is a permanently black page with no text, no error, no retry, and no indication that anything is wrong.

### 4.4 Blank-screen failure mode — confirmed point by point

Each of the four conditions the phase brief asks about was checked directly against the source.

| Question | Answer | Evidence |
|---|---|---|
| Is any screen active in static markup? | **No.** Zero `.screen` elements carry `active` | `grep -c 'screen active' index.html` → `0`; 20 `<div class="screen">` |
| Can a failure before `goTo()` leave a permanent black page? | **Yes** | §4.3; `.screen{display:none}` (17); `.screen.active{display:flex}` (18); first `active` is added at 1331 |
| Can `createClient()` throw when the SDK is unavailable? | **Yes — `ReferenceError`.** It can also throw `TypeError` if the global exists but is a partial or incompatible build | 964; vendor `var supabase=…` binding |
| Does any try/catch or fallback exist on the startup path? | **No.** Nothing guards lines 8, 964, 1312 or the `DOMContentLoaded` body. The only try/catch on the path is *inside* `checkSessionAndStart()` (1299–1304), which is unreachable when the SDK is missing | 964, 1312, 5020–5025 |

The `try/catch` at 1299–1304 is worth calling out precisely because it looks like protection and is not. It catches a rejected `getSession()` and falls back to `goTo('authemail')` — a correct and useful guard for a *network* failure against Supabase. It cannot help when the SDK is absent, because the script never reaches the function that contains it.

### 4.5 Every point where startup can fail before a visible screen appears

| # | Failure | Line | Current outcome | Covered by proposal? |
|---|---|---|---|---|
| F1 | SDK request fails — offline, DNS, CDN outage, corporate proxy, ad-blocker, `jsdelivr.net` blocked by network policy | 8 | **Permanent black page** | Yes — §6.2, §6.3 |
| F2 | SDK request times out or hangs | 8 | Black page for the duration; then F1 | Partly — §6.6 watchdog |
| F3 | SDK loads but exposes no `supabase` global (wrong path, HTML error page served with 200, truncated response) | 8 → 964 | **Permanent black page** (`ReferenceError`) | Yes — §6.3 |
| F4 | Global exists but `createClient` is missing or not a function (incompatible major, partial build) | 964 | **Permanent black page** (`TypeError`) | Yes — §6.3 |
| F5 | `createClient()` itself throws (malformed URL/key, a future SDK validating its inputs more strictly) | 964 | **Permanent black page** | Yes — §6.3 |
| F6 | **SRI hash mismatch** — introduced *by this phase* if integrity is added | 8 | Browser refuses to execute the script → identical to F1 | Yes — §6.3, and this is why §6.7 orders the work |
| F7 | `onAuthStateChange` registration throws | 1312 | **Permanent black page** | Yes — §6.4 |
| F8 | A synchronous throw in `buildStageFeed`/`renderArtists`/`renderWanted` before `checkSessionAndStart()` is reached | 5021–5023 | **Permanent black page** | Yes — §6.5 |
| F9 | `getSession()` hangs without resolving or rejecting | 1300 | Black page indefinitely — no timeout exists | Partly — §6.6 watchdog |
| F10 | Syntax error anywhere in the inline script | 960–5026 | **Permanent black page**; guards inside the block cannot help | Partly — §6.2 converts it to a visible splash; §6.6 adds a message |
| F11 | Slow SDK download on a poor connection | 8 | Black page for the whole download (render-blocking in `<head>`) | Only by §6.7, the separable script-position change |

F1, F3, F4, F5, F7, F8 are fully closed by the core proposal. F2, F9, F10 are reduced from "black page" to "branded splash", and to "splash plus honest message" if the watchdog is included. **F11 is not closed by the core proposal** — see §6.7.

### 4.6 The cold-start blank window exists on the normal path too

Even when everything works, steps 2–16 of §3 render nothing. Phase 20.7 recorded this as M-12 and attributed it to the `await` at line 1300. That is correct but incomplete: because line 8 is **render-blocking in `<head>`**, the blank window begins before `<body>` is even parsed and lasts for the entire SDK download.

This has a direct design consequence that is easy to get wrong. Marking a boot screen `active` in the static markup does **not**, on its own, eliminate the cold-start blank window — the browser cannot paint markup it has not parsed, and it will not parse `<body>` until the script at line 8 resolves. The boot screen closes the window from *parse-complete* to *`getSession()` resolution*; closing the *download* window additionally requires moving the script tag below the boot markup (§6.7).

---

## 5. File locations

| Path | Role in this phase |
|---|---|
| `index.html:8` | SDK script tag — to be pinned, integrity-checked, `crossorigin` |
| `index.html:14` | `html,body{background:#08080f}` — the black of the blank page |
| `index.html:17–18` | `.screen{display:none}` / `.screen.active{display:flex}` — the mechanism the fallback reuses |
| `index.html:288` | `<body>` — insertion point for the boot screen markup |
| `index.html:293–309` | `#screen-authemail` — styling reference for the fallback screen |
| `index.html:960` | Inline `<script>` opens |
| `index.html:962–964` | `SUPA_URL`, `SUPA_KEY`, `createClient` — the guarded initialiser replaces 964 |
| `index.html:1290–1293` | `enterApp()` |
| `index.html:1298–1305` | `checkSessionAndStart()` |
| `index.html:1312–1325` | `onAuthStateChange` top-level registration — to be guarded |
| `index.html:1327–1349` | `goTo()` — deactivates the boot screen automatically; **not modified** |
| `index.html:5020–5025` | `DOMContentLoaded` init block — to be guarded |
| `analysis/phase-21.2/phase-definition.md` | This document |
| `.apos/PROJECT_CONTEXT.md` | Phase of record, development branch, Phase 21.2 entry |

---

## 6. Recommended design

The smallest implementation that closes F1, F3, F4, F5, F7 and F8, preserves normal startup exactly, and introduces no framework, build step, or module system.

### 6.1 Pin the SDK to one exact version, with integrity and `crossorigin`

**Proposed replacement for `index.html:8`:**

```html
<script src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.1/dist/umd/supabase.js'
        integrity='sha384-0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV'
        crossorigin='anonymous'></script>
```

| Field | Value | Basis |
|---|---|---|
| Exact URL | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.1/dist/umd/supabase.js` | — |
| Version | **2.112.1** | npm `latest` and jsDelivr's own resolution of `@2`, both measured 2026-08-05 |
| Size | 210,842 bytes | Measured |
| SRI (SHA-384) | `sha384-0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV` | Computed locally from the downloaded bytes, 2026-08-05 |
| SHA-256 (cross-check) | `ed01c1c20daec4e06a08dbbf4fdc7d4a613091f7032a408faee2d6df45acad58` | Computed locally from the same bytes |

**This hash must be recomputed and re-verified at implementation time, not copied from this document.** It is recorded here as measured evidence supporting the analysis, not as an approved artefact. See validation check **S-3** (§9.1).

**Is SRI possible?** Yes. jsDelivr returns `access-control-allow-origin: *` and `cross-origin-resource-policy: cross-origin` on this URL (measured), so a CORS-enabled request succeeds.

**Is `crossorigin` needed?** **Yes — mandatory, not optional.** For a cross-origin classic script, SRI is only enforced on a CORS-enabled request. Adding `integrity` without `crossorigin='anonymous'` causes the browser to block the script outright, which would turn every load into failure mode F1. The two attributes must be added together or not at all.

**Is SRI appropriate?** Yes, with one condition. Arguments for: the SDK holds the user's session token, so a compromised or substituted bundle is a total account compromise; the pinned URL is served `immutable, max-age=31536000`, so the bytes are contractually stable and a hash mismatch would be a genuine anomaly rather than routine churn. Argument against: a mismatch is a hard, silent failure — the script simply does not execute. **That objection is what makes the ordering in §6.7 binding: the fallback screen must exist before the hash is added,** so that F6 presents as a readable message rather than the very blank page this phase exists to remove.

**Do not add `defer` or `async`.** This looks like an obvious improvement and is a trap. The inline script at 960 is a classic, non-deferred script inside `<body>`; it executes *during* parsing. A deferred external script executes *after* parsing completes. Adding `defer` to line 8 would invert the order, leaving `supabase` undeclared at line 964 on every single load — the guarded initialiser would then report a false "SDK unavailable" permanently. `async` is worse still, being nondeterministic. Recorded as a non-goal in §12.

### 6.2 A boot screen that is active in the static markup

Insert one 21st `.screen` immediately after `<body>` (line 288), carrying `active`:

```html
<div class="screen active" id="screen-boot">
  <div class="sa" style="display:flex;flex-direction:column;justify-content:center;align-items:center;padding:0 28px;text-align:center;">
    <div class="logo" style="font-size:32px;letter-spacing:-1px;text-shadow:0 0 30px rgba(232,184,48,.25);">STA<em>G</em>ERZ</div>
    <div id="bootMessage" style="font-size:10px;color:rgba(255,255,255,.35);margin-top:14px;letter-spacing:.5px;">Starting&hellip;</div>
    <div id="bootActions" style="display:none;margin-top:22px;">
      <button class="form-submit" onclick="location.reload()">RELOAD</button>
    </div>
  </div>
</div>
```

Why this reuses rather than extends anything: `goTo()` (1328) already begins by removing `active` from **every** `.screen`. The boot screen is therefore deactivated automatically by the first successful navigation — whether that is `goTo('stage')` or `goTo('authemail')` — with **no change to `goTo()` and no teardown code**. On the failure path, `goTo()` never runs and the boot screen simply stays.

**Verified safe against the existing code.** `.screen` is enumerated in exactly one place in the entire file — line 1328, inside `goTo()`. No code counts screens, indexes them, or depends on there being 20. The only other `active`-class reads are on `#screen-authemail`, `#screen-authwait` (1319–1320) and `#screen-collaborationdetail` (3991), all by explicit id.

**Copy discipline.** The default state says *"Starting…"*, not an error. It is shown on every normal load for a fraction of a second, so it must be neutral and branded. Error text is swapped in only when a failure is actually detected.

### 6.3 Guarded initialiser — replaces `index.html:964`

```js
var supabaseClient = null;
var startupFailure = null;   // null = healthy; a short machine code otherwise

try{
  if(typeof supabase === 'undefined' || !supabase || typeof supabase.createClient !== 'function'){
    startupFailure = 'sdk-unavailable';
  } else {
    supabaseClient = supabase.createClient(SUPA_URL, SUPA_KEY);
  }
}catch(e){
  console.error('STAGERZ startup: createClient failed', e);
  startupFailure = 'client-init-failed';
}
```

`typeof supabase === 'undefined'` is the only safe first test, for the reason established in §4.3: on load failure the identifier is undeclared, and any expression that *reads* it throws. The three conditions cover F3 (no global), F4 (wrong shape) and F5/F6 (constructor throws, or script blocked by SRI) with one branch each.

**Safety property this creates, which must be stated explicitly:** `supabaseClient` can now be `null`, and 12 call sites across the file dereference it unconditionally (`supabaseClient.auth.*` ×6, `supabaseClient.storage.from` ×4, `.removeChannel` ×1, plus the registration at 1312). The design does **not** guard those 12 sites, and does not need to — but only because of an invariant the implementation must preserve exactly:

> When `startupFailure` is non-null, the application never leaves the boot screen. `checkSessionAndStart()` is not called, `goTo()` is not called, and no interactive control that reaches `supabaseClient` is ever displayed.

The boot screen contains exactly one control — Reload — and it calls `location.reload()`, which touches nothing. Adding any further control to that screen without re-examining this invariant would be a defect.

### 6.4 Guard the top-level `onAuthStateChange` — `index.html:1312`

```js
if(supabaseClient){
  supabaseClient.auth.onAuthStateChange(async function(event, session){ /* body unchanged */ });
}
```

Closes F7. The callback body is not modified.

### 6.5 Guard the init block — `index.html:5020–5025`

```js
document.addEventListener('DOMContentLoaded', function(){
  if(startupFailure){ showStartupFailure(startupFailure); return; }
  try{
    buildStageFeed('all');
    renderArtists();
    renderWanted(null);
    checkSessionAndStart();
  }catch(e){
    console.error('STAGERZ startup: initialisation failed', e);
    showStartupFailure('init-failed');
  }
});
```

Closes F8. Note that `checkSessionAndStart()` is `async`, so this `try/catch` covers its synchronous prologue only — which is correct and sufficient, because its own internal `try/catch` (1299–1304) already handles the asynchronous path and routes to `goTo('authemail')`.

With one helper, placed beside the other small DOM helpers:

```js
// Phase 21.2 -- the only path that writes user-visible failure text.
// Fixed strings only: no error message, no stack, no URL, no key.
function showStartupFailure(code){
  var msg = document.getElementById('bootMessage');
  var actions = document.getElementById('bootActions');
  if(msg){
    msg.textContent = code === 'sdk-unavailable'
      ? 'STAGERZ could not load a required component. Check your connection and reload.'
      : 'STAGERZ could not start. Please reload the page.';
  }
  if(actions) actions.style.display = 'block';
}
```

**No secrets, no stack traces.** The function writes via `textContent`, never `innerHTML`, and selects from a fixed set of literal strings — the caught error is never interpolated. Diagnostics go to `console.error` only, matching the file's existing convention (`supaSelect` at 999). `SUPA_URL` and `SUPA_KEY` are already public by design (a publishable key in client source) but are deliberately not echoed into the DOM either.

### 6.6 Watchdog — separable, recommended

The core proposal cannot cover F2 (hang), F9 (`getSession()` never settles) or F10 (syntax error in the inline block), because all three prevent the guarded code from running at all. A small script element placed **immediately after line 8, before the inline block**, is in a separate failure domain and survives all three:

```html
<script>
// Phase 21.2 -- watchdog. Separate <script> element on purpose: it must
// survive a parse failure in the main block. Adds a recovery affordance;
// never removes or replaces content.
setTimeout(function(){
  var boot = document.getElementById('screen-boot');
  if(boot && boot.classList.contains('active')){
    var msg = document.getElementById('bootMessage');
    var actions = document.getElementById('bootActions');
    if(msg) msg.textContent = 'Still starting. If this does not clear, reload the page.';
    if(actions) actions.style.display = 'block';
  }
}, 10000);
</script>
```

It is **purely additive**: it checks that the boot screen is still active, and if so reveals the Reload button and softens the message. It never hides a screen and never contradicts `showStartupFailure()` — if that already ran, the button is already visible and the text is simply less specific, which is acceptable. The 10-second threshold must be long enough that a slow-but-working connection does not trip it.

This is marked separable so it can be dropped in review without touching the rest.

### 6.7 Script position — separable, closes F11

Moving the SDK `<script>` tag from `<head>` (line 8) to `<body>`, immediately before the inline script at 960, would let the boot screen parse and paint *before* the SDK download begins to matter. Execution order is preserved exactly — both are classic synchronous scripts, so the SDK still runs before line 964 — and the browser's preload scanner discovers the URL early regardless of position, so the download start time barely moves.

This is the **only** change that closes F11 and fully resolves M-12. It is proposed separately because it moves a line rather than adding one, and because the benefit is a first-paint improvement rather than a correctness fix.

### 6.8 Implementation order — binding

The steps are not independent, because step 1 can *cause* a failure that only step 2 makes visible.

1. Boot screen markup (§6.2) — visible fallback exists.
2. Guarded initialiser, guards, and `showStartupFailure()` (§6.3–§6.5) — failures become readable.
3. **Only then** pin the version and add `integrity` + `crossorigin` (§6.1).
4. Optional, in either order: watchdog (§6.6), script position (§6.7).

Performing step 3 first would mean that a wrong hash produces exactly the blank page this phase exists to eliminate, with no diagnostic.

---

## 7. Retry behaviour — evaluation and recommendation

| Option | What it does | Assessment |
|---|---|---|
| **Reload page** — `location.reload()` | Re-requests the document and the SDK; discards all in-memory state | **Recommended.** One line. No new code path. It is the *only* option that can recover from the dominant failure mode: if the script never loaded, the global will never appear, and no amount of re-running application code will change that. Supabase session state lives in local storage and survives a reload, so a signed-in user is not signed out |
| **Retry initialization** — re-run `createClient()` in place | Re-executes the guarded initialiser | **Not recommended.** Cannot succeed for F1/F3/F6, the most likely failures, because the missing global is missing permanently. Making it work would require dynamically injecting a fresh `<script>` element with cache-busting and a duplicate `integrity` attribute — a second loader path that can itself fail, must be kept in sync with line 8, and would need its own validation |
| **Both** | Two buttons | **Not recommended.** Offers the user a choice between a control that works and one that usually cannot, with no way for them to tell which is which. Adds surface for no benefit |

**Recommendation: Reload only.** Lowest risk, smallest diff, and strictly the most capable of the three.

One honest limitation: if the failure is a mistyped pinned URL or a wrong SRI hash shipped to production, Reload will fail identically every time. That is a deploy defect, not a runtime one; it is caught by validation checks **S-3** and **B-2** (§9) before merge, and its remedy is the rollback in §10.

---

## 8. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| **R1** | Pinning surfaces a behaviour difference between the pinned version and whatever floating build a given user was receiving | **Medium** — three distinct versions were observed in two days (§4.2) | Medium | Unavoidable and *desirable*: it converts an ongoing silent risk into one reviewed event. Full normal-path regression, §9.3 |
| **R2** | Wrong or stale SRI hash ships to production | Low | **High** — every load fails | Recompute at implementation time from two independent sources; check **S-3**; test the deliberate-mismatch case, **B-4** |
| **R3** | `integrity` added without `crossorigin` | Low | **High** — every load fails | Both attributes in one edit; check **S-2** asserts they co-occur |
| **R4** | Boot screen flashes visibly on every normal load | **High** — it will be seen | Low | Intentional. Neutral branded splash replacing black; no error wording in the default state |
| **R5** | Boot screen fails to clear, masking a working app | Low | High | It clears via existing `goTo()` (1328) with no new code; check **B-1**, **B-5** |
| **R6** | Watchdog fires on a slow-but-working connection | Medium | **Low** | Purely additive text plus a Reload button; nothing is hidden. 10 s threshold; check **B-8** |
| **R7** | `supabaseClient === null` reaches one of the 12 unguarded dereference sites | Low | Medium | The §6.3 invariant: a failed startup never leaves the boot screen. Check **S-6**, **B-3** |
| **R8** | Moving the script tag (§6.7) changes load timing in an unforeseen way | Low | Medium | Separable and independently revertible; check **B-9** |
| **R9** | A future SDK release makes the pin stale, with no process to update it | **Certain over time** | Low now, Medium later | Out of scope here. Recorded as **Q-5** — the pin creates a maintenance obligation this repository has no process for |

---

## 9. Validation plan

Level 3 is required. Structured to match `.apos/VALIDATION_STANDARD.md` §4 and §10.

### 9.1 Static checks — no browser, no network

Intended for an `analysis/phase-21.2/static-check.sh` in the implementation phase, following the Phase 21.1 precedent.

| # | Check | Expected |
|---|---|---|
| S-1 | Line 8 contains no floating `@2` specifier | 0 occurrences of `supabase-js@2/` |
| S-2 | Line 8 carries `integrity=` **and** `crossorigin=` | Both present on the same tag |
| S-3 | The `integrity` value equals a hash recomputed from the pinned URL at implementation time, verified from two independent sources | Byte-identical |
| S-4 | Line 8 carries neither `defer` nor `async` | 0 occurrences |
| S-5 | Exactly one `class="screen active"` in the markup, and it is `#screen-boot` | 1 |
| S-6 | No unguarded top-level `supabase.createClient(` remains | 0 |
| S-7 | `supabaseClient` is initialised to `null` and assigned only inside the guarded block | 1 assignment site |
| S-8 | The `onAuthStateChange` registration is inside `if(supabaseClient)` | 1 |
| S-9 | The `DOMContentLoaded` body is wrapped in `try{…}catch` and checks `startupFailure` first | 1 each |
| S-10 | `showStartupFailure()` uses `textContent`, never `innerHTML`, and interpolates no caught error | 0 `innerHTML`, 0 `e.message`, 0 `e.stack` |
| S-11 | `goTo()` (1327–1349) is byte-identical to the base commit | Unchanged |
| S-12 | Screen count is 21; `.screen` still enumerated in exactly one place | 21 / 1 |
| S-13 | Bracket balance `{}`, `()`, `[]` across the file | Balanced |
| S-14 | Line count and CRLF endings consistent with the base | `core.autocrlf=true` preserved |

### 9.2 Deterministic local simulation of SDK failure

**Primary method — DevTools request blocking. No file edit.**

1. Serve the working tree over `http://localhost:8080/`.
2. DevTools → Network → **Block request URL** → pattern `*jsdelivr*`.
3. Hard-reload.

This is deterministic, reversible, requires no modification of `index.html`, and is exact for F1. It is chosen deliberately over editing the `src` to a bad path: Phase 21.1 required a temporary source edit for validation and had to build a `pre-commit` marker hook plus SHA-256 verification to make that safe (`analysis/phase-21.1/validation.md` §6.1). **Blocking at the network layer removes that entire hazard class.**

**Secondary methods**, each also edit-free:

| Failure | How to induce |
|---|---|
| F1 — request fails | DevTools URL blocking, as above |
| F2 — timeout/hang | DevTools throttling → custom profile at minimal bandwidth |
| F3 — no global | Block the URL, then in the console before reload: nothing needed — F1 and F3 converge |
| F4 — wrong shape | Console, before `DOMContentLoaded`: overwrite the global with `{}` via a DevTools "Local overrides" stub, or run the harness in §9.5 |
| F6 — SRI mismatch | Temporarily corrupt one character of the `integrity` value **in a copy of `index.html` held in the scratchpad, never in the repository** |
| F10 — syntax error | Same scratchpad-copy technique |

The scratchpad-copy technique is the standing rule for this phase: **the repository working tree is never edited for validation purposes.** Any test needing modified source operates on a copy outside the repository.

### 9.3 Browser tests

| # | Test | Expected |
|---|---|---|
| B-1 | Normal cold load, no session | Boot screen appears immediately, then `#screen-authemail`. Boot screen no longer `active`. No console errors |
| B-2 | Normal cold load, valid session | Boot screen, then `#screen-stage`. Nav bar, badges, feed all correct |
| B-3 | SDK blocked (§9.2) | Boot screen stays; message is the human-readable SDK text; Reload button visible; **no blank page**; no uncaught `ReferenceError`; no interactive control reaching `supabaseClient` is displayed |
| B-4 | SRI mismatch, scratchpad copy | Identical presentation to B-3 |
| B-5 | Reload button from the B-3 state, with blocking removed | App starts normally |
| B-6 | Reload button with blocking still active | Returns to the same failure screen — no loop, no stuck spinner, no duplicate text |
| B-7 | Session survives a reload from the failure screen | Signed-in user lands on Stage, not on auth |
| B-8 | Slow connection (throttled), SDK eventually loads | Watchdog text may appear; app still starts normally when the SDK arrives; the boot screen still clears |
| B-9 | Script-position change (§6.7), if included | Boot screen paints before the SDK finishes downloading; startup otherwise identical |
| B-10 | Pinned version is the one actually executing | `supabase` global present; DevTools → Network shows `x-jsd-version: 2.112.1`; no fallback to any other version |

### 9.4 Normal-path regression

Because the pin may change the SDK version relative to what a given browser was previously served (R1), the SDK's own surfaces must be re-exercised. Restricted to the 12 `supabaseClient` call sites plus session handling — this is not a full application regression:

| # | Area | Covers |
|---|---|---|
| N-1 | Magic-link sign-in end to end | `auth.signInWithOtp` (1 site), `onAuthStateChange` `SIGNED_IN` |
| N-2 | Session restore on reload | `auth.getSession` (4 sites) |
| N-3 | Sign-out | `auth.signOut`, `SIGNED_OUT` branch, redirect to auth |
| N-4 | Collaboration asset upload and download | `storage.from` (4 sites) |
| N-5 | Realtime messaging — subscribe, receive, unsubscribe | `removeChannel`, `postgres_changes`, presence |
| N-6 | Authenticated REST reads and writes | `supaHeaders()` token attachment via `getSession` |
| N-7 | Phase 21.1 escaping spot-check | Confirms no regression from the base commit |

### 9.5 Optional harness

`analysis/phase-21.2/startup-verification.html`, following the Phase 21.1 precedent: fetch `index.html`, extract the guarded initialiser and `showStartupFailure()`, and drive them against synthetic globals — absent, `{}`, `{createClient: 'not a function'}`, a constructor that throws — asserting the resulting `startupFailure` code and DOM text each time. Unit-level only; it does not replace B-3.

### 9.6 Production post-merge checks

No PR preview environment exists (`.apos/PROJECT_CONTEXT.md`), so these run against `https://stagerz.app` immediately after deployment:

| # | Check |
|---|---|
| P-1 | View source: line 8 carries the pinned URL, `integrity`, `crossorigin` |
| P-2 | Network panel: the SDK returns 200 with `x-jsd-version: 2.112.1`, and is **not** blocked by an integrity error |
| P-3 | Console is free of `Failed to find a valid digest in the 'integrity' attribute` |
| P-4 | Cold load in a fresh profile reaches the auth screen |
| P-5 | Signed-in load reaches Stage; the boot screen clears |
| P-6 | One full magic-link sign-in against production |
| P-7 | Second browser or PoP confirms the same version is served — the drift measured in §4.2 no longer occurs |

### 9.7 Rollback procedure

| Situation | Action |
|---|---|
| Before commit | Discard the working tree by **file copy from a backup taken outside the repository** — never `git checkout`/`restore`/`stash` while uncommitted phase work is present (the Phase 21.1 hazard) |
| After commit, before push | `git reset --hard <base>` on the phase branch. `main` is untouched |
| **After merge to `main`** — production is broken | `git revert -m 1 <merge-commit>` on `main`, then push. GitHub Pages redeploys automatically. This restores line 8 to the floating `@2` and removes the boot screen and all guards in one step |
| Production broken by the pin alone, everything else fine | Minimal forward fix: change line 8 back to `@2` and drop `integrity`/`crossorigin`, keeping the fallback screen and guards. **Requires the same approval as any other production release** |

Rollback is a **production release** and is subject to `.apos/VALIDATION_STANDARD.md` §8. Deployment latency is GitHub Pages' publish time; the repository records no SLA for it.

---

## 10. Scope boundaries

Explicitly **excluded**, per the phase brief. Each is recorded rather than silently dropped.

| Excluded | Note |
|---|---|
| Content-Security-Policy | Absent from the application; recorded by Phase 20.7 and by Phase 21.1 §11. A separate phase |
| Service workers | Not present; not proposed |
| Offline mode | The failure screen reports a failure; it does not make the app work offline |
| Backend changes | None. No Supabase project setting is touched |
| Auth redesign | `checkSessionAndStart()` logic, `signInWithOtp`, `emailRedirectTo` and the magic-link flow are unchanged |
| Supabase schema / RLS | Untouched |
| General error-handling refactor | Only the three top-level statements at 964, 1312 and 5020 are guarded. The ~139 other functions are not touched, and no global `window.onerror` handler is proposed — Phase 20.7 item **M-9** stays open |
| Application modularization | Single-file architecture retained. No build step, bundler, framework or module system |

Additional non-goals established by the analysis itself:

| Non-goal | Reason |
|---|---|
| `defer` / `async` on line 8 | Would invert execution order against the inline script and break line 964 on every load — §6.1 |
| Self-hosting the SDK in the repository | A larger decision about vendoring; not required to close C-2 |
| A second CDN as automatic fallback | Two loader paths, two hashes, more failure modes than it removes |
| Retry-initialization button | Cannot recover the dominant failure mode — §7 |
| Removing the Google Fonts `@import` | Also render-blocking (line 10) but never blank-screening; unrelated to C-2 |

---

## 11. Unresolved questions

**Superseded by §0.** All except Q-5 were answered on 2026-08-06; the table below is preserved as written before approval. Q-5 remains open.

| # | Question | Why it matters |
|---|---|---|
| **Q-1** | **Which exact version to pin?** The Phase 20.7 instruction — "pin to the version currently resolved in production" — is **unsatisfiable as written**: production is currently serving at least two different versions to different users, and neither matches the 2.111.0 that Phase 21.1 validated against (§4.2). This document proposes **2.112.1** as the newest and the resolver's own answer, but that is a proposal, and it means the pinned version is one *nobody* has yet validated | Determines the exact URL and hash |
| **Q-2** | Should the SRI hash be **regenerated at implementation time**? Strongly recommended — this document's hash was measured on 2026-08-05 and is evidence, not an approved artefact | Wrong hash = total outage (R2) |
| **Q-3** | Is the **script-position change** (§6.7) in scope? It is the only change that closes F11 and fully resolves M-12, but it moves an existing line rather than adding one | Determines whether M-12 can be reported closed |
| **Q-4** | Is the **watchdog** (§6.6) in scope, and is 10 s the right threshold? | Determines whether F2/F9/F10 get a message or just a splash |
| **Q-5** | What process keeps the pin current? Pinning converts silent drift into a **standing maintenance obligation**, and this repository has no dependency-update process, no CI, and no lockfile. Without one, the pin will quietly age | An indefinitely stale SDK is its own risk, traded for the one being removed |
| **Q-6** | Exact **user-facing copy** and whether the boot screen should carry any branding beyond the wordmark — a product-owner decision, not a technical one | Text appears on every load |
| **Q-7** | Should `showStartupFailure()` distinguish `sdk-unavailable` from `client-init-failed` in the visible text at all, or show one message for both? More detail helps diagnosis; less detail is simpler and leaks nothing | Minor, but decide before implementing |

---

## 12. Summary

**Objective.** Close Phase 20.7 item **C-2**: remove the permanently-blank-page startup failure and replace the floating CDN dependency with an exact, integrity-checked version.

**What was found.** The startup path has exactly three top-level statements — `createClient()` at `index.html:964`, `onAuthStateChange` at 1312, and the `DOMContentLoaded` registration at 5020 — and **none of them is guarded**. Because the vendor bundle binds `var supabase`, a CDN failure leaves the identifier undeclared, so line 964 raises a `ReferenceError` that aborts the single 4,000-line inline script before any function is defined. No screen carries `active` in the static markup (0 of 20), `.screen{display:none}` is the default, and the first `active` is added by `goTo()` — which never runs. The result is a permanently black page with no message and no recovery. Eleven distinct failure points were enumerated (F1–F11); six produce that black page today, and there is no `try/catch`, no `onerror`, and no global error handler anywhere on the path.

**What was measured.** The floating dependency is worse than unpinned — it is **non-deterministic across users**. On 2026-08-05, jsDelivr's resolver reported `@2` → 2.112.1 while the Frankfurt edge was actually serving **2.112.0** (`x-cache: HIT`, `age: 34115`), and Phase 21.1 validated against **2.111.0** the day before. Three versions in two days, with two live simultaneously. This makes SRI impossible on the current URL and makes the Phase 20.7 instruction "pin to the version currently resolved in production" unsatisfiable as written — raised as **Q-1**.

**What is proposed.** Pin to `@2.112.1` with `integrity` (SHA-384, measured and recorded) and the mandatory `crossorigin='anonymous'`; add a 21st `.screen` carrying `active` in the static markup, which the existing `goTo()` deactivates automatically with no new teardown code; guard `createClient()` behind a `typeof` check and a `try/catch` that sets an explicit `startupFailure` code; guard the `onAuthStateChange` registration and the `DOMContentLoaded` body; and show a fixed, human-readable message via `textContent` with a single **Reload** control. Retry-initialization is evaluated and **rejected** — it cannot recover the dominant failure mode, because a script that never loaded leaves a global that will never appear. Two additions are marked separable: a watchdog in its own `<script>` element, and moving the SDK tag below the boot markup, which is the only change that closes the cold-start blank window on the normal path. The implementation order is binding: **fallback first, guards second, pin and hash last** — otherwise a wrong hash produces exactly the blank page this phase exists to remove.

**Validation.** 14 static invariants, 10 browser tests, 7 normal-path regressions across the 12 `supabaseClient` call sites, 7 production post-merge checks, and a four-case rollback. SDK failure is simulated by **DevTools request blocking, with no edit to the repository** — deliberately avoiding the temporary-source-edit hazard that Phase 21.1 had to build a `pre-commit` marker hook and SHA-256 verification to contain.

**Status.** Analysis only. No application code changed. Seven questions remain open, of which **Q-1** — which version to pin, given that no candidate matches what was last validated — must be answered before implementation begins.
