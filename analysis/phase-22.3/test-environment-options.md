# Phase 22.3 — Test Environment Options (J)

**Status:** evaluation. **No cloud environment created; no cost-confirmation workflow started.** Update 2026-09-20: the T1 tooling is installed and T1 remains the preferred first test environment, but its Storage runtime is blocked (`storage-api:v1.72.1` exit 139), so only the database gate could be run locally. Auth/API/Realtime, Edge Function and Storage API runtimes need either a fixed local stack or T2.

**Constraints (facts, 2026-09-19):**
- organisation `STAGERZ` on the **Free** plan;
- **2 active projects**: production `kbnmkyvbwkuvcklywdhk` and the contained legacy `edxicnafggnnvcdvxemk`;
- the Free limit is 2 active free projects, and paused projects do not count;
- local: Supabase CLI 2.117.0 installed; **Docker not installed**; `pg_dump` not installed.

Prices are Supabase documentation list prices, not quotes.

## Comparison

| | **T1 — Local Supabase stack** | **T2 — Second cloud project** | **T3 — Supabase branching** |
|---|---|---|---|
| What | `supabase start` on the owner's machine (Docker), baseline applied locally | A separate Supabase project built from the baseline | Preview branches created from the repository's `supabase/migrations` per PR or persistent branch |
| Prerequisites | Docker Desktop (Windows, WSL2) installed; `supabase init` (creates `config.toml`); baseline moved into `supabase/migrations` (decision 1) | **A free project slot**: pause or delete the legacy project (its disposition decision; a paused project is restorable for 90 days only), or an organisation upgrade to Pro; owner cost confirmation before creation | **Pro plan**; GitHub integration; `supabase/migrations` + `config.toml` + optional `seed.sql` in repo; baseline accepted (decision 1) |
| Likely cost | $0 platform cost | $0 on Free if a slot is freed; on Pro ~ $10/month per additional active Micro project (Pro itself $25/month incl. $10 compute credit) | Pro $25/month + usage from ~$0.01344/hour per Micro branch; not covered by the spend cap |
| Fidelity | Good for schema, RLS, grants and functions; Auth e-mails captured locally (Mailpit/Inbucket), so magic links are testable without SMTP; component versions may differ slightly from hosted; not reachable from phones or Netlify previews | **Highest**: same hosted platform, real Auth/SMTP behaviour (default SMTP reaches team members only, fine for the owner's testing), real Edge Functions and Storage | High: hosted, created from migrations; data not copied from production (seed only) |
| Convenience | Fast resets; offline; one machine only; Docker upkeep | Always-on URL usable from any device and from a Netlify test deploy; manual rebuilds; Free-plan pausing after 7 idle days | Most automated once set up (per-PR environments); most setup; depends on migrations discipline |
| Reset / rollback | `supabase db reset` (seconds) | Re-apply the baseline on a fresh project, or drop and re-create the schema (owner-approved); project deletion is irreversible but harmless | Delete or recreate the branch; merge/rebase tooling |
| Frontend targeting (design G3) | `localhost` → local | A chosen test host (e.g. a Netlify branch deploy) → T2 | Per-branch hosts → branch backend (more config) |
| Risk to production | None | None (separate project), provided the scripts' production guard and the ref checks are respected | Low. Branch merges can apply migrations to production if integration is misconfigured; needs care |

## Assessment (judgment)

- **T1** is the cheapest and fastest way to **prove the baseline** (the reproducibility gate). It needs Docker installed by the owner.
- **T2** is the best **ongoing** test environment for this app (magic-link Auth, Storage, Edge Functions, and multi-device testing). On Free it is **coupled to the legacy-project disposition**, which frees the slot.
- **T3** only becomes attractive after a Pro upgrade and once the B1 migration workflow is established.
- **Suggested path (owner decision 2):** T1 to run the gate if Docker is acceptable; otherwise T2 directly. Then T2 as the standing test environment, once the slot or plan question is settled. Revisit T3 when/if the organisation goes Pro.
