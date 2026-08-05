# Phase 21.1 — Validation Report

**Branch:** `phase-21.1-complete-output-escaping`
**Base commit:** `678949347bdb4a652fe29aeeb2dba2e698921242`
**Date:** 2026-07-29
**Format:** `.apos/VALIDATION_STANDARD.md` §10
**Level required:** 3 (browser validation) — behaviour-affecting change to `index.html`
**Level achieved:** **Level 3 COMPLETE.** 33/33 static invariants · 38/38 adversarial harness · B1–B11 + B13 PASS · B12 N/A · B14 PASS (retargeted to `profiles.location`). Not committed, not pushed.

---

## Scope

What was approved and implemented: eliminate the stored-XSS, HTML-attribute-injection and CSS-URL-injection surfaces recorded as Phase 20.7 item **C-1**, without changing intended behaviour. Full specification in `analysis/phase-21.1/phase-definition.md`.

Implemented: 18 HTML-text sinks escaped; 4 `photo_url` CSS-`url()` sinks removed from generated markup and re-applied through the DOM style API; 2 helpers added.

---

## Files changed

| Path | Change |
|---|---|
| `index.html` | Modified — 119 insertions, 33 deletions |
| `analysis/phase-21.1/phase-definition.md` | Created |
| `analysis/phase-21.1/validation.md` | Created (this file) |
| `analysis/phase-21.1/static-check.sh` | Created — 33 source invariants, no browser required |
| `analysis/phase-21.1/xss-verification.html` | Created — runtime adversarial harness |
| `.apos/PROJECT_CONTEXT.md` | Modified — phase of record, development branch, Phase 21.1 record |

**Not modified:** `README.md`, `CNAME`, `.apos/VALIDATION_STANDARD.md`, `.apos/WORKFLOW.md`, and every document under `analysis/phase-20.1/` … `analysis/phase-20.7/`. History is not rewritten.

---

## Checks performed

### 1. Static invariants — `static-check.sh`

```bash
bash analysis/phase-21.1/static-check.sh
```

**Result: 33 passed, 0 failed. Exit code 0.**

| Group | Checks | Outcome |
|---|---|---|
| `photo_url` reaches no HTML string or `url()` expression | 2 | PASS |
| Dangerous sinks absent (`outerHTML`, `insertAdjacentHTML`, `document.write`, `eval(`, `new Function`, `srcdoc`) | 6 | PASS — 0 occurrences each |
| Helpers defined once and wired to all 4 avatar sites | 4 | PASS |
| Each corrected HTML-text sink escaped | 14 | PASS |
| Trusted static entity values **not** escaped; already-escaped values **not** double-escaped | 7 | PASS |

One expectation in the script was wrong on first run and was corrected, not worked around: the pattern `escapeCollaborationHtml(pub.display_name || 'STAGERZ Artist')` matches **4** places, of which only **2** are this phase's `innerHTML` sinks — the other two are pre-existing correct uses that assign to a variable first (`actorName` in the activity loop, `name` in the credits list). The check now matches with the surrounding `+` concatenation operators so it counts only the two corrected sinks, and a second check asserts the two pre-existing forms are still present and untouched.

### 2. Escaper call-site count

```
escapeCollaborationHtml(  occurrences   baseline: 34   now: 52   (each includes 1 definition)
new call sites introduced by this phase: 18
```

18 new calls for 18 corrected sinks — no site double-counted, none missed.

### 3. Structural integrity

Bracket balance across the whole file, baseline vs current:

| Delimiter | Baseline | Current | Balanced before | Balanced after |
|---|---|---|---|---|
| `{` / `}` | 1059 / 1059 | 1063 / 1063 | yes | yes |
| `(` / `)` | 2896 / 2896 | 2948 / 2948 | yes | yes |
| `[` / `]` | 177 / 177 | 178 / 178 | yes | yes |

Line endings preserved: **5028 lines, 5028 CR characters** (CRLF throughout, `core.autocrlf=true`).

### 4. Full sink audit

Every value interpolated into a string literal in `index.html` was enumerated and classified by source and output context. Findings in `phase-definition.md` §4, §6.2 and §8. Summary:

