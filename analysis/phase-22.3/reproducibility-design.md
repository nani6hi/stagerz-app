# Phase 22.3 — Reproducibility Design

**Status:** Design, executed. The baseline is **verified and promoted to canonical** (`baseline-verification-record.md`). **Owner decisions taken 2026-09-19:**
1. B1;
2. T1 first;
3. rename deferred;
4. G3 now, with unknown hosts failing closed (not the test-backend fallback suggested in §4 below);
5. synthetic showcase + fixtures;
6. Auth capture now.

Implementation status: `phase-definition.md` §6. Nothing has been applied to any database.

---

## 1. Baseline strategy (B)

| Option | What it means | Assessment |
|---|---|---|
| **B1 — Canonical baseline + incremental migrations** | One generated, executable file that recreates the **current** application state on an empty project; every later change is a new timestamped migration. On production the baseline is only *recorded* as applied (metadata), never executed | **Recommended.** It reproduces exactly what runs today, including the Phase 21.4–21.7 hardening that is outside the history. It is deterministic (generated from the catalog) and verifiable by the fingerprint gate in one step. The standard Supabase pattern (the equivalent of `migration squash`) |
| **B2 — Reconstructed historical chain** | Pull the 43 stored statements into `supabase/migrations/`, add 4 synthetic migrations for Phases 21.4–21.7 | Possible, since the history text is retrievable. But: it replays defects before fixing them; it embeds the fictional seed inserts inside the schema history; there are two migrations with the same name; the 21.5 drop depends on test tables created earlier; and equivalence must still be proven by the same gate. Much more work, more failure points, and no functional gain |
| **B3 — B1 + read-only historical archive** | B1, plus (optionally) an archive of the 43 historical statements under `analysis/` as audit reference, never executed | A variant of B1. It keeps provenance without making history executable. The archive must first be checked for personal data (it contains the fictional seed data only, per Phase 22.0) |

**Recommendation (judgment): B1**, optionally with the B3 archive. **(owner — decision 1)**

**B1 mechanics, after approval:**
1. Prove the draft on a non-production environment: apply it, then pass the fingerprint gate.
2. Move it to `supabase/migrations/<version>_stagerz_baseline.sql`, with a version later than `20260917143322`.
3. Record it on production as applied without executing it (`supabase migration repair --status applied <version>`). This is a metadata-only write to production and needs its own approval.
4. From then on, every change is an incremental migration, applied first to test, then to production.

## 2. Repository structure (H)

```
supabase/
  README.md                         rebuild procedure, platform-vs-app split   (new, draft)
  migrations/20260919120000_stagerz_baseline.sql   CANONICAL baseline, verified     (promoted 2026-09-20)
  verify/fingerprint.sql            read-only reproducibility fingerprint       (new)
  verify/expected-production.json   production fingerprint, 2026-09-19          (new)
  config/environment-inventory.md   Edge Function config, secrets BY NAME, Storage, Realtime, Auth placeholders (new, draft)
  seed/README.md                    seed strategy; no data                      (new, draft)
  functions/…                       unchanged; byte-identical to deployed
  MIGRATIONS.md                     convention + production-history safety      (new)
  seed/showcase.sql, seed/fixtures.sql  synthetic seeds                         (new)
  config.toml                       deliberately NOT in the repository (local verification runs in a scratch workspace)
```

**Note on `migrations/`:** the draft was kept outside it until the gate passed, because any CLI `db push`, `db reset`, branching or GitHub integration reads that directory. The baseline moved there on 2026-09-20 after verification. The repository is still not linked to any project, and `config.toml` is still absent, so no CLI command targets anything from here.

| Required element | Where |
|---|---|
| 1 executable canonical baseline | `supabase/migrations/20260919120000_stagerz_baseline.sql` (17 tables, 1 view, 34 functions, 14 indexes, 4 triggers, 23 policies, 1 bucket, 5 Realtime members, exact grants and default privileges). **VERIFIED**: two clean rebuilds from empty databases, 20/20 fingerprint categories matching production, byte-identical between runs |
| 2 incremental migration convention | `supabase/README.md` "Future changes" |
| 3 Storage setup | baseline §10–§11; inventory §3 |
| 4 Realtime setup | baseline §12; inventory §4 |
| 5 Edge Function definitions and source | `supabase/functions/` (verified identical); `verify_jwt` and secrets in inventory §1–§2 |
| 6 config inventory and runbook | `supabase/config/environment-inventory.md`, `supabase/README.md` |
| 7 secrets-by-name inventory | inventory §2 |
| 8 seed strategy | `supabase/seed/README.md` **(owner — decision 5)** |
| 9 verification | `supabase/verify/*` (§3 below) |
| 10 rebuild procedure | `supabase/README.md` |

**Baseline construction notes:**
- **Ordering:** extensions → tables → PK/UNIQUE/CHECK → FKs → indexes → functions (`check_function_bodies = false`) → view → triggers → RLS → policies → bucket → Realtime → relation, column and function grants (revoke-then-grant, reproducing production ACLs exactly) → default privileges → comments.
- **Guard:** a DO block refuses to run if STAGERZ tables already exist, so it cannot be run on production by mistake.
- **Content boundary:** no data, users or secrets. The only `INSERT` is the bucket definition row.
- **Gate outcome (2026-09-20):** all three earlier unknowns are resolved. The file executed unmodified on two empty databases; the privileged statements succeeded (the storage policies needed an owner-capable role, documented in `supabase/README.md`); and the platform default grants matched, with `relation_grants`, `function_grants` and `default_privileges` all PASS. Evidence: `baseline-verification-record.md`.

## 3. Verification and fingerprint design (I)

