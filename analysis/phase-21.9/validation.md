# Phase 21.9 — Validation Record

**Branch:** `phase-21.9-s4-error-contract`
**Base commit:** `b1582a92c3dc9190614403434ff7688b66c4267b`
**Validation level required:** **3** (`index.html` behaviour changes)
**Merged:** **PR #20** into `main` — merge commit `2df2734247f5f1cccf0ae689d6e121775dea652b` (PR head `24252a63c41101b7623d39f68ac35fd209beb8c9`)
**Status:** **COMPLETE — MERGED, VALIDATED POST-MERGE. S-4 REMEDIATED — Phase 21.9.**
- **Done:**
  - implementation, committed as `ab3a46df3790d33d794435eab241e3da1524f67f` (parent `b1582a9`);
  - independent pre-commit review, approved subject to two corrections, both applied (§9);
  - Level 1 static review and static invariants (**41/41**);
  - offline browser harness (**55/55**, headless Edge);
  - real-application Level 3 local browser validation (**50/50**, network-isolated; **0** successful external requests, **0** Supabase requests) (§10);
  - branch pushed and **PR #20** merged into `main` (§7);
  - post-merge validation of the exact merged `main` `2df2734` (§12): static **41/41**, harness **55/55**, Level 3 **50/50**; **0** successful external requests; **0 / 0** Supabase requests attempted / sent; repository unchanged.
- **Not performed:** validation against live Supabase. Every browser run, before and after the merge, was deliberately network-isolated.

**S-4 is REMEDIATED — Phase 21.9** (§12).

---

## 1. What this record claims, and what it does not

**Claims:**
- The translator classifies every one of the 53 authenticated custom codes as the inventory specifies.
- It classifies representative implicit, transport, Storage and Auth failures safely.
- No converted call site displays raw backend text.
- The real `uploadCollaborationAsset` makes no request for an empty file.
- The existing specific error UX is intact.
- `index.html` has no syntax errors.
- In the **real application page** (§10): the translator initialises; the zero-byte guard blocks before any identity lookup, Storage request or insert; the message-edit and task-title length boundaries hold; and the translator produces safe copy in the real page context, with no Phase 21.9 JavaScript error or uncaught exception.

**Does not claim:**
- Behaviour against a live backend. Every browser run was network-isolated. Backend-dependent paths were driven by local stubs, and the SDK never loaded, so the authenticated application UI was not exercised.
- Anything about backend behaviour: no RPC, Storage or Auth request was made to Supabase.
- That the inventory stays current. It is a 2026-09-14 snapshot; the static check fails if the translator and the snapshot drift apart.

> **Finding-status note.** Finding status lives in `analysis/phase-21.3/backend-contract.md` §0.2. S-4 is recorded there as **REMEDIATED — Phase 21.9**: remediation implemented, independently reviewed, locally validated, merged as PR #20 (merge commit `2df2734`) and validated post-merge on that exact `main` (§12), network-isolated.

---

## 2. Files

| Path | State | SHA-256 (LF-normalized) |
|---|---|---|
| `index.html` | modified: +158 / −65 | `249109be9a694ba8a9ab7a9a090be94d5d10ca440e1a2264ccffec90e7771ead` (base `7f0b1d6a…04aa9`) |
| `analysis/phase-21.9/error-codes.tsv` | new — inventory snapshot | `9b21f83be3ac28daf8250eefbbee0758955cdc3832c8213745e3e72233fe4cf8` |
| `analysis/phase-21.9/static-check.sh` | new | `55f8be3829122b2105373c1803a67cb5e9131f73d232b1e694632cafd896a0e3` |
| `analysis/phase-21.9/error-contract-harness.html` | new | `4007d4156636b3b3066312add2c3517defc99e1c54a4dc29d3e3a9bbf44fecb8` |
| `analysis/phase-21.9/phase-definition.md`, `validation.md` | new | — |
| `analysis/phase-21.3/backend-contract.md` | modified — S-4 status notes only | — |

**Line endings:**
- `index.html` is LF in the index and CRLF in the working tree (`core.autocrlf=true`), with no mixed endings.
- `git diff --check` is clean.

