# Phase 20.4 — Remove Premature NACKL Integration

**Branch:** `phase-20.4-light-integration-analysis` (analysis/definition); implementation branch to be named separately
**Base commit:** `b49f0ce9e32ec7b0ba8e62224768fea2e0dd6a7a` (`main`, merge of Pull Request #3)
**Status:** Documentation defined. Implementation not started.

---

## 1. Phase title

**Phase 20.4 — Remove Premature NACKL Integration**

---

## 2. Problem statement

NACKL is present in the current full STAGERZ web application as isolated UI, CSS, and JavaScript, but it is **not part of the current product**.

Specifically:

- **Not part of the current full product.** NACKL was intended for a later, reduced STAGERZ Light version, after the real full app/web version is established.
- **Represented only by isolated UI, CSS, and JavaScript.** Twelve references in `index.html`: two CSS blocks, one Profile stat tile, one Backstage feature row, one call site, and one function.
- **Not backed by a real data source.** The counter is incremented by `Math.floor(Math.random()*3)+1`. There is no backend, database, Supabase, RPC, `localStorage`, timer, or external-configuration dependency of any kind.
- **Currently unstable.** `tickNACKL()` performs `nacklVal += …`, but **`nacklVal` is never declared** anywhere in the file. `+=` reads before writing, so the read of an undeclared identifier throws.
- **Causing a ReferenceError whenever Profile invokes the function.** `tickNACKL()` is called from `loadMyProfile()`, which runs on every Profile screen open, producing `ReferenceError: nacklVal is not defined` each time.
- **Misleading in Backstage.** The subscription feature list currently claims `NACKL mining tracked` — a promise the product does not keep, presented to users considering payment.

---

## 3. Product decision

- **NACKL is removed from the full web app.**
- **The concept is not rejected.** Removal is a scoping decision, not a rejection of the idea.
- **The concept remains deferred for a future STAGERZ Light version.**
- **No inactive NACKL runtime stub should remain in the full app.** Do not "fix" `nacklVal` by declaring it, do not hide the tile with CSS, and do not leave a disabled function behind. Removal means removal.
- **Historical documentation remains unchanged** where it records previous findings. Phase 20.1–20.3 validation reports and phase definitions describe what was true when written and must not be rewritten because the roadmap advanced.

---

## 4. Exact implementation scope

The future implementation must remove exactly these **six source areas** from `index.html`, and nothing else.

| # | Area | Line(s) at `b49f0ce` | Content |
|---|---|---|---|
| 1 | `.nackl-chip` CSS and its NACKL comment | 272–273 | `/* --- NACKL CHIP --- */` and `.nackl-chip{…}` |
| 2 | `@keyframes nackl-pulse` | 291–292 | `/* NACKL GLOW */` and the keyframe block |
| 3 | `#nacklCount` animation rule | 293 | `#nacklCount{animation:nackl-pulse 3s ease-in-out infinite;}` |
| 4 | Profile `#nacklCount` stat tile and NACKL label | 555 | The fourth `.p-stat` element |
| 5 | Backstage feature row | 957 | `<div class="bs-feature">…NACKL mining tracked</div>` |
| 6 | `tickNACKL()` call and the entire function | 2180, 4924–4928 | `tickNACKL();` inside `loadMyProfile()`, plus the function declaration |

**The CSS animation and selector must be removed together with the tile.** Areas 2 and 3 exist solely to animate the element defined in area 4; removing the tile without them leaves orphan CSS, and removing them without the tile leaves an un-animated element. Areas 2, 3, and 4 are a single unit.

Area 1 (`.nackl-chip`) is already dead — the class appears **zero times** in markup — and can be removed independently, but is included here so no NACKL trace remains.

Area 6 must remove **both** the call site and the function. Removing only one leaves either an unreachable function or a call to a missing function.

---

## 5. Expected resulting UI

### Profile

- **Three** statistics remain: **On Stage**, **Followers**, **Collabs**.
- Equal flex distribution — `.p-stats` is `display:flex` and `.p-stat` is `flex:1`, so three tiles reflow to fill the row.
- No blank fourth tile.
- No broken right border — `.p-stat:last-child{border-right:none}` resolves correctly against the new last tile.
- No NACKL label or value anywhere on the screen.

### Backstage

- No `NACKL mining tracked` claim.
- Remaining feature rows remain contiguous.
- No visual gap — the list is a simple vertical stack of `.bs-feature` elements.

### Console

- No `nacklVal is not defined` error after opening Profile repeatedly.

---

## 6. Dependencies and safety

NACKL is **isolated** from every one of the following. Each was verified by targeted search across the repository, not assumed:

- authentication
- Supabase sessions
- user identity
- navigation
- Wanted
- FameMaker
- Collaboration
- Messages
- Tasks
- Credits
- database state
- backend configuration

Additionally verified absent: no backend dependency, no database dependency, no Supabase dependency, no RPC dependency, no RLS or policy dependency, no `localStorage` dependency, no timer dependency, no external-configuration dependency.

`tickNACKL()` has **exactly one caller**. `#nacklCount` is referenced only by the CSS animation rule and by `tickNACKL()` itself. `.nackl-chip` is referenced by nothing.

**Consequence:** the removal cannot affect any other feature, and requires no backend or database knowledge to execute safely.

---

## 7. Acceptance criteria

Observable PASS/FAIL. No criterion may be satisfied by code inspection alone except where explicitly a repository check.

| # | Criterion | PASS |
|---|---|---|
| A1 | Zero case-insensitive NACKL occurrences in `index.html` | `grep -ic nackl index.html` returns 0 |
| A2 | No `nacklVal` | 0 occurrences |
| A3 | No `tickNACKL` | 0 occurrences |
| A4 | No `nacklCount` | 0 occurrences |
| A5 | No `.nackl-chip` | 0 occurrences |
| A6 | No `nackl-pulse` | 0 occurrences |
| A7 | No NACKL Profile stat | tile absent from the rendered Profile |
| A8 | No Backstage NACKL claim | feature row absent |
| A9 | Profile renders with three evenly distributed stats | On Stage / Followers / Collabs, equal widths |
| A10 | No layout gap at desktop width | no empty area, no broken border |
| A11 | No layout gap at mobile width | no overflow, no gap |
| A12 | Profile data still loads fully | name and role render as before |
| A13 | `loadMyWanted()` still executes | Wanted data appears on Profile |
| A14 | No new console error | clean apart from the known Telegram warning |
| A15 | Existing Telegram code is byte-identical | lines 8, 971–974 unchanged |
| A16 | `haptic()` and all existing call sites unchanged | function plus all 29 call sites byte-identical |
| A17 | Auth and session restoration unchanged | login and reload both work |
| A18 | Phase 20.1–20.3 messaging behavior unchanged | optimistic send, send guard, failed-send rollback, load-failure state all intact |

---

## 8. Runtime validation plan

**Level 3**, on a **Netlify deploy preview** built from the implementation branch's Pull Request.

### Browser and parse

- Preview loads.
- Inline JavaScript parses.
- No blocking startup error.

### Desktop

- Open Profile repeatedly.
- Verify three stats.
- Verify correct labels and values.
- Verify no empty area or broken borders.
- Verify no NACKL error.

### Mobile width

- Repeat Profile layout validation.
- Verify no overflow or gap.

### Backstage

- Verify the NACKL feature claim is absent.
- Verify remaining rows render normally.

### Authentication

- Existing session restoration.
- Normal login.
- Magic-link login.
- No unintended redirect.
- Supabase session remains valid.

### Regression

- Stage
- Wanted
- FameMaker
- Collaboration dashboard
- Messages
- Navigation
- Optimistic message send
- Reconciliation
- Edit
- Delete
- Message-load failure state

### Console and network

- No `nacklVal` ReferenceError.
- No new Supabase failure.
- The existing Telegram HapticFeedback warning **may remain** and is **explicitly outside Phase 20.4**.

---

## 9. Non-goals

Explicitly excluded from Phase 20.4:

- Telegram SDK
- Telegram initialization
- `tg`
- `ready()`
- `expand()`
- `haptic()`
- All 29 `haptic(...)` call sites
- HapticFeedback warning
- Supabase auth
- Magic-link configuration
- Session storage
- User identity
- Backend
- Database
- Schema
- RPC
- RLS
- Policies
- Hosting
- Deployment configuration
- Messaging loaders
- Message limit
- `photo_url` hardening
- Rewriting historical phase reports
- Implementing NACKL for the Light version

---

## 10. Rollback

**Rollback consists only of reverting the future Phase 20.4 implementation commit.**

There are no backend or data migrations, no schema changes, no policy changes, and no external configuration changes. Nothing is written to any database, and no user data is touched. A single `git revert` of the implementation commit fully restores the prior state.

---

## Relationship to the locked removal sequence

| Phase | Title | Scope |
|---|---|---|
| **20.4** | **Remove Premature NACKL Integration** | **This phase** — NACKL only |
| 20.5 | Evaluate and Isolate Telegram Runtime | Confirm whether an external Telegram Mini App entry point exists; document external configuration not stored in the repository; isolate SDK initialization from normal browser runtime. Removal only if proven safe |
| 20.6 | Remove Telegram Runtime from Full Web App | Remove the SDK script, `window.Telegram`, `tg`, `ready()`, `expand()`, `HapticFeedback`, every `haptic(...)` call, the `haptic()` function, and Telegram-specific comments and logic |

NACKL and Telegram are deliberately **not** removed together. NACKL is fully repository-provable, isolated, and testable in a normal browser. Telegram's true impact depends on whether a Telegram Mini App entry point exists — configuration **outside this repository** — and `haptic()` has 29 call sites that must survive. Bundling them would place a zero-risk cleanup behind an unverifiable one.

---

## Summary

Phase 20.4 removes six isolated NACKL source areas from `index.html`: two CSS blocks, the Profile stat tile, the Backstage feature claim, the `tickNACKL()` call, and the function itself. The change eliminates a `ReferenceError` that fires on every Profile open and removes a marketing claim the product does not fulfil. NACKL has no backend, database, Supabase, RPC, storage, timer, or external dependency, so the removal is isolated and requires no backend knowledge. Telegram is explicitly out of scope and deferred to Phases 20.5 and 20.6. Rollback is a single revert. Level 3 runtime validation on a Netlify deploy preview is required before merge.
