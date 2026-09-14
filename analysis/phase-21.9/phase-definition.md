# Phase 21.9 — Frontend error contract (S-4)

**Branch:** `phase-21.9-s4-error-contract`
**Base commit:** `b1582a9` (`main`, merge of PR #19 — Phase 21.8B closure)
**Addresses:** finding **S-4** — backend error codes reach the user as raw tokens
**Classification:** **UX / error-contract defect with a LOW information-disclosure component** — not a data-exposure vulnerability
**Status:** **IMPLEMENTED LOCALLY, INDEPENDENTLY REVIEWED — NOT YET PRODUCTION VALIDATED.**
- **Done:** implementation on the branch; independent pre-commit review (approved subject to two corrections, both applied); static check (41/41) and offline browser harness (55/55).
- **Outstanding:** real-application Level 3 browser validation, approval to commit, commit, push, PR, production confirmation.
- **Not committed, not pushed, no PR. S-4 remains OPEN — not REMEDIATED.**
**Validation level required:** **Level 3** — `index.html` behaviour changes (`.apos/VALIDATION_STANDARD.md` §2)

---

## 1. Objective

Stop showing raw backend text to users, with the smallest safe change: one frontend translation layer between every backend failure and the UI. Also close the zero-byte upload path, which is a directly reachable raw constraint error and a new source of Storage orphans.

**Not changed:** any database function, SQLSTATE assignment, constraint, policy, Edge Function, workflow or secret.

---

## 2. What the historical S-4 figure meant

`backend-contract.md` §11.3 recorded **58 backend-raised custom codes, 4 frontend-handled, 3 overlapping, so 55 unhandled**.

The **58 is exact** and was re-verified. The **55 overstated the gap**, for three reasons:

1. **Codes, not conditions.** Several codes express one condition (`delete_failed` is P0043, P0051 and P0059; "not found" has seven codes).
2. **No reachability split.** It counted 5 admin-only codes no browser can reach and 16 defensive codes the UI already prevents.
3. **"Unhandled" ignored the fallback.** All 20 RPC call sites already had a generic fallback. The real flaw was that it **displayed** `error.message` (the raw token), `hint`, `details` or the whole error JSON.

---

## 3. Re-derived inventory — read-only, 2026-09-14

Source: live catalog (`pg_get_functiondef`) of `kbnmkyvbwkuvcklywdhk`; the repository contains no current function bodies. Snapshot: `error-codes.tsv`.

| Measure | Count |
|---|---|
| `public` functions | 34 (23 with RAISE: 20 authenticated RPCs + 3 admin) |
| RAISE sites | **121** (116 authenticated + 5 admin), every one `RAISE EXCEPTION '<token>' USING ERRCODE = 'Pxxxx'` |
| Distinct custom codes | **58** — **53** authenticated (P0001, P0008–P0059), **5** admin-only (P0003–P0007) |
| `EXCEPTION WHEN` handlers, row or advisory locks | **0** |

**PostgREST HTTP mapping matters:** P0001 returns HTTP **400**, but every other `P0*` code returns HTTP **500**. A status-first translator would misreport 57 domain errors as server faults.

### Reachability of the 53 authenticated codes

| Class | Codes | Count |
|---|---|---|
| Directly reachable by one user | P0001, P0018 and P0057 (edit paths), P0033, P0053 | 5 |
| Reachable through stale or concurrent state | P0008, 0010, 0011, 0012, 0014, 0015, 0016, 0019, 0020, 0021, 0022, 0023, 0024, 0026, 0030, 0032, 0034, 0035, 0036, 0040, 0042, 0044, 0045, 0046, 0047, 0048, 0050, 0052, 0054, 0055, 0058 | 31 |
| Defensive: UI-prevented, race-only, invariant | P0009, 0013, 0017, 0025, 0027, 0028, 0029, 0031, 0037, 0038, 0039, 0041, 0043, 0049, 0051, 0056, 0059 | 17 |

**The real gap:** 34 reachable codes displayed raw tokens (all reachable codes except the handled P0012 and P0053). They collapse into about 12 user-facing conditions.

**Implicit errors reachable in practice:**
- 23514 on a zero-byte upload, direct.
- 23505 on a taken username, direct.
- 23505 and 23503 through unlocked races.
- 42501 from RLS.
- PGRST301, PGRST302 and PGRST303 for JWT and missing-token problems.
- Status 0 for network failures.

---

## 4. Architecture

**One block in `index.html`,** delimited by `// --- BACKEND ERROR CONTRACT (Phase 21.9 / S-4) ---` and `// --- END BACKEND ERROR CONTRACT ---`:

| Element | Role |
|---|---|
| `BACKEND_ERROR_COPY` | One fixed, safe sentence per category |
| `BACKEND_ERROR_SPECIFIC` | 11 codes with their own category, and optional own copy |
| `BACKEND_ERROR_GROUPS` | `NOT_FOUND_OR_CHANGED` (15), `FORBIDDEN` (11), `INTERNAL_ERROR` (16 defensive) |
| `classifyBackendError(failure)` | Returns `{category, message, code, status}` |
| `backendErrorMessage(failure, fallback)` | The only function call sites use. `fallback` is fixed copy for the action ("Could not send message.") and replaces the generic `INTERNAL_ERROR` sentence |

**Input shapes handled:**
- the helper results `{ok, status, error}` from `supaRpc` and the direct-write helpers, where `error` is a PostgREST JSON body, a string, or `{message:'Network error'}`;
- Storage errors (`status` / `statusCode`);
- Auth errors (`status`, `code`).

**Classification order:**
1. The code is looked up in the specific map, then the groups. **Codes are always matched before any status rule.**
2. `PGRST301`/`PGRST302`/`PGRST303` or HTTP 401 → `AUTH_REQUIRED`.
3. HTTP 429 → `RATE_LIMITED`.
4. Status 0 → `NETWORK_ERROR`.
5. A class-`40` code (serialization failure or deadlock) → `CONFLICT_RETRY`.
6. Anything else, including 23505, 23514, 23503, 42501, PGRST0xx, 5xx, unknown codes and admin codes → `INTERNAL_ERROR`, which shows the action fallback.

**Vocabulary:** `AUTH_REQUIRED`, `VALIDATION_FAILED`, `READ_ONLY`, `TRANSFER_REQUIRED`, `TARGET_UNAVAILABLE`, `ALREADY_EXISTS`, `NOT_FOUND_OR_CHANGED`, `FORBIDDEN`, `CONFLICT_RETRY`, `RATE_LIMITED`, `NETWORK_ERROR`, `INTERNAL_ERROR`.

**`RATE_LIMITED` is an addition** to the proposed vocabulary. The auth email path (`signInWithOtp`) was converted too, and Supabase's email rate limit is the most likely failure there. Without it, users would lose the one actionable signal.

### Specific mappings

| Code | Category | User sees |
|---|---|---|
| P0001 | AUTH_REQUIRED | "Your session has ended. Please sign in again." |
| P0012 | NOT_FOUND_OR_CHANGED | "This Wanted is no longer open." *(unchanged copy)* |
| P0013 | FORBIDDEN | "You cannot apply to your own Wanted." *(unchanged copy)* |
| P0014 | READ_ONLY | "This collaboration is no longer active, so it cannot be changed." |
| P0018 | VALIDATION_FAILED | "Title is too long (max 300 characters)." |
| P0032, P0033 | TARGET_UNAVAILABLE | **one shared message:** "This user cannot be added to the collaboration." |
| P0034 | ALREADY_EXISTS | "This user is already a participant in this collaboration." |
| P0040 | TRANSFER_REQUIRED | "Transfer ownership to another participant before leaving." |
| P0053 | ALREADY_EXISTS | "This participant already has a credit for this collaboration." *(unchanged copy)* |
| P0057 | VALIDATION_FAILED | "Message is too long (max 5000 characters)." |

**P0032 appears in two lists in the approved plan:** it is in the grouped not-found list, and it must share one message with P0033. The explicit privacy requirement wins, so P0032 and P0033 are both `TARGET_UNAVAILABLE`. That leaves 15 codes in the not-found group, not 16.

### Existing specific handlers, preserved

- **`applyToWanted`:** 23505 ("You already applied." and the button becomes `APPLIED`, disabled), P0012 and P0013 remain inline and **unchanged**. The client-side own-post check is unchanged.
- **`createCollaborationCredit`:** P0053 keeps its exact copy, now supplied by the map.
- **Username save:** a new site-specific case. 23505 on the `users` username PATCH can only be `users_username_key` (the PATCH sets only `username`), so it shows "That username is already taken." rather than the raw constraint message.

---

## 5. Call-site conversion

| Group | Sites | Change |
|---|---|---|
| RPC fallbacks (`supaRpc`) | **20 / 20** | `showToast(backendErrorMessage(result, '<existing default copy>'))` |
| Direct REST write fallbacks | **5 writes in 3 functions:** `submitWanted` (insert, update), `saveProfile` (`profiles`, `users`), `uploadCollaborationAsset` (asset insert) | Translator; username 23505 special case; upload copy no longer shows the Storage path or the cleanup error text |
| Silent direct writes | 2 (`markNotificationRead`, `markAllNotificationsRead`) | Unchanged: they display nothing to the user |
| Storage display sites | upload failure, preview failure, download failure | Translator |
| Auth | `sendOtp` | Translator (with `RATE_LIMITED`); raw error now logged to the console instead |

**Console diagnostics:** every site still `console.error`s the raw error. The five helper failure logs no longer include the **request payload** (`params` / `requestPayload`). The pre-existing `supaInsert REQUEST` log, which records every insert payload, is out of scope and unchanged.

---

## 6. Zero-byte upload guard

**Problem:** `uploadCollaborationAsset` uploaded any file to Storage, then inserted the `collaboration_assets` row. For an empty file:
- the insert fails `collaboration_assets_file_size_check` (`file_size > 0`) with a raw 23514 message;
- the browser's cleanup `remove()` is denied (no Storage DELETE policy, by design);
- a **new Storage orphan** is left behind, which is the S-3 path Phase 21.8B cleaned up.

**Change:** at the very start of the function, before `getMyDomainId()`, the Storage upload and the insert:
- if `!file || !(file.size > 0)`, show "This file is empty and cannot be uploaded.";
- release the busy guard;
- return.

Missing, `NaN` and negative sizes are also rejected. **No request of any kind is made.** No size or type guard existed before (no `accept` attribute, no size check), so nothing is duplicated. The database constraint and the cleanup design are unchanged.

---

## 7. Edit-path length checks

The create paths already checked length; the edit paths checked only for empty input, so P0057 and P0018 were directly reachable. Two checks were added, using the same limits and copy as create:
- `saveMessageEdit`: more than 5000 → "Message is too long (max 5000 characters)."
- `saveCollaborationTaskTitle`: more than 300 → "Title is too long (max 300 characters)."

No refactoring was needed.

---

## 8. Validation requirements

Details in `validation.md`.

**Done:**
- **Static check** (`static-check.sh`): inventory and map coverage, raw-text elimination, call-site routing, guard ordering, preserved handlers, logging hygiene, change scope.
- **Browser harness** (`error-contract-harness.html`): the translator, the real `uploadCollaborationAsset`, `applyToWanted`, `createCollaborationCredit` and `closeWantedPost`, extracted at run time and run against stubs with no outbound requests; plus a syntax compile of every inline script and a leak scan of every output.
- **Regression:** the existing Phase 21.2 static check.
- **Independent pre-commit review:** complete; approved subject to two corrections, both applied (`validation.md` §9).

**Outstanding before S-4 can be marked REMEDIATED:**
1. Real-application Level 3 browser validation on the branch (console, UI copy, upload guard in the real page, edit checks).
2. Explicit user approval to commit, then a PR.
3. Post-merge confirmation, with each step approved separately.

---

## 9. Rollback

Revert the branch changes to `index.html`; the analysis files are documentation only. Nothing outside the repository was changed, so there is nothing to roll back in Supabase.

---

## 10. Scope boundary

**In scope:** the translation layer; conversion of RPC, direct-write, Storage and auth error display; the zero-byte guard; the two edit length checks; removing request payloads from helper failure logs; this record and the S-4 status note.

**Out of scope:**
- Backend code taxonomy changes (PostgREST `PTxxx` status mapping, P0001's collision with PL/pgSQL's default code, merging duplicate codes).
- Locking in check-then-act RPCs.
- A UNIQUE constraint for credits.
- The pre-existing `supaInsert REQUEST` payload log.
- Upload rollback redesign.
- The two live asset rows with missing objects.
- Anything in S-3 or S-8.