**Not touched:** no Edge Function, SQL, workflow or other application file.

---

## 3. Static invariants — `bash analysis/phase-21.9/static-check.sh`

**Result: 41 passed, 0 failed, exit 0.** Needs no browser, server or network.

| Group | Checks | Result |
|---|---|---|
| M. Map coverage | M-1 58 codes; M-2 53 client-facing; M-3 5 admin; M-4 block extracted between markers; M-5 exactly 53 mapped (11 specific, 15 not-found, 11 forbidden, 16 defensive); M-6 no duplicates; M-7 every code classified as the inventory states; M-8 no code outside the inventory; M-9 code lookup precedes every HTTP-status rule; **M-10 the session rule maps PGRST301, PGRST302 and PGRST303 to `AUTH_REQUIRED`** | **10/10** |
| R. Raw text eliminated | R-1 no legacy raw-message variables; R-2 no `error.hint`/`details`; R-3 no `JSON.stringify` of errors; R-4 no `showToast` reading `.message`; R-5 no `textContent`/`innerHTML` reading `.error.message`; R-6 no "unknown error" suffix copy; R-7 29/29 translator calls pass literal fallback copy; R-8 20 `supaRpc` sites; R-9 20/20 RPC callers use the translator; R-10 3/3 displaying direct-write callers (5 writes) use it, plus 2 silent writers; R-11 3/3 Storage upload/download callers; R-12 auth OTP routed; R-13 no Storage path in upload copy | **13/13** |
| Z. Zero-byte guard | Z-1 guard before identity lookup, upload and insert; Z-2 releases busy state and returns | **2/2** |
| E. Edit length checks | E-1/E-2 present; E-3/E-4 copy consistent across create, edit and map | **4/4** |
| U. Existing UX | U-1..U-8: 23505 handler and APPLIED button state, P0012, P0013, P0053 copy | **8/8** |
| L. Diagnostics | L-1 `requestPayload` only in the pre-existing REQUEST log; L-2 no `params` in the RPC failure log | **2/2** |
| S. Scope | S-1 only approved paths changed; S-2 no Edge Function, SQL or workflow file | **2/2** |

---

## 4. Offline browser harness — `error-contract-harness.html`

**Environment:**
- Microsoft Edge (Chromium), `--headless=new`, fresh temporary profile.
- `--host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"`, so **no host other than 127.0.0.1 could be resolved**.
- Served by a throwaway local static server bound to 127.0.0.1; the server received only `index.html` and `error-codes.tsv`.
- The Supabase SDK is not loaded, and every network-facing dependency is a counting stub.

**Result: `PASS 55/55`** (`document.title`). The first runs recorded 53/53; the two assertions added for PGRST302 during review corrections (§9) make 55.

| Group | Assertions | Result |
|---|---|---|
| 0. Extraction and syntax | inline script found; **every inline script compiles**; translator block found | 3/3 |
| A/B. Coverage | 58 = 53 + 5; all 53 map to the inventory category at HTTP 500; category independent of HTTP status (400, 409); 11 specific + 26 grouped + 16 defensive; copy rules (specific exact, grouped shared, defensive uses the action fallback); no leak in any of the 53 outputs; **P0032 and P0033 identical**; 5 admin codes absent from the map; admin codes fall to `INTERNAL_ERROR` | 9/9 |
| C/D. Implicit and transport | 23505, 23514, 23503, 42501 → safe generic; **PGRST301, PGRST302, PGRST303** and bare 401 → `AUTH_REQUIRED`; **PGRST301/302/303 each show exactly the session copy**, even when message, details and hint carry raw text; status 0 (object and string) → `NETWORK_ERROR`; unknown code, 5xx non-JSON and PGRST000 → safe generic; 40001 → `CONFLICT_RETRY`; Storage 403 → generic, Storage 401 → `AUTH_REQUIRED`; Auth 429 → `RATE_LIMITED`; null and undefined → generic; every COPY entry leak-free | 21/21 |
| F. Zero-byte guard (real function) | size 0: **0 Storage requests, 0 identity lookups, 0 inserts**; busy guard released once; empty-file copy shown; missing size and negative size also blocked; size 1 control proceeds to upload and insert; Storage upload failure shows safe copy with no insert; metadata failure with cleanup OK, and with cleanup failed, both show safe copy and no Storage path | 9/9 |
| G. Existing UX and converted sites | 23505 → "You already applied." and APPLIED/disabled; P0012; P0013; own post blocked client-side with 0 RPCs; P0001 → session copy; unknown → action fallback; network → connection copy; P0053 exact copy; credit P0014 → read-only; `closeWantedPost` P0008 → not-found copy and a forbidden code → forbidden copy; every driven toast leak-free; ≥ 80 outputs examined | 13/13 |

