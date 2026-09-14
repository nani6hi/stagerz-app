# Phase 21.9 — Validation Record

**Branch:** `phase-21.9-s4-error-contract`
**Base commit:** `b1582a92c3dc9190614403434ff7688b66c4267b`
**Validation level required:** **3** (`index.html` behaviour changes)
**Status:** **IMPLEMENTED LOCALLY, INDEPENDENTLY REVIEWED — NOT YET PRODUCTION VALIDATED. S-4 is NOT REMEDIATED.**
- **Done:**
  - implementation, locally on the branch;
  - independent pre-commit review, approved subject to two corrections, both now applied (§9);
  - Level 1 static review, static invariants (**41/41**) and the offline browser harness (**55/55**, headless Edge).
- **Outstanding:** real-application Level 3 browser validation, explicit approval to commit, commit, push, PR, and post-merge/production confirmation.

**S-4 remains OPEN.**

---

## 1. What this record claims, and what it does not

**Claims:**
- The translator classifies every one of the 53 authenticated custom codes as the inventory specifies.
- It classifies representative implicit, transport, Storage and Auth failures safely.
- No converted call site displays raw backend text.
- The real `uploadCollaborationAsset` makes no request for an empty file.
- The existing specific error UX is intact.
- `index.html` has no syntax errors.

**Does not claim:**
- Behaviour in the running application against a live backend. The harness drives extracted functions against stubs.
- Anything about backend behaviour: no RPC, Storage or Auth request was made to Supabase.
- That the inventory stays current. It is a 2026-09-14 snapshot; the static check fails if the translator and the snapshot drift apart.

> **Finding-status note.** Finding status lives in `analysis/phase-21.3/backend-contract.md` §0.2. S-4 is recorded there as **OPEN**: remediation implemented locally and independently reviewed, real-application validation pending, not committed.

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
| No unexpected console errors | **Not yet run in the real application.** The harness compiled every inline script without error |
| No duplicate UI entries | Not applicable (no rendering change) |
| Correct immediate UI behaviour | Harness-verified for the driven functions; **pending in the real app** |
| Correct success reconciliation | Harness control case (1-byte upload proceeds); **pending in the real app** |
| Correct failure rollback | Harness-verified (busy guard released; no insert after upload failure); **pending in the real app** |
| Whole-area loading flash | Not applicable |
| Slow-network behaviour | Not applicable (no change to request timing) |
| Offline / failed-request behaviour | Harness-verified (status 0 → connection copy); **pending in the real app** |

---

## 7. Git and repository state

- **Branch:** `phase-21.9-s4-error-contract`, created from `main` at `b1582a9`.
- **Working tree:** `index.html` and `analysis/phase-21.3/backend-contract.md` modified; `analysis/phase-21.9/` untracked.
- **No commit, no push, no PR.**
- **Scratch-only artefacts** (the local server script, headless profile, mutant copy, DOM dumps) live in the session scratchpad, not the repository.
- **Review bundle:** the independent review used a plain-text bundle generated outside the repository. It is not part of the repository.

---

## 8. Unresolved and out of scope

1. **Real-application Level 3 validation is outstanding** (§6).
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

**What the review does not change:** real-application Level 3 validation, approval to commit, commit, push, PR and production confirmation are still outstanding. **S-4 remains OPEN and is not REMEDIATED.**
