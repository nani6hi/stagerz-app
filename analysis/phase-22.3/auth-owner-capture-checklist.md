# Phase 22.3 — Owner Auth Capture Checklist (production `kbnmkyvbwkuvcklywdhk`)

**Why:** Auth configuration is not readable by the available tooling, but it is part of what makes the backend work (the magic-link sign-in depends on it). It must be captured once, recorded in `supabase/config/environment-inventory.md` §6, and reproduced in any rebuilt environment.

**How:**
- Open the Supabase dashboard for project **`kbnmkyvbwkuvcklywdhk`** and check that the URL contains that ref.
- **Read only; change nothing.**
- Report each value in plain text (or a screenshot with any e-mail addresses or secrets covered).

**Do NOT send or record:**
- user e-mail addresses or user lists;
- SMTP passwords, API keys, JWT secrets or service-role keys;
- any secret value.

Where a field is a secret, report only "set / not set".

## A. URL configuration — Authentication → URL Configuration

| # | Setting | What to report |
|---|---|---|
| A1 | Site URL | The URL |
| A2 | Redirect URLs (allow-list) | Every entry, exactly as listed (these are URLs, not secrets) |

## B. Sign-in and providers — Authentication → Sign In / Providers

| # | Setting | What to report |
|---|---|---|
| B1 | Allow new users to sign up | ON / OFF |
| B2 | Allow anonymous sign-ins | ON / OFF |
| B3 | Allow manual linking | ON / OFF (if shown) |
| B4 | Email provider enabled | ON / OFF |
| B5 | Confirm email | ON / OFF |
| B6 | Secure email change | ON / OFF |
| B7 | Secure password change / password requirements | Values (the app uses magic link, but the provider may still allow passwords) |
| B8 | Email OTP expiration | Seconds |
| B9 | Email OTP length | Digits |
| B10 | Other enabled providers (Google, Apple, Phone, …) | List, or "none" |

## C. Email — Authentication → Emails (and SMTP Settings)

| # | Setting | What to report |
|---|---|---|
| C1 | Custom SMTP enabled | ON / OFF |
| C2 | If ON: sender name and sender address domain, host and port | Values. **Do not report the SMTP password.** |
| C3 | "Magic Link" template | Whether it uses `{{ .ConfirmationURL }}` (a link), `{{ .Token }}` (a code) or both. Structure only; no need to copy the text |
| C4 | "Confirm signup" template | Same as C3 |

## D. Rate limits — Authentication → Rate Limits

| # | Setting | What to report |
|---|---|---|
| D1 | Emails sent per hour | Value |
| D2 | Sign-ups and sign-ins (per IP / per period) | Value |
| D3 | Token refreshes | Value |
| D4 | Token verifications (OTP / magic link) | Value |

## E. Bot and abuse protection — Authentication → Attack Protection

| # | Setting | What to report |
|---|---|---|
| E1 | CAPTCHA protection | ON / OFF; provider name if ON. **Not the secret key.** |
| E2 | Leaked password protection | ON / OFF (expected OFF on Free) |

## F. Sessions and JWT — Authentication → Sessions, and Project Settings → JWT Keys

| # | Setting | What to report |
|---|---|---|
| F1 | Access-token (JWT) expiry | Seconds |
| F2 | Refresh-token reuse interval / rotation | Values |
| F3 | Time-box / inactivity timeout for sessions | Values or "not set" |
| F4 | JWT signing system | Legacy JWT secret / new signing keys. **No key material.** |

## G. API keys — Project Settings → API Keys (state only)

| # | Setting | What to report |
|---|---|---|
| G1 | Legacy JWT-based keys (anon / service_role) | **Already known (tool-read 2026-09-19): legacy `anon` ENABLED.** Owner confirms only whether `service_role` shows the same (it is not listed by the tooling) |
| G2 | Publishable / secret keys | **Already known: 1 publishable key, enabled.** Owner reports only the **number** of secret (`sb_secret_…`) keys, and whether they are enabled. Never the values |

## H. Hooks and advanced

| # | Setting | What to report |
|---|---|---|
| H1 | Auth hooks (send-email, custom access token, …) | List enabled hooks, or "none" |
| H2 | MFA settings | Enabled factors, or "none" |

## What happens with the answers

- The answers are recorded in `supabase/config/environment-inventory.md` §6 (values only; no secrets or e-mails).
- Rebuilt environments copy them, with URLs adapted per environment.
- **Items that are production-readiness gaps are listed, not fixed, in Phase 22.3:** for example C1 = OFF (the default SMTP only reaches team members), E1 = OFF, and wide redirect allow-lists.

---

## Capture record — COMPLETE (2026-09-19; two owner submissions)

