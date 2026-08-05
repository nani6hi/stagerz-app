# Project Context

Confirmed stable facts only. Anything not established is marked **unknown** rather than inferred.

---

## Identity

| Field | Value |
|---|---|
| Project name | STAGERZ |
| Process | APOS |
| Role of this project | STAGERZ is the APOS reference implementation |
| Current APOS phase of record | Phase 21.1 — Complete Output Escaping |
| Current phase status | **Implementation and Level 3 validation complete.** 33/33 static invariants · 38/38 adversarial harness · B1–B11 + B13 PASS · B12 N/A · B14 PASS (retargeted to `profiles.location`). Temporary validation redirect fully reverted, verified by SHA-256. Awaiting ChatGPT review and explicit user approval. Not committed, not pushed — `analysis/phase-21.1/validation.md` |

---

## APOS Phases

| # | Phase |
|---|---|
| 0 | Project Initialization |
| 1 | Requirements Analysis |
| 2 | Architecture Review |
| 3 | ADR |
| 4 | Technical Specification |
| 5 | Implementation Plan |
| 6 | Task Specification |
| 7 | Implementation |
| 8 | Documentation Update |
| 9 | Review Support |
| 10 | Release Preparation |
| 11 | Maintenance |

---

## Application

| Field | Value |
|---|---|
| Main application file | `index.html` |
| Architecture | Single-page application, contained primarily in `index.html` |

---

## Repository and Deployment

| Field | Value |
|---|---|
| Repository remote | https://github.com/nani6hi/stagerz-app.git |
| Deployment | GitHub Pages, serving the `main` branch directly (no `.github/workflows`, no `netlify.toml`) |
| Production domain | `stagerz.app` (`CNAME`) |
| Pull-request previews | **None.** GitHub Pages provides no per-PR preview environment. Pre-merge Level 3 validation runs against a local server on `localhost`; authenticated flows that depend on the Supabase magic-link redirect to `https://stagerz.app` can only be validated after merge and deployment |
| Production branch | `main` |
| Current development branch | `phase-21.1-complete-output-escaping` (local only — no upstream) |

---

## Roles and Authority

| Actor | Responsibility |
|---|---|
| **ChatGPT** | Architecture, governance, reviews, implementation approval |
| **Claude Code** | Analysis and approved implementation |
| **User** | Final authority for source changes and commits |

---

## Directory Conventions

| Path | Contents |
|---|---|
| `analysis/<phase>/` | Analysis results |
| `.apos/` | Governance rules |

---

## Product Roadmap Decisions

Permanent product decisions. These constrain scope regardless of what the code currently contains.

### NACKL is excluded from the current full web app

**Decision:** NACKL does not belong in the current full STAGERZ web application.

NACKL was intended for a later, reduced **Light version**, after the real full app/web version is established. The NACKL implementation currently present in `index.html` is **premature** and creates unnecessary runtime errors, state, and maintenance burden inside the main app.

Consequences:

- Do **not** repair `nacklVal` as a standalone cosmetic fix.
- Do **not** expand NACKL.
- Do **not** integrate NACKL further into Profile or any other module.
- Complete removal of NACKL from the current full web app is scheduled as **Phase 20.4**.
- The NACKL product idea is **preserved as a deferred concept for a future Light version**.

**Removal from the full app does not mean deletion of the product idea.** It means the idea returns in the Light version, on purpose, rather than persisting here by accident.

### Telegram runtime integration is excluded from the current full web app

**Decision:** Telegram Mini App / Telegram-specific runtime integration does not belong in the current full STAGERZ web application.

Like NACKL, it is preserved as a concept for a future STAGERZ Light / Mini App version. Removal from the full app does **not** mean deletion of the product idea.

**Product-owner decision recorded 2026-07-28 (resolves the Phase 20.6 prerequisite gate):**

> STAGERZ is currently being developed as an **independent web application**. The current product must be built, tested, and completed **without any Telegram dependency or Telegram-specific runtime behavior**. A separate Telegram light version may be developed later, **only after** the main web application is technically complete, stable, and user-friendly. The existing Telegram Mini App configuration is **not part of the currently supported product scope and must not block this removal**.

