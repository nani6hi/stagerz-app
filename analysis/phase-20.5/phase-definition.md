# Phase 20.5 — Evaluate and Isolate Telegram Runtime

**Branch:** `phase-20.5-telegram-runtime-isolation` (analysis/definition); implementation branch to be named separately
**Base commit:** `31dc073af588d1664d0991b98e6b0995d5174660` (`main`, merge of Pull Request #4)
**Status:** Analysis complete, scope defined. Implementation not started.

---

## 1. Current-state inventory

The entire Telegram runtime surface in the repository is **five lines**, plus a meta tag that is not Telegram-specific.

| # | Line | Type | Content |
|---|---|---|---|
| 1 | 8 | HTML | `<script src='https://telegram.org/js/telegram-web-app.js'></script>` |
| 2 | 962 | JS comment | `// --- TELEGRAM ---` |
| 3 | 963 | JS | `var tg = window.Telegram && window.Telegram.WebApp;` |
| 4 | 964 | JS | `if(tg){ try{tg.ready();}catch(e){} try{tg.expand();}catch(e){} }` |
| 5 | 965 | JS | `function haptic(t){ … }` — the wrapper |

Plus **28 `haptic(...)` call sites**. `haptic(` occurs **29 times** in `index.html`: **1 function definition** (line 965) plus **28 call sites** — the consumers.

**Line 5 — `<meta name='viewport' …>` — is NOT Telegram-specific.** It is a standard responsive-web meta tag required by every mobile browser. It must never be removed as part of Telegram work.

### Absent entirely

Verified zero occurrences across the repository: `initData`, `initDataUnsafe`, `themeParams`, `colorScheme`, `BackButton`, `MainButton`, `openTelegramLink`, `openLink`, `platform`, `setHeaderColor`, `setBackgroundColor`, `setBottomBarColor`, `safeArea`, Telegram viewport APIs, Telegram user objects, Telegram auth payloads.

**There is no Telegram identity, authentication, or data integration of any kind.**

---

## 2. Exact source locations

### SDK inclusion — line 8

```html
<script src='https://telegram.org/js/telegram-web-app.js'></script>
```

Classic, non-`defer`, non-`async`, loaded **before** the Supabase SDK (line 9) and before the inline application block (961–4973). Render-blocking by placement.

### Initialization — lines 962–964

```js
// --- TELEGRAM ---
var tg = window.Telegram && window.Telegram.WebApp;
if(tg){ try{tg.ready();}catch(e){} try{tg.expand();}catch(e){} }
```

### Haptic wrapper — line 965

```js
function haptic(t){ try{ if(tg&&tg.HapticFeedback){ if(t==='success'||t==='error'||t==='warning') tg.HapticFeedback.notificationOccurred(t); else tg.HapticFeedback.impactOccurred(t||'light'); } }catch(e){} }
```

### The 28 `haptic(...)` call sites

Lines 1253, 1322, 1341, 1930, 1967, 2035, 2053, 2131, 2353, 3101, 3238, 3258, 3278, 3299, 3566, 3586, 3826, 3846, 3879, 3897, 4458, 4478, 4658, 4848, 4868, 4901, 4943, 4954 — 28 distinct lines, one call each, totalling **28 calls**. One of them (1322) sits inline with other statements on its line but is still a single call. Together with the `haptic()` definition on line 965, that accounts for all **29** occurrences of `haptic(` in the file.

Argument distribution: `haptic('success')` ×26, `haptic('light')` ×1, `haptic('heavy')` ×1.

**The return value is never used** — no assignment, no `return haptic(...)`, no chaining. Every call is fire-and-forget.

Feature distribution: authentication (1253, 1322), navigation (1341), wanted posts (1930, 1967, 2035, 2053, 2131, 2353), collaborations (3101, 3238–3299), messaging (3566, 3586), tasks (3826–3897), assets (4458, 4478), credits (4658, 4848–4901), FameMaker (4943, 4954).

---

## 3. Dependency map

```
telegram-web-app.js (line 8, external CDN)
        │  defines window.Telegram
        ▼
tg = window.Telegram && window.Telegram.WebApp     (963)
        ├──► tg.ready() / tg.expand()               (964)  — Telegram-host viewport only
        └──► haptic(t)                              (965)  — reads tg.HapticFeedback
                     ▲
                     │  28 call sites across 9 feature areas
                     │  (auth, nav, wanted, collab, messaging,
                     │   tasks, assets, credits, famemaker)
```

**Critical structural fact:** `haptic()` is the **single point of contact** between the 28 call sites and Telegram. No call site touches `tg`, `window.Telegram`, or `HapticFeedback` directly. The boundary already exists in shape — it is simply not named, documented, or defensive.

### Cross-feature coupling — verified zero

Targeted search inside each function for `tg`, `telegram`, `initData`, `HapticFeedback`:

| Function | Telegram references |
|---|---|
| `sendOtp()` | 0 |
| `enterApp()` | 0 |
| `checkSessionAndStart()` | 0 |
| `getMyDomainId()` | 0 |
| `fetchMyProfile()` | 0 |
| `loadMyProfile()` | 0 |
| `goTo()` | 0 |
| `loadCollaborationMessages()` | 0 |
| `sendCollaborationMessage()` | 0 |

---

## 4. Risk analysis

| Item | Coupling | Risk if changed | Notes |
|---|---|---|---|
| SDK `<script>` (8) | Lightly coupled | **Low–medium** | Removing it makes `tg` permanently `undefined` — already the browser behavior. Risk is to Telegram *hosts*, not browsers |
| `tg` init (963) | Lightly coupled | Low | Short-circuits safely |
| `ready()` / `expand()` (964) | Lightly coupled | Low | Guarded by `if` + two `try/catch`; affects Telegram viewport only |
| `haptic()` wrapper (965) | **Deeply coupled — 28 call sites** | **High if removed** | Must survive Phase 20.5 entirely |
| 28 call sites | Deeply coupled | **High if removed** | Deferred to Phase 20.6 |
| Auth / Supabase / identity / navigation / messaging | **Not coupled** | — | Proven zero references |
| Telegram Mini App entry point | **Externally configured — UNKNOWN** | Unknown | Not inspectable from this repository |

---

## 5. Browser compatibility analysis

### Normal browser (desktop or mobile)

1. Line 8 fetches `telegram-web-app.js` from `telegram.org`. The script executes and defines `window.Telegram`.
2. Line 963: `window.Telegram && window.Telegram.WebApp` — outside Telegram, `WebApp` exists but is inert, or `window.Telegram` is undefined if the CDN fetch failed. Either way `tg` is falsy-or-inert; **no throw**.
3. Line 964: `if(tg)` skipped when falsy; when truthy-but-inert, `ready()`/`expand()` are wrapped in individual `try/catch`.
4. `haptic()`: `if(tg && tg.HapticFeedback)` fails or the call throws inside the `try` — **silent no-op** either way.

**Net effect in a normal browser: no visible behavior, no error, no product impact.**

### Telegram WebView

1. `window.Telegram.WebApp` is real. `tg` is truthy.
2. `ready()` signals the host the app is initialized; `expand()` expands the Mini App to full height. **These are the only two behaviors that visibly differ between environments.**
3. `haptic()` triggers real device haptics — unless the host version does not support the method.

### Known console warning

`Telegram.WebApp HapticFeedback is not supported in version 6.0` originates **inside the Telegram SDK**, not from `index.html`. It fires when `tg.HapticFeedback` **exists** but the host reports version 6.0. Line 965 guards on *existence*, not on *version support*. Cause: **version mismatch within a Telegram host** — not normal-browser execution, and not an incorrect guard.

### Failure modes when Telegram is unavailable

| Scenario | Behavior | Throws? |
|---|---|---|
| CDN blocked / offline | `window.Telegram` undefined → `tg` undefined | **No** |
| Normal browser | `tg` inert or undefined | **No** |
| SDK loads but `WebApp` missing | `&&` short-circuits | **No** |
| `ready()`/`expand()` throw | Caught individually | **No** |
| `HapticFeedback` missing or throws | Guarded + `try/catch` | **No** |

**No unguarded Telegram reference exists.** Every one of the three consumers is defended.

---

## 6. Required analysis conclusions

| Question | Conclusion |
|---|---|
| Exact dependency surface | 5 lines (8, 962–965) + 28 `haptic()` call sites (29 total `haptic(` occurrences = 1 definition + 28 calls) |
| Active runtime behavior | `ready()` and `expand()` **inside Telegram only**; haptics inside Telegram only |
| Cosmetic / optional | **All of it**, for the web app. Haptics are tactile polish; `ready()`/`expand()` are host viewport hints |
| Already guarded | **All three consumers** — `&&` short-circuit (963), `if` + 2× `try/catch` (964), `if` + `try/catch` (965) |
| Unguarded calls | **None** |
| Is SDK inclusion necessary? | **Not for the web app.** Necessary only if a Telegram Mini App entry point exists — **externally configured, unknown** |
| Is Telegram required for core STAGERZ functionality? | **No.** Authentication, identity, sessions, navigation, profile, wanted, messaging, tasks, assets, credits all contain zero Telegram references |
| Safest isolation boundary | **`haptic()` itself.** It is already the single choke point; Phase 20.5 formalizes it |
| Must remain untouched until 20.6 | The SDK script tag, `tg`, `ready()`, `expand()`, and all 28 call sites |

---

## 7. Recommended isolation design

**Principle: Reuse → Extend.** The boundary already exists as `haptic()`. Phase 20.5 **extends** it into an explicit, documented compatibility layer. No new pattern is created, and no call site changes.

The isolation must achieve four things without altering visible product behavior:

1. **Name the boundary.** A clearly marked Telegram-compatibility section containing every Telegram reference, so Phase 20.6 has an exact, contiguous deletion target.
2. **Single detection point.** Telegram availability determined once, in one place, rather than re-derived at each consumer.
3. **`haptic()` becomes platform-agnostic in contract.** Its documented contract becomes *"best-effort tactile feedback; silently does nothing when unavailable"* — a contract that stays true after Phase 20.6 removes Telegram entirely. The 28 call sites then need no knowledge of what backs it.
4. **Explicit no-op path.** The non-Telegram branch is intentional and documented, not incidental.

**Constraint:** the resulting code must behave **identically** in all three environments. Phase 20.5 is a structural clarification, not a behavior change.

---

## 8. Explicit Phase 20.5 implementation scope

Confined to `index.html`, lines 962–965 and their immediate surroundings:

- **In scope:** grouping the Telegram references into one clearly delimited compatibility block; documenting the boundary and the Phase 20.6 removal target in comments; making the availability check a single named detection; documenting `haptic()`'s platform-agnostic contract and its explicit no-op path.
- **Line count:** small — a structural regrouping plus comments. No logic change.
- **Behavior:** must remain byte-equivalent in effect. Normal browsers: no-op, as today. Telegram: `ready()`, `expand()`, and haptics unchanged.

**Out of scope for 20.5, explicitly:** removing the SDK script tag; removing `tg`, `ready()`, or `expand()`; removing or editing `haptic()`'s call sites; changing any of the 28 call sites; changing the arguments passed; replacing Telegram with another platform integration.

---

## 9. Explicit Phase 20.6 deferred-removal scope

Reserved for Phase 20.6 and **not** to be performed in 20.5:

- Remove the Telegram SDK script tag (line 8)
- Remove `window.Telegram` references
- Remove `tg`
- Remove `ready()`
- Remove `expand()`
- Remove `HapticFeedback` handling
- Remove **every** `haptic(...)` call — all 28 sites
- Remove the `haptic()` function
- Remove Telegram-specific comments and runtime logic

End state: no Telegram-specific runtime code in the full web app; Telegram preserved only as a documented future Light / Mini App concept; the app fully functional on normal browser and Supabase behavior alone.

**Phase 20.6 has a hard prerequisite that Phase 20.5 must answer first:** whether an external Telegram Mini App entry point exists and must keep working. That configuration is **not stored in this repository** and cannot be determined from it.

---

## 10. External configuration not stored in the repository

Documented as unknown rather than assumed:

- Whether a Telegram Bot / Mini App is registered pointing at `stagerz.app`
- Whether any BotFather menu button or web-app URL targets this application
- Whether real users currently open STAGERZ inside Telegram
- Telegram host version distribution (relevant to the HapticFeedback warning)
- Netlify build settings (no `netlify.toml` in the repository)
- Supabase dashboard configuration, including the magic-link redirect allow-list

**The first three are decision-blocking for Phase 20.6** and must be answered by the product owner, not inferred from code.

---

## 11. Verification plan

**Level 3**, on a Netlify deploy preview from the implementation branch's Pull Request.

Because Phase 20.5 changes no behavior, verification is primarily a **no-change proof**:

### Browser and parse
- Preview loads; inline JavaScript parses; no blocking startup error.

### Normal browser — desktop
- App loads; no new console error.
- Authentication: session restoration, normal login, magic-link login; no unintended redirect.
- Navigation across Stage, Wanted, FameMaker, Profile, Collaboration, Backstage.
- Messaging regression: optimistic send, reconciliation, edit, delete, message-load failure state.
- All 28 haptic-triggering actions still complete their primary effect (toast, navigation, save).

### Normal browser — mobile width
- Repeat layout and navigation checks; no overflow.

### Telegram WebView — *if an entry point exists*
- `ready()` and `expand()` still take effect; haptics still fire.
- If no entry point exists, record as **NOT VERIFIED** with the reason. **Do not create a Telegram bot solely to test.**

### Console and network
- No new error; no new Supabase failure.
- The existing HapticFeedback warning may remain and is outside Phase 20.5.

### Repository checks
- Only `index.html` and Phase 20.5 documentation changed.
- All 28 `haptic(...)` call sites byte-identical.
- No auth, Supabase, backend, or messaging code changed.

---

## 12. Rollback plan

Rollback is reverting the Phase 20.5 implementation commit. There are no backend or data migrations, no schema changes, no policy changes, and no external configuration changes. Because Phase 20.5 changes no behavior, rollback carries no user-visible consequence.

---

## 13. Non-goals

- Removing the Telegram SDK script
- Removing `tg`, `ready()`, or `expand()`
- Removing `haptic()` or any of its 28 call sites
- Fixing the HapticFeedback version warning
- Replacing Telegram with another platform integration
- Adding a new platform-abstraction framework
- Authentication, magic-link configuration, session storage, user identity
- Supabase, backend, schema, RPC, RLS, policies
- Hosting or deployment configuration
- Messaging behavior, loaders, message limit
- `photo_url` hardening
- The `<meta name='viewport'>` tag — standard responsive web, not Telegram
- Rewriting historical phase reports
- Registering or configuring a Telegram bot
- Starting Phase 20.6

---

## 14. Stop conditions

Stop and report rather than proceeding if any of the following occurs:

1. Implementation would require changing any of the 28 `haptic(...)` call sites.
2. Implementation would change behavior in any environment.
3. The isolation cannot be achieved without touching authentication, Supabase, or messaging.
4. Evidence emerges that a Telegram Mini App entry point exists and depends on current initialization order — this changes Phase 20.6's premise and must be recorded before continuing.
5. Removing or reordering the SDK script proves necessary to isolate — that is Phase 20.6 scope, not 20.5.
6. Any unguarded Telegram reference is discovered that this analysis missed.

---

## Summary

Telegram's runtime footprint is five lines plus a single wrapper function with 28 consumers. Every consumer is already guarded; nothing throws when Telegram is absent; and authentication, identity, navigation, and messaging contain zero Telegram references. Telegram is therefore an **optional enhancement, not a dependency**, for the web app — the only environment-specific behavior is `ready()`/`expand()` and real haptics inside a Telegram host.

Phase 20.5 extends the boundary that already exists — `haptic()` — into an explicit, documented compatibility block with a single detection point and a platform-agnostic contract, changing no behavior and no call site. Phase 20.6 then deletes that block and all 28 call sites, gated on one question this repository cannot answer: whether an external Telegram Mini App entry point exists.