**Source:** the owner's dashboard screenshots of production `kbnmkyvbwkuvcklywdhk`. The values are **owner/dashboard-confirmed** (not tool-verified), except where "tool" is noted. **No setting was changed.** No e-mail, secret or key value was supplied or recorded. The full value table is in `supabase/config/environment-inventory.md` §6.

| Item | Status | Value |
|---|---|---|
| A1 Site URL | ✅ captured | `https://stagerz.app` |
| A2 Redirect URLs | ✅ captured | `https://stagerz.app` (1 entry) |
| B1 Allow new users to sign up | ✅ | ON |
| B2 Anonymous sign-ins | ✅ | OFF |
| B3 Manual linking | ✅ | OFF |
| B4 Email provider | ✅ | ENABLED |
| B5 Confirm email | ✅ | ON |
| B6 Secure email change | ✅ | ON |
| B7 Password settings | ✅ | secure password change OFF; require current password OFF; leaked-password prevention OFF; minimum length 6; no extra requirements |
| B8 Email OTP expiry | ✅ | 3600 s |
| B9 Email OTP length | ✅ | 6 digits |
| B10 Other providers | ✅ | Phone DISABLED; all others disabled |
| C1 Custom SMTP | ✅ | OFF |
| C2 SMTP details | n/a (custom SMTP off) | — |
| C3 Magic Link template mode | ✅ | link-based |
| C4 Confirm-signup template | optional (same question as C3) | — |
| D1–D4 Rate limits | ✅ | e-mails 2/h; SMS 30/h; token refresh 150 / 5 min / IP; token verification 30 / 5 min / IP; anonymous 30/h/IP; sign-up and sign-in 30 / 5 min / IP; Web3 30 / 5 min / IP; IP forwarding OFF |
| E1 CAPTCHA | ✅ | OFF |
| E2 Leaked-password protection | ✅ | DISABLED |
| F1 JWT / access-token expiry | ✅ | 3600 s |
| F2 Refresh-token rotation / reuse | ✅ | ON / 10 s |
| F3 Time-box / inactivity / single session | ✅ | 0 (never) / 0 (never) / OFF |
| F4 JWT signing system | optional | — |
| G1 Legacy keys | ✅ | `anon` enabled (tool and owner); `service_role` enabled (owner) |
| G2 Publishable / secret keys | ✅ | 1 publishable, enabled (tool); 1 `sb_secret_…` key (count only) |
| H1 Auth hooks | ✅ | none |
| H2 MFA | ✅ | TOTP ENABLED; Phone DISABLED; max 10 factors; AAL1 session limit ON (0 factors enrolled, per database) |

**Status: COMPLETE.** All required items are captured.

Optional items not captured, and not needed for reproducibility:
- C4, the confirm-signup template (the app uses the magic-link flow);
- F4, the JWT signing system (key material is never recorded; the key *state* is captured in G1/G2).

### Observations for later phases (recorded, not acted on)

1. **External users cannot sign in today.** Sign-ups are ON, but custom SMTP is OFF: the default SMTP delivers only to organisation team members and is limited to **2 e-mails per hour**. This confirms the production-readiness blocker (custom SMTP phase).
2. **The redirect allow-list holds only `https://stagerz.app`.** That is consistent with the Phase 22.3 environment map, which keeps the production redirect fixed to `https://stagerz.app` for every production host (`www`, Netlify). A future test or local environment needs its **own** project allow-list; production's list stays as it is.
3. **Sign-ups ON with CAPTCHA OFF:** acceptable while the default SMTP caps sending. It becomes an abuse risk once custom SMTP opens delivery (Supabase recommends CAPTCHA at that point). This belongs to the SMTP/readiness phase.
4. **Sessions** never time out (no time-box or inactivity limit); refresh-token rotation is ON with a 10 s reuse interval. These are platform defaults. Revisit in the readiness review.
5. **Magic link confirmed link-based, OTP 6 digits / 3600 s.** This matches the shipped flow. The `index.html` comments' intended numeric-code flow (label inventory §5) would need the template changed, which requires custom SMTP. It stays a product decision for the SMTP phase.
6. **Password settings are weak** (minimum length 6, no complexity, leaked-password prevention OFF). The app is passwordless, but the email provider accepts password sign-up and sign-in through the API. Readiness review: consider disabling password sign-in or strengthening the rules.
7. **Legacy JWT keys (`anon`, `service_role`) are both enabled**, alongside 1 publishable and 1 secret key. Nothing in the repository uses the legacy keys (the frontend uses the publishable key; the Edge Functions receive platform-injected keys). Whether the legacy keys can be disabled — which would need checking what the platform injects into `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` for the functions — is a later hardening item.