Scope boundary: Phase 20.6 removes the Telegram runtime **from this repository only**. External BotFather / Telegram Mini App configuration is deliberately **not** inspected or modified by this phase.

Telegram removal is deliberately **not** bundled with NACKL removal. NACKL is fully repository-provable and isolated; Telegram's true impact depends on whether an external Mini App entry point exists — configuration outside this repository — and `haptic()` has 28 call sites. The sequence below separates the two so a zero-risk cleanup is not blocked behind an unverifiable one.

**Call-site count of record: 28.** Pre-20.5 documentation recorded `haptic(` as occurring 29 times (1 definition + 28 calls). Phase 20.5 added three explanatory comment mentions, so the current raw count in `index.html` is **32** = 28 call sites + 1 function definition + 3 comment mentions. The number of **executable call sites is unchanged at 28**.

### Locked removal sequence

| Phase | Title | Scope |
|---|---|---|
| **20.4** | **Remove Premature NACKL Integration** | **Completed** — merged in Pull Request #4 (`31dc073af588d1664d0991b98e6b0995d5174660`). All NACKL UI, CSS, and JavaScript removed; misleading NACKL feature claim removed; `nacklVal is not defined` ReferenceError eliminated |
| **20.5** | **Evaluate and Isolate Telegram Runtime** | **Completed** — merged in Pull Request #5 (`155b029cdfcd752104849f1d52f84c0aa645ce61`). Every Telegram runtime reference collapsed into one contiguous, marker-delimited compatibility block (`index.html` 962–1001); `tg` renamed to `telegramWebApp`; single detection point; `haptic()` given a documented platform-agnostic contract. No behavior change, no call site changed |
| **20.6** | **Remove Telegram Runtime from Full Web App** | **Completed** — merged in Pull Request #6 (`275caf3944f1194434ca4924272731c03111bbd1`). Complete Telegram runtime removal, including all 28 `haptic(...)` call sites: the Telegram SDK script tag (line 8), the compatibility block (962–1001) with `window.Telegram`, `telegramWebApp`, `ready()`, `expand()`, `HapticFeedback`, and the `haptic()` function, plus every `haptic(...)` call site and all Telegram-specific comments. Deletion only — no substitute (no `navigator.vibrate`, no sound, no animation). Authentication, sessions, identity, navigation, messaging, and all collaboration workflows preserved unchanged |

### Final intended full-app architecture

On completion of Phase 20.6, the current full STAGERZ web application will have:

- no NACKL runtime;
- no Telegram SDK;
- no Telegram initialization;
- no Telegram haptics;
- normal browser runtime only;
- Supabase-only authentication and session management.

NACKL and Telegram are preserved **only as future Light-version concepts**. The full web app must remain fully functional using normal browser and Supabase behavior alone.