**Leak criteria applied to every output:**
- no snake_case, no `P0xxx` or `23xxx`/`42xxx`/`40xxx` codes;
- no backend token from the inventory;
- no constraint name (all 44 in the relevant tables), no table name;
- none of: `violates`, `duplicate key`, `Key (`, `Failing row`, `row-level security`, `relation "`, `JWT`, `PGRST`, `SQLSTATE`, `null`, `undefined`, `[object`, braces or double quotes.

### 4.1 Harness defect found and fixed during validation

The first run reported 52/53. The syntax assertion failed ("Unexpected identifier 'here'") because an HTML comment near the top of `index.html` mentions a `<script>` tag in prose, and the extractor treated it as a script.

**Checked independently with Deno:** the identical failure occurs on the **unmodified base** `index.html`, and the real application script compiles in both base and branch. The harness now strips HTML comments before extracting scripts. **No application code changed as a result.**

### 4.2 Mutation test — the checks detect regressions

A scratch copy of `index.html` (outside the repository) was given three faults:
1. the zero-byte guard disabled;
2. P0033 given a message distinct from P0032;
3. `closeWantedPost` reverted to `showToast(result.error.message)`.

| Tool | Result against the mutant |
|---|---|
| Harness (53-assertion version, before §9) | **FAIL 8 of 53.** Caught all three faults: P0032/P0033 identity, all four zero-byte assertions, both `closeWantedPost` copy assertions, the driven-toast leak scan |
| Static check | Caught faults 1 and 3 (R-4, R-9, Z-1, Z-2). **Did not catch fault 2**: the category was unchanged, and M-7 checks categories, not copy. The harness covers it. The run also showed spurious M-1/M-2/M-3/M-8 failures, an artefact of running the copied script outside the repository |

---

## 5. Regression — existing Phase 21.2 static check

`bash analysis/phase-21.2/static-check.sh` on the branch: **57 passed, 0 failed, 0 skipped.**
- S-35..S-38 confirm `goTo()`, `checkSessionAndStart()`, `enterApp()` and the `onAuthStateChange` body are byte-identical to that phase's base.
- S-42 confirms LF in the index and CRLF in the working tree.

**Network disclosure:** section 7 of that script (S-43..S-47) downloads the pinned public `@supabase/supabase-js@2.112.1` bundle from **cdn.jsdelivr.net** to re-verify its SRI hash. I attempted to force that section to skip with a failing `curl` stand-in, but the stand-in's directory path contained `C:` and the colon broke the PATH entry, so the real `curl` ran.
- **What it did:** read-only GETs of a public CDN asset, twice (the branch run and a comparison run). All live hash, version and CORS checks passed.
- **What it did not touch:** Supabase, production, or anything application-specific.

---

## 6. Level 3 browser-validation checklist (`.apos/VALIDATION_STANDARD.md` §4)

| Item | Status |
|---|---|
| No unexpected console errors | **PASS in the real application** (§10.5): no uncaught exception and no syntax, type or reference error. Only expected network-block messages, the intended diagnostic logs of the stubbed failures, and one unrelated browser-extension log |
| No duplicate UI entries | Not applicable (no rendering change) |
| Correct immediate UI behaviour | **PASS in the real application**: exact copy shown in the real `#toast` and `#caUploadStatus` elements for the zero-byte and length-guard cases |
| Correct success reconciliation | **Partially applicable.** 1-byte upload and 5000/300-character edits pass the new guards and reach the next step. That step was a local stub; the live success path against the backend was deliberately not exercised |
| Correct failure rollback | **PASS in the real application**: busy state released (`true → false`, control re-enabled) after the zero-byte rejection and after each stubbed failure; no insert after a failed upload |
| Whole-area loading flash | Not applicable |
| Slow-network behaviour | Not applicable (no change to request timing) |
| Offline / failed-request behaviour | **PASS in the real application**: blocked SDK yields the Phase 21.2 startup-failure screen; a stubbed status-0 failure shows the connection copy |

