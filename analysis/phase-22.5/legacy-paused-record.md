# Legacy Supabase Project — Retirement Record (EXPORT + PAUSE)

**Date:** 2026-09-20. **Nature:** documentation only, from a read-only verification.
No Supabase mutation was performed by this record; the pause itself was **owner-initiated**.
**Repository base:** `main` @ `c54f6da4e68acf326167878fad2f1f548395f3b5`.

**Legacy project:** `edxicnafggnnvcdvxemk` ("stagerz-app") — the Telegram-era backend, contained by
Phase 22.1, pre-pause-verified earlier the same day (`legacy-pre-pause-record.md`).
**Production backend of record:** `kbnmkyvbwkuvcklywdhk` (Phase 22.2, Option A) — untouched.

---

## 1. Verified state

| Project | Status verified 2026-09-20 |
|---|---|
| `edxicnafggnnvcdvxemk` | **`INACTIVE`** — paused, following an owner-initiated pause |
| `kbnmkyvbwkuvcklywdhk` | `ACTIVE_HEALTHY` — unchanged |

The `INACTIVE` status was read from the Supabase project listing at the platform level. Nothing was
resumed, deleted, migrated or otherwise modified.

## 2. Backups taken by the owner

Before / around retirement the owner downloaded **both** the Supabase database backup and the
Storage objects backup, and stored them locally under `STAGERZ_Backup_2026-09-20`.

**Verified by metadata only. The archives were NOT opened and their contents were not inspected.**

| Archive | Observed size |
|---|---|
| `Supabase_Database/db_cluster-20-09-2026@21-29-00.backup.gz` | **42,587 bytes** |
| `Supabase_Storage/edxicnafggnnvcdvxemk.storage.zip` | **22 bytes** |

**The 22-byte Storage archive is an empty zip, and that is correct** — it is consistent with the
pre-pause finding of **0 Storage buckets and 0 Storage objects** in the legacy project. The small
database archive is likewise consistent with the recorded 8 data rows (3 `users`, 5
`wanted_posts`). The backups corroborate the pre-pause inventory rather than contradicting it.

> **The backups live outside this repository and MUST NOT be committed.** They contain legacy
> tester data. No backup file, archive, extract or fragment of one belongs in version control, now
> or later.

## 3. Disposition decision — CLOSED

**The legacy disposition decision is closed as: EXPORT + PAUSE.**

- **Export:** done — database and Storage archives held locally by the owner.
- **Pause:** done — project verified `INACTIVE`.
- **DELETE is NOT authorized.** Deletion is irreversible and would permanently destroy the in-place
  containment evidence and the ability to re-verify R-1 … R-4 against the live project. Nothing in
  this record, or in `legacy-pre-pause-record.md`, supports deletion.

## 4. What is NOT changed by this record

**Phase 22.0 remains CLOSED / COMPLETE / PASS.** Its classification
**`C — MIXED / LEGACY ENVIRONMENT`** (owner-accepted 2026-09-19) remains **the correct
point-in-time finding** for the environment as it stood on that date: a test-named project serving
the production domain beside a still-active legacy project. **It is not rewritten.** The pause does
not make that finding wrong — it makes it historical.

**Phase 22.1 containment records remain historical and unchanged.** `remediation.sql`,
`rollback.sql`, `validation.sql`, the remediation plan and the apply/validation record (Part B
**PASS 66 / FAIL 0**) all stand exactly as committed.

Only **current-state** claims elsewhere in the documentation were updated, and each such update is
marked as superseding a dated statement rather than replacing history.

## 5. LG-1 — containment layer 4

LG-1 was already **REMEDIATED / CONTAINED IN DEPTH** in Phase 22.1. The pause adds a fourth layer:

| Layer | Control | Verification |
|---|---|---|
| 1 | All client table and column privileges revoked (R-1) | Re-verified PASS 2026-09-20 — 0 grants |
| 2 | Six restrictive deny-all policies `p221_containment_deny_client` for `anon` + `authenticated` (R-2) | Re-verified PASS 2026-09-20 |
| 3 | Legacy JWT `anon` key disabled; sign-ups and anonymous sign-ins OFF (N-1 / N-2) | Phase 22.1 — tool + owner |
| **4** | **The project is `INACTIVE`** — it serves no API at all | **Verified 2026-09-20** |

### Permanently accepted historical residual

The legacy `anon` key **string** remains in this public repository's **git history** (commits
before `24609a8`). **This is a permanently accepted historical residual.** No history rewrite is
authorized, and none is planned. Exploitability is nil: it would require someone to both re-enable
the disabled key **and** resume the paused project, and layers 1–2 would still deny all access.

**This has never concerned production.** The production project's legacy JWT has never appeared in
the repository's git history; the only JWT ever committed belonged to the legacy project.

## 6. Free-plan slot

With the legacy project `INACTIVE`, **the Free-plan active-project slot constraint is resolved**,
against the owner-observed dashboard rule recorded in `legacy-pre-pause-record.md` §6 (free-project
limit 2; another free project requires one to be deleted, paused or upgraded).

> **This satisfies the prerequisite for T2 only. It does NOT authorize the creation of T2.**
> Creating a test environment remains a separate, unapproved owner decision within the proposed
> Phase 22.5.

## 7. Deliberately not established

**The paused-project restore / retention window has NOT been established and is not stated here.**
It must not be guessed or inferred. If any decision ever comes to depend on that duration, it
requires its own verification against current Supabase documentation or the dashboard first.

## 8. Scope of this record

Documentation only. No Supabase mutation, no database change, no migration, no Edge Function
deployment, no key or secret change, no Auth change, no application-code change, no T2 creation,
and no inspection of backup archive contents.