`supabase/verify/fingerprint.sql` (read-only, single `SELECT`, marker `STAGERZ-FINGERPRINT-v1`). It was run on production on 2026-09-19, and the result is stored in `expected-production.json`.

| Exact-match checks (gate) | Environment-specific (reported, never compared) |
|---|---|
| relations and kinds and RLS flags (18) | PostgreSQL version, extension versions |
| columns: type, NOT NULL, default (141) | migration history presence and content (`supabase migration list`) |
| constraints (definitions) | row counts, Auth user count, Storage object count |
| indexes (definitions) | project ref, URLs, API keys |
| view definition and options | Auth configuration (captured separately, adapted per environment) |
| functions: `md5(pg_get_functiondef)` per signature (34) | Edge Function **versions** and deploy timestamps |
| app triggers incl. `auth.users` (4) | secret values (never read) |
| policies incl. `storage.objects` (23) | |
| relation, column and function grants | |
| `postgres` default privileges in `public`/`storage` | |
| Realtime membership (5 tables) | |
| bucket config | |
| app extensions present | |

**Beyond the SQL gate:**
- **Edge Functions:** compare the deployed file SHA-256 (via `get_edge_function` or the CLI) with the repository, and check `verify_jwt = false`. Done for production on 2026-09-19: 10/10 identical.
- **Baseline version:** check the expected migration row (after B1) in each environment.
- **Behaviour:** the Phase 21.x rollback-only probe pattern (the Phase 22.1 `validation.sql` style) can be re-used as a behavioural smoke gate on the rebuilt environment.

**Gate definition:** a rebuilt environment is "reproduced" when:
1. every `exact` key equals `expected-production.json`;
2. all 4 functions are deployed from the repository with `verify_jwt = false` and the required secret names set;
3. the behavioural smoke checks pass.

## 4. Frontend environment targeting (G)

**Today:** `index.html:1013-1014` hard-code the production URL and publishable key. `emailRedirectTo` is hard-coded to `https://stagerz.app` (`:1423`). There is no build step. GitHub Pages and Netlify both serve `main`, and Netlify previews therefore hit production.

| Approach | How | Pros | Cons |
|---|---|---|---|
| G1 — constants plus separate `env.production.js` / `env.test.js` | Swap the file per deployment | Explicit | Needs per-deploy file substitution; GitHub Pages can't do that without a branch divergence or build step |
| G2 — runtime config file (`/config.json` fetched at start-up) | Hosting serves a different file per site | App logic untouched | Extra network round trip before auth init; still needs per-site file control; CSP later |
| **G3 — host-based selection table in `index.html`** | A small, explicit map `{hostname → {url, key, redirect}}` read at start-up; `emailRedirectTo` becomes the selected entry's origin | Zero build, zero infrastructure; works for GitHub Pages, Netlify production, Netlify branch/preview hosts and `localhost` (T1); easy to review; publishable keys are public by design | Every new production host must be added deliberately; needs a clear rule for unknown hosts |
| G4 — generated config (small build step) | CI writes the config per target | Standard in larger stacks | Introduces a build system, which is not justified at this size |

**Recommendation (judgment): G3**, implemented as a later, separately approved change:
- **Production hosts:** exact allow-list (`stagerz.app`, `www.stagerz.app`, `aquamarine-puppy-beccd9.netlify.app`) → production.
- **Test hosts:** `localhost` / `127.0.0.1` → local (T1); the chosen test host(s) → test backend.
- **Unknown hosts: recommended to use the test backend** (fail-safe for data; a new production domain added without updating the map shows up immediately and harms no data). The alternative is a visible "unconfigured host" error. **(owner — decision 4, including this rule)**
- **Related per-environment settings:**
  - each Supabase project's Auth redirect allow-list must contain its own hosts;
  - `STAGERZ_ALLOWED_ORIGIN` per environment for `delete-account`;
  - the session storage key already differs automatically per project ref.
- **No runtime change in Phase 22.3.**

## 5. Rebuild procedure

See `supabase/README.md`: new empty project → baseline → optional seed → deploy functions with `--no-verify-jwt` → secrets by name → Auth config from the capture → fingerprint gate → frontend targeting → behavioural checks.

## 6. Phase 22.3 scope boundary (K)

| In Phase 22.3 | Later, separate phases |
|---|---|
| Production-designation cleanup (the 4 `index.html` comments, current docs; historical records untouched) | Custom SMTP (a production blocker for external users) |
| Reproducibility: baseline, verification gate, config and secret inventory, rebuild runbook | Backups / Pro-plan decision |
| Auth configuration capture (owner) | Synthetic and test data cleanup |
| Rebuild **verification design**, and, if approved, executing the gate on a test environment | The 2 `collaboration_assets` rows with missing Storage objects |
| Frontend-targeting **design** | CSP / start-up dependency hardening; implementing G3 (touches runtime) |
| Test-environment **strategy decision** | Creating the test environment (needs cost confirmation) — may become the last step of 22.3 if approved, otherwise its own phase |
| | Project rename (dashboard) **(owner — decision 3)**; UI and product work; Advisor review before launch |

## 7. Owner decisions required

1. **Baseline strategy:** B1 (recommended), B2, or B1 plus the B3 archive.
2. **Test environment:** T1, T2 or T3 (`test-environment-options.md`), including any cost confirmation.
3. **Rename** the production Supabase project (`stagerz-foundation-v2-test` → e.g. `stagerz-production`). Cosmetic: the ref stays.
4. **Frontend environment mechanism now or later** (G3 recommended), and the unknown-host rule.
5. **Safe seed data** in non-production environments: none, showcase-only, or showcase plus fixtures.
6. **Auth settings capture** by the owner (`auth-owner-capture-checklist.md`).
