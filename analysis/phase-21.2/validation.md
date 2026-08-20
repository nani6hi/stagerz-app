# Phase 21.2 — Validation Record

**Branch:** `phase-21.2-startup-resilience`
**Base commit:** `780d6f92263d51874d660fff53801899f4fff2de`
**Validation level:** 3 (behaviour change in `index.html`, per `.apos/VALIDATION_STANDARD.md` §2)
**Status:** Implementation complete, including the approved **D-1 fix**. Static, headless, browser and authenticated-regression validation **all executed and passing**. **B-1…B-12: 12/12 PASS. N-1…N-7: 7/7 PASS against a real magic-link session. D-1 found, approved, fixed and re-verified. Risk R1 closed for 11 of the 12 `supabaseClient` call sites.**

> **PRE-MERGE LEVEL 3 IS COMPLETE.** The only outstanding items are production **P-1…P-7**, which cannot run before deployment, and `storage.remove` ([4836](../../index.html#L4836)), an error-cleanup path deliberately not manufactured.

**The only source change beyond the approved implementation is the approved D-1 fix (§8.4). No source was changed during any validation run.** Not committed. Not pushed.

---

## 1. Pre-edit verification gates

All four gates required by the approved prompt were checked **before** any edit was made.

| Gate | Expected | Measured | Result |
|---|---|---|---|
| Branch | `phase-21.2-startup-resilience` | `phase-21.2-startup-resilience` | PASS |
| HEAD | `780d6f9` | `780d6f92263d51874d660fff53801899f4fff2de` | PASS |
| `index.html` unchanged | identical to HEAD | `git status --porcelain index.html` empty; `git diff HEAD -- index.html` empty | PASS |
| Working-tree SHA-256 of `index.html` at start | — | `21d57a30cee71dd32589337c6c427ef49b3f8356e3ab65a7c9079571ba78b2fa` | recorded |

`.apos/PROJECT_CONTEXT.md` was **already modified in the working tree before this session began** (the Phase 21.2 analysis entry). That pre-existing modification was not made by the implementation step and is not part of the code change.

---

## 2. Dependency verification (Q-1 / Q-2)

The SRI hash was **recomputed immediately before editing**, not copied from `phase-definition.md`, and verified from two independent downloads using two independent hash implementations.

| Property | Value |
|---|---|
| Pinned URL | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.1/dist/umd/supabase.js` |
| Version | **2.112.1** |
| Size | **210,842 bytes** |
| **SHA-384 (SRI)** | `0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV` |
| **SHA-256** | `ed01c1c20daec4e06a08dbbf4fdc7d4a613091f7032a408faee2d6df45acad58` |
| Measured | 2026-08-06 |

**Two independent sources, cross-checked:**

| Source | Client | Hash tool | Bytes | SHA-384 | SHA-256 |
|---|---|---|---|---|---|
| Download A | `curl` | OpenSSL + `sha256sum` | 210,842 | as above | as above |
| Download B | .NET `WebClient` | .NET `SHA384`/`SHA256` | 210,842 | as above | as above |

`Compare-Object` on the two byte arrays reported **zero differences** — the downloads are byte-identical.

**Self-identification confirmed (Q-2):**

- Embedded client-header constant inside the bundle: `supabase-js/2.112.1`
- HTTP response header: `x-jsd-version: 2.112.1`, `x-jsd-version-type: version`

**SRI enforceability confirmed:** the response carries `access-control-allow-origin: *` and `cross-origin-resource-policy: cross-origin`, so a CORS-enabled request succeeds and `integrity` can be enforced. `Cache-Control: public, max-age=31536000, immutable` confirms the pinned bytes are contractually stable.

Both recorded hashes match the values in `phase-definition.md` §6.1 exactly. That document's hash was evidence, not an approved artefact; this recomputation is the artefact.

---

## 3. What changed

Four files touched in total. **Exactly one is application code.**

| Path | Change |
|---|---|
| `index.html` | **Modified** — 138 insertions, 17 deletions (`git diff --numstat`); 5,028 → 5,149 lines. Includes the approved D-1 fix |
| `analysis/phase-21.2/validation.md` | **Created** — this document |
| `analysis/phase-21.2/static-check.sh` | **Created** — 56 static invariants |
| `analysis/phase-21.2/startup-failure-harness.html` | **Created** — browser harness |
| `analysis/phase-21.2/phase-definition.md` | **Updated** — approved decisions recorded |
| `.apos/PROJECT_CONTEXT.md` | **Updated** — phase status (already dirty pre-session) |

### 3.1 The five edits to `index.html`, in the binding order of §6.8

| # | Location | Edit |
|---|---|---|
| 1 | after `<body>` (was 288) | Boot screen `#screen-boot` added, carrying `class="screen active"` |
| 2 | was 964 | `createClient()` replaced by the guarded initialiser; `showStartupFailure()` added beside it |
| 3 | was 1312 | `onAuthStateChange` registration wrapped in `if(supabaseClient){…}` **and, per the approved D-1 fix, in a `try/catch` setting `startupFailure`**; **callback body unchanged** |
| 4 | was 5020 | `DOMContentLoaded` body checks `startupFailure` first, then runs inside `try/catch` |
| 5 | was 8 → now 1007 | SDK tag removed from `<head>`, re-added after the boot markup and immediately above the application script, pinned with `integrity` + `crossorigin` |

The pin (edit 5) was applied **last**, so that a wrong hash would have presented as the readable failure screen built in edits 1–4 rather than as the blank page this phase exists to remove.

---

## 4. Startup sequence, before and after

### 4.1 Before (at `780d6f9`)

| # | Step | Line | Visible? |
|---|---|---|---|
| 1 | `<head>` parsing begins | 1–7 | black |
| 2 | **SDK requested — render-blocking, floating `@2`, no SRI, no failure path** | **8** | black |
| 3 | `<style>` parsed (incl. blocking Google Fonts `@import`) | 9–286 | black |
| 4 | `<body>` parsed — **20 `.screen` divs, none `active`** | 288–958 | black |
| 5 | Inline script begins | 960 | black |
| 6 | **`var supabaseClient = supabase.createClient(…)` — unguarded** | **964** | black |
| 7 | ~139 function declarations evaluate | 966–5018 | black |
| 8 | **`onAuthStateChange(…)` — unguarded top level** | **1312** | black |
| 9 | `DOMContentLoaded` listener registered | 5020 | black |
| 10 | `await getSession()` | 1300 | black |
| 11 | **`goTo()` adds `active` — first visible pixel** | **1331** | first paint |

Steps 1–10 render a black viewport. Any failure at 2, 6 or 8 aborts the single inline script and the page stays black permanently.

### 4.2 After

| # | Step | Line | Visible? |
|---|---|---|---|
| 1 | `<head>` parsing begins — **no script tag in `<head>`** | 1–289 | black |
| 2 | `<style>` parsed (Google Fonts `@import` still blocking) | 11–288 | black |
| 3 | `<body>` parsed — **`#screen-boot` carries `active`** | **303–311** | **branded boot screen paintable** |
| 4 | Remaining 20 screens parsed | 313–1005 | boot screen |
| 5 | **SDK requested — pinned 2.112.1, SRI, crossorigin** | **1007–1009** | boot screen visible during download |
| 6 | Inline script begins | 1011 | boot screen |
| 7 | `SUPA_URL`, `SUPA_KEY` assigned | 1013–1014 | boot screen |
| 8 | **Guarded initialiser** — `typeof` check + `try/catch` | **1030–1042** | boot screen |
| 9 | `showStartupFailure()` declared | 1049–1055 | boot screen |
| 10 | ~139 function declarations evaluate | — | boot screen |
| 11 | **`onAuthStateChange` — guarded by `if(supabaseClient)`** | **1407–1420** | boot screen |
| 12 | `DOMContentLoaded` registered | 5123 | boot screen |
| 13 | Init: `startupFailure` checked, then `try/catch` | 5124–5134 | boot screen |
| 14 | `await getSession()` in `checkSessionAndStart()` | 1391 | boot screen |
| 15 | `goTo()` clears boot screen, activates the real screen | **1424–1446** | app UI |

**The black viewport is gone from every step.** On failure the sequence stops at 12 with the boot screen carrying the message and the Reload control.

---

## 5. Failure paths — every one enumerated in §4.5 of the phase definition

| # | Failure | Before | After | Closed by |
|---|---|---|---|---|
| **F1** | SDK request fails (offline, DNS, CDN outage, proxy, ad-blocker) | permanent black page | boot screen + fixed message + Reload | guarded initialiser → `sdk-unavailable` |
| **F2** | SDK request times out / hangs | black page, then F1 | **boot screen with "Starting…"** — no message, no Reload | partial: splash only. Q-4 excluded the watchdog |
| **F3** | SDK loads but exposes no `supabase` global | permanent black page (`ReferenceError`) | boot screen + message + Reload | `typeof supabase === 'undefined'` |
| **F4** | Global exists, wrong shape / `createClient` missing | permanent black page (`TypeError`) | boot screen + message + Reload | `typeof supabase.createClient !== 'function'` |
| **F5** | `createClient()` itself throws | permanent black page | boot screen + message + Reload | `try/catch` → `client-init-failed` |
| **F6** | **SRI hash mismatch** (introduced by this phase) | n/a | identical to F1 | script never executes → `sdk-unavailable` |
| **F7** | `onAuthStateChange` registration throws | permanent black page | boot screen + fixed message + Reload | `if(supabaseClient){…}` for a null client, **plus a `try/catch` for a throwing registration — added by the D-1 fix, §8.4** |
| **F8** | Sync throw in `buildStageFeed`/`renderArtists`/`renderWanted` | permanent black page | boot screen + message + Reload | `try/catch` → `init-failed` |
| **F9** | `getSession()` hangs, never settles | black page indefinitely | **boot screen with "Starting…"** | partial: splash only. Q-4 excluded the watchdog |
| **F10** | Syntax error anywhere in the inline script | permanent black page | **boot screen with "Starting…"** | partial: splash only — guards inside the block cannot help |
| **F11** | Slow SDK download | black page for the whole download | boot screen throughout | SDK tag moved below the boot markup (Q-3) |

**Fully closed: F1, F3, F4, F5, F6, F7, F8, F11.** F7 was closed by the D-1 fix, approved after browser testing showed the original `if(supabaseClient){…}` guard covered only the null-client case (§8.4).
**Reduced from black page to branded splash: F2, F9, F10** — the user sees "Starting…" indefinitely rather than a black void, but gets no message and no Reload control. This is the accepted consequence of Q-4 excluding the watchdog, and is now the phase's only residual startup gap.

**`getSession()` rejection** (as opposed to hanging) is handled by the pre-existing `try/catch` inside `checkSessionAndStart()`, which routes to `goTo('authemail')`. That clears the boot screen and shows the sign-in screen — visible and recoverable, not a black page. That function was **deliberately not modified** and is verified byte-identical to base (check S-36).

---

## 6. Static invariants — `analysis/phase-21.2/static-check.sh`

```
bash analysis/phase-21.2/static-check.sh
```

**RESULT: 57 passed, 0 failed, 0 skipped — ALL STATIC INVARIANTS HOLD** (re-run after the D-1 fix; S-23b is the invariant that fix added)

| Group | Checks | Result |
|---|---|---|
| 1. Dependency pinned, integrity-checked, CORS-enabled | S-1…S-8 | 8/8 PASS |
| 2. Boot screen active in static markup | S-9…S-16 | 9/9 PASS |
| 3. Startup guarded | S-17…S-25 (incl. **S-23b**) | 10/10 PASS |
| 4. Failure text leaks nothing | S-26…S-29 | 9/9 PASS |
| 5. Scope boundaries not crossed | S-30…S-40b | 16/16 PASS |
| 6. Structural integrity | S-41…S-42 | 4/4 PASS |
| 7. Live asset verification (network) | S-43…S-47 | 5/5 PASS |

Invariants worth calling out:

- **S-1** — zero occurrences of the floating `supabase-js@2/` specifier remain.
- **S-5** — the SDK tag carries neither `defer` nor `async` (decision 6). Adding either would invert execution order against the inline script and break `createClient()` on every load.
- **S-7 / S-8** — position asserted numerically: `</head>` at 289, boot markup at 303, **SDK tag at 1007**, application script at 1012. The tag is after the boot markup and before the app script, exactly as decision 5 requires.
- **S-15 / S-15b** — the boot screen carries exactly one control, and **zero** references to `supabaseClient`. This is the machine-checked form of the §6.3 invariant.
- **S-23b** — added by the D-1 fix: the `onAuthStateChange` registration must sit inside both the null check **and** a `try/catch` that sets `startupFailure`. Prevents a silent regression of D-1.
- **S-29** — exactly one fixed literal message (Q-6/Q-7).
- **S-30…S-34** — no watchdog, no `window.onerror`, no `unhandledrejection`, no CSP, no service worker. The excluded scope is asserted, not merely intended.
- **S-35…S-38** — `goTo()`, `checkSessionAndStart()`, `enterApp()` and the `onAuthStateChange` **callback body** are compared against `git show 780d6f9:index.html` and are **byte-identical** (the callback body modulo its added indentation level).
- **S-43…S-47** — the live asset's SHA-384 and SHA-256 match the `integrity` attribute and this record, and `x-jsd-version` is `2.112.1`.

### 6.1 Two checker defects found and fixed

The first run reported 5 failures. Four were defects in the checker, one was a counting artefact — **none was a defect in `index.html`**:

1. Three `awk` range anchors containing `/` characters (`^// --- NAVIGATION ---$`, `^</div>$`) were syntax errors. The `region()` helper now escapes forward slashes.
2. **Counting artefact, the Phase 20.5 precedent.** Raw counts of `crossorigin='anonymous'` (2) and `supabaseClient.` (14) were inflated by the explanatory comments added by this phase. The executable counts are **1** and **12** — unchanged from base. Both checks now match the executable form only (`crossorigin='anonymous'></script>` and `supabaseClient\.[a-zA-Z_]`), and S-40 asserts the count is exactly 12 in both base and current.

This is the same phenomenon `.apos/PROJECT_CONTEXT.md` records for `haptic(` in Phase 20.5: comments mention identifiers, so raw greps conflate prose with code.

---

## 7. Headless guard verification — executed

The guarded initialiser was extracted from the live `index.html` and driven against synthetic globals, covering the failure modes network blocking cannot produce (F4, F5). No Node or Python is available in this environment, so the run used Windows Script Host.

```
cscript //Nologo verify-guards.js index.html
```

**RESULT: 42 passed, 0 failed**

| Group | What was proven |
|---|---|
| 0. Extraction | The guarded block was located and extracted from the live source (1,071 chars) — the test cannot drift from the code it verifies |
| 1. Healthy path | `startupFailure` stays `null`, `supabaseClient` is the created client, **no `console.error`**, boot message untouched, Reload stays hidden |
| 2. SDK absent (F1/F3/F6) | `sdk-unavailable`; `supabaseClient` stays `null`; **no `ReferenceError` escaped** — verified with `supabase` genuinely undeclared, not merely `undefined` |
| 3. Wrong shape (F4) | `{}`, `createClient` as string, as number, global `null`, global `undefined` → all `sdk-unavailable` |
| 4. Constructor throws (F5) | `client-init-failed`; `supabaseClient` stays `null`; exactly one `console.error`; a bare non-`Error` throw is handled identically |
| 5. Failure text | All four codes render the **same fixed message** (Q-7 confirmed). The text contains none of: the URL sentinel, the key sentinel, `SENTINEL`, `jsdelivr`, `supabase`, `Error`, `boom`, `undefined`, `null`, `stack`, or the machine code itself |
| 6. Defensive | `showStartupFailure()` does not throw when the boot nodes are absent |

Rendered message, confirmed identical for every code:

> `STAGERZ could not start. Please check your connection and reload.`

`SUPA_URL` and `SUPA_KEY` were replaced with unmistakable sentinels for the run, so any leak into user-visible text would be conclusive. **No leak occurred.**

`analysis/phase-21.2/startup-failure-harness.html` is the browser form of the same suite, with one addition a browser can enforce and WSH cannot: the DOM stub **throws if `innerHTML` is ever written**, so the "textContent, never innerHTML" rule is enforced at run time as well as by grep. **It was subsequently executed in Edge — 48/48 pass, 0 failures** (B-8, §8.2).

---

## 8. Browser validation — EXECUTED 2026-08-06

### 8.1 Environment and method

| Item | Value |
|---|---|
| Browser | **Microsoft Edge (Chromium) 151.0.4129.59**, headless (`--headless=new`) |
| Chrome/Chromium | Not installed on this machine |
| Node / Python | **Not available** — no `http.server`, no Puppeteer/Playwright |
| Local server | `powershell -File scratchpad/server.ps1` — a `System.Net.HttpListener` static server on `http://localhost:8080/`, bound without administrator rights |
| URL map | `/repo/…` → the real working tree (**read-only, never written**); `/sim/…` → scratchpad copies; `/slow/sdk.js?ms=N` → the pinned SDK bytes after an artificial delay; `/flaky/sdk.js` → 404 on first request, real SDK after |
| Capture | `--dump-dom` (redirected to file) plus `--screenshot`, `--window-size=420,860`, `--virtual-time-budget` |
| Screenshot analysis | `System.Drawing`, sampling every 3rd pixel, classifying against the page background `#08080f` |

**DevTools request blocking was not available** (no interactive DevTools in headless, and no CDP client without Node). Two stronger substitutes were used instead:

- **Real network failure against the real file** — `--host-resolver-rules="MAP cdn.jsdelivr.net 127.0.0.1:9"` makes the CDN genuinely unresolvable. This runs against the **unmodified working-tree `index.html`**, which DevTools blocking also would.
- **Scratchpad copies** for everything requiring modified source, generated by `gen-sims.ps1`/`gen-extra.ps1`/`gen-paint.ps1`, which read the working tree once and write only outside the repository.

**The working-tree `index.html` was never edited for validation.** Confirmed after every run: `git diff --numstat index.html` → `127  18`, unchanged from the implementation step.

Instrumentation note: sim copies carry two injected probes — an error recorder after `<body>` and a JSON collector before `</body>`. The `/repo/…` runs (B-1, B-3) are **uninstrumented** and were read by parsing the dumped DOM directly.

### 8.2 Results — B-series

**All results below were re-run against the post-D-1-fix `index.html` and are current.**

| # | Test | Method | Result |
|---|---|---|---|
| **B-1** | Normal cold load, no session | `/repo/index.html`, real pinned SDK, fresh profile | **PASS** — `screen-authemail` active, `screen-boot` cleared, 0 console errors, 10.6 % non-background pixels |
| **B-2** | Cold load with a session | Initially a stubbed client; **subsequently re-run with a genuine magic-link session during N-2** | **PASS** — `screen-stage` active, nav bar present, boot cleared, 0 errors, on both `F5` and `Ctrl+F5` cold loads with a real session |
| **B-3** | SDK blocked | **Real `index.html`**, `cdn.jsdelivr.net` mapped to a dead address | **PASS** — `screen-boot` stays active, fixed message shown, `bootActions` `display: block`, no uncaught `ReferenceError`, no blank page |
| **B-4** | SRI mismatch | Scratchpad copy, one character of the hash corrupted (`sha384-0x8…` → `sha384-1x8…`) | **PASS** — browser refused the script; `startupFailure='sdk-unavailable'`, `typeof supabase === 'undefined'`, identical presentation to B-3 |
| **B-5** | Reload recovers | `/flaky/sdk.js`: 404 on load 1, real SDK on load 2; RELOAD clicked programmatically | **PASS** — load 1 → failure screen; after the click, load 2 → `screen-authemail`, boot cleared, 0 errors |
| **B-6** | Reload with the fault persisting | Sim with a permanent 404, RELOAD clicked | **PASS** — load 2 returns the identical failure screen. No loop, no duplicated text, no stuck spinner, 0 errors |
| **B-7** | Session survives reload from the failure screen | Real magic-link session, SDK failed on demand via a local CONNECT proxy, recovered through the page's own RELOAD control — see §8.9 | **PASS** — during the failure `session key present: true`, `supabaseClient: null`, `startupFailure: sdk-unavailable`, fixed message, Reload shown, `leak check: CLEAN`, no black screen; after unblocking, RELOAD restored **Stage** with the nav bar and **no re-login** |
| **B-8** | `startup-failure-harness.html` | Served from `/repo/analysis/phase-21.2/`, extracting the guards from the live `index.html` | **PASS — 48/48**, 0 failures |
| **B-9** | `getSession()` rejects | Stubbed client returning a rejected promise carrying a sentinel-laden `Error` | **PASS** — boot cleared, `screen-authemail` shown; visible and recoverable, not black |
| **B-10** | Boot screen paints before the SDK arrives | Paint Timing A/B against a locally delayed SDK (8 s) | **PASS — decisive**, see §8.3 |
| **B-11** | The pinned version is the one executing | SRI enforcement A/B plus live-asset checks S-43…S-47 | **PASS** — correct hash executes (`typeof supabase === 'object'`), corrupted hash does not. SRI guarantees the executed bytes hash to the pinned SHA-384, which equals the 2.112.1 bytes |
| **B-12** | Slow but working connection | SDK served locally with a 3.5 s delay | **PASS** — app started normally, boot screen cleared. As Q-4 implies, the screen reads "Starting…" for the whole wait |

Every failure case above rendered **exactly** the fixed string, and the Reload control was present and visible:

> `STAGERZ could not start. Please check your connection and reload.`

| Case | `startupFailure` | `supabaseClient` | `typeof supabase` | Reload visible |
|---|---|---|---|---|
| F1 (404) | `sdk-unavailable` | `null` | `undefined` | yes |
| F3 (no global) | `sdk-unavailable` | `null` | `undefined` | yes |
| F4 (`{}`) | `sdk-unavailable` | `null` | `object` | yes |
| F4b (`createClient` not a function) | `sdk-unavailable` | `null` | `object` | yes |
| F5 (constructor throws) | `client-init-failed` | `null` | `object` | yes |
| F6 (SRI mismatch) | `sdk-unavailable` | `null` | `undefined` | yes |
| **F7 (registration throws)** — after the D-1 fix | `client-init-failed` | non-null | `object` | yes |

### 8.3 B-10 — cold-start paint, measured

The SDK was served locally with an 8-second delay, and First Contentful Paint was compared against the SDK's `responseEnd`, using the shipped layout versus the pre-fix layout (SDK returned to `<head>`, exactly where it sat at `780d6f9`).

| Layout | First Contentful Paint | SDK `responseEnd` | Painted before the SDK arrived? |
|---|---|---|---|
| **Shipped** (SDK in `<body>`, below the boot markup) | **224 ms** | 8,025 ms | **Yes — 7,801 ms earlier** |
| Pre-fix (SDK in `<head>`) | **8,064 ms** | 8,025 ms | No — paint waited for the download |

**This is the direct measurement that closes F11 and M-12.** The script-position change approved as Q-3 moves first paint from *after* the SDK download to 224 ms, independent of how slow the CDN is.

Screenshot pixel analysis, for the same claim in visual form:

| Frame | Non-background pixels | Interpretation |
|---|---|---|
| Empty page on `#08080f` (pre-fix analogue) | **0.00 %** | a black screen |
| Failure state, blocked CDN, real `index.html` | **4.60 %** | wordmark + message + Reload button |
| Normal load, auth screen | **10.60 %** | full auth UI |
| F7 stuck state, **before** the D-1 fix | **0.87 %** | wordmark + "Starting…" only — no message, no Reload |
| F7, **after** the D-1 fix | **4.60 %** | identical to every other failure screen |

**No tested failure state produced a black screen**, and after the D-1 fix no tested failure state produces a stuck splash either.

### 8.4 Defect found — D-1

> **D-1 — `onAuthStateChange` throwing is NOT closed by `if(supabaseClient){…}`, contrary to the F7 row in §5 as originally written.**

**Reproduced:** a client is created successfully, but `supabaseClient.auth.onAuthStateChange(…)` throws synchronously — the shape an incompatible or partial SDK build produces.

**Observed:** `Uncaught TypeError` escapes; the remainder of the inline script is abandoned; the `DOMContentLoaded` listener at line 5123 is never registered; the app is stuck on `#screen-boot` showing **"Starting…"** with **no message and no Reload control** (0.87 % non-background pixels). `startupFailure` is `null`, so `showStartupFailure()` is never reached.

**Why the guard misses it:** `if(supabaseClient)` only tests that the client is non-null. It does not protect the *call*. The §6.4 design assumed a non-null client implies a working `auth` surface.

**Severity — reduced, not eliminated, by this phase.** With the SDK now pinned and integrity-checked, the bytes are cryptographically fixed, so the SDK's shape cannot change under a user without the `integrity` attribute also failing (which is F6, and F6 *is* closed). D-1 becomes live again the moment the pinned version is bumped, which is exactly what Q-5 leaves unmanaged.

**Reported first, not improvised.** The implemented code matched approved design §6.4 exactly, so per `.apos/WORKFLOW.md` §"Stop-and-report rule" the defect was reported and no source was changed until a decision was made.

#### D-1 — APPROVED AND FIXED (2026-08-06)

Approved as being directly within Phase 21.2 startup-resilience scope, with the fix constrained to: wrap only the registration; reuse the existing `startupFailure` state and generic failure path; expose no raw error text; leave the callback body, normal-path auth behaviour, and the excluded scope untouched.

**Applied — the entire change:**

```diff
 if(supabaseClient){
-  supabaseClient.auth.onAuthStateChange(async function(event, session){
-    …callback body, unchanged…
-  });
+  try{
+    supabaseClient.auth.onAuthStateChange(async function(event, session){
+      …callback body, unchanged, re-indented one level…
+    });
+  }catch(e){
+    console.error('STAGERZ startup: onAuthStateChange registration failed', e);
+    startupFailure = 'client-init-failed';
+  }
 }
```

Six lines added (`try{`, `}catch(e){`, two body lines, `}`, and the closing brace shift). No new failure code, no new message, no new DOM node, no watchdog, no retry. `client-init-failed` is the code the `createClient`-throws path already uses, and `showStartupFailure()` renders one fixed message for every code, so the user-visible result is identical to the other failure paths.

**Verified after the fix** (`/sim/f7-onauth-throws/`, same simulation that exposed the defect):

| Field | Before the fix | After the fix |
|---|---|---|
| `startupFailure` | `null` | **`client-init-failed`** |
| Boot message | `Starting…` | **the fixed failure message** |
| `bootActions` display | `none` | **`block`** |
| Reload visible | **no** | **yes** |
| Uncaught errors | `Uncaught TypeError: …` | **none** |
| Non-background pixels | 0.87 % (stuck splash) | **4.60 %** — identical to F1 |
| `supabaseClient` | non-null | non-null (unchanged; the invariant is carried by `startupFailure`) |

**Regression check — every other path is byte-for-byte identical in behaviour:**

| Case | Active screen | `startupFailure` | Reload |
|---|---|---|---|
| Healthy | `screen-authemail` | `null` | hidden |
| F1 404 | `screen-boot` | `sdk-unavailable` | visible |
| F3 no global | `screen-boot` | `sdk-unavailable` | visible |
| F4 `{}` | `screen-boot` | `sdk-unavailable` | visible |
| F4b not a function | `screen-boot` | `sdk-unavailable` | visible |
| F5 constructor throws | `screen-boot` | `client-init-failed` | visible |
| F6 SRI mismatch | `screen-boot` | `sdk-unavailable` | visible |
| F9 `getSession` rejects | `screen-authemail` | `null` | hidden |

A new static invariant, **S-23b**, asserts the registration sits inside both the null check and a `try/catch` that sets `startupFailure`, so D-1 cannot silently regress.

### 8.5 Navigation and screen-load smoke test

Requirements 11 and 12 asked that existing auth, navigation, collaboration, wanted, assets, applicants and messaging paths still work. `goTo()` was driven across **every** screen in a copy of the real file, recording activation and uncaught errors.

| Metric | Result |
|---|---|
| Screens in the document | 21 (20 application + `#screen-boot`) |
| Screens navigated | 20 |
| Activated successfully | **20 / 20** |
| Uncaught errors during the whole sweep | **0** |

Screens covered: `authemail, authwait, stage, search, wanted, famemaker, profile, editprofile, postwanted, wantedapplicants, mycollaborations, collaborationdetail, collaborationmessages, collaborationtasks, collaborationassets, collaborationcredits, board, content, artist, backstage`.

This confirms navigation is structurally unchanged and every screen — including the collaboration, wanted, applicants, assets and messaging screens — renders without throwing. **It does not confirm their authenticated data loads**, which is what N-4…N-6 cover and which remain unrun.

### 8.6 Secret- and error-leak scan

The rendered text of `#screen-boot` was extracted from every captured DOM dump and scanned for: `SIMULATEDLEAK`, `sb_publishable`, `kbnmkyvbwkuvcklywdhk`, `supabase.co`, `jsdelivr`, `TypeError`, `ReferenceError`, the three machine codes, `at Object`, and `.js:`.

**Result: 0 leaks in 19 dumps before the D-1 fix, and 0 leaks in 15 dumps after it.** The post-fix set includes the D-1 case itself, where the registration threw a `TypeError` whose message contained `SIMULATEDLEAK`; the rendered screen read only the fixed message and `RELOAD`.

The strongest case is F5, where `createClient` threw an `Error` whose message deliberately contained `SIMULATEDLEAK sb_publishable_SECRET https://kbnmkyvbwkuvcklywdhk.supabase.co`. The rendered boot screen read only:

> `STAGERZ  ·  STAGERZ could not start. Please check your connection and reload.  ·  RELOAD`

### 8.7 Authenticated regression N-1…N-7 — EXECUTED 2026-08-17

Required because the pin may change the SDK version relative to whatever floating build a given browser was previously served (risk R1). **All seven ran against a genuine magic-link session** on the live project `kbnmkyvbwkuvcklywdhk`, driven manually by the product owner and recorded only from observed output.

#### 8.7.1 How the session was obtained

`emailRedirectTo` is hardcoded to `https://stagerz.app` ([index.html:1329](../../index.html#L1329)), so the emailed link returns to **production**, not to the local build. Editing that line would be a source change and adding `localhost` to Supabase's redirect allow-list would be a backend change — both outside this phase's scope.

Resolved without either, using the implicit flow the client defaults to (no `flowType` option, and the bundle's defaults are `flowType: 'implicit'`, `detectSessionInUrl: true`): Supabase's `/auth/v1/verify` endpoint answers with a `302` whose `Location` carries the tokens in a URL fragment. `scratchpad/handoff.ps1` reads that header with `curl`, reconstructs the URL against `http://localhost:8080/repo/index.html`, and launches the browser in one motion — **601 ms end to end**, well inside the token lifetime. The link is read from an interactive prompt, so it never enters shell history, and no token value is printed.

Two failed attempts preceded this and are recorded because they shaped the method:

1. **A two-stage clipboard hand-off** left a human-speed gap; the access token expired in transit. Confirmed by direct measurement — `/auth/v1/user` returned **HTTP 403, "token is expired"** — with the fragment complete and all four required params present. Not an application fault.
2. **A consumed link.** The local server had stopped, so the exchange was wasted. `handoff.ps1` now pre-flights the server and refuses to touch the link if it is down.

#### 8.7.2 Results

| # | Area | Covers | Result |
|---|---|---|---|
| **N-1** | Magic-link sign-in end to end | `auth.signInWithOtp` (1329), `onAuthStateChange` `SIGNED_IN` (1416), `getSession` (1418) | **PASS** — hand-off in 601 ms, all four fragment params present, landed on Stage with the nav bar, no auth errors |
| **N-2** | Session restore on reload | `auth.getSession` (1064, 1368, 1391, 1418) | **PASS** — both `F5` and `Ctrl+F5` returned to Stage; `supabaseClient.auth.storage === window.localStorage` confirmed |
| **N-3** | Sign-out | `auth.signOut` (1351), `SIGNED_OUT` branch | **PASS** — `Signed out.` toast, email screen, and after reload: `sb key present: false`, `has session: false`, `realtime chan: null` |
| **N-4** | Collaboration assets | `storage.upload` (4800), `storage.download` (4855 explicit, 4691 preview) | **PASS** — upload succeeded and listed as an image; explicit download **byte-identical**, SHA-256 `c414cd0e…7ce77` matching the source exactly; inline preview rendered |
| **N-5** | Realtime messaging | `removeChannel` (4127), `postgres_changes` (4170), presence (4197) | **PASS** — channel `joined` on `realtime:collaboration-2a17b76a…`; an INSERT reached a second tab in 1–2 s with no reload; on leaving, both channel handles `null` and no `removeChannel failed` |
| **N-6** | Authenticated REST reads/writes | `supaHeaders()` token attachment via `getSession` (1064) | **PASS** — `session token used: true`, `is anon key: false`; own profile loaded; a profile write saved and survived a reload |
| **N-7** | Phase 21.1 escaping spot-check | No escaping regression from base | **PASS** — see 8.7.4 |

#### 8.7.3 Call-site coverage — 11 of 12

| Line | Call | Covered by |
|---|---|---|
| 1064 | `auth.getSession` (supaHeaders) | N-6 |
| 1329 | `auth.signInWithOtp` | N-1 |
| 1351 | `auth.signOut` | N-3 |
| 1368 | `auth.getSession` | N-2 / N-6 |
| 1391 | `auth.getSession` (checkSessionAndStart) | N-2 |
| 1416 | `auth.onAuthStateChange` | N-1, N-3 |
| 1418 | `auth.getSession` (SIGNED_IN branch) | N-1 |
| 4127 | `removeChannel` | N-5 |
| 4691 | `storage.download` (preview) | N-4 addendum |
| 4800 | `storage.upload` | N-4 |
| 4855 | `storage.download` (explicit) | N-4 |
| **4836** | **`storage.remove`** | **NOT COVERED** |

`storage.remove` at 4836 runs only as error cleanup when the metadata insert fails *after* a successful upload. That condition was not manufactured, so it is recorded as uncovered rather than claimed.

#### 8.7.4 N-7 detail, including one sub-test discarded as non-probative

- **Part A — the helper.** `escapeCollaborationHtml('<img src=x onerror=alert(1)>')` → `&lt;img src=x onerror=alert(1)&gt;`. **PASS.**
- **Part C — own Profile screen. DISCARDED, not counted as a pass.** The product owner correctly rejected it: `#profileRole` showed the setup-state string, so the payload was never rendered there. `loadMyProfile()` writes that element only when `myProfile.name` is truthy ([index.html:2270](../../index.html#L2270)), and even then via **`textContent`** — structurally incapable of HTML injection and therefore exercising none of Phase 21.1's escaping.
- **Part D — the real sink. PASS.** With `profiles.location` set to `<img src=x onerror=alert(1)>`, the participant row inside `openCollaboration()` — `#cdContent`, meta line built at [index.html:2967](../../index.html#L2967) from the value escaped at [index.html:2945](../../index.html#L2945) — rendered:

  ```
  "👤stgerz1@stgerz1 · 🎬 Filmmaker · <img src=x onerror=alert(1)>Owner"
  ```

  `payload as text: true`, `LIVE img[src="x"]: false`, `any img nodes: 0`, no alert. The zero `img` count independently re-confirms Phase 21.1's removal of `photo_url` from generated markup.

#### 8.7.5 Environmental finding — N-2 first attempt

N-2 initially failed: sign-in worked, but every reload returned to the email screen. Diagnosed from the bundle, not guessed. auth-js probes storage with

```js
br = () => { … try { localStorage.setItem(e,e); localStorage.removeItem(e); V.writable = true }
             catch { V.writable = false } … }
```

and on failure **silently** falls back to in-memory storage:

```js
this.persistSession ? (r.storage ? … : br() ? this.storage = globalThis.localStorage
                                            : (this.memoryStorage = {}, this.storage = ci(this.memoryStorage)))
```

The product owner's normal Edge profile denies `localStorage` (`SecurityError: Access is denied for this document`), so the session lived only in memory. **This behaviour is identical in 2.111.0 and is not a Phase 21.2 regression.** Re-run in a dedicated Edge profile (default settings, `localStorage` writable — verified before use), N-2 passed.

> **Observation for a future phase, outside this scope:** any STAGERZ user who blocks site data silently cannot stay signed in — no message, no explanation. The app has no detection or messaging for this. Pre-existing, unrelated to the pin, recorded rather than fixed.

#### 8.7.6 Verdict on risk R1

**No behavioural difference was found between 2.112.1 and the 2.111.0 baseline** across sign-in, session restore, sign-out, authenticated REST reads and writes, Storage upload/download/preview, realtime `postgres_changes`, presence, and channel teardown. Every failure encountered during this campaign was environmental or procedural, and each was traced to a cause in the SDK source or the browser configuration before being dismissed. **Risk R1 is closed for the 11 covered call sites** and remains open only for `storage.remove`.

### 8.8 B-7 method — toggleable failure with the browser left open

B-7 was the last outstanding browser test because it needs two conditions **simultaneously**: a live authenticated session, and an SDK failure that can be *removed* without restarting the browser — otherwise the page's own RELOAD control cannot be the thing under test.

The Edge build on this machine has **no DevTools "Network request blocking"** panel (`Ctrl+Shift+P → blocking` returns no command), so the originally planned method was unavailable.

Resolved with `scratchpad/proxy.ps1`, a local HTTP **CONNECT** proxy that Edge is pointed at via `--proxy-server=http://127.0.0.1:8888`, with `--proxy-bypass-list=<local>;localhost;127.0.0.1` so the local server stays directly reachable and `--disable-quic` so nothing sidesteps the proxy. Mode is read per request from a control file:

- `allow` — every host is tunnelled as a **raw byte relay**, so TLS stays end-to-end and Subresource Integrity still validates
- `block` — only `*jsdelivr*` receives `502 Bad Gateway`; every other host still tunnels

Verified before use, independently of the browser:

| Mode | jsDelivr | SHA-384 of the relayed bytes | Google Fonts |
|---|---|---|---|
| `allow` | HTTP 200, 210,842 bytes | **matches the pinned SRI hash** | 200 |
| `block` | `CONNECT tunnel failed, 502` | — | **200** (unaffected) |

and then end-to-end against the real app headlessly: `allow` → `screen-authemail`; `block` → `screen-boot` with the fixed failure message and Reload revealed.

Because the block is toggled outside the browser, the session, the profile and the open page all survive the transition — which is exactly what B-7 needs. **No source was modified**; `index.html` was served unchanged from the working tree throughout.

One practical detail worth recording: the SDK is served `Cache-Control: immutable, max-age=31536000`, so **DevTools → Network → Disable cache** must be ticked or the browser serves it from cache and the block never bites.

### 8.9 Production post-merge checks — NOT RUN

No PR preview environment exists, so these run against `https://stagerz.app` after deployment.

| # | Check |
|---|---|
| P-1 | View source: pinned URL, `integrity`, `crossorigin` present; SDK tag in `<body>`, not `<head>` |
| P-2 | Network: SDK returns 200 with `x-jsd-version: 2.112.1`, not blocked by an integrity error |
| P-3 | Console free of `Failed to find a valid digest in the 'integrity' attribute` |
| P-4 | Cold load in a fresh profile reaches the auth screen |
| P-5 | Signed-in load reaches Stage; boot screen clears |
| P-6 | One full magic-link sign-in against production |
| P-7 | Second browser or PoP serves the same version — the §4.2 drift no longer occurs |

---

## 9. Unresolved concerns

1. **F2, F9 and F10 still present as an indefinite "Starting…" splash.** Q-4 excluded the watchdog, so a hang, a never-settling `getSession()`, or a syntax error in the inline block gives the user a branded screen with no message and no Reload control. This is a deliberate, approved trade — strictly better than the black page, but **not a closed failure path**, and now the only residual startup gap. Worth weighing when Q-4 is revisited: a watchdog is the only remaining mechanism that would surface a Reload control for a failure the guards cannot observe, which is exactly the class D-1 belonged to before it was caught.
2. **The pin creates a standing maintenance obligation with no process behind it (Q-5, unanswered).** There is no lockfile, no CI, and no dependency-update process. The pin will silently age, and 2.112.1 will eventually be an old SDK. This trades silent drift for silent staleness.
3. ~~**2.112.1 is a version nobody has validated against this app.**~~ **Closed by §8.7.** N-1…N-7 ran against a real authenticated session and found no behavioural difference from the 2.111.0 baseline at 11 of the 12 call sites.
4. **The 12 `supabaseClient` dereference sites remain unguarded by design.** They are safe only because of the invariant that a failed startup never leaves the boot screen. Adding any control to `#screen-boot` that reaches `supabaseClient` would break it. S-15/S-15b guard this mechanically, but the invariant is a design property, not a language-enforced one. **Note that after the D-1 fix `supabaseClient` can be non-null while `startupFailure` is set** — the invariant is now carried by `startupFailure` alone, not by the client being null.
5. **`storage.remove` ([index.html:4836](../../index.html#L4836)) is the one call site still uncovered.** It runs only as error cleanup when a metadata insert fails after a successful upload. Closing it would mean forcing an insert failure; that was judged not worth manufacturing, so it is recorded as uncovered rather than claimed.
6. ~~**B-7 is the one outstanding browser test.**~~ **Closed.** Run with a real session and an on-demand SDK failure via the local CONNECT proxy (§8.8): the session survived the failure state and the page's own RELOAD control restored Stage without re-login. B-2 is likewise a full pass, re-run with a real session during N-2. **B-1…B-12 are now 12/12.**
7. **The magic-link redirect is hardcoded to production** ([index.html:1329](../../index.html#L1329)), so authenticated local testing is only possible via the `curl` token hand-off documented in §8.7.1. Any future local authenticated testing inherits this constraint. Worth a decision in a later phase — an environment-aware `emailRedirectTo` would remove it, but that is a source change outside this scope.
8. **A user who blocks site data cannot stay signed in, silently** (§8.7.5). Pre-existing, unrelated to the pin, but surfaced by this campaign and worth a product decision.
9. **Browser testing used Edge, not Chrome or Firefox.** Edge is Chromium, so Chrome behaviour should match closely; Firefox and Safari have independent SRI and script-ordering implementations and were **not** tested.
10. **Headless is not identical to headed.** Paint timing, in particular, was measured headless; the ordering conclusion (paint at 224 ms vs 8,064 ms) is far too large a margin to be an artefact, but the absolute numbers are not user-facing measurements.
11. **`.apos/PROJECT_CONTEXT.md` was already modified before this session.** That pre-existing change is unrelated to the code edit and is carried in the same working tree.

---

## 10. Summary

The pre-edit gates passed: branch `phase-21.2-startup-resilience`, HEAD `780d6f9`, `index.html` byte-identical to HEAD. The SRI hash was recomputed from two independent downloads that proved byte-identical, and the asset was confirmed to self-identify as 2.112.1 both internally and via `x-jsd-version`.

`index.html` changed in five places, applied in the binding order — boot screen first, guards second, pin and hash last. The floating `@2` specifier is gone; the SDK is pinned to 2.112.1 with SHA-384 integrity and the mandatory `crossorigin='anonymous'`, moved out of `<head>` to sit after the boot markup and immediately above the application script, with neither `defer` nor `async`. A 21st screen carries `active` in the static markup and is cleared automatically by the existing `goTo()`, which is byte-identical to base. Three top-level statements that could each abort the whole script are now guarded, and one fixed message with a single Reload control is the only user-visible failure text.

**Eight of the eleven enumerated failure paths are fully closed (F1, F3, F4, F5, F6, F7, F8, F11). Three are reduced from a permanently black page to an indefinite branded splash** — F2, F9 and F10, by the approved exclusion of the watchdog. F7 was closed only after browser testing exposed **defect D-1**: the original `if(supabaseClient){…}` guard covered a null client but not a throwing registration, and the F7 row in §5 was wrong as first written. D-1 was reported rather than improvised, approved as in-scope, fixed with six lines reusing the existing `startupFailure` path, and re-verified.

57 static invariants pass, including byte-identical comparison of the four functions this phase must not have changed and the new S-23b guard against a D-1 regression. 42 headless guard assertions and 48 in-browser harness assertions pass against code extracted from the live source.

**Browser validation was executed in Microsoft Edge 151.0.4129.59 against a local `HttpListener` server.** B-1, B-3, B-4, B-5, B-6, B-8, B-9, B-10, B-11 and B-12 **PASS**; B-2 is a **partial pass** (stubbed session, not a real one); B-7 was **not runnable**. The blocked-CDN and normal-load cases ran against the **unmodified working-tree `index.html`**; everything requiring modified source used scratchpad copies, and `git diff --numstat index.html` remained `127 18` throughout. No tested failure state produced a black screen, and a scan of all 19 captured DOM dumps found **zero** leaked secrets, URLs, error messages, stacks, or machine codes. First Contentful Paint measured **224 ms** with the shipped layout against **8,064 ms** with the SDK returned to `<head>` — the direct measurement that closes F11 and M-12.

**All seven N-tests then ran against a genuine magic-link session** on the live project, driven manually and recorded only from observed output. N-1…N-7 all **PASS**, covering 11 of the 12 `supabaseClient` call sites: sign-in, session restore across both reload types, sign-out, authenticated REST read and write, Storage upload with a **byte-identical** download round-trip plus inline preview, realtime `postgres_changes` delivered to a second tab in 1–2 s, presence, and clean channel teardown. The Phase 21.1 escaping spot-check passed at the real `innerHTML` sink, with a stored `<img src=x onerror=alert(1)>` rendering as inert text and zero `img` nodes in the participant list.

**No behavioural difference from the 2.111.0 baseline was found. Risk R1 is closed for those 11 call sites**; `storage.remove` (4836) is an error-cleanup path that was not manufactured and stays uncovered. Every failure met along the way was environmental or procedural — an expired token, a consumed link, and an Edge profile that denies `localStorage`, causing auth-js to fall back silently to memory storage — and each was traced to its cause in the SDK source or the browser configuration before being dismissed. None implicated the pin.

**B-7, the last outstanding browser test, then passed.** With a real session live, the SDK request was failed on demand through a local CONNECT proxy (§8.8) — necessary because this Edge build has no DevTools request-blocking panel, and because the block had to be *removable* with the browser still open for the page's own RELOAD control to be the thing under test. During the failure the session key remained in `localStorage` while `supabaseClient` was `null`, the fixed message and Reload were shown, the leak scan was CLEAN, and there was no black screen. Unblocking and clicking RELOAD returned the user to Stage with the nav bar and **no re-login**.

**Pre-merge Level 3 is complete: 57/57 static invariants, 42/42 headless guard assertions, 48/48 in-browser harness assertions, 12/12 browser tests, 7/7 authenticated regressions.** The only remaining work is production **P-1…P-7**, which cannot run before deployment, plus `storage.remove` (4836), an error-cleanup path deliberately not manufactured. The only source change beyond the approved implementation is the approved D-1 fix; **no source was changed during any validation run**. No commit has been made and nothing has been pushed.
