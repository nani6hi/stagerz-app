# Phase 21.3 R-5 remediation — W-1 / W-3 / W-4

**Branch:** `phase-21.3-backend-contract-resume` (local only, not pushed)
**Parent commit:** `e5244a9fb80987c9ac5b9c5de2882a1eb7901255`. This is the accurate pre-remediation Phase 21.3 snapshot and is not amended.
**Target:** `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk` only. Never `stagerz-app` / `edxicnafggnnvcdvxemk`.
**Status:** **APPLIED AND VALIDATED on the test project (2026-09-17), R-5 PASS.**
- `migration.sql` was applied once as migration `20260917143322 phase21_3_r5_w1_w3_w4`; the stored statement is byte-identical.
- All catalog gates pass. The corrected behavioural template passed 40/40 on run 2; run 1 had 38/40 because of two template defects (`validation.md` §10).
- `rollback.sql` has not been executed.
- Not pushed and not merged.

The rest of this document describes the design as prepared.
**Validation level:** backend-only; no `index.html` change. The gates are in `validation.md`.

| File | Role | SHA-256 (LF, as committed) |
|---|---|---|
| `migration.sql` | executable migration candidate, one guarded DO statement | `5ca16d90ae685e0da450a11de1ef16e602f73b5a5bbc1b5b1bd74e639e47033a` (36,271 bytes, md5 `e99dfd9e4a2dd987469d2ebcdf37571d`) |
| `rollback.sql` | reviewed rollback, one guarded DO statement | `7ac92c1d21930e072973bdfc94164f1c98acf85cdda6578bcfd26a5bf3629e95` (26,291 bytes) |
| `behavioral-validation.sql` | rollback-only post-apply test template with in-statement synthetic fixtures | `9bccf38fbc7d6064a9ac9442b227c2549566e8d2825039a8b6ea33e6d2ba2f44` (28,510 bytes). Corrected T15/T19 after run 1; the run-1 version was `3f1793ea…09ca`. |
| `apply-validation-record-2026-09-17.md` | apply and validation evidence (both behavioural runs) | — |
| `validation.md` | baseline, gates, behavioural matrix, static review | — |

**History.**
- **`b0c0a49`:** first preparation. Its display-name rule showed the signup placeholder `'New Artist'` like a real name.
- **This revision:** implements the product owner's final decision (**option A**, §2) and supersedes those hashes. W-1, W-2, W-3 and W-4 scope is unchanged.

---

## 1. Origin

Phase 21.3 (`analysis/phase-21.3/validation.md` §8–§17, commit `e5244a9`) failed gate **R-5** ("client write surface is exactly what the frontend needs") with four findings. The read-only decision analysis classified them, and the product owner then decided:

| ID | Finding (as captured in `e5244a9`) | Product decision | Handled here |
|---|---|---|---|
| **W-1** | `authenticated` holds table-level INSERT on `wanted_posts`, so a client can set `id` and `created_at` (for example, a future `created_at` pins a post to the top of the public feed, which is ordered by `created_at.desc`) | **NARROW** to the frontend's columns | yes |
| **W-2** | `profiles` column UPDATE grants include columns the current Edit Profile form does not send (`available`, `category`, `country_flag`, `looking_for`) | **ACCEPT** the current design; no change | no — later recorded under R-5 as reviewed and non-material |
| **W-3** | `authenticated` can UPDATE `users.first_name`, `last_name`, `photo_url`, `bio`, `location`; the frontend only updates `username`. `first_name`/`last_name` feed `public_profiles.display_name`, which the Edit Profile form never writes. | **PROFILE-CENTRED MODEL** | yes |
| **W-4** | `authenticated` holds INSERT and DELETE on `follows` and `likes` (with matching policies), but no frontend flow writes either table | **KEEP TABLES, DISABLE UNUSED WRITES** | yes |

## 2. Profile-centred model (W-3)