| Sink family | Count | Status |
|---|---|---|
| `innerHTML` | 81 assignments | Audited; 18 user-controlled values corrected |
| `outerHTML`, `insertAdjacentHTML`, `document.write` | 0 | Absent entirely |
| Inline `style` attributes carrying a runtime value | 4 | All corrected |
| CSS `url(...)` strings in markup | 4 | All removed |
| Event-handler attributes with an interpolated value | 0 | Static `onclick=` attributes take literal arguments only |
| `src` / `href` built by string concatenation | 0 | Preview/download use `URL.createObjectURL()` assigned via `.src` / `.href` |
| Template literals assigned to an HTML sink | 0 | The file uses string concatenation throughout |

### 5. Adversarial runtime harness — executed; two assertion defects found and corrected

**First run: 28/38 passed. No `alert()` dialog appeared at any point.**

| Group | Result |
|---|---|
| Text payloads | 6/6 PASS |
| URL rejection | 15/15 PASS |
| URL acceptance | 4/4 PASS |
| Trusted static | 2/2 PASS |
| **CSS breakout** | **0/5 FAIL** |
| **Fallback** | **1/6 FAIL** |

Both failing groups were investigated individually. **Neither was a security defect and neither was an implementation defect.** Both were incorrect expectations in the harness itself. `index.html` was not changed in response, and the security bar was raised rather than lowered.

#### 5.1 CSS breakout 0/5 — incorrect harness expectation (two separate assertion bugs)

A uniform 0/5 across five structurally different payloads is the signature of a broken assertion, not five distinct breakouts. Two assertions were wrong:

**(a) Exact property allowlist vs. CSSOM longhand expansion.** The test asserted that every property in `el.style` was one of exactly `background-image`, `background-size`, `background-position`. But assigning `background-position` causes Blink and WebKit to enumerate the longhands `background-position-x` and `background-position-y`. Those names are not in the allowlist, so the assertion failed for **every** payload — including payloads where nothing adverse happened. The assertion was testing an engine-specific serialization detail, not a security property.

**(b) `;` treated as evidence of declaration injection.** The test asserted `backgroundImage.indexOf(';') === -1`. A semicolon is a legal URL path character and is not percent-encoded by the URL serializer, so it legitimately survives **inside the quoted CSS string** for the primary breakout payload. A `;` inside a quoted string cannot terminate a declaration; its presence proves nothing.

**Correction.** The assertions were replaced with CSSOM-behavioural ones that are strictly stronger:

1. Property names are snapshotted **before and after** assignment; every **newly added** property must be in the `background-` family. This tolerates longhand expansion on any engine while still proving no foreign declaration came into existence.
2. `background-image` must match exactly one `url()` token.
3. The URL extracted from that token must be **byte-identical to `safeImageUrl()`'s return value** — proving nothing was appended, truncated or split.
4. That extracted URL, **re-parsed**, must have protocol `http:` or `https:` — proving no `javascript:` URL became active.
5. `applied` must equal `safeImageUrl(payload) !== null`.

Assertions 3 and 4 are materially stronger than the string checks they replace: the old test could not have detected a URL that was silently truncated at a quote, whereas byte-identity plus re-parse can.

The harness now prints, for each payload, the raw input, the `safeImageUrl()` result, the assigned and browser-normalized `style.backgroundImage`, the full `style.cssText`, the complete property list, the foreign-property list, the parsed `url()` token, and the re-parsed protocol — so the evidence is visible rather than asserted.

#### 5.2 Fallback 1/6 — incorrect harness expectation (impossible assertion)

The test asserted `el.style.backgroundImage === ''` after a rejected URL. The observed value was `"initial"`.

**Root cause: the `background` shorthand, in both the fixture and production.** The placeholder markup is `style="background:#1a1228;"`. `background` is a shorthand that sets *every* background longhand, so `background-image` is explicitly given the value `initial`. Reading it back can therefore never yield `''` for the placeholder markup. This is CSS shorthand semantics, not browser quirk, not stylesheet interference, and not test-setup error — and it is identical in production, so the expectation was unsatisfiable by construction.

This is confirmed by the one fallback case that passed: the **positive control** uses `style=""` (no shorthand, because a photo is present), so `backgroundImage` genuinely starts empty there and the assertion held.

**Correction.** The fallback criteria now assert behaviour rather than a serialization form:

1. `applyAvatarImage()` returns `false`.
2. The inline style is **byte-identical before and after** the call (`cssText` compared) — a rejected value must change nothing at all.
3. No property was added.
4. `background-image` contains no `url(` token — `''`, `initial` and `none` are all acceptable.
5. The 👤 (U+1F464) placeholder glyph is still present.

Criterion 2 is stronger than the original: "changed nothing" subsumes "no image applied" and additionally catches any unintended write to an unrelated property.

