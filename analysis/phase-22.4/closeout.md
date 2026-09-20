# Phase 22.4 — Closeout

**Phase:** 22.4 — Current-Epoch Production Smoke & Deployment Surface Reconciliation
**Status:** **COMPLETE / PASS** — closed 2026-09-20. The transient `www` TLS condition observed during migration is **RESOLVED**; see §7.
**Date:** 2026-09-20.
**Merged work:** PR #29 (merge `7eaf829de0927c67ab1455d7c54cb1f8153beee7`, phase commit
`9cd28557283f749ab57010bd3e8d31303001de4e`). `main` = `origin/main` = `7eaf829`.
**Closeout branch:** `phase-22.4-closeout`, from `main` @ `7eaf829`. Documentation only.

---

## 1. Closure statement

**Phase 22.4 is COMPLETE / PASS.** Every acceptance criterion in `phase-definition.md` §5 is
**MET**, and all five stated purposes of the phase were carried out. The one item that briefly held
closure — the `www` TLS certificate — **has been resolved without any setting change**; the full
chronology and evidence are in §7.

### PASS means

- **current-epoch production startup, authentication, session restore, core read, profile write,
  restoration and sign-out were demonstrated** within the intentionally reduced safe scope;
- the **scheduled maintenance status was reconciled**;
- the **stale / split deployment surface was diagnosed**;
- **`stagerz.app` is the canonical public production surface on GitHub Pages**;
- **`www.stagerz.app` now resolves through GitHub Pages and redirects to the apex successfully** in
  owner-observed HTTPS validation;
- the **Netlify custom domains `stagerz.app` and `www.stagerz.app` were detached**;
- **Netlify is no longer in the STAGERZ custom-domain public request path**;
- **PR #29 removed the native Netlify hosts from the current production host map**;
- production data was left as found — the single approved edit was restored and verified.

### PASS does NOT mean

- that **D — Auth / API / Realtime clean-room** is complete;
- that **E — full Edge Functions clean-room** is complete;
- that **G — Storage API clean-room** is complete;
- that **C3 — full Auth-account fixture** is complete;
- that the **stale native Netlify deployment itself has been republished or retired** — it has not
  (§5);
- that the **T2 / test-environment strategy** is complete;
- that **all production-readiness / hardening issues are solved** (§6);
- that **global DNS / TLS behaviour was exhaustively tested from every resolver**;
- that the **other-artist `public_profiles` read** was verified on the current epoch — it was
  **NOT EXECUTED** (§3);
- that the **collaboration write path, Realtime delivery or the Phase 21.9 error contract** were
  verified on the current epoch — **SKIPPED by design** and **N/A** respectively (§3);
- that any **network-level audit** was performed — observation was via the browser Console only.

---

## 2. Deployment architecture after reconciliation

| Surface | DNS | Served by | Status |
|---|---|---|---|
| `stagerz.app` (apex, canonical) | STRATO `A → 185.199.108.153` (**unchanged**) | **GitHub Pages** | **Current** — serves `origin/main` @ `7eaf829` **byte-identical** (276,592 bytes, SHA-256 `4878aacd3aac05bc…`), verified cache-busted |
| `www.stagerz.app` | STRATO `CNAME → nani6hi.github.io` (**migrated**) | **GitHub Pages** | **Working over HTTP and HTTPS.** 301 to `https://stagerz.app/`, `Server: GitHub.com`; certificate `CN=stagerz.app` with SAN `DNS:stagerz.app, DNS:www.stagerz.app`, verify code 0. The transient TLS gap during migration is **RESOLVED** — see §7 |
| `aquamarine-puppy-beccd9.netlify.app` | Netlify-owned | Netlify | **Still serves the stale `7ae06c1` build** (274,833 bytes, SHA-256 `9074cb183e841ff6…`). No longer a STAGERZ production host in code |
| `main--aquamarine-puppy-beccd9.netlify.app` | Netlify-owned | Netlify | Same stale deploy |
| `deploy-preview-N--…netlify.app` | Netlify-owned | Netlify | Previews still build; fail closed, do not boot the app |

**Netlify custom domains: removed.** Independently verified read-only — the project's
`primarySiteUrl` is now **`https://aquamarine-puppy-beccd9.netlify.app`**, no longer
`https://stagerz.app`. The split deployment ownership recorded in
`netlify-surface-diagnosis.md` §4 is **resolved**.