| Object | Role after this change |
|---|---|
| `users` | Account / technical identity. `username` stays client-editable (Edit Profile → `supaUpdateMinimal('users', …, {username})`). `first_name`, `last_name`, `photo_url`, `bio` and `location` stay as columns, keep their data and stay readable by the owner. They are no longer client-updatable. |
| `profiles` | Public profile. `display_name` is the authoritative, editable public display name. `profiles.bio` and `profiles.location` are the profile versions. Grants and policies are unchanged (W-2). |
| `public_profiles` | Public projection. The same seven columns (`id, username, photo_url, is_system, created_at, is_deleted, display_name`) with the same names, order and types. `display_name` now comes from `profiles`. |

**Final `display_name` rule** (product owner decision, **option A**). `'New Artist'` is a technical signup placeholder, not a genuine public name. The rule is evaluated per user, first match wins:

1. `users.anonymized_at IS NOT NULL` → `'Deleted User'`. This keeps the existing view's anonymization semantics.
2. Take `profiles.display_name` with **all** leading and trailing whitespace removed (`[[:space:]]`: spaces, tabs, CR, LF). Use it if it is non-null, non-empty and **not exactly** `'New Artist'` → that trimmed value.
3. Otherwise, if `users.username` contains a non-whitespace character → `users.username`, unchanged.
4. Otherwise → `'STAGERZ Artist'`.

No row data is changed.

**Why this exact placeholder comparison** (read-only evidence, `validation.md` §2.6):
- **Single producer.** The literal `'New Artist'` is produced only by `handle_new_auth_user`: `coalesce(new.raw_user_meta_data->>'display_name', 'New Artist')`, run by the `on_auth_user_created` trigger.
  - `profiles.display_name` has no column default and no CHECK constraint; no column default anywhere contains the text.
  - Only migration `20260712100630` mentions it.
- **Always the metadata-less default.** The frontend signs up with `signInWithOtp` and sends no metadata, and 0 auth users carry a `display_name` in their metadata. The value is therefore always the exact literal.
- **Data matches the literal.** All 24 placeholder rows match it byte-for-byte. There are **0** case variants, 0 leading/trailing-whitespace variants and 0 inner-whitespace variants, and 0 onboarded users hold the placeholder.
- **Case-sensitive comparison.** A case-insensitive match would not catch any placeholder the backend can produce. It would only hide a name a user deliberately typed, such as `'new artist'`.
- **Whitespace trimmed first.** The comparison runs after trimming, so a padded placeholder (possible through signup metadata or a direct API call) is still recognised.
- **Accepted consequence.** A user who deliberately saves exactly `New Artist` sees their username instead. This is the product owner's decision, and T16 covers it.

Design points:

- **Join.** `FROM public.users u LEFT JOIN (SELECT pr.user_id, <trimmed display_name> AS name FROM public.profiles pr) p ON p.user_id = u.id`.
  - The derived table only computes the trimmed name once. It reads nothing but `profiles.user_id` and `profiles.display_name`, both already public.
  - `profiles.user_id` is `NOT NULL`, `UNIQUE` and a FK to `users` with `ON DELETE CASCADE`, so the join cannot multiply rows.
  - The LEFT JOIN keeps a user with no profile row, which then uses the username fallback. The live count of such users is 0.
  - The row set therefore stays exactly `users`, as it is today. The migration preflight checks the constraints; the postflight checks the row set.
- **No new exposure.** `profiles.display_name` is already readable by `anon` and `authenticated` (`profiles are publicly readable`, `USING (true)`). The view exposes no new column. `photo_url` still comes from `users`; avatar upload is out of scope.
- **Security behaviour unchanged.**
  - `CREATE OR REPLACE VIEW` keeps the relation OID, the owner (`postgres`) and the ACL (`anon=r`, `authenticated=r`, plus the owner and `service_role` entries).
  - Because the statement has no `WITH (…)` clause, `reloptions` stay NULL. The view therefore keeps running with its owner's rights, which is the accepted Phase 21.4 `security_definer_view` design.
  - The Security Advisor item is expected to remain exactly as it is (accepted, not "remediated", not to be resolved).
  - The migration postflight asserts owner, ACL, `reloptions`, column list, absence of column ACLs and anon/authenticated privileges.
