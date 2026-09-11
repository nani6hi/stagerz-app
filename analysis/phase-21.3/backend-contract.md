# STAGERZ — Backend Contract

**Phase:** 21.3 — Capture the Backend Contract in the Repository
**Branch:** `phase-21.3-backend-contract`
**Base commit:** `ebfe536`
**Project ref:** `kbnmkyvbwkuvcklywdhk`

---

## 0. Status — read this first

This document has **two halves.**

| Half | Source | Status |
|---|---|---|
| **Client side** — what `index.html` demands of the server | Static audit of the working tree at `ebfe536` | **COMPLETE and authoritative** |
| **Server side** — what the Supabase project actually provides | Live read-only introspection | **Access confirmed; headline counts and several facts captured (§11). Detailed snapshot awaiting delivery** |

Read-only access to `kbnmkyvbwkuvcklywdhk` has been verified and the confirmed results so far are recorded in **§11**. The per-object detail — column lists, constraint definitions, function bodies, policy expressions, grant rows — is being extracted externally and will be transcribed verbatim into the `.sql` artifacts when it arrives.

**Nothing is invented, and no placeholder stands in for data that can now be read live.** Where a fact is confirmed it is stated as confirmed; where detail is still outstanding that is stated plainly rather than filled with a guess.

The client half is not a placeholder either. It is the **demand side of the contract**, derived by exhaustive audit, and it is what the extraction is reconciled against. Every reconciliation check in `validation.md` is expressed against it.

**No backend write of any kind has been performed or attempted at any point in this phase.**

---

### 0.1 Reconciliation notice — read before §11 and §12

