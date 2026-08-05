# Phase 21.1 — Complete Output Escaping

**Branch:** `phase-21.1-complete-output-escaping`
**Base commit:** `678949347bdb4a652fe29aeeb2dba2e698921242` (`main`, merge of Pull Request #7 — Phase 20.7)
**Addresses:** Phase 20.7 register item **C-1** (Critical) — *Incomplete output escaping — stored XSS*, recorded at `analysis/phase-20.7/codebase-assessment.md` §C.6 and §E.
**Status:** Implementation complete. Static verification passed. **Browser validation (Level 3) not yet performed.** Not committed, not pushed.
**Validation level required:** Level 3 — this is a behaviour-affecting change to `index.html` (`.apos/VALIDATION_STANDARD.md` §2).

---

## 1. Objective

Eliminate the stored-XSS, HTML-attribute-injection and CSS-URL-injection surfaces in `index.html` without changing intended application behaviour.

Phase 20.7 established that `escapeCollaborationHtml()` is correct and already applied at 32 sites, but that several paths interpolate user-controlled database values into `innerHTML` unescaped, and that `photo_url` is concatenated into an inline `style` attribute inside a CSS `url()` expression at four avatar sites. This phase closes both classes.

**Pattern decision (`.apos/WORKFLOW.md`): Reuse → Extend.** The HTML-text fixes **reuse** the existing `escapeCollaborationHtml()` helper unchanged. The `photo_url` fixes **extend** the file's existing "build markup, then finish the node programmatically" idiom — already used for `.onclick`, `.textContent` and `.style.cssText` — with two small helpers. No new pattern was created, no framework, no build step, and the single-file architecture is preserved.

---

## 2. Method

Every target was located by **content and data-origin tracing**, not by the line numbers recorded in Phase 20.7 — those numbers moved as edits were applied. For each candidate the questions answered before editing were:

1. What is the **source** of this value? (static literal / server-written column / client-written column)
2. What is the **output context**? (HTML text / attribute / CSS / `textContent` / native dialog)
3. Is it **already escaped** upstream?
4. Does it carry **intentional markup** that escaping would destroy?

That last question is what makes this phase non-mechanical: `index.html` mixes user data and developer-authored HTML entities in the same expressions.

---

## 3. Helpers added

Both are placed immediately after `escapeCollaborationHtml()`, matching the existing convention that shared string helpers live together. Function declarations hoist, so the earlier call sites resolve normally — the same arrangement `escapeCollaborationHtml()` already relies on.

### 3.1 `safeImageUrl(value)` → `string | null`

Validates an externally supplied image URL. **Returns `null` on every rejection** — an explicit failure value, never a throw and never a partially sanitised string.

```js
function safeImageUrl(value){
  try{
    if(value === null || value === undefined) return null;
    var raw = String(value).trim();
    if(!raw) return null;
    var parsed = new URL(raw);
    if(parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
    var href = parsed.href;
    if(/["\\\r\n]/.test(href)) return null;
    return href;
  }catch(e){
    return null;
  }
}
```

**Parsing is the protection, not pattern matching.** The `URL` constructor is the authority on what a URL is, and its serializer (`parsed.href`) is the authority on what comes back out.

| Rule | Mechanism |
|---|---|
| Accepts only `http:` and `https:` | Explicit `parsed.protocol` allowlist |
| Rejects `javascript:`, `data:`, `blob:`, `file:`, and every other scheme | Same allowlist — anything not `http:`/`https:` fails, including schemes not enumerated |
| Rejects malformed URLs | `new URL()` throws; caught and converted to `null` |
| Rejects relative values and bare payload text | **No base argument is supplied**, so relative input does not parse |
| Never throws | Whole body wrapped in `try/catch` returning `null` |
| Output cannot contain `"`, `\`, CR or LF | The URL serializer percent-encodes them; the regex is a defensive invariant that can never fire for a URL that parsed |

Scheme matching is case-insensitive and whitespace-tolerant for free: `parsed.protocol` is normalised by the parser, so `JaVaScRiPt:` and `  javascript:alert(1)  ` are both rejected without any manual normalisation.

### 3.2 `applyAvatarImage(el, photoUrl)` → `boolean`

Applies the background image through the DOM style API. Returns `true` when an image was applied, `false` when the caller's placeholder should stand.

```js
function applyAvatarImage(el, photoUrl){
  if(!el) return false;
  var safeUrl = safeImageUrl(photoUrl);
  if(safeUrl === null) return false;
  el.style.backgroundImage = 'url(' + JSON.stringify(safeUrl) + ')';
  el.style.backgroundSize = 'cover';
  el.style.backgroundPosition = 'center';
  return true;
}
```

**Two independent layers make CSS breakout impossible:**

1. **No HTML context exists.** The URL is written to a single CSS property on an existing element. It never enters an HTML string, so there is no `style` attribute to close, no tag to close, and no declaration list to append to. Writing to `el.style.backgroundImage` cannot create a second declaration — the CSSOM rejects the whole assignment if the value does not parse as one valid `background-image`.
2. **`JSON.stringify` produces the quoted CSS string.** It escapes `"` and `\` and cannot emit a raw newline, and CSS string escaping accepts the same `\"` and `\\` forms. This is applied *on top of* the percent-encoding `safeImageUrl()` has already guaranteed.

**Parentheses need no special handling and are deliberately not rejected.** Inside a quoted CSS string, `(` and `)` are ordinary characters that cannot terminate the `url()` token — only the closing quote can, and that character cannot survive either layer. Rejecting parentheses would break legitimate image URLs for no security benefit. This is proven, not asserted: the payload `https://example.com/a(b)c` is a test case in §7.

**The same reasoning applies to `;`.** A semicolon is a legal URL path character and is not percent-encoded by the URL serializer, so it can legitimately appear inside the quoted CSS string. It cannot terminate a declaration from inside a string. **A URL is not rejected because its text resembles CSS** — the security property is enforced by where the value lands, not by what it looks like.

### 3.3 The security rule, stated precisely

The boundary is **DOM/CSSOM behaviour**, not string pattern matching. A valid `http`/`https` URL containing URL-legal punctuation must not be rejected merely because it resembles CSS. What must hold after assignment is:

| # | Property | How it is enforced |
|---|---|---|
| 1 | Only `background-image` (plus the two presentation properties written deliberately) is newly set | Values are written to individual CSS properties via the style API; the CSSOM rejects a whole assignment that does not parse as one valid value for that property |
| 2 | No additional CSS declaration is created | Same — there is no declaration list being concatenated, so there is nothing to append to |
| 3 | No `javascript:` URL becomes active | `safeImageUrl()` allowlists `http:`/`https:` before anything is written |
| 4 | No payload escapes the single `url()` value | The URL serializer cannot emit `"`, `\`, CR or LF; `JSON.stringify` independently quotes and escapes what remains |

§7.2 verifies exactly these four, by inspecting the CSSOM after assignment rather than by matching strings.

---

## 4. Corrected sites, grouped by output context

### Context A — HTML text inside `innerHTML`

All values below reach `innerHTML` as text and are now wrapped in `escapeCollaborationHtml()`.

| # | Value | Function | Data origin | User-controlled via |
|---|---|---|---|---|
| 1 | `item.title` | `renderWanted()` | `wanted_posts.title` | `submitWanted()` |
| 2 | `item.loc` (inside `locText`) | `renderWanted()` | `wanted_posts.location` | `submitWanted()` — **see §5** |
| 3 | `item.comp` | `renderWanted()` | `wanted_posts.compensation` | `submitWanted()` |
| 4 | `item.cat` | `renderWanted()` | `wanted_posts.category` | `submitWanted()` |
| 5 | `item.role` | `renderWanted()` | `wanted_posts.role_needed` | `submitWanted()` |
| 6 | `item.user` | `renderWanted()` | Literal `'Artist'` on DB rows; static name on demo rows | **Not** user-controlled — escaped as defence in depth; see §6.3 |
| 7 | `pub.display_name` | `openApplicants()` | `profiles.display_name` | `saveProfile()` |
| 8 | `pub.username` | `openApplicants()` | `users.username` | `saveProfile()` |
| 9 | `prof.role` | `openApplicants()` | `profiles.role` | `saveProfile()` |
| 10 | `prof.location` | `openApplicants()` | `profiles.location` | `saveProfile()` |
| 11 | `pub.display_name` | `renderParticipantRow()` (in `openCollaboration()`) | `profiles.display_name` | `saveProfile()` |
| 12 | `pub.username` | `renderParticipantRow()` | `users.username` | `saveProfile()` |
| 13 | `prof.role` | `renderParticipantRow()` | `profiles.role` | `saveProfile()` |
| 14 | `prof.location` | `renderParticipantRow()` | `profiles.location` | `saveProfile()` |
| 15 | `c.title` | `loadMyCollaborations()` | `collaborations.title` | Collaboration creation |
| 16 | `collab.title` | `openCollaboration()` header | `collaborations.title` | Collaboration creation |
| 17 | `wantedTitle` | `openCollaboration()` | `wanted_posts.title` | `submitWanted()` |
| 18 | `a.asset_type` | `loadCollaborationAssets()` | `collaboration_assets.asset_type` | **Client-written** — see §6.1 |

**Sites 8–10 and 12–14 are escaped per element before `join()`, not after.** `metaParts.join(' &middot; ')` inserts a trusted HTML entity as the separator; escaping the joined string would turn `&middot;` into a literal `&amp;middot;` and change visible output. Escaping each part individually is both correct and behaviour-preserving.

### Context B — CSS `url()` inside an inline `style` attribute

All four sites had the identical defect: `photo_url` concatenated into a `style` attribute string, where a single `'` closes the `url()` and then the attribute. All four now emit **no URL in the markup at all**.

| # | Function | Element | Selector used after `innerHTML` |
|---|---|---|---|
| 1 | `renderParticipantRow()` (in `openCollaboration()`) | `.artist-av` | `row.querySelector('.artist-av')` |
| 2 | Activity-row loop (in `openCollaboration()`) | `.artist-av` | `row.querySelector('.artist-av')` |
| 3 | `runInviteUserSearch()` | `.artist-av` | `row.querySelector('.artist-av')` |
| 4 | `buildCollaborationMessageRow()` | `.card-av` | `row.querySelector('.card-av')` |

Uniform transformation at each site — before:

```js
var avatarStyle = pub.photo_url
  ? "background-image:url('"+pub.photo_url+"');background-size:cover;background-position:center;"
  : 'background:#1a1228;';
var avatarContent = pub.photo_url ? '' : '&#128100;';
```

after:

```js
var hasPhoto = safeImageUrl(pub.photo_url) !== null;
var avatarStyle = hasPhoto ? '' : 'background:#1a1228;';
var avatarContent = hasPhoto ? '' : '&#128100;';
// ... row.innerHTML = ... unchanged except avatarStyle/avatarContent ...
applyAvatarImage(row.querySelector('.artist-av'), pub.photo_url);
```

The `querySelector` is scoped to the freshly built `row`, so it cannot match another row's avatar. In sites 2 and 4 the surrounding fixed styles (`width:32px;height:32px;font-size:15px;` / `width:26px;height:26px;font-size:12px;`) are untouched; only the photo-dependent portion changed.

---

## 5. Exact handling of `item.loc`

**`item.loc` was not in the Phase 20.7 finding table.** It was found by tracing data origin during the required full scan and is a genuine additional sink.

`renderWanted()` builds one array from two sources:

```js
var items = currentWantedCat==='all' ? wantedData.slice() : wantedData.filter(...);
if(dbData){
  dbData.forEach(function(p){
    items.unshift({ ..., loc:p.location, ... , fromDB:true, ...});
  });
}
```

So `item.loc` carries the **static demo string** on `wantedData` rows and **`wanted_posts.location`** — free text written by `submitWanted()` — on real rows. Both flow through the same expression:

```js
var locText = item.remote ? (item.flag||'') + ' Remote' : (item.flag||'') + ' ' + item.loc;
```

`locText` is then interpolated into `innerHTML`. A Wanted post with `location` set to `<img src=x onerror=alert(1)>` and `remote` false executes in the browser of every user who opens the Wanted feed.

**This line is mixed-trust and could not be escaped as a whole.** `item.flag` is a developer-authored HTML entity pair (`'&#127475;&#127468;'` — a flag emoji) present on every `wantedData` row. Escaping `locText` after construction would render those flags as the literal text `&#127475;&#127468;` in the demo cards, a visible regression.

**Resolution — escape the user-controlled operand only, at the point of concatenation:**

```js
var locText = item.remote ? (item.flag||'') + ' Remote' : (item.flag||'') + ' ' + escapeCollaborationHtml(item.loc);
```

`item.flag` stays trusted markup, `item.loc` is neutralised, and `locText` is safe to interpolate. Note that the `item.remote` branch never reaches `item.loc` at all — the sink exists only on the non-remote path, which is exactly the path a real non-remote post takes.

---

## 6. Exact handling of trusted static entity-bearing values

`index.html` deliberately stores presentation markup inside its demo datasets. Passing those values through the text escaper would render entities literally and change visible output. Each exclusion below is a deliberate decision, not an oversight.

### 6.1 The rule applied

> **Escape values that originate in the database. Do not escape developer-authored presentation constants or already-escaped values.**

Within database-sourced values a second distinction determined whether an *enum-like* column needed escaping:

| Written by | Examples | Treatment |
|---|---|---|
| **The client**, via `supaInsert`/`supaUpdate` from the browser | `collaboration_assets.asset_type`, all `wanted_posts` and `profiles` text | **Escaped.** A participant can `POST` an arbitrary value straight to the REST endpoint regardless of what the UI computes |
| **The server only**, via an RPC | `collaborations.status` | Documented as safe — see §8 |

`a.asset_type` (site 18) is the concrete case. `classifyCollaborationAssetType(mimeType)` returns one of five fixed strings in the UI, but the value is sent from the browser in `supaInsert('collaboration_assets', {... asset_type: assetType ...})`. Whether a `CHECK` constraint exists is **unknown** — the backend contract is not in this repository (Phase 20.7 item C-3). It is escaped rather than assumed safe.

### 6.2 Values deliberately **not** escaped

| Value | Location | Why escaping would be wrong |
|---|---|---|
| `item.flag` | `renderWanted()` | Entity pair `'&#127475;&#127468;'` in `wantedData` — a flag emoji. Escaping renders it literally |
| `item.badgeText` | `renderWanted()` | `'&#129001; Live'`, `'&#11088; 98% Match'`, `'&#128293; Urgent'` — entity + text |
| `item.time` | `renderWanted()` | Static string (`'Just now'`, `'2h ago'`); no DB source |
| `verifiedBadge` | `renderWanted()` | A complete `<span>` HTML fragment built locally. Escaping would print the tag as text |
| `a.role`, `a.n`, `a.loc`, `a.bg`, `a.emoji` | `renderArtists()` | `artistDB` is entirely static; `role` contains `'&#128131; Dancer &middot; Choreographer'`. **No database value ever enters this function** |
| `item.title`, `item.artist`, `item.loc`, `item.views` … | `buildCard()`, `buildShort()` | `stageData` only — static. Note this `item.loc` is a **different variable** from §5's, from a different dataset, and is correctly left alone |
| `c.r`, `c.n`, `c.e`, `c.b`, `w.b`, `w.emoji`, `w.grad` | Stage credits / works | `stageData` sub-objects; `r` contains `'Vocals &middot; Songwriter'` |
| `m.icon`, `m.label`, `m.subtitle` | `openCollaboration()` Modules | Developer-authored array literal |
| `actorName`, `sentence`, `creditedName`, `senderLine`, `safeBody`, `safeFileName`, `uploaderName`, `name`, `role` | Activity/messages/assets/credits | **Already escaped upstream.** Re-escaping would double-encode and display `&amp;lt;` to users |
| `metaParts.join(' &middot; ')` | Applicants, participants | Parts already escaped individually; the separator is trusted markup |
| `checkGlyph`, `avatarContent` | Tasks, avatars | `'&#10003;'`, `'&#9744;'`, `'&#128100;'` — entity constants |

### 6.3 One deliberate exception to the rule

`item.user` (site 6) is escaped despite **not** being user-controlled: it is the literal `'Artist'` on database rows and a static name on demo rows. Escaping is behaviour-neutral (no demo name contains `& < > " '`) and closes the hole that would open the moment a real uploader name is wired into that field. This is defence in depth and is recorded here so it is not mistaken for a misclassification.

---

## 7. Adversarial verification

Two complementary artefacts. Both run locally; **neither requires network access**.

### 7.1 `analysis/phase-21.1/static-check.sh` — source invariants, no browser

33 assertions over `index.html`: that `photo_url` reaches no HTML string or `url()` expression; that `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval(`, `new Function` and `srcdoc` are absent entirely; that both helpers exist exactly once and are wired to all four avatar sites; that each corrected sink is escaped; and — importantly — that the trusted entity-bearing values in §6.2 are **not** escaped and the already-escaped values are **not** double-escaped.

```bash
bash analysis/phase-21.1/static-check.sh
```

### 7.2 `analysis/phase-21.1/xss-verification.html` — runtime behaviour

Fetches `../../index.html`, extracts `escapeCollaborationHtml`, `safeImageUrl` and `applyAvatarImage` **by brace-matching the real source**, and evaluates them. It therefore always tests the shipped implementation and cannot drift from a copied snippet.

Coverage:

| Group | Payloads |
|---|---|
| Text | `<img src=x onerror=alert(1)>`, `</div><script>alert(1)</script>`, `"><svg onload=alert(1)>`, `'><iframe srcdoc="<script>alert(1)</script>">`, plus `&`/quote round-trips |
| URL — reject | `javascript:alert(1)`, `data:text/html,<script>alert(1)</script>`, `blob:https://example.com/fake`, `file:///etc/passwd`, `vbscript:`, `JaVaScRiPt:`, whitespace-padded, malformed text, protocol-relative, relative path, empty, whitespace-only, `null`, `undefined`, `http://` |
| URL — accept | valid `https`, valid `http`, https with query string, https percent-encoded |
| CSS breakout | `https://example.com/a")};background-image:url("javascript:alert(1)`, a declaration-injection variant, a backslash variant, a newline variant, and `https://example.com/a(b)c` |
| Fallback | rejected scheme, malformed, `null`, `undefined`, empty — plus a **positive control** proving a valid URL does replace the placeholder |
| Trusted static | demonstrates that escaping an entity would render it literally, i.e. why `item.flag` is excluded |

Assertions are structural rather than visual.

**Text group:** element count created, `script`/`img`/`svg`/`iframe` counts, exact attribute-name list, and `textContent` round-trip equality.

**CSS-breakout group** — verifies the four properties in §3.3 directly against the CSSOM:

1. Property names snapshotted **before and after**; every newly added property must be in the `background-` family.
2. `background-image` must match exactly one `url()` token.
3. The URL inside that token must be **byte-identical** to `safeImageUrl()`'s return value — catching any truncation at a quote, or any split into multiple values.
4. That URL, **re-parsed**, must have protocol `http:` or `https:`.
5. `applied` must equal `safeImageUrl(payload) !== null`.

**Fallback group** — a rejected value must change nothing at all: `applyAvatarImage()` returns `false`, inline `cssText` is **byte-identical before and after**, no property was added, `background-image` holds no `url(` token, and the 👤 glyph remains.

> **Assertions corrected after the first run.** An earlier version of this harness asserted an exact three-name property allowlist and the absence of `;` in the serialized value, and required `backgroundImage === ''` in the fallback group. All three were wrong: CSSOM expands `background-position` into `-x`/`-y` longhands, `;` is legal inside a quoted URL string, and the `background` shorthand used by the placeholder markup sets `background-image: initial` rather than leaving it empty. The replacements above are stricter, not looser — byte-identity and re-parsing catch failures the string checks could not. Full analysis in `validation.md` §5.1–§5.2.

```
Serve the repository over http:// (VS Code Live Server) and open:
  http://127.0.0.1:5500/analysis/phase-21.1/xss-verification.html
```

`file://` will not work — `fetch()` of a local file is blocked by CORS. The page reports this explicitly rather than failing silently. Results are also exposed as `window.__PHASE_21_1_RESULT__` for any external runner.

---

## 8. Remaining concerns

Recorded, not fixed. None is introduced by this phase.

| # | Concern | Location | Assessment |
|---|---|---|---|
| R-1 | `collaborations.status` reaches `innerHTML` unescaped via `statusLabel` and the read-only notice | `loadMyCollaborations()`, `openCollaboration()` | **Not fixed — server-written.** The client never writes this column; it changes only through `change_collaboration_status()`, which validates transitions against a fixed set. Escaping it would be harmless but is outside the stated scope. Worth doing if the RLS policy on direct `UPDATE` is ever confirmed permissive |
| R-2 | The backend contract is not in the repository | Phase 20.7 item **C-3** | Whether `collaboration_assets.asset_type` has a `CHECK` constraint, and whether RLS blocks direct `UPDATE` of `collaborations.status`, **cannot be determined from this repository.** Both R-1 and site 18 were decided defensively for exactly this reason |
| R-3 | Raw server error text, including `JSON.stringify(error)`, is shown to users | ~20 sites, Phase 20.7 item **M-10** | **Not an XSS sink** — every path terminates in `showToast()`, which assigns `textContent`. Verified. It is an information-disclosure and UX issue only |
| R-4 | Demo content renders as real platform content | Phase 20.7 item **H-2** | Untouched by this phase. `wantedData` rows still interleave with real rows and still carry a verification badge no real user can earn |
| R-5 | No Content-Security-Policy header or meta tag | `index.html` `<head>` | A CSP would provide defence in depth behind the escaping. GitHub Pages cannot set headers, but a `<meta http-equiv="Content-Security-Policy">` is possible. Out of scope; worth a future phase |
| R-6 | `escapeCollaborationHtml()` is HTML-text-safe only | helper | It is correct for its context and is used only in HTML-text contexts. It is **not** an attribute-value escaper and must not be repurposed as one. After this phase no user value is placed in an attribute at all |

**Confirmed absent — verified, not assumed:** `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval(`, `new Function`, `srcdoc` (0 occurrences each). No `src`/`href` attribute is built by string concatenation; the asset preview and download paths use `URL.createObjectURL()` results assigned via `.src`/`.href` properties. No inline event-handler attribute interpolates a runtime value — the 132 static `onclick=` attributes in the markup block take literal arguments only, and dynamic handlers are assigned as `.onclick` properties.

---

## 9. Behaviour preservation

No change to database queries, Supabase writes, authentication, navigation, collaboration behaviour, Wanted behaviour, visible wording, or layout.

- **Fallback is byte-identical.** When `photo_url` is missing the emitted markup is `style="background:#1a1228;"` with the `&#128100;` glyph — exactly as before. The only difference is that an *invalid* URL now also takes this path instead of producing a broken `url('…')`, which is a strict improvement: no broken-image icon, no empty control, no layout shift.
- **When a photo is present** the element previously received `background-size:cover;background-position:center` from the inline attribute; it now receives the same two properties from the style API, plus the image. Computed style is equivalent.
- **Escaped values render identically** for all normal input. Only input containing `& < > " '` renders differently — and for those the new rendering is the correct one: the characters appear as themselves instead of being parsed as markup.
- The two functions are additive; no existing function signature or call site changed.

---

## 10. Rollback

`git checkout -- index.html` pre-commit; `git revert <commit>` post-commit. No database migration, no schema change, no external configuration, no data transformation — the change is confined to one file plus new documentation. Deleting `analysis/phase-21.1/` removes the verification artefacts with no runtime effect.

---

## 11. Non-goals

Removing demo content; adding a Content-Security-Policy; changing `escapeCollaborationHtml()`; introducing a sanitizer library, framework, build step or module system; converting `innerHTML` construction to `createElement`; addressing any other Phase 20.7 register item (C-2, C-3, H-1…H-7, M-*, L-*); altering the Supabase schema, RPCs or RLS; touching authentication or navigation.

---

## Summary

Eighteen HTML-text sinks and four CSS-`url()` sinks were corrected in `index.html`. The text fixes reuse the existing `escapeCollaborationHtml()`; the `photo_url` fixes remove the URL from the generated markup entirely and apply it through the DOM style API behind a parsing-based validator that returns `null` on rejection and never throws.

Three findings went beyond the Phase 20.7 table: **`item.loc`** in `renderWanted()` carries `wanted_posts.location` and was a live stored-XSS vector on non-remote posts; **`a.asset_type`** is a client-written column and is attacker-influencable regardless of what the UI computes; and the demo datasets store HTML entities in `flag`, `badgeText` and `role`, so a blanket escape would have produced a visible regression. The mixed-trust `locText` expression is the clearest example of why each sink had to be traced to its origin rather than escaped mechanically.

33 static invariants pass. The browser harness is written and covers every required payload, but **has not yet been executed** — that is Level 3 work and is recorded as outstanding in `analysis/phase-21.1/validation.md`.