- **Dependencies.** Nothing depends on `public_profiles`: no view, rule, function body (checked by literal text search) or publication. Its only change of dependencies is from `{users}` to `{profiles, users}`.
- **Consequence: the view becomes non-auto-updatable** (a join). Nothing writes through it: `anon` and `authenticated` only have SELECT, and neither `index.html` nor the repository's Edge Function sources reference it except for SELECTs. `service_role` / `postgres` lose the theoretical ability to UPDATE `users` through the view; nothing uses it. The postflight records the change as `NO/NO`.
- **Functions.** No function changes:
  - `admin_anonymize_account` already sets `profiles.display_name = 'Deleted User'` and nulls the legacy `users` name columns.
  - `handle_new_auth_user` keeps creating the placeholder; the view simply never shows it.

### 2.1 Visible effect on current data (aggregate counts only, 2026-09-17)

| Count | Value |
|---|---|
| users | 32 |
| users without a profile / profiles without a user | 0 / 0 |
| blank or whitespace-only profile `display_name` | 0 |
| profiles holding the `'New Artist'` placeholder | 24, all of them not onboarded (username NULL) |
| anonymized users | 0 |
| users whose public `display_name` changes under the final rule | **3**, each moving from the legacy first/last name to the chosen profile `display_name` (the intended fix) |
| — to username / to `'STAGERZ Artist'` | 0 / 0 |
| users whose `display_name` stays the same | 29, including the 24 non-onboarded users, who keep `'STAGERZ Artist'` |
| rows that would publicly show `'New Artist'` | **0** |
| system users whose `display_name` changes | 0 |

With the `b0c0a49` rule, 27 names would have changed; 24 of them would newly have shown `'New Artist'`. Option A removes that visible effect.

The frontend's only username-setting flow (`saveProfile`) requires a non-empty display name, so an onboarded user normally has a chosen name.

## 3. Remediation (`migration.sql`)

One `DO` statement: **PREFLIGHT → CHANGES → POSTFLIGHT**. Any failed guard raises and nothing persists, whatever the caller's transaction handling. `search_path` is pinned to `public` for the transaction, so deparsed expressions compare stably. All DDL is schema-qualified. No secrets.

### W-1 — `wanted_posts`

```sql
revoke insert on table public.wanted_posts from authenticated;
grant insert (user_id, title, description, role_needed, category,
              location, remote, compensation, status)
  on table public.wanted_posts to authenticated;
```

- The nine columns are exactly what `index.html` sends (`{user_id, title, description, role_needed, category, location, remote, compensation, status:'open'}`).
- `id` (`gen_random_uuid()`) and `created_at` (`now()`) are no longer client-insertable; their defaults are unchanged.
- The INSERT policy (`onboarded active users can insert own wanted posts`), the seven UPDATE column grants, SELECT, the `status` CHECK and the defaults are untouched.
- PostgREST's `return=representation` keeps working: table-level SELECT and the `USING (true)` SELECT policy are unchanged.
- Resulting ACLs:
  - relation: `authenticated=r`;
  - `attacl`: `aw` on the seven updatable columns and `a` on `user_id` and `status`.

**`status = 'open'` hardening (evaluated separately; not included).**
- Today a client can insert its own post directly as `closed`.
- This harms no one else: the post belongs to the caller, the CHECK allows only `open`/`closed`, and a closed post is simply not applicable.
- No product invariant found in the current contract requires a new post to start `open`.
- The hardening would be one extra `AND (status = 'open')` in the INSERT policy's WITH CHECK. It is left as an optional follow-up (§8) to keep this change minimal.

### W-3 — `users` and `public_profiles`

```sql
revoke update (first_name, last_name, photo_url, bio, location)
  on table public.users from authenticated;
create or replace view public.public_profiles as
select u.id, u.username, u.photo_url, u.is_system, u.created_at,
       (u.anonymized_at is not null) as is_deleted,
       case
         when u.anonymized_at is not null then 'Deleted User'::text
         when p.name <> ''::text and p.name <> 'New Artist'::text then p.name
         when regexp_replace(u.username, '^[[:space:]]+|[[:space:]]+$', '', 'g') <> ''::text then u.username
         else 'STAGERZ Artist'::text
       end as display_name
  from public.users u
  left join (select pr.user_id,
                    regexp_replace(pr.display_name, '^[[:space:]]+|[[:space:]]+$', '', 'g') as name
               from public.profiles pr) p
    on p.user_id = u.id;
```