> **This document was written BEFORE Phase 21.4. Its S-1 evidence is HISTORICAL.**
>
> **S-1 is REMEDIATED.** Phase 21.4 (PR #11, merge `968b501`, now on `main` at `f4d1fa7`) revoked the write privileges. **`anon` and `authenticated` now hold `SELECT` only** on `public.public_profiles`. Re-verified live on 2026-08-31.
>
> §11.0 and §12 are **preserved deliberately and unedited in substance** — they are the evidence that found and proved the exposure, and erasing them would erase the finding. Read them as *"what was true before Phase 21.4"*, not as current state. Each carries its own banner.

> **A second remediation has since landed. S-2 is also HISTORICAL.**
>
> **S-2 is REMEDIATED.** Phase 21.5 dropped `public._test_results` and `public._test_run_log` on **2026-09-08**. Both tables and both owned sequences are gone; the two `rls_disabled_in_public` Security Advisor ERRORs they produced no longer appear. §11.1 is preserved unedited as the evidence that found the exposure, and carries its own banner.
>
> The 28 rows those tables held are preserved in `analysis/phase-21.5/pre-drop-snapshot.sql`, committed before the drop. Their content is summarised in `analysis/phase-21.5/phase-definition.md` §3.

**Three evidence epochs are used throughout this document:**

| Label | Meaning |
|---|---|
| **HISTORICAL (pre-21.4)** | Captured 2026-08-22/23, before the ACL was fixed. §11.0, §11.4's first paragraph, all of §12 |
| **HISTORICAL (pre-21.5)** | Captured 2026-08-22/23 and re-confirmed 2026-08-31, before the test tables were dropped. §11.1 |
| **CURRENT (post-21.5)** | Re-verified live 2026-09-08 against `kbnmkyvbwkuvcklywdhk`. §0.2. The post-21.4 re-verification of 2026-08-31 stands for §11.4's current-state block and §12.7, neither of which Phase 21.5 touched |

### 0.2 Current status of all findings — S-5, S-6, S-7 rows live-verified 2026-09-11; S-2 row 2026-09-08; all others 2026-08-31

| ID | Finding | Status |
|---|---|---|
| **S-1** | `anon` write path to `public.users` via `public_profiles` | ✅ **REMEDIATED — Phase 21.4 / PR #11.** ACL now `anon=r`, `authenticated=r` |
| **S-2** | `_test_results` / `_test_run_log` world-writable by `anon` | ✅ **REMEDIATED — Phase 21.5.** Both tables dropped 2026-09-08. `public` table count 19 → 17; both owned sequences gone; both Advisor ERRORs cleared; the REST endpoints now return 404. 28 rows preserved in `analysis/phase-21.5/pre-drop-snapshot.sql` |
| **S-3** | No DELETE policy on `storage.objects` | ⚠️ **OPEN** — still only SELECT + INSERT policies |
| **S-4** | Unhandled backend SQLSTATEs | ⚠️ **OPEN** — 58 backend-raised, **55 unhandled** (see §11.3 correction) |
| **S-5** | Default privileges grant ALL on new objects to `anon` | ✅ **REMEDIATED — Phase 21.6.** 2026-09-11: `anon` and `authenticated` removed from the `postgres` TABLES and SEQUENCES defaults in `public` and `storage`; `postgres` and `service_role` retained. Every existing object ACL byte-identical. FUNCTIONS and `supabase_admin` defaults deliberately unchanged |
| **S-6** | `anon` / `authenticated` hold `MAINTAIN` on `public.users` | ⚠️ **OPEN** — found in the Phase 21.6 analysis; residue of an enumerated revoke in migration `20260712144926`. Deferred to Phase 21.7 |
| **S-7** | Three `log_collaboration_*_activity` trigger functions executable by `PUBLIC`, and so by `anon` | ⚠️ **OPEN** — found in the Phase 21.6 analysis; built-in `EXECUTE`-to-`PUBLIC` default, not `pg_default_acl`. Deferred to Phase 21.7 |

**S-1, S-2 and S-5 are now remediated, each by its own approved phase — S-1 by Phase 21.4, S-2 by Phase 21.5, S-5 by Phase 21.6. S-3, S-4, S-6 and S-7 remain OPEN and are remediated by nothing in this document.**

**S-5 was the root cause of S-1 and S-2, and it is now closed for future objects.** Until 2026-09-11, the `postgres` default privileges in `public` and `storage` granted ALL — including TRUNCATE — to `anon` and `authenticated` on every new table, view and sequence. Phase 21.6 removed both roles from those four entries, keeping `postgres` and `service_role`. The fix is deliberately not retroactive: no existing object's ACL changed, which is why S-6 — a residue on `public.users` left by an earlier incomplete revoke — survives and is tracked separately. One latent twin outside this project's control remains: the `supabase_admin` / `public` TABLES default, which applies only to objects created *as* `supabase_admin`. Detail: `analysis/phase-21.6/`.

---

## 1. Method

Every figure below comes from a static audit of `index.html` at `ebfe536`, cross-checked against `analysis/phase-20.7/codebase-assessment.md`. All access is funnelled through a small set of helpers, which is what makes an exhaustive audit possible:

| Helper | Line | Role |
|---|---|---|
| `supaHeaders(extra)` | [1061](../../index.html#L1061) | Attaches the live session token, falling back to the publishable key |
| `supaSelect(table, filters, columns)` | [1070](../../index.html#L1070) | All reads |
| `supaSelectCount(table, filters)` | [1101](../../index.html#L1101) | Count-only reads |
| `supaInsert(table, data)` | [1125](../../index.html#L1125) | Direct inserts |
| `supaUpsert(table, data, conflictCol)` | [1151](../../index.html#L1151) | Upserts |
| `supaUpdate(table, filters, data)` | [1177](../../index.html#L1177) | Direct updates |
| `supaUpdateMinimal(table, filters, data)` | [1236](../../index.html#L1236) | Narrow-column updates |
| `supaRpc(fnName, params)` | [1286](../../index.html#L1286) | All RPC calls |

**There is no other path to the backend.** The only literal REST path in the file is `/rest/v1/rpc/`; every table access goes through the helpers above, and every RPC name is a **string literal** — there is no dynamic or computed dispatch. That was verified explicitly, and it is what makes the counts below exhaustive rather than indicative.

---

## 2. Tables and views the frontend references — 14

Matches the Phase 20.7 inventory exactly.

| # | Relation | Referenced | Notes |
|---|---|---|---|
| 1 | `wanted_posts` | 7 | Read + insert + update |
| 2 | `profiles` | 6 | Read + update |
| 3 | `public_profiles` | 5 | **View.** Read only |
| 4 | `wanted_applications` | 3 | Read only (writes go via RPC) |
| 5 | `notifications` | 3 | Read + update (`read` flag only) |
| 6 | `collaboration_participants` | 3 | Read only |
| 7 | `users` | 2 | Read + update (`username` only) |
| 8 | `collaborations` | 2 | Read only |
| 9 | `collaboration_tasks` | 2 | Read only |
| 10 | `collaboration_assets` | 2 | Read + insert |
| 11 | `user_auth_accounts` | 1 | Read only — auth→domain identity mapping |
| 12 | `collaboration_messages` | 1 | Read only |
| 13 | `collaboration_credits` | 1 | Read only |
| 14 | `collaboration_activity` | 1 | Read only |

### 2.1 Column projections the frontend depends on

These are explicit `select=` lists. Each is a column-level dependency: if a column disappears or is revoked, the corresponding screen breaks.

| Relation | Columns requested |
|---|---|
| `users` | `id, username, first_name, last_name, photo_url, bio, location` |
| `profiles` | `role, location, bio, rating, followers_count, collab_count, project_count` |
| `public_profiles` | filtered by `id` — projection not narrowed (`*`) |
| `collaborations` | `id, title, status, wanted_post_id, created_at` |
| `collaboration_participants` | `user_id, participant_type, created_at`; also `collaboration_id, participant_type` |
| `collaboration_messages` | `created_at` (latest-message probe) |
| `collaboration_tasks` | `id, status`; also `id` filtered `status=eq.todo` |
| `collaboration_assets` | `id, file_size, created_at` |
| `collaboration_credits` | `id, user_id` |
| `collaboration_activity` | `id, actor_user_id, activity_type, reference_id, metadata, created_at` |
| `wanted_posts` | `title`; plus unnarrowed reads filtered by `status`/`user_id` |
| `wanted_applications` | `wanted_post_id`; also `id, applicant_id, status, created_at` |
| `notifications` | `id` filtered `read=eq.false` |
| `user_auth_accounts` | filtered by `auth_user_id` |

---

## 3. RPCs the frontend calls — 20

**20 distinct functions, 20 call sites, one call site each.** All names are string literals.

| # | Function | Line | Calling function |
|---|---|---|---|
| 1 | `close_own_wanted_post` | [2035](../../index.html#L2035) | `closeWantedPost()` |
| 2 | `create_wanted_application` | [2070](../../index.html#L2070) | `applyToWanted()` |
| 3 | `respond_to_wanted_application` | [2457](../../index.html#L2457) | `respondToApplication()` |
| 4 | `change_collaboration_status` | [3212](../../index.html#L3212) | `changeCollaborationStatus()` |
| 5 | `invite_collaboration_participant` | [3349](../../index.html#L3349) | `performCollaborationInvite()` |
| 6 | `remove_collaboration_participant` | [3368](../../index.html#L3368) | `removeParticipant()` |
| 7 | `transfer_collaboration_ownership` | [3387](../../index.html#L3387) | `transferOwnership()` |
| 8 | `leave_collaboration` | [3407](../../index.html#L3407) | `promptLeaveCollaboration()` |
| 9 | `edit_collaboration_message` | [3674](../../index.html#L3674) | `saveMessageEdit()` |
| 10 | `delete_collaboration_message` | [3693](../../index.html#L3693) | `deleteMessagePrompt()` |
| 11 | `create_collaboration_message` | [3738](../../index.html#L3738) | `sendCollaborationMessage()` |
| 12 | `edit_collaboration_task` | [3932](../../index.html#L3932) | `saveCollaborationTaskTitle()` |
| 13 | `delete_collaboration_task` | [3951](../../index.html#L3951) | `deleteCollaborationTaskPrompt()` |
| 14 | `create_collaboration_task` | [3974](../../index.html#L3974) | `createCollaborationTask()` |
| 15 | `complete_collaboration_task` | [4000](../../index.html#L4000) | `completeCollaborationTask()` |
| 16 | `edit_collaboration_asset` | [4620](../../index.html#L4620) | `saveCollaborationAssetEdit()` |
| 17 | `delete_collaboration_asset` | [4643](../../index.html#L4643) | `deleteCollaborationAssetPrompt()` |
| 18 | `edit_collaboration_credit` | [5011](../../index.html#L5011) | `saveCollaborationCreditEdit()` |
| 19 | `delete_collaboration_credit` | [5030](../../index.html#L5030) | `deleteCollaborationCreditPrompt()` |
| 20 | `create_collaboration_credit` | [5053](../../index.html#L5053) | `createCollaborationCredit()` |

Each requires a captured definition in `functions.sql` and an EXECUTE grant recorded in `grants.sql`.

---

## 4. Read surface

All reads go through `supaSelect` / `supaSelectCount`, authenticated by `supaHeaders()` ([1061](../../index.html#L1061)), which attaches the live session access token when one exists and otherwise falls back to the publishable key. **Both `anon` and `authenticated` read paths are therefore live and must both be captured** — several screens render before a session is confirmed.

---

## 5. Write surface — only 7 direct writes

This is the most contract-critical section. Almost every mutation goes through an RPC; only these seven touch tables directly, so **the grants that permit exactly these and no more are the enforcement boundary.**

| # | Line | Operation | Relation | Payload scope |
|---|---|---|---|---|
| 1 | [2137](../../index.html#L2137) | `UPDATE` | `wanted_posts` | Edit own post, filtered `id=eq.<editingWantedId>` |
| 2 | [2153](../../index.html#L2153) | `INSERT` | `wanted_posts` | New post; `user_id` supplied by the client |
| 3 | [2213](../../index.html#L2213) | `UPDATE` | `profiles` | `display_name, role, location, bio, skills…`, filtered `user_id=eq.<myId>` |
| 4 | [2223](../../index.html#L2223) | `UPDATE` | `users` | **`username` only**, filtered `id=eq.<myId>` |
| 5 | [2626](../../index.html#L2626) | `UPDATE` | `notifications` | `{read:true}`, single row |
| 6 | [2634](../../index.html#L2634) | `UPDATE` | `notifications` | `{read:true}`, all own unread |
| 7 | [4810](../../index.html#L4810) | `INSERT` | `collaboration_assets` | Metadata after a successful Storage upload |

Site 4 is deliberately narrow: [index.html:2222](../../index.html#L2222) carries a comment stating the payload must not include `anonymized_at`, `is_system`, `id` or other internal fields. **Whether that narrowness is actually enforced server-side by a column grant, or is only a client-side convention, is exactly the kind of question this phase must answer.** Phase 21.1 already flagged the same concern: a direct REST `PATCH` would bypass any client-side check.

---

## 6. Storage

Bucket **`collaboration-assets`**, four operations:

| Line | Operation |
|---|---|
| [4691](../../index.html#L4691) | `download` — in-app preview |
| [4800](../../index.html#L4800) | `upload` |
| [4836](../../index.html#L4836) | `remove` — error cleanup after a failed metadata insert |
| [4855](../../index.html#L4855) | `download` — explicit download |

Object path is built at [4795-4797](../../index.html#L4795-L4797) as:

```
<collaboration_id>/<epoch_ms>-<rand6>-<sanitized_filename>
```

`contentType` is `file.type || 'application/octet-stream'` ([4798](../../index.html#L4798)).

**The frontend imposes no size or MIME restriction whatsoever** — no `accept` attribute on the file input ([802](../../index.html#L802)), no size check before upload. Any limit is purely server-side, which makes `file_size_limit` and `allowed_mime_types` on the bucket part of the contract rather than an implementation detail.

---

## 7. Error-code contract

Four SQLSTATEs are branched on. Each maps to a specific user-visible outcome, so a change to any of them silently degrades the UI into a generic error.

| SQLSTATE | Emitting RPC | Frontend site | Condition (inferred from UI copy) | User sees |
|---|---|---|---|---|
| `23505` | `create_wanted_application` | [2081](../../index.html#L2081) `applyToWanted()` | Unique violation — duplicate application | "You already applied." Button → `APPLIED`, disabled |
| `P0012` | `create_wanted_application` | [2087](../../index.html#L2087) `applyToWanted()` | Target post is not open | "This Wanted is no longer open." |
| `P0013` | `create_wanted_application` | [2092](../../index.html#L2092) `applyToWanted()` | Applicant owns the post — server backstop for a client-side check | "You cannot apply to your own Wanted." |
| `P0053` | `create_collaboration_credit` | [5070](../../index.html#L5070) `createCollaborationCredit()` | Participant already credited | "This participant already has a credit for this collaboration." |

Anything else falls through to a generic path that logs the real error and shows `message` / `hint` / `details` ([2099-2100](../../index.html#L2099-L2100)).

**The conditions above are inferred from UI copy, not read from function bodies.** Confirming them — and finding any *additional* SQLSTATE the backend raises that the frontend does **not** handle — is a required output of the extraction. An unhandled custom code surfaces to the user as a raw Postgres message, which is both a UX and an information-disclosure concern.

---

## 8. Auth, identity and realtime

**Auth surface** — four SDK entry points: `getSession` ×4, `signInWithOtp` ×1, `signOut` ×1, `onAuthStateChange` ×1.

**Flow assumptions baked into `index.html`:**

- Implicit flow with `detectSessionInUrl` (client created with no options, [1037](../../index.html#L1037)); confirmed against the 2.112.1 bundle defaults during Phase 21.2.
- `emailRedirectTo` hardcoded to `https://stagerz.app` ([1329](../../index.html#L1329)).
- Email magic link, not numeric OTP — the comment at [1309-1316](../../index.html#L1309-L1316) records that the hosted template sends `{{ .ConfirmationURL }}` and cannot be changed without custom SMTP.
- Session persisted in `localStorage` under `sb-kbnmkyvbwkuvcklywdhk-auth-token`.

**Identity chain** — `auth.users.id` → `user_auth_accounts.auth_user_id` → `public.users.id` (the "domain identity"), resolved by `getMyDomainId()` ([1358](../../index.html#L1358)), which notes it mirrors the server-side `current_stagerz_user_id()`. **Both that function and whatever populates `user_auth_accounts` at signup must be captured.**

**Realtime** — one channel per collaboration, `collaboration-<id>`, with `postgres_changes` on **five** tables — `collaboration_messages`, `collaboration_tasks`, `collaboration_assets`, `collaboration_credits`, `collaboration_activity` — plus presence keyed by domain user id. **Those five tables must be members of the `supabase_realtime` publication**; publication membership is part of the contract and is easy to overlook.

---

## 9. Known repository-vs-backend discrepancies

Carried forward from earlier phases; each needs confirming or refuting against the live catalog.

1. **`public_profiles` does not read `profiles`.** Phase 21.1 confirmed via `pg_get_viewdef` that the view is sourced from `public.users`, resolving `display_name` as `'Deleted User'` → trimmed `first_name`+`last_name` → `users.username` → `'STAGERZ Artist'`. Meanwhile the UI writes `profiles.display_name` ([2213](../../index.html#L2213)) — **a column the view never reads.** The captured view definition must state this plainly.
2. **`users.username` write narrowness is unverified.** See §5, site 4.
3. **`collaboration_assets.asset_type` is client-written**, so attacker-influencable regardless of UI logic; Phase 21.1 escaped it defensively. Whether a `CHECK` constrains it is unknown — that is Phase 20.7 item **C-3**.
4. **`collaborations.status` is documented as server-RPC-written only** and was deliberately left unescaped by Phase 21.1. That assumption rests on grants that have never been read.

---

## 10. Reconciliation targets

The extraction is complete when every count below is matched by captured objects:

| Object | Expected from client audit |
|---|---|
| Tables/views referenced | **14** |
| RPCs called | **20** |
| Direct write sites | **7**, across 5 relations |
| Storage buckets | **1** (`collaboration-assets`) |
| Handled SQLSTATEs | **4** |
| Realtime publication members | **≥5** |

A captured object the frontend never uses is **not** an error — the backend may legitimately be wider. It is recorded as surplus. The reverse — a frontend dependency with no captured backend object — **is** an error, and blocks the phase.

---

## 11. Live extraction — results

Read-only introspection of `kbnmkyvbwkuvcklywdhk` (`stagerz-foundation-v2-test`, Postgres 17.6.1.141, eu-north-1, `ACTIVE_HEALTHY`). **Every statement below is a `SELECT` against catalog views. No write was performed or attempted.**

### 11.0 FINDING S-1 — ✅ REMEDIATED by Phase 21.4 / PR #11 — *historical evidence below*

> **STATUS: REMEDIATED.** The exposure described in this section **no longer exists**. Phase 21.4 revoked the write privileges; `anon` and `authenticated` now hold `SELECT` only. Confirmed live 2026-08-31 — see §0.2 and §12.7.
>
> **Everything below this banner is HISTORICAL evidence, captured 2026-08-22/23 before the fix.** It is preserved verbatim and deliberately: it is how the exposure was discovered and proved, and it is the justification for the Phase 21.4 change. Read it in the past tense. It does **not** describe the current state.

**Original finding, as recorded pre-remediation:**

This was not previously known and is the most serious result of the phase.

**The privilege chain, every link verified from the catalog:**

| # | Fact | Value |
|---|---|---|
| 1 | `public_profiles` is a **view** | `relkind = 'v'` |
| 2 | Owned by | `postgres` — also the owner of `public.users` |
| 3 | `reloptions` | **`(none)`** → `security_invoker` is **not** set, so the view executes with **owner** privileges |
| 4 | `users` RLS | `relrowsecurity = true`, **`relforcerowsecurity = false`** → the owner **bypasses RLS** |
| 5 | View is auto-updatable | `is_updatable = YES`, `is_insertable_into = YES`, **0** INSTEAD OF triggers, no `WITH CHECK OPTION` |
| 6 | Grants to **`anon`** | `INSERT` and `UPDATE` on 7 columns |
| 7 | Columns actually writable | `id`, `username`, `photo_url`, `is_system`, `created_at` (all `is_updatable = YES`) |

**Consequence.** An **unauthenticated** caller appears able to `PATCH /rest/v1/public_profiles?id=eq.<uuid>` and have the write land in `public.users`, bypassing both the `users` UPDATE policy (`id = current_active_stagerz_user_id()`) and the carefully scoped column grants described in §11.4. The exposed columns include **`username`** — the identifier the UI renders and Phase 21.1 assumed only the owner could change — and **`is_system`**.

`display_name` and `is_deleted` are **not** writable, because both are computed expressions in the view. That limits the blast radius but does not remove it.

**Verification boundary — stated precisely.** This is established from **configuration only**. It was **not** tested, because testing requires a write, which this phase forbids and which would modify production data. Two things could still defuse it in practice and have not been checked: whether PostgREST is configured to expose the view for writes, and whether any gateway rule intercepts such a request. **Treat this as a finding requiring urgent review, not as a confirmed exploit.**

**Not fixed here.** Phase 21.3 captures the contract; it does not change it. Remediation is a separate, approved change.

### 11.1 FINDING S-2 — two test tables are world-writable by `anon`

> **HISTORICAL (pre-21.5) — this describes state that no longer exists.** Both tables were dropped by Phase 21.5 on 2026-09-08 and S-2 is **REMEDIATED** (§0.2). This section is preserved unedited because it is the evidence that found the exposure; erasing it would erase the finding. Read it as *"what was true before Phase 21.5"*.

| Table | RLS | Policies | `anon` privileges |
|---|---|---|---|
| `_test_results` | **disabled** | 0 | `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` |
| `_test_run_log` | **disabled** | 0 | `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` |

Unauthenticated callers can read, write and **truncate** both. They are evidently test scaffolding, and neither is referenced by `index.html`. Combined with the project being named `stagerz-foundation-v2-test`, this is direct evidence for the long-open **Q-2**.

### 11.2 FINDING S-3 — the frontend's Storage `remove()` cannot succeed

`storage.objects` has RLS **enabled** with exactly **two** policies — `SELECT` and `INSERT`, both `authenticated`, both scoped by path prefix:

```
bucket_id = 'collaboration-assets'
AND is_collaboration_participant(((storage.foldername(name))[1])::uuid)
```

**There is no DELETE policy.** The frontend calls `.remove()` at [4836](../../index.html#L4836) — the cleanup path that runs when an asset uploads successfully but its metadata insert then fails. Under this configuration that cleanup **will be denied**, orphaning the uploaded object.

This is precisely the call site Phase 21.2 recorded as *"not covered"* by its testing, so it has never been exercised.

The policies also confirm §6's coupling note: authorisation depends on the first path segment being the collaboration UUID, exactly the format [4795-4797](../../index.html#L4795-L4797) builds.

### 11.3 FINDING S-4 — 55 of 58 backend error codes are unhandled, and surface as raw tokens

> **CORRECTION (2026-08-31), not a staleness fix.** This section originally said **54**. That was an arithmetic error on my part: I subtracted all 4 handled codes from 58, but only **3** of them (`P0012`, `P0013`, `P0053`) are among the 58 backend-`RAISE`d codes. The fourth, `23505`, is produced by the UNIQUE constraint `wanted_applications_wanted_post_id_applicant_id_key`, not by any `RAISE`, so it was never in that set. The correct figure is **58 − 3 = 55**. Re-verified live: 58 distinct backend SQLSTATEs, all three handled RAISE codes still present, and the `23505` constraint still in place. S-4 remains **OPEN** and is one code worse than recorded.

The backend raises **58 distinct SQLSTATEs**. The frontend branches on **4**, only **3** of which are backend-raised.

The messages are **machine tokens, not sentences** — `no_active_stagerz_identity`, `collaboration_not_active`, `not_a_participant`, `only_owner_may_transfer`, `title_too_long`, `body_empty`. The generic fallback at [2099-2100](../../index.html#L2099-L2100) renders `error.message` directly, so **any of the 55 unhandled codes reaches the user as a snake_case identifier**.

Selected inventory (full list in `functions.sql`):

| Code | Message | Raised by |
|---|---|---|
| `P0001` | `no_active_stagerz_identity` | **all 20** frontend RPCs — the auth guard |
| `P0008` | `post_not_found_or_not_open_or_not_owned` | `close_own_wanted_post` |
| `P0011` | `wanted_post_not_found` | `create_wanted_application` |
| **`P0012`** | `wanted_post_not_open` | `create_wanted_application` — **handled** |
| **`P0013`** | `cannot_apply_to_own_wanted` | `create_wanted_application` — **handled** |
| `P0014` | `collaboration_not_active` | 16 functions |
| `P0015` | `not_a_participant` | 8 functions |
| `P0016` | `collaboration_not_found` | 10 functions |
| `P0022` | `only_owner_may_change_status` | `change_collaboration_status` |
| **`P0053`** | `duplicate_credit` | `create_collaboration_credit` — **handled** |
| `P0054`–`P0059` | message CRUD guards | message functions |

`23505` — the fourth handled code — is raised by no function body. It comes from the constraint `wanted_applications_wanted_post_id_applicant_id_key UNIQUE (wanted_post_id, applicant_id)`. **R-3 resolved.**

`P0014`, `P0015` and `P0016` alone cover 34 raise sites across the collaboration surface and are all unhandled.

### 11.4 Grants — the split is real, and precisely engineered

> **CURRENT (post-21.4), live-verified 2026-08-31 — one grant in this section changed.**
>
> **`public.public_profiles` now grants `SELECT` only** to `anon` and `authenticated`:
> ```
> postgres=arwdDxtm/postgres | service_role=arwdDxtm/postgres | anon=r/postgres | authenticated=r/postgres
> ```
> Effective privileges (`has_table_privilege`, SELECT/INSERT/UPDATE/DELETE): `anon` **true/false/false/false**, `authenticated` **true/false/false/false**, `service_role` **true/true/true/true** (untouched).
>
> **Every other grant described below is unchanged.** The `users`, `profiles`, `notifications` and `wanted_posts` column-level grants are exactly as recorded. Live totals: **336** table-grant rows and **1500** column-grant rows in `public` (was 348 / 1542 pre-21.4; Δ −12 / −42, wholly attributable to this one view). Grant rows for relations *other than* `public_profiles`: **320**, unchanged.

**HISTORICAL (pre-21.4) analysis follows.** The column-grant findings below remain accurate and current; only the `public_profiles` table-level grant has changed.

Table-level grants alone appear to omit UPDATE on `users`, `profiles`, `notifications` and `wanted_posts`. **Column-level grants supply them**, scoped tightly:

| Relation | Role | Column-level UPDATE |
|---|---|---|
| `users` | `authenticated` | `bio, first_name, last_name, location, photo_url, username` |
| `profiles` | `authenticated` | `available, bio, category, country_flag, display_name, location, looking_for, role, skills` |
| `notifications` | `authenticated` | **`read` only** |
| `wanted_posts` | `authenticated` | `category, compensation, description, location, remote, role_needed, title` |

Two consequences worth stating:

- **Discrepancy 2 RESOLVED.** The `users` grant **excludes** `anonymized_at`, `is_system` and `id` — exactly what the comment at [2222](../../index.html#L2222) claims. The narrowness is genuinely enforced server-side, not merely by client convention.
- **`wanted_posts` UPDATE excludes `status` and `user_id`**, so ownership and open/closed state cannot be changed over REST; `status` moves only through `close_own_wanted_post`.

**Function EXECUTE grants are correct.** All five `admin_*` functions are granted to `postgres, service_role` **only** — *not* `authenticated`. No privilege escalation. All 20 frontend RPCs are granted to `authenticated` (not `anon`). The three `log_*` trigger functions carry the Postgres default `PUBLIC` EXECUTE, which is low-risk since they are only meaningful as triggers, but it is the one non-uniform grant among the 34.

### 11.5 Counts, reconciled

| Object | Live | Client demand | Result |
|---|---|---|---|
| `public` tables | **19** | — | 5 unreferenced: `follows`, `likes`, `pending_asset_deletions`, `pending_auth_deletions`, plus the 2 test tables (net of the 14) |
| `public` views | **1** | — | `public_profiles` |
| Relations | **20** | 14 | 6 surplus |
| Functions | **34** | 20 RPCs | 14 surplus: 5 `admin_*`, 5 helpers, 4 trigger functions |
| RLS policies | **27** | — | verified: sums exactly across 19 tables |
| Storage policies | **2** | — | SELECT + INSERT only — see S-3 |
| `public` triggers | **3** | — | all AFTER INSERT activity loggers |
| `auth` triggers | **1** | signup hook | `on_auth_user_created` |
| Realtime tables | **5** | 5, named | **exact match** |

**No frontend dependency is missing from the backend.** All 20 RPCs and all 14 relations exist by name.

### 11.6 RLS posture

RLS is enabled on **17 of 19** tables. The two exceptions are the test tables (S-2).

Reads are participant-scoped through `is_collaboration_participant()`; writes are ownership-scoped through `current_active_stagerz_user_id()`. The design is coherent and consistently applied — which is what makes the `public_profiles` view bypass (S-1) an anomaly rather than the pattern.

**Two tables have RLS enabled and zero policies** — `pending_asset_deletions` and `pending_auth_deletions`. That denies all access to non-owner roles, which is the correct posture for internal queues. **Recorded explicitly, as R-8 requires.**

`relforcerowsecurity` is `false` on **every** table. Owners therefore bypass RLS everywhere; that is the default, and it is the precondition that makes S-1 exploitable.

### 11.7 Signup trigger and identity chain

```sql
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
```

`SECURITY DEFINER`, `search_path = ''`, EXECUTE to `postgres, service_role` only. This is what populates `auth.users.id → user_auth_accounts.auth_user_id → public.users.id`, the chain `getMyDomainId()` ([1358](../../index.html#L1358)) depends on and which the repository has never recorded.

### 11.8 `public_profiles` definition — discrepancy 1 CONFIRMED from DDL

```sql
SELECT id, username, photo_url, is_system, created_at,
       anonymized_at IS NOT NULL AS is_deleted,
       CASE
         WHEN anonymized_at IS NOT NULL THEN 'Deleted User'
         WHEN first_name IS NOT NULL OR last_name IS NOT NULL
           THEN TRIM(BOTH FROM (COALESCE(first_name,'') || ' ') || COALESCE(last_name,''))
         ELSE COALESCE(username, 'STAGERZ Artist')
       END AS display_name
FROM users;
```

`FROM users` — it never reads `profiles`. The Edit Profile screen writes `profiles.display_name` ([2213](../../index.html#L2213)), a column this view cannot see. Phase 21.1's finding is confirmed from the actual definition.

### 11.9 All four known discrepancies resolved

| # | Discrepancy | Resolution |
|---|---|---|
| 1 | `public_profiles` ignores `profiles.display_name` | **CONFIRMED** — §11.8 |
| 2 | `users.username` write narrowness | **CONFIRMED ENFORCED** — column grant excludes internal fields (§11.4) |
| 3 | `collaboration_assets.asset_type` CHECK | **REFUTED — no CHECK exists.** Only `file_size > 0` and `UNIQUE (storage_path)`. The client can write any `asset_type`, and `authenticated` holds a column-level INSERT grant on it. **Phase 21.1's defensive escaping was necessary** |
| 4 | `collaborations.status` RPC-only | **CONFIRMED** — `authenticated` has `SELECT` only on `collaborations`; `status` is further constrained by `CHECK (status IN ('active','completed','archived'))` |

### 11.10 Constraints and indexes of contract significance

- `wanted_applications_wanted_post_id_applicant_id_key` **UNIQUE (wanted_post_id, applicant_id)** — the source of `23505`
- `users_username_key` **UNIQUE (username)**
- `idx_one_owner_per_collaboration` — **partial unique index** on `collaboration_id WHERE participant_type = 'owner'`, enforcing exactly one owner
- `collaborations_wanted_post_id_key` UNIQUE — one collaboration per Wanted post
- `collaboration_assets_storage_path_key` UNIQUE (storage_path); `CHECK (file_size > 0)`
- Length limits enforced in the database as well as in the RPCs: messages `<= 5000`, task titles `<= 300`
- **`collaboration_credits` has no unique constraint** — `P0053 duplicate_credit` is enforced only by an explicit check inside `create_collaboration_credit`, with no database-level backstop against a concurrent duplicate

### 11.11 What remains to transcribe

Everything above is captured. The one outstanding item is **verbatim bodies for 22 of the 34 functions** in `functions.sql` — 12 are captured. Their *contract-bearing* content is already extracted in full (signature, volatility, security mode, `search_path`, EXECUTE grants, and every `RAISE` with its SQLSTATE and message), so nothing about the contract is unknown; only the full source text is pending.

---

## 12. S-1 escalation — read-only verification of the write-exposure chain *(HISTORICAL — pre-Phase-21.4)*

> **⚠️ THE ENTIRE SECTION 12 IS HISTORICAL EVIDENCE, captured 2026-08-23 BEFORE the fix.**
>
> Every privilege value, plan output and classification in §12.1–§12.6 describes the **pre-remediation** state. The exposure it proves was closed by Phase 21.4 / PR #11. **Do not read §12 as current.**
>
> It is preserved unedited because it is the proof that justified the remediation — the privilege chain, the absence of every defusing mechanism, and the `EXPLAIN` plan showing `Update on users` with no RLS predicate. Deleting it would leave the fix unexplained.
>
> **For the current state, see §12.7 and §0.2.**

Performed 2026-08-23. **No write, and no write test, was performed against production.** All database statements were `SELECT`; the HTTP probes were `OPTIONS` and a `GET` requesting **zero rows**.

### 12.1 Authoritative privilege checks (`has_*_privilege`)

| Check | Result |
|---|---|
| `anon` USAGE on schema `public` | **true** |
| `anon` SELECT / INSERT / UPDATE / **DELETE** on `public_profiles` | **all true** |
| `anon` UPDATE on cols `username`, `photo_url`, `is_system`, `id` | **all true** |
| `anon` SELECT on base `public.users` | **false** |
| `anon` UPDATE on base `public.users` | **false** |
| `postgres` `rolbypassrls` | **true** |
| `anon` `rolbypassrls` | false |
| view owner / base owner | `postgres` / `postgres` |
| `users` RLS enabled / **FORCED** | true / **false** |

`anon` has **no direct access** to `users`. The view is the only path — and it is open, including DELETE.

### 12.2 Defusing mechanisms — all absent

| Candidate | Value |
|---|---|
| `check_option` | **NONE** |
| `security_invoker` / `security_barrier` | **not set** (`reloptions = (none)`) |
| INSTEAD OF triggers on the view | **0** |
| Non-SELECT rules on the view | **0** |
| `is_trigger_updatable` / `_deletable` / `_insertable_into` | NO / NO / NO — genuinely auto-updatable |
| Generated or identity columns in `users` | **(none)** |
| Gateway / API restriction | none discoverable read-only |

### 12.3 PostgREST exposure

- `GET /rest/v1/public_profiles?select=id&limit=0` → **HTTP 200 `[]`**. The view **is** exposed through PostgREST to `anon`.
- `GET /rest/v1/users?select=id&limit=0` → **HTTP 401 / `42501`**. Base table correctly blocked.
- OpenAPI root (`/rest/v1/`) → **HTTP 401, "Only secret API keys can be used for this endpoint."** Not retrievable with the publishable key; no secret key was obtained or used.
- `OPTIONS` returns `Allow: GET, HEAD, POST, OPTIONS` **identically for every relation, including `users`** where `anon` has no privileges at all. The header is therefore **static, not privilege-derived, and is not evidence in either direction.**

**PostgREST implements no write authorisation of its own.** It issues the statement as the role and lets Postgres decide. With the schema exposed and `anon` holding UPDATE on the view, a `PATCH` is issued and Postgres governs the outcome.

### 12.4 Partial mitigation — `safeupdate`

`authenticator` preloads `session_preload_libraries = supautils, safeupdate`, which rejects `UPDATE`/`DELETE` **without a WHERE clause**.

This bounds the impact: an unfiltered mass update or delete is blocked (PostgREST also refuses unfiltered mutations by default). A **targeted** `?id=eq.<uuid>` write supplies a WHERE clause and is **not** blocked.

### 12.5 Column mapping

| View column | Base column | Writable |
|---|---|---|
| `id` | `users.id` | **YES** |
| `username` | `users.username` | **YES** |
| `photo_url` | `users.photo_url` | **YES** |
| `is_system` | `users.is_system` | **YES** |
| `created_at` | `users.created_at` | **YES** |
| `is_deleted` | `anonymized_at IS NOT NULL` — computed | NO |
| `display_name` | CASE expression — computed | NO |

### 12.6 Classification

> ## CONFIRMED CONFIGURATION EXPOSURE — *as classified on 2026-08-23; since REMEDIATED*

Every link is positively verified read-only, and no defusing mechanism exists. `users.username` is UNIQUE, so a targeted write can also collide with or seize another account's username.

**Scope of the claim:** this is confirmed *at configuration level*. End-to-end execution was **not** tested, because that requires a write. `safeupdate` bounds it to targeted, single-row writes rather than mass modification.

**Not remediated *by this phase*.** Phase 21.3 captures the contract; it does not change it. Remediation was carried out separately by **Phase 21.4 / PR #11** — see §12.7.

### 12.7 CURRENT state — S-1 closed, live-verified 2026-08-31

> ## ✅ REMEDIATED — Phase 21.4 / PR #11
>
> The exposure proved in §12.1–§12.6 **no longer exists.**

The chain was broken at its weakest necessary link — the grant — leaving the rest of the design untouched:

| Link from §12.1 / §12.2 | Then (pre-21.4) | Now (live 2026-08-31) |
|---|---|---|
| `anon` INSERT / UPDATE / DELETE on the view | **true / true / true** | **false / false / false** |
| `authenticated` INSERT / UPDATE / DELETE | **true / true / true** | **false / false / false** |
| `anon` / `authenticated` SELECT | true | **true — deliberately retained** |
| `service_role` | all true | all true — untouched |
| Raw ACL | `anon=arwdDxtm` | **`anon=r`, `authenticated=r`** |
| View owner / `relkind` / `reloptions` | `postgres` / `v` / `(none)` | **unchanged** |
| View definition (md5) | `d86256ac1ad53a250c96c315ed69a52e` | **`d86256ac1ad53a250c96c315ed69a52e` — unchanged** |
| `users` RLS enabled / forced | `true` / `false` | **`true` / `false` — unchanged**, 2 policies intact |

**What deliberately did *not* change, and why it matters.** `security_invoker` was **not** set, the view definition was **not** altered, and `users` RLS was **not** touched. The definer-view read gateway remains intentional and load-bearing: neither role can `SELECT public.users` directly, and the `users` SELECT policy is own-row-only, so making the view `security_invoker` would have broken every profile read. The defect was never the definer semantics — it was write privileges on a read gateway.

**Consistency with the documented change.** The resulting ACL is exactly what these two statements produce, and nothing more:

```sql
REVOKE ALL ON TABLE public.public_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO anon, authenticated;
```

`arwdDxtm` → `r` for precisely those two roles; `postgres` and `service_role` untouched; grant-row deltas (−12 table, −42 column) accounted for entirely by this view. Full record: `analysis/phase-21.4/`.