**Achieved and merged to `main` (Pull Request #6, `275caf3`).** `index.html` on `main` contains **zero** occurrences of `telegram`, `window.Telegram`, `telegramWebApp`, `HapticFeedback`, `ready()`/`expand()` Telegram initialization, and `haptic` in any form — re-verified during Phase 20.7 (`grep -c -i "telegram\|haptic" index.html` → `0`). `index.html` is the only file in the repository containing executable code, so **the main web app is Telegram-independent.** Details in `analysis/phase-20.6/phase-definition.md` §14.

### Guardrail — a future Telegram Light version must not reintroduce coupling

**Any future Telegram light version must be implemented separately and must not silently reintroduce runtime coupling into the main web application.**

Binding rules:

1. **Separate delivery artifact** — its own entry point, build target, or repository. **Not** a conditional branch inside the main app's `index.html`.
2. **No conditional platform code in the main app** — no `if (window.Telegram)`, no platform sniffing, no "harmless" SDK script tag, no `haptic()`-style wrapper kept "just in case". A guard that is inert today is still coupling.
3. **No shared mutable runtime** — reusing Supabase schema and API contracts is fine; requiring the main app to carry Telegram-aware code is not.
4. **Sequencing is fixed** — Light-version work begins only after the main web application is technically complete, stable, and user-friendly.
5. **Explicit governance** — reintroducing any Telegram runtime into the main app requires a new APOS phase and a recorded reversal of this roadmap decision. It may not arrive as an incidental part of unrelated work.

Phases 20.4, 20.5, and 20.6 exist because Telegram and NACKL runtime code accumulated inside the main app without a boundary. The removed implementation is preserved in git history at `155b029cdfcd752104849f1d52f84c0aa645ce61` and documented in `analysis/phase-20.5/phase-definition.md`, so the Light version can recover it deliberately from a clean base.

### Phase history

| Phase | Title | Status |
|---|---|---|
| 20.1 | Optimistic Message Sending | Merged to `main` (PR #1) |
| 20.2 | Messaging Hardening | Merged to `main` (PR #2) |
| 20.3 | Message Load Failure Visibility | Merged to `main` (PR #3) |
| 20.4 | Remove Premature NACKL Integration | Merged to `main` (PR #4) |
| 20.5 | Evaluate and Isolate Telegram Runtime | Merged to `main` (PR #5) |
| 20.6 | Remove Telegram Runtime from Full Web App | Merged to `main` (PR #6, `275caf3`) — 69 lines deleted + 1 in-place edit in `index.html`; SDK script, compatibility block, and all 28 `haptic(...)` call sites removed. Deployed to production per product-owner report. *No post-deployment authenticated-validation record exists under `analysis/phase-20.6/`; the outcome is reported, not documented in this repository.* |
| 20.7 | Codebase Assessment & Roadmap | Merged to `main` (PR #7, `6789493`) — analysis only; no application code changed. Full assessment at `analysis/phase-20.7/codebase-assessment.md` |
| 21.1 | Complete Output Escaping | **Current phase** — implementation complete, static verification passed; Level 3 outstanding. `analysis/phase-21.1/` |

### Phase 21.1 — Complete Output Escaping (implementation)

Closes Phase 20.7 register item **C-1** (Critical) — incomplete output escaping / stored XSS.

**Changed in `index.html`** (119 insertions, 33 deletions):

- **18 HTML-text sinks** now escaped with the existing `escapeCollaborationHtml()`: Wanted feed (`title`, `location`, `compensation`, `category`, `role_needed`), Applicants and participant rows (`display_name`, `username`, `role`, `location`), collaboration titles in My Collaborations and the Workspace header, the linked Wanted title, and `collaboration_assets.asset_type`.
- **4 `photo_url` CSS-`url()` sinks** removed from generated markup entirely. The URL is no longer interpolated into any inline `style` attribute; it is applied after the node exists via the DOM style API.
- **Two helpers added:** `safeImageUrl(value)` — parses with the `URL` constructor, accepts only `http:`/`https:`, returns `null` for every rejection, never throws; and `applyAvatarImage(el, photoUrl)` — writes a single CSS property using `JSON.stringify()` for the quoted string.

**Three findings beyond the Phase 20.7 table**, all recorded in `analysis/phase-21.1/phase-definition.md`:

1. **`item.loc` in `renderWanted()`** carries `wanted_posts.location` and was a live stored-XSS vector on non-remote posts. It sits in a mixed-trust expression alongside `item.flag`, a developer-authored HTML entity pair, so only the user-controlled operand is escaped.
2. **`collaboration_assets.asset_type`** is written by the client via `supaInsert`, so it is attacker-influencable regardless of what the UI computes. Escaped defensively — whether a `CHECK` constraint exists is unknowable from this repository (item C-3).
3. **The demo datasets store HTML entities** in `wantedData.flag`/`badgeText` and `artistDB.role`. A blanket escape would render them literally. Trusted static presentation constants are explicitly excluded and documented.

**Standing rule established by this phase:** escape values that originate in the database; do not escape developer-authored presentation constants or values already escaped upstream. Within database values, columns the **client** can write are escaped; columns only a **server RPC** writes (e.g. `collaborations.status`) are documented as safe rather than escaped.

**Verification artefacts:** `analysis/phase-21.1/static-check.sh` (33 source invariants, no browser or network needed — **33/33 pass**) and `analysis/phase-21.1/xss-verification.html` (runtime adversarial harness that extracts the helpers from the live `index.html` — **38/38 pass**).

**Level 3 validated in the live app** against `kbnmkyvbwkuvcklywdhk` with a real session. B1–B11 and B13 PASS; B12 **N/A** (no `photo_url` exists in the dataset); **B14 PASS** — a stored `<img src=x onerror=alert(1)>` rendered as inert literal text in a participant meta line, no alert, no HTML parsing. B14 was **retargeted from `display_name` to `profiles.location`** because of the reachability finding below. Full record: `analysis/phase-21.1/validation.md` §6.

**Findings surfaced during validation — none a Phase 21.1 regression, all pre-existing:**

1. **`public_profiles.display_name` does not reflect `profiles.display_name` — CONFIRMED.** All six `innerHTML` display-name sinks read the view; Edit Profile writes the table. Confirmed by querying the active project (`pg_get_viewdef('public.public_profiles')`): the view is sourced from **`public.users`** and resolves `display_name` as `'Deleted User'` for anonymized users → trimmed `first_name` + `last_name` when either exists → `users.username` → `'STAGERZ Artist'`. **It never reads `profiles.display_name`.**

   Consequence: through the UI, no HTML metacharacter can reach that column — the app writes only `users.username`, which `saveProfile()` constrains to `^[a-z0-9_.]+$`, and never writes `first_name`/`last_name`. That lowers the practical severity of six of the eighteen corrected sinks. **Escaping is retained** because both the username restriction and any write protection on `first_name`/`last_name` are **client-side or unrecorded server-side grants** (item C-3) — a direct REST `PATCH` would bypass the client check. This is a **confirmed pre-existing data-model inconsistency, not a Phase 21.1 regression**, and `profiles.display_name` is currently written by the UI and read by nothing. Reconciling the two columns and capturing the `users` grants belongs to backend-contract capture.
2. **Notification → Applicants routing does not fire.** `wanted.application.created` maps to `navigateToWantedPostApplicants`, but tapping such notifications does not open the view. Pre-existing Phase 13.2 behaviour.
3. **Applicants reachable only via an unlabeled 8px `<div>`** in Profile → My WANTED. Aligns with item B.9.

**Not addressed, recorded:** no Content-Security-Policy exists; `collaborations.status` remains unescaped by decision; demo-content presentation (item H-2) is untouched.

### Phase 20.6 prerequisite — RESOLVED

Phase 20.6 carried one gate that this repository could not answer:

> Does a live external Telegram Bot / Mini App entry point exist that points at STAGERZ, and do real users currently open the app inside Telegram?

**Resolved by the product-owner decision recorded above (2026-07-28):** the existing Telegram Mini App configuration is outside the currently supported product scope and does not block removal. Implementation proceeded on that basis. Full record at `analysis/phase-20.6/phase-definition.md` §13.1.

### Phase 20.7 — Codebase Assessment (recommendations, **not** decisions)

Phase 20.7 was an analysis-only evaluation of the application after Telegram removal. It changed no application code and recorded no roadmap decision. Full document: `analysis/phase-20.7/codebase-assessment.md`.

**Nothing in that document is binding.** Its roadmap is a *proposal* for ChatGPT review under `.apos/WORKFLOW.md`. Phase numbering (21.1–21.10) is suggested, not assigned.

**Baseline measured (at `275caf3`):** `index.html` is 4,942 lines / ~265 KB — CSS 9–286, markup 288–958, JavaScript 960–4940. 20 screens, all reachable via `goTo()`. 139 functions, 47 module-level `var`s, 194 `getElementById` calls, 81 `.innerHTML` assignments. Backend surface: 20 RPCs and 14 tables/views across one Supabase project. Zero `@media` queries, zero `aria-*` attributes, zero tests/lint/CI.

**Three findings ranked Critical:**

1. **Incomplete output escaping.** `escapeCollaborationHtml()` exists and is applied at 32 sites, but 10 sites interpolate user-controlled values (`display_name`, `username`, `role`, `location`, Wanted `title`, collaboration `title`) unescaped into `innerHTML`, plus 4 `photo_url` injections into inline `style` attributes. Stored-XSS class.
2. **Unpinned CDN dependency with no failure path.** `@supabase/supabase-js@2` floats across all v2 releases with no SRI and no lockfile. Because no screen carries `active` in the static markup, a CDN failure makes the whole inline script throw at `supabase.createClient()` and the user sees a permanently blank page.
3. **The backend contract exists only inside Supabase.** 20 RPCs, 14 tables/views, RLS policies, column grants, the signup trigger, and Storage bucket policies have no representation in this repository. Nothing here can reconstruct the server — this is also the root cause of "no staging environment" and "authenticated flows unverifiable pre-merge."

**Open question raised for the product owner (recorded, not answered):** `index.html` describes the Supabase project at `kbnmkyvbwkuvcklywdhk.supabase.co` as a *"disposable test project"* and the auth flow as *"TEST ONLY"* (lines 307–310, 1218–1225). Whether that is still accurate — and therefore whether production user data currently sits on a project not intended to persist — is **unknown from this repository and must be confirmed rather than assumed.**

**Architecture verdict:** the single-file architecture is sound and is recommended for retention. No build step, bundler, framework, module system, or file split is proposed. The assessment found no compelling technical reason to change it.

---

## Governance Gates

- Source changes require explicit approval.
- Commits require successful validation **and** explicit user approval.
- Validation procedure is defined in `.apos/VALIDATION_STANDARD.md`.

---

## Unknown

The following are **not** established and must not be assumed:

- APOS acronym expansion — unknown.
- Release procedure beyond "deployed via GitHub Pages from `main`" — unknown.
- Branching and merge policy (how development branches reach `main`) — unknown.
- Definitions of the individual APOS phase deliverables — unknown.
- Whether the Supabase project at `kbnmkyvbwkuvcklywdhk.supabase.co` is still the "disposable test project" the code describes, or is now the intended production data store — **unknown**; raised by Phase 20.7, not yet answered.
- The full backend contract (RPC bodies, RLS policies, column grants, triggers, Storage policies) — **not recorded anywhere in this repository.** Phase 20.7 enumerated the 20 RPCs and 14 tables/views the client calls, but their definitions exist only inside the Supabase project.

Previously listed as unknown, now established by Phase 20.7 (`analysis/phase-20.7/codebase-assessment.md`):

- **Runtime dependencies and third-party integrations.** Exactly one runtime dependency: `@supabase/supabase-js@2`, loaded from jsDelivr at `index.html:8` (unpinned within v2, no SRI). Plus Google Fonts via a CSS `@import`. No other third-party code.
- **Backend services.** One Supabase project providing PostgREST, Auth (email magic link), Realtime (`postgres_changes` + presence), and Storage (bucket `collaboration-assets`).

---

## Summary

STAGERZ is the APOS reference implementation: a single-page application contained primarily in `index.html`, deployed to GitHub Pages from the `main` branch, with development currently on `phase-21.1-complete-output-escaping`. Phases 20.4–20.6 removed NACKL and the Telegram runtime; Phase 20.7 assessed the resulting codebase and proposed a roadmap, changing no application code; Phase 21.1 is closing the stored-XSS and CSS-injection surfaces that assessment identified. ChatGPT owns architecture, governance, reviews, and approval; Claude Code performs analysis and approved implementation; the user is the final authority for source changes and commits. Analysis output lives under `analysis/<phase>/` and governance rules under `.apos/`. Items listed under **Unknown** above are deliberately unrecorded rather than inferred.
