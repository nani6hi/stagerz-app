# Phase 22.4 — Netlify Deployment Surface: Read-Only Diagnosis

**Date:** 2026-09-20. **Diagnosis nature:** read-only — public HTTP GETs, public GitHub REST, and
read-only Netlify project/deploy metadata. **No Netlify, DNS or domain change was made.**
**Status: DIAGNOSED. Architecture APPROVED IN PRINCIPLE by the owner 2026-09-20; repository Step 2
IMPLEMENTED; all DNS and Netlify steps NOT EXECUTED — see §9.**

---

## 1. What each public surface actually serves

| Surface | Serves | Evidence |
|---|---|---|
| `stagerz.app` (apex) | **Current `main` @ `3b38e6b`** — byte-identical to `origin/main:index.html` (276,708 bytes, SHA-256 `6b847208cdd0ab10…`) | cache-busted GET; `Server: GitHub.com`; `Last-Modified 2026-09-20T12:01:19Z`, 39 s after the PR #28 merge |
| `www.stagerz.app` | **Nothing of its own** — HTTP **301** to `https://stagerz.app/`, served by **Netlify** (`Server: Netlify`, `X-Nf-Request-Id`) | GET without redirect following |
| `aquamarine-puppy-beccd9.netlify.app` | **Stale build of commit `7ae06c1`** (PR #25, Phase 22.2, 2026-09-19) | byte match against the git blob history |
| `main--aquamarine-puppy-beccd9.netlify.app` | **The same stale deploy** | byte match |

**Both Netlify hostnames serve one and the same deploy**, not two divergent builds. The 536-byte
difference between them is a **Netlify-injected hosting-provider comment and `<meta>` block** added
on the primary domain only.

The served `index.html` is byte-identical to the blob at **`ab3a46d`** (Phase 21.9, 2026-09-14),
which is consistent: `ab3a46d` was the last commit to change `index.html` before Phase 22.3, so the
file at `7ae06c1` is the same file.

*Measurement correction:* the Phase 22.3 closeout recorded 274,832 / 274,296 bytes and described
these as two builds. Today's cache-busted measurements are **274,833 / 274,297**, and both resolve
to the same deploy; the earlier figures were one byte short through the measurement method used.
The substantive finding — a stale pre-Phase-22.3 surface — stands, and is now pinned to an exact
commit.

## 2. What Netlify itself reports

Project `aquamarine-puppy-beccd9`, id `7724a510-9620-44e4-8d2f-76d53dc9542a`, team plan
`nf_team_dev`, `claimed: true`. Netlify records its **`primarySiteUrl` as `https://stagerz.app`**.

**Current production deploy:**

| Field | Value |
|---|---|
| Deploy id | `6aaedbd3f37b7f0008d4f107` |
| State | `ready` |
| Context | `production` |
| Branch | `main` |
| `commit_ref` | **`7ae06c17be0b1341fd00db6195809107a0176e5e`** (PR #25 merge) |
| Created / published | 2026-09-19T19:00:35Z / **2026-09-19T19:00:45Z** |
| `updated_at` | 2026-09-20T11:59:53Z (touched, **not** republished) |
| `error_message` | `null` |
| `manual_deploy` / `deploy_source` | `false` / `api` |

## 3. Repository relationship — the link is intact and building

Netlify produced **deploy-preview** builds for every Phase 22.3 branch commit:

| Commit | Netlify build | Time (UTC) |
|---|---|---|
| `775f048` | check-runs present | 2026-09-20 00:57:19Z |
| `cb2bb12` | check-runs present | 2026-09-20 10:22:54Z |
| `9b207a7` | deploy `6aafcab27323b5000857e970` | 2026-09-20 11:59:46Z |

The PR #28 preview was retrieved in full: context `deploy-preview`, branch `phase-22.3-closeout`,
`review_id: 28`, state `ready`, "4 new files uploaded", `published_at: null` (previews are never
published). It built **~54 seconds before** the merge commit.

**So the repository connection, the build pipeline and PR previews all work.** What is missing is a
**production-context deploy for each `main` merge commit after `7ae06c1`** — `86ba828` (PR #26),
`209bd3e` (PR #27) and `3b38e6b` (PR #28) produced none, while GitHub Pages deployed all three.

## 4. DNS and split ownership

| Name | Record | Points to |
|---|---|---|
| `stagerz.app` | A → `185.199.108.153` | **GitHub Pages** |
| `www.stagerz.app` | CNAME → `aquamarine-puppy-beccd9.netlify.app` | **Netlify** |

The repository `CNAME` file contains `stagerz.app`, the GitHub Pages custom domain.

**Split deployment ownership:** Netlify believes it owns `stagerz.app` (its `primarySiteUrl`), but
DNS gives the apex to GitHub Pages. Netlify serves only `www`, as a 301 to the apex. A `www`
visitor therefore lands on the **current** build; the stale Netlify build is reachable only at the
two `*.netlify.app` URLs.

## 5. Classification, on evidence

**Ruled out:**

- *disconnected repository* — previews build from repository commits;
- *failed deploy* — `error_message: null`, previews succeed;
- *wrong production branch on the stale deploy* — its `branch` is `main`;
- *build-minute or plan exhaustion* — previews continue to build.

**Most probable: a stale deploy retained as production** — either **auto-publishing is disabled**,
or **production-branch builds for `main` are no longer triggered**.

**Cannot be distinguished from the available read-only surface — mechanism UNKNOWN.** The Netlify
MCP surface exposes neither a deploy list nor the project's build settings. One look at the
project's *Build & deploy → Continuous deployment* settings, plus its deploy list, would settle it.

## 6. Risk

**Not an outage.** The stale build carries the hard-coded production Supabase URL and still
functions. The real exposure:

- `aquamarine-puppy-beccd9.netlify.app` and `main--…` are **publicly reachable**, are in the
  application's **production** host allow-list, and serve a **6-day-old build against the live
  production backend**;
- that stale build **predates the Phase 22.3 fail-closed environment selection**;
- authentication cannot complete there in any case — the Auth redirect allow-list has a single
  entry, `https://stagerz.app` — so the stale surface offers a degraded, signed-out experience;
- two public surfaces can silently diverge again whenever the publish path breaks.

## 7. Architecture options — does STAGERZ need two public production surfaces?

**On the evidence, no.** There is no recorded requirement for a second surface; it arose by drift,
its ownership and intent were never documented, and it cannot complete authentication.

| Option | For | Against |
|---|---|---|
| **1. GitHub Pages canonical; retire the public Netlify surface later, keeping Netlify for PR previews** | Matches reality — Pages holds the apex, auto-deploys in ~40 s, and is what users reach. Removes the divergence risk and one undocumented surface. PR previews demonstrably work and are genuinely useful | `www` currently depends on the Netlify redirect, so that must be re-homed **before** any teardown. Loses Netlify's response-header and redirect capability |
| **2. Keep Netlify as a secondary production surface and restore deployment sync** | Preserves redundancy | Maintains a surface nobody needs, that cannot authenticate, and that reintroduces divergence whenever sync breaks |
| **3. Move canonical production to Netlify** | Real response headers and redirects — relevant if a CSP is ever added, since GitHub Pages cannot send response headers | A migration with DNS risk for a benefit not needed today; a CSP can begin as a `<meta>` tag |
| **4. Option 1 plus removing the two public `*.netlify.app` hosts from the application's production allow-list** | Everything in option 1, and it closes the divergence exposure **immediately and in the repository**, independent of any Netlify setting | Requires an `index.html` change, so a small code phase; deploy previews would then fail closed — arguably correct, since they cannot authenticate anyway |

**Recommendation (not a decision):** **option 1, with option 4's allow-list change as the first
concrete step.** Keep GitHub Pages canonical, keep Netlify for PR previews, and stop treating
`*.netlify.app` as a production host. **Re-home the `www` redirect before any Netlify teardown.**

## 8. Decision required from the owner — **DECIDED 2026-09-20, see §9**

1. **Which option** (1, 2, 3, 4 or another) defines the intended role of the Netlify surface?
2. If the Netlify surface is to be retired or de-listed, **how is `www.stagerz.app` to be served**
   afterwards — a DNS-level redirect, GitHub Pages, or keeping the Netlify site solely for that
   redirect and previews?
3. Should the diagnosis be completed first — a read of the Netlify project's continuous-deployment
   settings and deploy list — to establish the exact mechanism before acting?

**Until an option is approved, nothing about Netlify is to be changed:** no deploy trigger, no
domain or DNS change, no production-branch setting change, no allow-list edit, no disabling or
deletion of the site, no redirect change.

---

## 9. Owner decision and implementation status (2026-09-20)

### Architecture approved in principle

The product owner approved the target architecture:

- **`stagerz.app` is the canonical GitHub Pages production application** — and the only one.
- **`www.stagerz.app` must ultimately be served or redirected through GitHub Pages, not Netlify.**
- **No `*.netlify.app` hostname may be accepted as STAGERZ production.**
- **The Netlify site is retained.** It must **not** be deleted or disabled. Its eventual
  preview/test role will be decided **together with the T2 test-environment decision**.

This is approval **in principle** for the architecture. It is **not** blanket approval to mutate
systems: each migration step needs its own approval.

### Step 2 — IMPLEMENTED (repository only)

The only step approved and executed so far is the repository change:

- `index.html` — the two site-level Netlify hostnames
  (`aquamarine-puppy-beccd9.netlify.app`, `main--aquamarine-puppy-beccd9.netlify.app`) were removed
  from `STAGERZ_HOST_ENVIRONMENT`. `stagerz.app`, `www.stagerz.app`, `localhost` and `127.0.0.1`
  are unchanged, and `STAGERZ_ENVIRONMENTS` (Supabase URL, publishable key, auth redirect) is
  **byte-identical** to `origin/main`.
- `tests/environment-selection.test.ts` — those hosts moved out of the expected-production list and
  into the fail-closed list, plus a new architecture-invariant test,
  *"no `*.netlify.app` hostname is accepted as production"*, which also asserts that no host
  containing `netlify.app` remains anywhere in the map. **6/6 tests pass**, and a deliberate
  mutation re-adding one host is caught by two tests.

**Effect:** every Netlify hostname class — site, branch, deploy-preview and deploy-permalink — now
**fails closed**, so the stale Netlify surface can no longer reach the production backend, even
while it remains publicly served. This closes the exposure in the repository, independently of any
Netlify setting.

**Effect on previews:** none in practice. Deploy previews already failed closed before this change
(they were never in the host map), so they already did **not** boot the application. This change
does not degrade them further — see §4 of `preflight.md` and §D of the Phase 22.4 diagnosis
discussion.

### NOT executed — everything outside the repository

| Step | System | Status |
|---|---|---|
| 0 — read Netlify continuous-deployment settings and deploy list | Netlify UI | **NOT DONE** — root cause of the stale deploy therefore remains **UNKNOWN** (§5) |
| 1 — add the 3 missing apex `A` records (and optional `AAAA`) | STRATO DNS | **NOT EXECUTED** |
| 3 — repoint `www` CNAME to `nani6hi.github.io` | STRATO DNS | **NOT EXECUTED** |
| 4 — remove the `www` alias and the `stagerz.app` custom domain from Netlify | Netlify | **NOT EXECUTED** |
| 5 — Netlify residual role (keep previews / republish / delete) | Netlify | **DEFERRED to the T2 decision** |

**No DNS record, Netlify setting, domain, redirect, deploy or `CNAME` file was changed.**

### Consequences that remain true until the DNS step is executed

1. **`www.stagerz.app` still depends on Netlify.** It resolves by CNAME to
   `aquamarine-puppy-beccd9.netlify.app` and is served by Netlify as a 301 to the apex. Removing or
   disabling the Netlify site now would **break `www`**. That is why the site must be retained
   until Step 3 is executed and verified.
2. **The stale Netlify surface remains publicly served** at both `*.netlify.app` hostnames, still
   showing the `7ae06c1` build. After Step 2 is deployed it can no longer select the production
   backend — it will fail closed and show the start-up failure panel instead.
3. **Netlify still believes it owns `stagerz.app`** (`primarySiteUrl`), so split deployment
   ownership persists until Step 4.
4. **The apex still has a single `A` record** and no `AAAA`, so it remains a single-IP dependency
   until Step 1.