**The Netlify project was not deleted**, by owner decision. Its residual preview/test role remains
**deferred to the T2 test-environment decision**.

---

## 3. Production smoke evidence (authoritative summary)

Executed manually by the owner on `https://stagerz.app`, 2026-09-20. Full record:
`production-smoke-record.md`.

| Test | Result | Classification |
|---|---|---|
| P22.4-1 Startup / production environment selection | **PASS** | TESTED |
| P22.4-2 Real magic-link authentication | **PASS** | TESTED |
| P22.4-2 Session restore (F5 and Ctrl+F5) | **PASS** | TESTED |
| P22.4-3 Stage / core authenticated read | **PASS** | TESTED |
| P22.4-4b Own profile read | **PASS** | TESTED |
| P22.4-5 Reversible `profiles.bio` write | **PASS** | TESTED |
| P22.4-5 Persistence after reload | **PASS** | TESTED |
| P22.4-5 Exact restoration of the original value | **PASS** | TESTED |
| P22.4-8 Sign-out and signed-out state after reload | **PASS** | TESTED |
| P22.4-4 Other/public artist profile via Stage | **NOT EXECUTED** | Stage UI exposed no such navigation path; no deep link or DevTools bypass was fabricated. **A UI/product finding, not backend evidence** |
| P22.4-6 Collaboration message mutation | **SKIPPED BY DESIGN / SAFETY** | Would leave permanent `collaboration_activity` and notification rows. **Not a FAIL** |
| P22.4-7 Stale-delete / error-contract test | **N/A — NOT EXECUTED** | Dependant of the skipped P22.4-6; no substitute was performed |

Production backend selected and exercised: **`kbnmkyvbwkuvcklywdhk`**, schema epoch
**`20260917143322`**. No tester e-mail address, magic-link URL, auth token or profile-bio literal
is recorded anywhere in this repository.

**Residue:** none. The one edited field was restored to its exact original value and verified after
reload.

---

## 4. Migration executed — steps, evidence, and what was deliberately not done

| Step | System | Status | Evidence |
|---|---|---|---|
| **2** — remove the two site-level `*.netlify.app` hosts from `STAGERZ_HOST_ENVIRONMENT` | Repository | **DONE** — merged in **PR #29** (`7eaf829`) | Production map is now `stagerz.app`, `www.stagerz.app` → production; `localhost`, `127.0.0.1` → local. 6/6 tests pass, including the invariant *"no `*.netlify.app` hostname is accepted as production"* |
| **3** — repoint the `www` CNAME | STRATO DNS | **DONE** — `www.stagerz.app CNAME → nani6hi.github.io`; STRATO reported *"Ihre Aktion wurde erfolgreich ausgeführt."* | Independently re-verified at the **authoritative** nameserver `shades11.rzone.de` **and** via a public resolver |
| **4** — remove Netlify's custom domains | Netlify | **DONE** — `stagerz.app` removed via Domain Management → Options → Remove domain; `www.stagerz.app` disappeared with it | Netlify Domain Management then listed only `aquamarine-puppy-beccd9.netlify.app`; HTTPS section reported *"A custom domain is required to provision a certificate."* Independently confirmed: `primarySiteUrl` is now the `.netlify.app` host |
| **1** — add the 3 missing apex `A` records | STRATO DNS | **NOT EXECUTED** | Apex still resolves to the single IP `185.199.108.153`; **deliberately unchanged** during this operation |
| **0** — read Netlify continuous-deployment settings / deploy list | Netlify | **NOT EXECUTED** | The stale-deploy root cause therefore remains **UNKNOWN** |
| **5** — Netlify residual role | Netlify | **DEFERRED** to the T2 decision | Project retained, not deleted |

**Deliberately not changed:** no NS, MX, AAAA, DMARC, SPF or unrelated DNS record; the apex `A`
record; the repository `CNAME` file; GitHub Pages settings; Supabase; the Netlify project itself.

### Owner browser validation — two checks, before and after certificate issuance