**How NULLs fall through.**
- A missing profile row gives a NULL `p.name`. The comparisons then yield NULL, so the CASE falls through to the username branch.
- A NULL `username` falls through to `'STAGERZ Artist'` the same way.

**Checked against synthetic literals (read-only, no table rows).** Both this expression and the independent postflight specification were evaluated on 18 cases:
- genuine, padded, tab- or newline-padded, and inner-spaced names;
- the exact, padded and tab-padded placeholder;
- `new artist`, `NEW ARTIST` and `New Artist Collective`;
- empty and whitespace-only names, and a NULL name;
- a NULL, blank or whitespace username;
- anonymized accounts.

They agreed on all 18 (`validation.md` §2.6).

- `authenticated` keeps column UPDATE on `username` only.
- Every column SELECT grant on `users` is kept, because `fetchMyProfile` still selects `id,username,first_name,last_name,photo_url,bio,location`.
- The `users` policies are unchanged.
- No column is dropped and no data is changed.

### W-4 — `follows`, `likes` (option B)

```sql
revoke insert, delete on table public.follows, public.likes from authenticated;
drop policy "active users can create own follows" on public.follows;
drop policy "active users can remove own follows" on public.follows;
drop policy "active users can create own likes"   on public.likes;
drop policy "active users can remove own likes"   on public.likes;
```

- Tables, rows, the `anon`/`authenticated` SELECT grants and both `… are publicly readable` policies are kept. The public policy count goes from 25 to 21.

**Option A (keep the policies, inert) vs option B (drop them): B is chosen.**
- Without the grant, the policies can never be evaluated. Keeping them would leave the contract describing a write path that does not exist.
- More importantly, any later broad grant (for example, a `GRANT INSERT … TO authenticated` issued for another reason) would silently re-activate a follow/like write surface.
- Dropping them makes "no client writes" explicit and reviewable. A future social feature must re-introduce grants and policies together, deliberately.
- `rollback.sql` re-creates them verbatim.

### Postflight (summary)

- **W-1:** exact ACLs; INSERT columns exactly the nine; UPDATE columns unchanged; no DELETE; `anon` has no INSERT; `wanted_posts` policies unchanged.
- **W-2:** `profiles` ACL, column ACLs and policies byte-identical to the baseline.
- **W-3, `users`:** exact ACLs; UPDATE only `username`; SELECT columns unchanged; no widening for `anon`/`authenticated`; policies unchanged.
- **W-3, `public_profiles` catalog:**
  - kind, owner, `reloptions` NULL, ACL, column names, types and order, and no column ACLs;
  - `anon`/`authenticated` hold SELECT only;
  - dependencies are exactly `{profiles, users}`;
  - the definition no longer references `first_name`/`last_name`; it contains a LEFT JOIN and the `'New Artist'`, `'STAGERZ Artist'` and `'Deleted User'` constants;
  - the view is not auto-updatable.
- **W-3, `public_profiles` rows:** the row set equals `users`, and a row-by-row comparison of every view column finds 0 mismatches.
  - The comparison is against an **independently written** specification of the final rule: a `substring`-based trim and a regex non-whitespace test.
  - It computes only counts; no data leaves the statement.
- **W-4:** exact ACLs; no INSERT/UPDATE/DELETE for `authenticated`; SELECT kept for both roles; only the SELECT policy remains on each table.
- **Global:** RLS enabled and not forced on the five tables; 21 public policies; 34 public functions; O-1/O-2/O-3 state intact (the `wanted_applications` and `collaboration_assets` ACLs, the FK is `ON DELETE RESTRICT`, and the nine `collaboration_assets` INSERT columns).

## 4. Explicit exclusions

- **W-2:** no change.
- No `DROP` of any column or table. No row or data change (the postflight only counts).
- No function, trigger, constraint, index, default or RLS-mode change.
- No Storage bucket or policy, and no avatar upload.
- No Edge Function, secret, Advisor action or `index.html` change.
- The Phase 21.3 snapshot files in `analysis/phase-21.3/` are not rewritten. They are regenerated only after a future approved apply.
- The `wanted_posts` `status = 'open'` hardening (§3, §8) is not included.

## 5. Rollback (`rollback.sql`)

One guarded `DO` statement.

