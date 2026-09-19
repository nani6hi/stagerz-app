# Phase 22.3 — Production / Test Label Inventory (F)

**Status:** inventory only; **wording not changed yet**. Update 2026-09-19: L-4 and L-5 (the hard-coded backend and redirect) were addressed by owner decision 4. `index.html` now selects the backend and the redirect by hostname (`frontend-environment-mapping.md`), with production values unchanged. The comment wording (L-1 … L-3) still awaits the §5 product decision.

**Classes:**
- **F1** documentation-only;
- **F2** code comment only (no runtime effect);
- **F3** user-visible;
- **F4** runtime-affecting.

**Rule proposed for the cleanup step:**
- **Current** documents and code are corrected.
- **Historical records** (`analysis/phase-*` files, applied-SQL headers) are **not rewritten**. They describe what was true, or believed, when written. At most a pointer note is added where a stale header could mislead a future reader.

## 1. Code — `index.html`

| # | Location | Text (short) | Class | Note |
|---|---|---|---|---|
| L-1 | `index.html:330-332` (HTML comment) | "AUTH: MAGIC LINK WAIT (TEST ONLY -- disposable project's hosted email template sends {{ .ConfirmationURL }} … cannot be edited without custom SMTP" | **F2** | Also encodes a **design intent** (see §5) |
| L-2 | `index.html:1403-1410` (JS comment) | "AUTH: EMAIL MAGIC LINK (TEST ONLY)", "The disposable test project's hosted email template…", "This test flow still calls signInWithOtp() … only the post-send UI and verification path differ from production." | **F2** | Same design intent |
| L-3 | `index.html:1440` (JS comment) | "verifyOtpCode() removed in the test version" | **F2** | Same |
| L-4 | `index.html:1013-1014` | `SUPA_URL` / `SUPA_KEY` hard-coded to the production project | **F4** | Not a wrong label (it *is* production now), but it is the single-environment coupling addressed by design G |
| L-5 | `index.html:1423` | `emailRedirectTo: 'https://stagerz.app'` | **F4** | Correct for production; must become environment-derived with G3 |
| — | User-visible UI strings | No "test", "demo", "beta" or "disposable" text is shown to users (the "demo" hits at `:1815-1816, 2010` are a local UI demo card, unrelated to the backend) | **F3: none** | — |

## 2. Supabase metadata

| # | Item | Class | Note |
|---|---|---|---|
| L-6 | Project name `stagerz-foundation-v2-test` | F1-like (dashboard metadata, not in the repo) | Rename is **owner decision 3**. The ref `kbnmkyvbwkuvcklywdhk` is permanent |
| L-7 | `supabase/functions/delete-account/index.ts:9` fallback origin `https://stagerz.app` | F4 (correct for production) | Per-environment via `STAGERZ_ALLOWED_ORIGIN` |
| L-8 | `.github/workflows/process-pending-asset-deletions.yml:45` production function URL | F4 (correct for production) | A test environment would need its own dispatch target (not in scope) |

## 3. Current documentation — `.apos/PROJECT_CONTEXT.md`

| # | Line | Text (short) | Class | Proposed treatment |
|---|---|---|---|---|
| L-9 | `:15` | "whether that project is the intended production store or a test project is **not established**" | F1, **stale** (superseded by Phase 22.2) | Replace with "production backend of record (Phase 22.2)" |
| L-10 | `:16` | "Fix, test project only (`kbnmkyvbwkuvcklywdhk`)" | F1, stale wording | Reword to "production (`kbnmkyvbwkuvcklywdhk`)" |
| L-11 | `:17` | "whose production / test status is not established" | F1, stale | As L-9 |
| L-12 | `:186` | "applied to the test project as migration `20260916215204`" | F1, stale wording | Reword |
| L-13 | `:299` | Open question quoting "disposable test project" / "TEST ONLY" (stale line refs 307–310, 1218–1225; now 330 and 1403) | F1, **answered** by Phases 22.0 and 22.2 | Mark resolved, with a pointer |
| L-14 | `:18`, `:20`, `:321` | Phase 22.0 and 22.2 records ("disposable Foundation v2 test environment", "originated as a test environment") | F1, **accurate history** | Keep |
| L-15 | `:71` (and `analysis/phase-21.3/backend-contract.md:272`) | Cite `index.html:1329` for `emailRedirectTo` (now `:1423`) | F1, stale reference | Update the line reference |

## 4. Historical records (not to be rewritten)

`analysis/` holds 35 files in 11 directories that say "test project", "disposable", "TEST ONLY" or `stagerz-foundation-v2-test`:
- backend-integrity-remediation 6;
- phase-20.7 1, phase-21.1 1;
- phase-21.3 9, phase-21.3-r5-remediation 5;
- phase-21.4 1, phase-21.5 4, phase-21.6 2, phase-21.7 2;
- phase-22.0 2, phase-22.2 2.

Two cases deserve a **pointer note**, not a rewrite:

| # | File | Issue |
|---|---|---|
| L-16 | `analysis/backend-integrity-remediation/migration.sql`, `analysis/phase-21.3-r5-remediation/migration.sql` | Headers still say "PREPARED, NOT APPLIED", although both were applied (`20260916215204`, `20260917143322`) |
| L-17 | `analysis/phase-21.4/5/7 migration.sql` | "the ONLY permitted production mutation" versus "test project" elsewhere. Resolved by Phase 22.2 (it was production de facto) |

## 5. Design intent hidden in L-1 … L-3 (surfaced for the owner)

The comments say the **intended production sign-in** is a **numeric e-mail OTP code** (`verifyOtpCode()`), and that the shipped **magic-link** flow is a "test version". It exists only because the hosted default e-mail template sends a link and cannot be edited without custom SMTP.

With `kbnmkyvbwkuvcklywdhk` now production, the cleanup must decide which is true:
- **(a)** magic link is the accepted production flow, so the comments are reworded; or
- **(b)** the OTP-code flow remains the goal, so it is tracked with the **custom SMTP** phase, where the template becomes editable.

This is a product decision tied to SMTP. It is out of Phase 22.3's runtime scope; the comment wording will follow the decision.