---

## 7. Git and repository state

- **Branch:** `phase-21.9-s4-error-contract`, created from `main` at `b1582a9`.
- **Product commit:** `ab3a46df3790d33d794435eab241e3da1524f67f` "feat(phase-21.9): add safe frontend error contract". Parent `b1582a92c3dc9190614403434ff7688b66c4267b`; 7 files: `index.html`, `analysis/phase-21.3/backend-contract.md` and the five `analysis/phase-21.9/` files.
- **Documentation commit:** `3040fdfb3d459b56a8675adaaa5b705f4521d1bf` "docs(phase-21.9): record local validation" records the completed local validation. It changes only `phase-definition.md`, `validation.md` and `backend-contract.md`; `index.html` is unchanged.
- **Push:** branch `phase-21.9-s4-error-contract` pushed to `origin` with explicit approval (normal push, no force). A later documentation-only commit, `24252a6` "docs(phase-21.9): record PR status", recorded the PR status.
- **PR #20:** **merged** into `main`. Merge commit `2df2734247f5f1cccf0ae689d6e121775dea652b`, parents `b1582a9` and PR head `24252a63c41101b7623d39f68ac35fd209beb8c9`. The merged tree has no file differences from the PR head. The branch is retained.
- **Checks observed on the earlier PR head `3040fdf`, while PR #20 was open (historical):**
  - the Netlify deploy-preview commit status reported `success`;
  - three Netlify check runs (redirect rules, header rules, pages changed) completed with conclusion `neutral`;
  - no GitHub Actions workflow runs exist for this branch.
  - Checks re-run on each new head commit. The Netlify deploy preview is an automatic, non-production preview build.
- **Scratch-only artefacts** (the local server script, headless profile, mutant copy, DOM dumps) live in the session scratchpad, not the repository.
- **Review bundle:** the independent review used a plain-text bundle generated outside the repository. It is not part of the repository.

---

## 8. Unresolved and out of scope

1. **Live-backend behaviour is unvalidated.** All browser validation, including the post-merge validation (§12), was network-isolated; any test-project or production validation needs its own approval.
2. **The inventory is a snapshot.** New backend codes need a translator entry; unmapped codes fail safe to the action fallback.
3. **The pre-existing `supaInsert REQUEST` log** still records every insert payload in the console.
4. **Backend taxonomy items are left for a later phase:** HTTP 500 for P0002–P0059, P0001's collision with the PL/pgSQL default code, duplicate `delete_failed` codes, unlocked check-then-act races, no UNIQUE constraint on credits.
5. **Copy is English-only**, consistent with the rest of the UI.

---

## 9. Independent pre-commit review

An independent ChatGPT review of the complete pre-commit bundle (full `index.html` and `backend-contract.md` diffs, all new files, focused extracts, static searches, scope review) is **complete**.

**Outcome:** implementation **approved subject to two small corrections**, both applied without any product-code change.

| # | Correction | Applied |
|---|---|---|
| 1 | The translator already mapped PGRST301, PGRST302 and PGRST303 to `AUTH_REQUIRED`, but the harness only exercised 301 and 303 | Added an explicit PGRST302 case, plus one assertion that all three show exactly the session copy (harness 53 → **55**). Added static check **M-10**, which confirms the session rule names all three codes (static 40 → **41**). Translator mapping unchanged |
| 2 | Documentation still listed the review as outstanding | Status wording updated here, in `phase-definition.md` and in the `backend-contract.md` S-4 row |

**After the corrections, offline only:** static check **41/41**, harness **55/55**, every inline script compiles, `git diff --check` clean. The Phase 21.2 check's network-capable section was **not** run.