**PREFLIGHT.** Requires exactly the state `migration.sql` leaves behind:
- ACLs, column ACLs and policies;
- for `public_profiles`: dependencies `{profiles, users}`, a LEFT JOIN and the `'New Artist'` constant in the definition, and view rows matching the migration's final (option A) `display_name` rule.

Any other state, including a partial one, aborts with no change.

**CHANGES.**
- **W-1:** revoke the nine column INSERT grants, then restore table-level INSERT.
  - The `user_id`/`status` column ACLs may be left as empty arrays rather than NULL; all guards ignore empty ACLs.
- **W-3:** restore the five column UPDATE grants, then `CREATE OR REPLACE` the original single-table view.
- **W-4:** restore INSERT and DELETE, then re-create the four policies verbatim (permissive, `TO PUBLIC`, same expressions).

**POSTFLIGHT.** Requires the exact pre-migration baseline:
- all ACLs, column ACLs and policies;
- `public_profiles` pretty-definition md5 = `d86256ac1ad53a250c96c315ed69a52e`, and the definition contains neither `New Artist` nor `profiles`, so no part of the placeholder rule survives;
- `public_profiles` dependencies `{users}`, updatability `YES/YES`, and owner, ACL and `reloptions` unchanged;
- 25 public policies, 34 functions, O-1/O-2/O-3 intact.

Offline, the rollback view text parses to the same tree as the live pretty definition. If the server deparse still differed, the postflight would abort the rollback atomically, with no partial state.

Rows written while the migration was in effect are not modified. `rollback.sql` must not be executed without separate approval.

## 6. Migration representation and reproducibility

- `migration.sql` is the single source of truth for one future `apply_migration` call. The file content is sent unchanged, under a descriptive name such as `phase21_3_r5_w1_w3_w4`.
- After apply, the stored `statements[1]` must hash to the SHA-256 above, as was done for `20260916215204`.
- The repository still does not contain the project's full remote migration chain, and this directory does not claim to.

## 7. Advisor expectation

- **Before (unchanged by this preparation):** the accepted `public_profiles` `security_definer_view` item.
- **After apply:** the same item, unchanged. The view's security mode is not altered, and no new object, function or `search_path` issue is introduced.
- Any additional finding after apply is a validation failure (`validation.md` §5, C-14). Advisor findings are never resolved from this workflow.

## 8. Remaining questions and follow-ups (recorded, not actioned)

1. **`'New Artist'` placeholder: decided (option A), implemented in this revision.** Residual points:
   - The view and `handle_new_auth_user` share the literal. If the trigger default ever changes, the view must change with it. Keeping them in sync is a review item for any future change to `handle_new_auth_user`.
   - A user who deliberately saves exactly `New Artist` is shown their username. This is accepted and tested (T16).
   - `index.html` may still show the raw `profiles.display_name` (for example, `'New Artist'`) to the user in their own Edit Profile form. That is a frontend matter outside this backend change.
2. **`wanted_posts` `status = 'open'` on INSERT.** Optional hardening (§3).
3. **Legacy `users` identity columns.** `first_name`, `last_name`, `photo_url`, `bio`, `location` stay as dormant data, still read by `fetchMyProfile` (only `username` is used). A later cleanup could narrow that SELECT. Dropping the columns is out of scope.
4. **`public_profiles.photo_url`** still comes from `users.photo_url`, which is no longer client-editable. All current values are NULL (aggregate). Avatar support will need its own design (storage, validation, which table owns the URL).
5. **W-2** is to be recorded under R-5 as reviewed and non-material when Phase 21.3 is re-evaluated.

## 9. Required approvals, in order

1. Review of this commit (local, not pushed). Push only with explicit approval.
2. Explicit approval to apply `migration.sql` once to `kbnmkyvbwkuvcklywdhk` and run the gates in `validation.md` §3–§6, including the rollback-only `behavioral-validation.sql`.
3. Documentation of the apply record, then regeneration of the Phase 21.3 snapshot for the new epoch and re-evaluation of R-5 (W-1/W-3/W-4 remediated; W-2 accepted).
4. Phase 21.3 closure, PR and merge: each separately approved. A merge to `main` is a production release.

`rollback.sql` is executed only with its own explicit approval.
