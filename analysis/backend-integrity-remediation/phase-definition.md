# Backend integrity remediation — O-1 / O-2 / O-3

**Branch:** `backend-integrity-o1-o2-o3`
**Base commit:** `20acbe8292e3b706fd57040f1f2ff6c790e67a62` (`main`)
**Phase number:** not assigned. The next 21.x number is ambiguous (21.10 is proposed in the Phase 20.7 roadmap), so this remediation is named descriptively until one is assigned.
**Target:** `stagerz-foundation-v2-test` / `kbnmkyvbwkuvcklywdhk`
**Status:** **O-1, O-2, O-3 REMEDIATED on the test project — applied and validated 2026-09-16.**
- Applied with explicit approval as migration version `20260916215204` (`backend_integrity_o1_o2_o3`) from commit `2c0fb5e`. The stored statement is byte-identical to `migration.sql` (SHA-256 `7f273f08…5221`).
- All pre-apply gates, post-apply catalog gates C-1 to C-14 and behavioural tests T1 to T12 pass; the validation left no data behind (`validation.md` §9).
- `rollback.sql` was not executed.
- **Not yet merged** to `main`.

**Phase 21.3:** remains **PAUSED** until merge and closure of this remediation are approved.
**Validation level:** backend-only, no `index.html` change. The gates are in `validation.md`.

---

## 1. Origin

Found during the Phase 21.3 resume/re-baseline (2026-09-15) and confirmed by two further read-only reviews (2026-09-15/16). All evidence is catalog-level; no write test has been performed. No S-number is assigned.

| ID | Observation | Classification | Severity |
|---|---|---|---|
| **O-1** | `authenticated` could INSERT directly into `wanted_applications` (all columns, including `status`), bypassing `create_wanted_application` | **REMEDIATED** (2026-09-16, validated) | Low — workflow integrity |
| **O-2** | `authenticated` could DELETE its own `wanted_posts` row. `collaborations_wanted_post_id_fkey` was `ON DELETE CASCADE`, so deleting a post destroyed its collaboration and all collaboration data, even after collaboration ownership was transferred | **REMEDIATED** (2026-09-16, validated) | **Highest of the three** — irreversible destruction of other users' data; bypassed the collaboration ownership model |
| **O-3** | `authenticated` could INSERT every `collaboration_assets` column, including `id`, `created_at` and the lifecycle column `deleted_at`, and `storage_path` was not bound to the collaboration folder | **REMEDIATED** (2026-09-16, validated) | Low — storage lifecycle / metadata integrity |

The descriptions below (§2–§8) were written before the apply and describe the defects as found.

---

## 2. Root cause

**One historical pattern: permissions granted against the early data model (2026-07-12 to 07-18) were never re-reviewed as the model evolved.**

- **O-1.** The direct INSERT grant and policy were created on 2026-07-14 as the original application path. `create_wanted_application` arrived on 2026-07-15, and the grant was never revoked. Phases 16.2 and 18.2 of the original build did revoke direct INSERT once an RPC became "the sole creation path"; `wanted_applications` was missed.
- **O-2.** "Delete own wanted post" was granted on 2026-07-12, when nothing depended on posts. On 2026-07-15 `collaborations.wanted_post_id` was added with `ON DELETE CASCADE`, which silently turned "delete my post" into "delete a shared collaboration".
  - `wanted_posts.user_id` never changes; `transfer_collaboration_ownership` only changes `participant_type`. A former owner therefore keeps this power.
  - Foreign-key cascades run as the table owner and bypass child-table RLS.
  - The frontend has no delete action; posts are only closed (`close_own_wanted_post`).
- **O-3.** A table-level INSERT grant (2026-07-18) automatically covered `deleted_at`, which was added on 2026-07-19 as "temporary bridge state only", set solely by `delete_collaboration_asset`. A client-inserted soft-deleted row would be invisible, never queued, and protected from the orphan reaper.

---

## 3. Remediation (`migration.sql`)

One atomic `DO` statement with a drift-detecting PREFLIGHT and an intended-state POSTFLIGHT.

**O-1**
- `REVOKE INSERT ON public.wanted_applications FROM authenticated`.
- `DROP POLICY "active users can apply to open wanted posts"`.
- Keeps SELECT and its policy, RLS, and both RPCs unchanged. `create_wanted_application` becomes the only client creation path.

**O-2**
- `REVOKE DELETE ON public.wanted_posts FROM authenticated`.
- `DROP POLICY "active users can delete own wanted posts"`.
- Recreate `collaborations_wanted_post_id_fkey` with **`ON DELETE RESTRICT`**. Name, column, referenced key, MATCH SIMPLE, ON UPDATE NO ACTION and non-deferrability are unchanged; the separate UNIQUE constraint and NOT NULL are untouched.
- **RESTRICT, deliberately:** the check is immediate and cannot be deferred, so no role — including `service_role`, admin tooling or the dashboard — can remove a post that produced a collaboration without handling the collaboration explicitly. RESTRICT only refuses; it never deletes, so it can't orphan rows.
- `wanted_applications → wanted_posts` stays `ON DELETE CASCADE`.
- **Product contract after the change:** posts are closed through `close_own_wanted_post`; there is no client physical deletion. **No post-delete RPC is added.** If the product later wants "delete a post that never produced a collaboration", that will be a separate, reviewed RPC.