**First check, immediately after the DNS change.** In a private/incognito browser the owner
navigated to `https://www.stagerz.app` and observed: the browser ended at `stagerz.app`, the
STAGERZ login UI rendered normally, HTTPS succeeded without a certificate warning, and the visible
DevTools console showed no red runtime error. At that moment GitHub had **not yet issued** the
`www` certificate (§7), so the most consistent reading is that the fresh incognito profile carried
no HSTS pin and the request reached GitHub Pages over HTTP, was redirected, and completed over
HTTPS **on the apex**.

**Second check, after GitHub reported "DNS check successful".** In a private/incognito browser the
owner **explicitly entered `https://www.stagerz.app`** and observed: **no TLS/certificate warning**,
successful navigation, the address bar ending at `stagerz.app`, and the STAGERZ login UI rendering
normally. This is direct evidence that **`https://www.stagerz.app` itself now terminates TLS
successfully**.

**Scope of that evidence, stated precisely:** both are **browser/runtime evidence of the
owner-observed `www` → apex path**, corroborated by independent command-line certificate and
redirect verification (§7). **Neither is a claim that global DNS or TLS propagation was
exhaustively verified from every resolver.**

### No-downtime result

The canonical surface, `stagerz.app`, was **never interrupted**: it is served by GitHub Pages from
a DNS record that was never touched, and it verifiably serves the current merged build. The
ordering constraint was honoured — Step 2 merged before the DNS change, and Step 4 (Netlify domain
removal) was performed only after Step 3. The one transient defect, on `www` over HTTPS during
certificate provisioning, is **resolved** (§7).

---

## 5. Netlify native hostname — explicitly NOT reconciled

`aquamarine-puppy-beccd9.netlify.app` and `main--…` **still serve the stale `7ae06c1` deploy**
(verified again after the migration: 274,833 bytes, SHA-256 `9074cb183e841ff6…`, unchanged). That
build **predates the environment-selection block entirely** — it contains no
`STAGERZ_HOST_ENVIRONMENT` at all and still carries the hard-coded production Supabase URL.

**Therefore the host-fail-closed protection from PR #29 does NOT apply to what that hostname is
currently serving.** The repository guarantee applies to every future build; it cannot retroactively
change a deploy published on 2026-09-19.

What has changed is the **request path**: the hostname is no longer reachable through any STAGERZ
custom domain, so it is no longer in the public production path. It remains publicly reachable at
its native Netlify address.

**Open until separately reconciled or retired** — carried into the T2/Netlify-role decision.

---

## 6. Deferred gates and carry-forwards

### Phase 22.3 clean-room gates — unchanged, still OPEN

Nothing in Phase 22.4 converts any of these to PASS. They belong to later runtime/test-environment
validation, most likely **Phase 22.5 / T2**.

| Gate | Status |
|---|---|
| **D** — Auth / API / Realtime clean-room | **OPEN** |
| **E** — complete Edge Functions clean-room | **OPEN** (`delete-account` and `process-pending-deletions` still never executed anywhere) |
| **G** — Storage API clean-room | **OPEN** (blocked locally by `storage-api:v1.72.1` exit 139) |
| **C3** — full Auth-account fixture | **OPEN** |

### Carry-forwards not resolved by this phase

| Item | Gate |
|---|---|
| `https://www.stagerz.app` certificate | **RESOLVED 2026-09-20** — transient during migration; see §7 |
| Netlify native hostname still serving the stale build (§5) | Before public beta |
| Apex has a single `A` record and no `AAAA` (migration Step 1) | Hardening |
| Netlify stale-deploy root cause **UNKNOWN** (migration Step 0) | Hardening / T2 |
| 2 `collaboration_assets` rows referencing missing Storage objects | Before public beta |
| Default SMTP reaches organisation members only — custom SMTP | **Before real users** |
| Backups / Free-plan readiness | **Before real users** |
| CAPTCHA / signup-abuse hardening | Before public beta |
| Synthetic / test-data cleanup | Before public beta |
| Account-deletion UI gap — `delete-account` has no caller | Product / before real users |
| Legacy production `anon` / `service_role` key hardening | Hardening |
| Session policy, CSP, monitoring, CI | Hardening |
| Migration-history reconciliation | Deferred infrastructure |
| Legacy project disposition / T2 decision | Deferred infrastructure |
| **Stage exposes no direct artist-profile navigation** (found by P22.4-4) | Product / UX |

---

## 7. The `www` TLS condition — transient during migration, now RESOLVED