#### 5.3 Re-run result — **PASS, 38/38**

The corrected harness was re-executed by the product owner and reported:

```
ALL TESTS PASSED — 38/38 checks passed
```

Text payloads 6/6 · URL rejection 15/15 · URL acceptance 4/4 · CSS breakout 5/5 · Fallback 6/6 · Trusted static 2/2. No `alert()` dialog appeared.

The test count is unchanged at 38 — no test was removed, disabled or relaxed to reach it. The five CSS-breakout and five negative fallback cases now pass against the corrected, stricter assertions described in §5.1–§5.2.

To reproduce:

```
1. Serve the repository root over http://   (a PowerShell HttpListener server on
   port 8080 was used; VS Code Live Server works equally well)
2. Open  http://localhost:8080/analysis/phase-21.1/xss-verification.html
3. Hard-reload (Ctrl+Shift+R) so the corrected harness is fetched, not a cached one
4. Read the summary banner; the page title also shows PASS/FAIL and the count
```

### 6. Browser validation — **COMPLETE**

Level 3 per `.apos/VALIDATION_STANDARD.md` §4. Performed against a local server serving the working tree, with a real authenticated session.

#### 6.1 Environment

| Field | Value |
|---|---|
| Served from | Working tree via a read-only PowerShell `HttpListener` on `http://localhost:8080/` |
| Backend | Supabase project `kbnmkyvbwkuvcklywdhk` — **named `stagerz-foundation-v2-test`** |
| Auth flow | **Implicit** — confirmed from the served bundle (`@supabase/supabase-js@2` → 2.111.0): `DEFAULT_OPTIONS = {…, detectSessionInUrl:!0, flowType:'implicit'}`; the literal `"pkce"` appears 0 times |
| Session established | Yes, on `localhost` |
| Date | 2026-08-04 / 2026-08-05 |

**A temporary, local-only change was required to authenticate against the working tree.** `emailRedirectTo` is hardcoded to `'https://stagerz.app'`, so a magic link requested from localhost lands on production. A token-fragment copy workaround was attempted first and **does not work**: production's own supabase-js consumes the fragment and calls `history.replaceState(...)` to strip it, leaving `https://stagerz.app/#`.

The temporary change was a single line, guarded and fully reverted:

- Backup taken outside the repository; SHA-256 recorded **before** the edit.
- A local `.git/hooks/pre-commit` (untracked, uncommittable) hard-blocked any commit while the marker `PHASE-21.1-TEMP-VALIDATION-ONLY` was present. Verified firing, exit code 1.
- `http://localhost:8080/**` added to Supabase **Redirect URLs**; Site URL left unchanged.
- Restored by **file copy, never `git checkout`/`restore`/`stash`** — the Phase 21.1 work is uncommitted and those commands would have destroyed it.
- Post-restore SHA-256 `21d57a30cee71dd32589337c6c427ef49b3f8356e3ab65a7c9079571ba78b2fa` — byte-identical. Marker absent, `emailRedirectTo` back to `https://stagerz.app`, diffstat back to 119+/33−, hook removed.

#### 6.2 Results