**O-3**
- Replace the table-level INSERT with column-level INSERT on exactly the nine columns the frontend sends: `collaboration_id`, `uploaded_by`, `storage_path`, `file_name`, `mime_type`, `file_size`, `asset_type`, `title`, `description`.
- `id` and `created_at` keep their defaults; `deleted_at` stays lifecycle-controlled.
- `ALTER POLICY "active participants can create collaboration asset metadata"`: the three existing conditions are kept verbatim, and two are added:
  - `deleted_at IS NULL`;
  - `split_part(storage_path, '/', 1) = collaboration_id::text` with `length(storage_path) > length(collaboration_id::text) + 1`. This is the frontend's own `<collaboration_id>/<file>` format and the same folder rule Storage uses.
- SELECT policy, `delete_collaboration_asset`, the queue, the drainer and the reaper are unchanged.

**Frontend:** no change. `uploadCollaborationAsset` sends exactly the nine columns, `applyToWanted` already uses the RPC, and there is no delete action.

---

## 4. Explicit exclusions

- **`public.public_profiles`:** not altered — see §6.
- **`wanted_posts` INSERT narrowing:** not included. Clients can still supply `status`, `id` and `created_at` on insert. This is a low, adjacent follow-up (§8), not part of this scope.
- **Not touched:** any function or trigger; `users`; `profiles`; `follows`/`likes`; Storage policies or objects; Edge Functions; workflows; secrets; `index.html`.
- **Not added:** a delete-post RPC.
- **Not done here:** Phase 21.3 snapshot work, or importing the 41 remote migrations.

---

## 5. Rollback (`rollback.sql`)

- **Purpose:** an emergency reversal of exactly the three changes. It is not executed.
- **Precondition:** its PREFLIGHT refuses to run unless `migration.sql` is in effect.
- **Exactness:** it restores the table ACLs, effective INSERT columns, both dropped policies (same name, command, role and permissiveness), the original asset INSERT check and the CASCADE FK. The POSTFLIGHT compares the re-created policy expressions **byte for byte** with the verbatim captured deparse.
- **One representational difference:** an emptied column ACL may be stored as `{}` rather than NULL; both mean "no column privilege".
- **Warning:** running it re-opens O-1 to O-3.

---

## 6. `public.public_profiles` Security Advisor item — accepted, out of scope

The Advisor reports `security_definer_view` (ERROR) for `public.public_profiles`. This is the **accepted design from Phase 21.4**:
- The view has no `security_invoker` option, so it runs with its owner's permissions: the PostgreSQL default for views.
- It is a curated read-only projection of `users` (id, username, photo, `is_system`, `created_at`, a derived `is_deleted` and a derived `display_name`).
- `anon` and `authenticated` hold SELECT only.
- Invoker semantics would break every profile read, or would require exposing raw `users` columns more widely.

Phase 21.4 fixed the write exposure (S-1) and deliberately kept definer semantics. Phases 21.5 and 21.7 tracked the ERROR count at 1. The finding is **not suppressed and not "resolved"**; it is recorded as accepted, and post-apply gate C-14 requires it to remain exactly that one finding.

---

## 7. Migration representation and reproducibility

- **Location:** this directory, following the `analysis/phase-21.4` … `21.7/migration.sql` convention.
- **Not in `supabase/migrations/`,** because the repository does not hold the project's 41 remote migrations. A lone file there would falsely suggest a complete chain, and `supabase db push` would see history drift.
- **How it will be applied (only after approval):**
  1. Send `migration.sql` unchanged through **`apply_migration`**, name `backend_integrity_o1_o2_o3`, so the live migration history records it. This differs from Phases 21.4–21.7, which used `execute_sql` and left no history row.
  2. Verify the stored statements equal this file (`validation.md` C-12, C-13).
  3. Record the assigned version in a follow-up documentation commit.
- **Later:** Phase 21.3's reproducibility work can import this file, together with the remote chain and a baseline for the 21.4–21.7 changes, into a real migration directory.

---

## 8. Out-of-scope follow-ups (recorded, not actioned)

1. **`wanted_posts` INSERT column narrowing (low).** The table-level INSERT lets clients supply `status`, `id` and `created_at` when creating a post. The frontend sends `user_id`, content columns and `status: 'open'`. A future change could narrow the grant and add `status = 'open'` to the INSERT check.
2. **Legacy application data.** Four `accepted` applications from 2026-07-15 point at posts without collaborations. They predate the collaboration tables; recorded in `validation.md` §2.3 and not changed.
3. **Anonymous user-directory enumeration through `public_profiles`.** A product/privacy question, not a defect (§6).
4. **Reliability items carried over from S-8** (Phase 21.8A §14.6).

---

## 9. Required approvals, in order

1. Independent review of this directory — **done**.
2. Explicit approval for `apply_migration` — **given and executed** 2026-09-16 (version `20260916215204`).
3. Explicit approval for the rollback-only behavioural validation — **given and executed**; all tests pass (`validation.md` §9.4).
4. **Still open**, each needing its own approval: any production smoke test, PR and merge, project-level documentation closure (Phase 21.3 snapshot, `PROJECT_CONTEXT.md`), and resuming Phase 21.3.

The preparation step itself applied nothing. The only persistent Supabase change of this remediation is the single approved migration.