**Status: RESOLVED. No setting was changed to resolve it.** This section is retained in full
because the failure was genuinely observed and independently verified; erasing it would break the
audit trail. What changed is its **status**, not the finding.

### Chronology

| Time (UTC, 2026-09-20) | Event | Source |
|---|---|---|
| 14:33:59 | PR #29 merged to `main` as `7eaf829` | GitHub |
| 14:34:33 | GitHub Pages published the merge; apex serving the new build | HTTP `Last-Modified` |
| *(before 14:42:34)* | **Transient failure observed.** `https://www.stagerz.app` could not complete TLS: the certificate presented was **`CN=*.github.io`**, the CNAME target's default wildcard, which does not cover `www.stagerz.app`. Three consecutive `curl` attempts returned `code=000`. `http://www.stagerz.app/` already returned **301 → `https://stagerz.app/`** with `Server: GitHub.com`, so DNS and Pages routing were already correct | Independent read-only verification (`curl`, `openssl s_client`) |
| *(around then)* | GitHub Pages Settings showed **Custom domain: `stagerz.app`**, **"DNS Check in Progress"**, **Enforce HTTPS enabled**. **No GitHub Pages setting was changed** | Owner, manual check |
| **14:42:34** | **GitHub issued the certificate** — `notBefore = Sep 20 14:42:34 2026 GMT` | Certificate itself |
| shortly after | GitHub Pages Settings showed **"DNS check successful"**, Enforce HTTPS still enabled | Owner, manual check |
| after that | **Owner browser validation.** In a private/incognito browser the owner explicitly entered `https://www.stagerz.app`: **no TLS/certificate warning**, the browser navigated successfully, the address bar ended at `stagerz.app`, and the STAGERZ login UI rendered normally | Owner, manual check |
| later | **Independent re-verification.** `https://www.stagerz.app/` → **HTTP 301 → `https://stagerz.app/`**, `Server: GitHub.com`. Certificate `subject=CN=stagerz.app`, **SAN `DNS:stagerz.app, DNS:www.stagerz.app`**, issuer Let's Encrypt, **`Verify return code: 0 (ok)`**, valid `Sep 20 – Dec 19 2026`. Full chain follows to `https://stagerz.app/` with **HTTP 200** | `curl`, `openssl s_client` |

### Interpretation

The failure was a **transient migration condition**: GitHub had not yet completed its DNS check and
certificate issuance for the newly pointed `www` name. The certificate's own `notBefore` of
**14:42:34Z** is objective proof that no certificate covering `www.stagerz.app` existed at the time
of the failing checks, and that one existed afterwards. **It was never a misconfiguration**, and
**no GitHub Pages, DNS or Netlify setting was changed to fix it** — GitHub completed provisioning
on its own.

### The HSTS consideration, now moot

Netlify had previously served `www` with `Strict-Transport-Security: max-age=31536000`, so during
the gap any browser with that pin would have forced HTTPS and hit the certificate mismatch with no
click-through. Now that a valid certificate covering `www.stagerz.app` is in place, the pin is
satisfied rather than violated, and this concern no longer applies.

### Scope of the evidence

The owner's check is **browser/runtime evidence of an explicit `https://www.stagerz.app` request**,
and mine is command-line verification of the certificate and redirect from one vantage point.
Together they establish that the path works. **Neither is a claim that global DNS or TLS behaviour
was exhaustively tested from every resolver**, and no such claim is made anywhere in this phase.

## 8. Next recommended phase

**Phase 22.5 — Runtime Rebuild & Test Environment Validation.** Scope: a T2 cloud test
environment; gate **D** clean-room Auth/API/Realtime; gate **E** all four Edge Functions, including
the first controlled runtime exercise of `delete-account` and `process-pending-deletions`; gate
**G** Storage API; gate **C3** full Auth fixture. The T2 slot question is coupled to the legacy
project's disposition on the Free plan, and **T2 creation, legacy pause/delete and a Supabase Pro
upgrade are all still unapproved.**

Two small items could be folded in or handled separately: migration **Step 0** (read Netlify's
continuous-deployment settings, resolving the stale-deploy root cause) and migration **Step 1**
(apex `A`-record redundancy). Retiring or republishing the Netlify native hostname (§5) fits
naturally alongside the T2 decision.