**What the review did not change (state at review time):** real-application Level 3 validation, approval to commit, commit, push, PR and production confirmation were still outstanding. Level 3 local validation and the local commit were completed afterwards (§10, §7), followed by the merge and post-merge validation (§11, §12). At review time S-4 was still OPEN; it is now **REMEDIATED — Phase 21.9** (§12).

---

## 10. Real-application Level 3 local browser validation

**Result: `L3 PASS 50/50`.** Run against the working tree that became commit `ab3a46d`; `index.html` SHA-256 (LF-normalized) `249109be…1ead`, identical to the committed file.

### 10.1 Method and network isolation

- **Browser:** Microsoft Edge (Chromium), `--headless=new`, fresh temporary profile. Background networking, component updates, sync and pings disabled.
- **Isolation, two independent layers:**
  - `--host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"`, so every hostname except 127.0.0.1 was unresolvable;
  - `--proxy-server=http://127.0.0.1:9` (a dead proxy), so non-loopback traffic, including IP literals, could not connect.
  - The rules were never relaxed.
- **Evidence:** Chromium's network log (`--log-net-log`, 1,440 events) and the browser console captured on stderr.
- **Server:** a throwaway local server bound to 127.0.0.1 served the working tree read-only and logged every request.
- **Test page:** kept outside the repository. It loaded the **real `index.html`** in a same-origin iframe. After boot, only the network-facing globals in the app's own window were replaced with counting stubs: `fetch`, `getMyDomainId`, `supaRpc`, `supaInsert` and `supabaseClient`. The real `showToast` and busy-state helpers stayed in place. The real functions were then called directly.

### 10.2 Results

| Area | Assertions | Result |
|---|---|---|
| Real application boot | real `index.html` loaded; `classifyBackendError` and `backendErrorMessage` present; `BACKEND_ERROR_COPY` (12), `BACKEND_ERROR_SPECIFIC` (11) and `BACKEND_ERROR_GROUPS` (15/11/16) initialised; functions defined after the translator block present, so the whole script executed; the blocked SDK produced the expected Phase 21.2 startup-failure state (`sdk-unavailable`, `#screen-boot`, "STAGERZ could not start. Please check your connection and reload."); no raw backend token or database text rendered | 8/8 |
| Zero-byte upload guard (real `uploadCollaborationAsset`) | real 0-byte `File` → toast and `#caUploadStatus` show "This file is empty and cannot be uploaded."; busy state `true → false`, button re-enabled; function returned; `getMyDomainId` 0, Storage upload 0, metadata insert 0, fetch 0. **1-byte control:** passes the guard and reaches the identity lookup and the **stubbed** Storage upload (1/1/1); stubbed failure shown only as "Upload failed. Please try again."; no insert; busy released; fetch 0 | 17/17 |
| Message edit (real `saveMessageEdit`) | **5001** characters → "Message is too long (max 5000 characters)."; RPC 0, fetch 0. **5000** characters pass the guard and reach only the intercepted RPC stub; its simulated network failure shows the connection copy; busy released; fetch 0 | 4/4 |
| Task title edit (real `saveCollaborationTaskTitle`) | **301** characters → "Title is too long (max 300 characters)."; RPC 0, fetch 0. **300** characters pass the guard and reach only the intercepted stub; connection copy; busy released; fetch 0 | 4/4 |
| Translator smoke test (real page context) | P0001 → session copy; P0014 → read-only; P0032 and P0033 → **identical** copy; P0040 → transfer-first; P0053 → established copy; PGRST301/302/303 → **identical** session copy; status 0 → connection copy; unknown code → safe action fallback. Every input carried raw `message`, `details` and `hint` text (snake_case token, `violates constraint`, `Key (`, `Failing row`, `SQLSTATE`); **none reached any output** | 16/16 |
| Network stub summary | no `fetch` reached the app-window stub during the tests | 1/1 |

### 10.3 Network audit

| Measure | Count |
|---|---|
| Localhost requests served (server log) | **4**: the test page 200, `/index.html` 200, `/analysis/phase-21.9/error-codes.tsv` 200, `/favicon.ico` 404 |
| Attempted external requests (network log) | **27** records, 11 distinct URLs: the jsdelivr SDK, Google Fonts, 2 antivirus-injected script loads (§10.4), and Edge background services (edge.microsoft.com, bing.com, arc.msn.com) |
| **Successful external requests** | **0**: every attempt ended with `ERR_PROXY_CONNECTION_FAILED` or received no response headers |
| TCP connections to non-loopback addresses | **0** |
| **Supabase requests attempted / sent** | **0 / 0** |