| # | Check | Result | Notes |
|---|---|---|---|
| B1 | App loads; no console error | **PASS** | Session restored, Stage opened. No `safeImageUrl is not defined`, no `applyAvatarImage is not defined`, no `Uncaught SyntaxError`. Supabase requests 200. Only red entry was `favicon.ico` 404 — the repo contains no favicon; unrelated |
| B2 | Demo cards render entities as glyphs | **PASS** | Verified objectively by headless DOM dump *and* in-app. Rendered DOM contains **0** occurrences of `&amp;#` (no double-escaping) and **0** raw `&#1x` entities outside `<script>`. Non-remote demo rows render `🇰🇷 Seoul` / `🇺🇦 Kyiv` — trusted `item.flag` preserved as a glyph while `item.loc` passed through the escaper |
| B3 | Real Wanted post fields render | **PASS** | Title, category, role, compensation, location all normal. No visible escaped entities |
| B4 | Applicants list | **PASS** | Name renders; meta line `@username · role · location` with real `·`; missing fields omitted cleanly; Accept/Reject present. **Reached via Profile → My WANTED → the 👤 count chip** (see §8 finding 3) |
| B5 | My Collaborations titles | **PASS** | |
| B6 | Workspace header + `From:` line | **PASS** | |
| B7 | Participant rows | **PASS** | Name, meta line with real `·`, 👤 placeholder avatars |
| B8 | Activity rows | **PASS** | Sentences natural; **no double-escaping** — no visible `&amp;`. This is the check that the pre-existing escaped activity block was not escaped a second time |
| B9 | Invite picker | **PASS** | Rows render with placeholder avatars, names, `@username`, layout intact. First attempt returned no rows — the search matches **`username` only** ([index.html:3184](../../index.html#L3184)) and requires ≥2 characters ([3161](../../index.html#L3161)); the term used was a display name from the fictional `artistDB`. Re-run with a real username substring passed |
| B10 | Messages | **PASS** | Sender avatars at the correct 26px `.card-av` size, alignment intact, bodies and sender lines clean. This is the only `applyAvatarImage()` site targeting `.card-av` |
| B11 | Assets | **PASS** | `type · size · uploader · date` with real `·`; `asset_type` renders as a plain word; filenames, titles, descriptions clean; icons present |
| B12 | Real `photo_url` renders | **N/A** | **No profile in the dataset has a `photo_url`** (verified: `users_with_photo = 0`). Product-owner decision to record N/A rather than write data. The harness positive control already proves a valid https URL is applied at `cover`/`center` through the DOM/CSS path |
| B13 | Missing-photo fallback | **PASS** | 👤 glyph centred on the neutral `#1a1228` circle across participants, invite results and messages. No broken-image icons, no empty/collapsed circles, correct sizes (42/32/26px), no layout shift, borders intact |
| B14 | Stored XSS payload renders inert | **PASS** | **Retargeted to `profiles.location`** — see §6.3 |

**All four `applyAvatarImage()` call sites were exercised in the live app:** participant rows (B7), activity rows (B8), invite picker (B9), message rows (B10).

#### 6.3 B14 — retargeted to `profiles.location`

B14 was originally specified against `display_name`. **That is not testable through the UI**, for the reason recorded in §8 finding 1: every `innerHTML` display-name sink reads the `public_profiles` view, while Edit Profile writes the `profiles` table, and the view does not surface that column.

Observed during the first attempt: the payload was stored and appeared on the Profile screen (which uses `textContent`, and therefore proves nothing), while the participant row continued to show the username. The product owner correctly rejected that as inconclusive.

**Retargeted to `location`**, which is one of the fields named in the phase scope and is unambiguously reachable:

- `#editLocation` — [index.html:620](../../index.html#L620) — free text, **no `maxlength`, no pattern, no validation**.
- `saveProfile()` writes it to `profiles.location` — [index.html:2105](../../index.html#L2105).
- `renderParticipantRow()` reads `prof.location` from the `profiles` query ([index.html:2620](../../index.html#L2620)) and renders it via `escapeCollaborationHtml(prof.location)` into **`innerHTML`** — [index.html:2837](../../index.html#L2837).

Procedure: original value `Berlin, Germany` recorded out-of-band first; Location set to `<img src=x onerror=alert(1)>`; saved; workspace re-opened to force a re-fetch; observed; restored immediately.

**Observed result:**

```
@stgrz1 · Filmmaker · <img src=x onerror=alert(1)>
```

- **No alert dialog appeared at any point** — not on save, not on render.
- The payload rendered as **literal visible text**; it was **not parsed as HTML**.
- **No broken-image icon** — which would have indicated the `<img>` tag was parsed.
- The ` · ` separators rendered correctly around the payload, confirming the per-part escaping preserved the trusted separator entity.
- No new console errors.
- Original value restored.

This is the end-to-end proof of the phase: a stored, attacker-controlled value containing an active XSS payload, rendered through a Phase 21.1 corrected `innerHTML` sink, is inert.

---

## Results

| Check | Level | Result |
|---|---|---|
| Approved scope implemented | 1 | **PASS** |
| No unrelated refactors | 1 | **PASS** — one file changed; no query, auth, navigation or feature change |
| No syntax errors | 1 | **PASS** — bracket balance and diff review, then **confirmed by real browser execution** (B1): the inline script parsed and ran end-to-end with no `SyntaxError` |
| No unintended file changes | 1 | **PASS** |
| Static invariants | 1 | **PASS** — 33/33 |
| Success path tested | 3 | **PASS** — B1–B11, B13 all pass in the live app with an authenticated session |
| Failure / fallback path tested | 3 | **PASS** — B13 confirms the missing/invalid-`photo_url` fallback is visually unchanged; harness fallback group 6/6 |
| Adversarial harness executed | 3 | **PASS — 38/38.** First run 28/38 exposed two harness assertion defects (§5.1, §5.2); both corrected and made stricter, then re-run clean. No alert dialog at any point |
| Git branch verified | — | **PASS** — `phase-21.1-complete-output-escaping` |
| Git diff reviewed | 1 | **PASS** |
| Validation results documented | — | **PASS** — this file |
| ChatGPT review | — | **NOT PERFORMED** |
| Explicit user approval | — | **NOT REQUESTED** |

---

## Failures and limitations

**No check failed.** Two limitations and one deviation are recorded rather than papered over:

1. **B12 could not be tested — recorded N/A, not passed.** No profile in the dataset has a `photo_url`, so the "real image renders at `cover`/`center`" path was never exercised in the live app. The harness positive control covers it at unit level. Closing this properly needs a profile with a real image URL.
2. **B14 was retargeted** from `display_name` to `location` (§6.3). The originally specified field is not reachable through the UI (finding 1 below). The retargeted test proves the same property through the same corrected code path, but the phase definition's B14 wording is now historically inaccurate and should be read together with §6.3.
3. **No static JavaScript parser was available** (`node`, `deno`, `bun`, Python all absent). This is now moot — B1 confirmed by real browser execution that the inline script parses and runs.

Out of scope, recorded in `phase-definition.md` §8: `collaborations.status` (server-written, left unescaped); absence of a Content-Security-Policy; demo-content presentation; raw server error text in toasts (verified **not** an XSS sink — `showToast()` uses `textContent`).

---

## 8. Findings surfaced during validation

Three issues found while validating. **None is a Phase 21.1 regression** — all pre-date this phase. Recorded for future phases.

### Finding 1 — `public_profiles.display_name` does not reflect `profiles.display_name` — **CONFIRMED**

**Status: confirmed pre-existing data-model inconsistency. Not a Phase 21.1 regression. Not an open question.**

**Severity: reduces, but does not eliminate, the reachability of six corrected sinks.**

Every `innerHTML` sink that renders a display name reads the **`public_profiles` view**, while Edit Profile writes the **`profiles` table**:

| Sink | Line | Reads |
|---|---|---|
| `openApplicants()` name | [2326](../../index.html#L2326) | `public_profiles.display_name` |
| `renderParticipantRow()` name | [2858](../../index.html#L2858) | `public_profiles.display_name` |
| Activity `actorName` | [2957](../../index.html#L2957) | `public_profiles.display_name` |
| Invite results | [3212](../../index.html#L3212) | `public_profiles.display_name` |
| Message `senderLine` | [3418](../../index.html#L3418) | `public_profiles.display_name` |
| Credits `name` | [4825](../../index.html#L4825) | `public_profiles.display_name` |

`saveProfile()` writes `display_name` into `profiles` ([2105](../../index.html#L2105)); `fetchMyProfile()` reads it back from `profiles` ([2137](../../index.html#L2137), [2149](../../index.html#L2149)) — which is why the Profile screen showed the updated value while participant rows did not.

**Observed:** with `profiles.display_name` set to a payload, the participant row continued to render the account's *username*. The client never substitutes username for display name — the only fallback is the literal `'STAGERZ Artist'` ([2858](../../index.html#L2858)) — so the view had to be resolving `display_name` from a different base table.

**Confirmed by direct query** against the active project (`kbnmkyvbwkuvcklywdhk`):

```sql
select pg_get_viewdef('public.public_profiles'::regclass, true);
```

`public_profiles` is sourced from **`public.users`**, and `display_name` resolves in this order:

| Order | Source | Condition |
|---|---|---|
| 1 | `'Deleted User'` | user is anonymized |
| 2 | trimmed `first_name` + `last_name` | either is present |
| 3 | `users.username` | neither name is present |
| 4 | `'STAGERZ Artist'` | nothing else available |

**It does not read `profiles.display_name` at any point.** This fully explains the observation: the account had no first/last name, so the view fell through to `users.username`, which is what rendered.

**Consequences for reachability.** Working back from that chain to what the application can write:

| Input to the view | Client-writable through the UI? |
|---|---|
| `users.first_name`, `users.last_name` | **No** — the app never writes them. `supaUpdateMinimal('users', …, {username: …})` at [2114](../../index.html#L2114) writes *only* `username`, and no other write path touches `users` |
| `users.username` | **Yes**, but constrained — `saveProfile()` normalizes it and rejects anything failing `^[a-z0-9_.]+$` ([2083–2088](../../index.html#L2083-L2088)), so no HTML metacharacter can pass |
| `'Deleted User'`, `'STAGERZ Artist'` | Literals |

**Through the application UI, no HTML metacharacter can reach `public_profiles.display_name`.** That lowers the practical severity of six of the eighteen corrected sinks.

**Escaping them remains correct and is retained.** Two residual exposures keep it justified rather than merely defensive:

1. The username restriction is a **client-side** check. Whether an equivalent `CHECK` constraint or trigger enforces it server-side is **not recorded in this repository** (Phase 20.7 item **C-3**). A direct `PATCH` to `/rest/v1/users` would bypass the client regex entirely if no server-side constraint exists.
2. `users.first_name` and `users.last_name` feed the view at higher precedence than username. Whether `authenticated` holds column-level `UPDATE` on them is likewise **unrecorded**. If it does, a direct REST write injects into all six sinks at once — and the app's own comments confirm this table already carries deliberate column-level grant restrictions ([2138–2142](../../index.html#L2138-L2142)), which means grants here are non-uniform and cannot be assumed.

Both are questions about **server-side grants, not about this phase**. Escaping closes the sink regardless of how the value arrives, which is the correct posture given the backend contract is uncaptured.

`role` and `location` are written directly to `profiles` by `saveProfile()` and are unambiguously reachable — which is what makes the retargeted B14 a valid proof.

**Recommended follow-up, outside Phase 21.1:** capture the `public_profiles` definition and the `users` column grants as part of Phase 21.3 (backend contract capture), and reconcile the two display-name columns — `profiles.display_name` is currently written by the UI and read by nothing.

### Finding 2 — notification → Applicants routing did not fire

`handleNotificationTap` maps `wanted.application.created` → `navigateToWantedPostApplicants` ([2472](../../index.html#L2472), [2454](../../index.html#L2454)). "New application" notifications were present on the Board screen but tapping them did not open the Applicants view. Either the stored `type` string differs from that literal, or `resolvedTargetId` was null ([2499–2502](../../index.html#L2499-L2502)). Pre-existing Phase 13.2 behaviour; not investigated further as it is outside Phase 21.1 scope.

### Finding 3 — Applicants reachable only via an unlabeled 8px control

The sole working route to applicant management is a `<div>` chip rendered at [2236–2239](../../index.html#L2236-L2239) in the Profile → My WANTED list, styled at `font-size:8px` / `color:rgba(255,255,255,.5)` with no label, showing `👤 <count>`. It renders on every post including those with zero applicants. It was initially reported as "no Applicants view exists in the UI" — a reasonable conclusion given the styling. Aligns with Phase 20.7 item **B.9** (19 semantic `<button>` elements against 186 click handlers).

---

## Git status

```
On branch phase-21.1-complete-output-escaping
Changes not staged for commit:
        modified:   .apos/PROJECT_CONTEXT.md
        modified:   index.html
Untracked files:
        analysis/phase-21.1/
```

Branch has no upstream. Nothing staged, committed or pushed.

---

## Commit recommendation

**Technically ready to commit; the remaining gates are governance, not verification.**

Level 3 is satisfied: 33/33 static invariants, 38/38 adversarial harness, B1–B11 and B13 pass in the live app, and B14 proves a stored XSS payload renders inert through a corrected `innerHTML` sink. B12 is recorded N/A by product-owner decision with a stated reason. The temporary validation change has been fully reverted and verified byte-identical by SHA-256.

Two gates remain, and neither may be assumed (`.apos/VALIDATION_STANDARD.md` §6, `.apos/WORKFLOW.md`):

1. **ChatGPT review** — architecture, governance and scope conformance.
2. **Explicit user approval** to commit.

Two things a reviewer should weigh, both recorded above rather than buried:

- **B12 was not tested** (§8, limitation 1). It is N/A by decision, not by proof.
- **B14 was retargeted** from `display_name` to `location` (§6.3), because finding 1 shows the originally specified field is not UI-reachable. The security property is proven; the phase definition's B14 wording is now historically inaccurate.

## Release recommendation

**Do not push without separate approval.** Pushing is a distinct step requiring its own explicit approval; approval to commit is not approval to push. The branch has no upstream and none was created. `main` deploys to production via GitHub Pages, so a merge there is a production release.

Finding 1 is **resolved** and no longer gates anything. It is recorded as a confirmed data-model inconsistency with a reachability caveat; the residual questions it raises are about server-side grants on `public.users` and belong to backend-contract capture, not to this phase.