### 10.4 Environment observation — antivirus script injection

The workstation's **Kaspersky** antivirus intercepts local HTTP traffic. It inserted a `<script src="http://me.kis.v2.scr.kaspersky-labs.com/…/main.js">` tag into the locally served pages (the test page and `index.html`) as they reached the browser.

- **Not STAGERZ:** the tag is not part of `index.html`, and no repository file was changed.
- **Never loaded:** the network isolation blocked it (`ERR_PROXY_CONNECTION_FAILED`), so it could not influence the results.

**This is an environment observation, not a STAGERZ defect.**

### 10.5 Console review

| Class | Messages |
|---|---|
| A. Expected, caused only by network blocking | "STAGERZ startup failed: sdk-unavailable"; blocked SDK and Google Fonts loads; the blocked injected script; failed Edge background requests |
| B. Phase 21.9-related | only the intended diagnostic logs of the deliberately failing stubs (`uploadCollaborationAsset: Storage upload result` / `…FAILED -- no metadata insert attempted`; `edit_collaboration_message result` / `FAILED`; `edit_collaboration_task result` / `FAILED`). No warnings or errors in the Phase 21.9 code |
| C. Unrelated | one log line from Edge's built-in component extension |

**No uncaught exception and no syntax, type or reference error.**

### 10.6 Repository integrity

- The repository fingerprint (HEAD, branch, status, full diff and untracked files) was **identical** before and after the browser run.
- `git diff --check` was clean.
- `index.html` was unchanged.
- All browser artefacts (server, test page, profile, network log, console capture, DOM dump) stayed in the session scratchpad.

---

## 11. Phase 21.9 closure steps

Each step was approved separately:

1. **PR #20 review and merge.** PR #20 was merged into `main` as merge commit `2df2734` (§7). Under `.apos/VALIDATION_STANDARD.md` §8 a merge to `main` is a production release.
2. **Post-merge validation of the exact merged `main`.** Complete, 2026-09-15 (§12).
3. **Live-backend release or test-project validation.** Not performed; none was approved. The closure decision rests on the network-isolated validation of §12.
4. **Final S-4 closure** in `analysis/phase-21.3/backend-contract.md` §0.2. Complete: **S-4 REMEDIATED — Phase 21.9.**

---

## 12. Final post-merge validation and S-4 closure record

**Main validated:** `2df2734247f5f1cccf0ae689d6e121775dea652b` (merge of PR #20; parents `b1582a9` and PR head `24252a6`)
**Date:** 2026-09-15
**Result:** **PASS** on every check.

### 12.1 Synchronization and integrity

- Local `main` was fast-forwarded to `origin/main` with a read-only fetch. Local `main` = `origin/main` = `2df2734`; working tree clean.
- The merged tree has no file differences from PR head `24252a6`.
- `index.html` on `main` is byte-identical to the reviewed product state: SHA-256 (LF) `249109be…1ead`, the same blob as product commit `ab3a46d`.
- Confirmed present on `main`: the backend error contract block and both functions; the zero-byte upload guard; the 5000-character message-edit and 300-character title-edit checks; the PGRST301/302/303 session rule; P0032 and P0033 both `TARGET_UNAVAILABLE` with one shared message.
- Raw-display regression searches (raw-message variables, `showToast` reading `.message`, `error.details` / `error.hint`, `JSON.stringify` of errors, `textContent` / `innerHTML` reading message, details or hint): **0 matches**.
- All five Phase 21.9 validation files are present on `main`.

### 12.2 Results

| Check | Result |
|---|---|
| Static invariants (`static-check.sh`) | **41/41 PASS**; S-1 confirms only the 7 approved paths differ from `b1582a9` |
| Offline browser harness | **55/55 PASS** |
| Syntax | application script compiles; the one script-extraction error is the known HTML-comment false positive (§4.1), identical on the base |
| `git diff --check` | clean, `b1582a9..2df2734` and working tree |
| Real-application Level 3 | **50/50 PASS** |
| Successful external requests | **0** |
| Supabase requests attempted / sent | **0 / 0** |
| TCP connections to non-loopback addresses | **0** |
| Repository during validation | **unchanged** — identical fingerprint (HEAD, branch, status, diff, untracked files) before and after |

The Phase 21.2 static check was not re-run, so its network-capable section was not used.

### 12.3 Level 3 checks on the merged `index.html`

Method as §10.1: headless Edge, fresh profile, hostname resolution blocked except 127.0.0.1, dead proxy for all non-loopback traffic, network log and console captured; the real `index.html` served from 127.0.0.1 and driven in a same-origin iframe with the network-facing globals replaced by counting stubs.

| Area | Result |
|---|---|
| Boot and script integrity | Real `index.html` loaded and executed fully; translator tables initialised (12 / 11 / 15-11-16); blocked SDK produced the expected `sdk-unavailable` startup state; no raw backend text rendered |
| Zero-byte upload | Rejected before the identity lookup: "This file is empty and cannot be uploaded." in the toast and upload status; identity lookup 0, Storage upload 0, metadata insert 0, fetch 0; busy state `true → false` |
| 1-byte control | Passes the guard and reaches only the stubbed identity lookup and stubbed upload; stubbed failure shows "Upload failed. Please try again."; no insert, no raw Storage text; busy released; fetch 0 |
| Message edit boundary | **5001** rejected locally with the 5000-character message, 0 RPC, 0 fetch; **5000** passes to the intercepted RPC stub; safe connection copy; busy released |
| Task title boundary | **301** rejected locally with the 300-character message, 0 RPC, 0 fetch; **300** passes to the intercepted RPC stub; safe connection copy; busy released |
| Translator smoke test | P0001 and PGRST301/302/303 → `AUTH_REQUIRED`, identical session copy; P0014 → `READ_ONLY`; P0032 and P0033 → `TARGET_UNAVAILABLE`, identical copy; P0040 → `TRANSFER_REQUIRED`; P0053 → `ALREADY_EXISTS`, established copy; status 0 → `NETWORK_ERROR`; unknown code → `INTERNAL_ERROR` with the safe action fallback |
| Hostile raw backend data | Inputs carried raw `message`, `details` and `hint` text; **none reached any output**; no snake_case token displayed |
| Console review | No uncaught exception; no syntax, type or reference error. Only the expected `sdk-unavailable` startup message, the intended diagnostic logs of the deliberately failing stubs, and one unrelated line from Edge's built-in component extension |

### 12.4 Network audit

- Loopback: **4** successful requests, matching the server log (test page, `index.html`, `error-codes.tsv`, `favicon.ico` 404).
- External: **25** attempts recorded (the jsdelivr SDK, Google Fonts, the antivirus-injected script, Edge background services); **0 successful** — each failed at the dead proxy or received no response.
- Supabase: **0** attempted, **0** sent.

**Environment observation.** Kaspersky again injected its `main.js` script tag into the locally served pages (§10.4). The isolation blocked it, so it never loaded and could not affect the results. This is an environment observation, not a STAGERZ defect.

A first Level 3 launch was discarded before any test ran: a Git Bash path conversion in the throwaway server's read-permission argument made it answer 404 for the test page (2 loopback requests, nothing executed). The rerun with Windows-style paths is the result above.

### 12.5 What this validation does not claim

- **Production Supabase was not exercised.** The validation was deliberately network-isolated; backend-dependent paths were driven by local stubs, and no RPC, Storage, Auth or Edge Function request reached Supabase.
- No database row, Storage object, Edge Function, secret, deployment or GitHub setting was changed by the validation.

### 12.6 Closure

The exact merged `main` matches the reviewed product state and passes every static, harness and real-application Level 3 check. The closure was explicitly approved.

**S-4 REMEDIATED — Phase 21.9.**

Recorded in `analysis/phase-21.3/backend-contract.md` §0.2 by a documentation-only commit that changes this file, `phase-definition.md` and `backend-contract.md`; `index.html` is not changed by it.
