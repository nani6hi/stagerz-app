# Phase 22.3 — Frontend Environment Mapping (design D / G3)

**Owner approval:** decision 4. Implement a minimal hostname-based environment config now:
- no build system;
- unknown hosts fail closed;
- the sign-in redirect follows the selected environment;
- known production hosts are unchanged.

## 1. Exact mapping

| `window.location.hostname` | Environment | Supabase URL | Key | `emailRedirectTo` |
|---|---|---|---|---|
| `stagerz.app` | **production** | `https://kbnmkyvbwkuvcklywdhk.supabase.co` | the existing publishable key (unchanged) | `https://stagerz.app` (unchanged: fixed, not the current origin) |
| `www.stagerz.app` | **production** | same | same | `https://stagerz.app` (unchanged) |
| `aquamarine-puppy-beccd9.netlify.app` | **production** (Netlify production deploy of `main`) | same | same | `https://stagerz.app` (unchanged) |
| `main--aquamarine-puppy-beccd9.netlify.app` | **production** (Netlify's branch URL of the same `main` deploy) | same | same | `https://stagerz.app` (unchanged) |
| `localhost`, `127.0.0.1` | **local** (T1 local Supabase stack) | `http://127.0.0.1:54321` (Supabase CLI default API port) | **not in the repository**: read at runtime from `localStorage['stagerz:local-supabase-key']`, which the developer sets once from `supabase status`. If it is missing, startup fails closed | `window.location.origin` (e.g. `http://localhost:8080`) |
| **anything else** (including Netlify deploy previews `deploy-preview-N--…`, other branch deploys, `file://`, IP addresses, mirrors) | **none: FAIL CLOSED** | — | — | — |

**Adding a future test host** (for example the T2 cloud test environment on a Netlify branch deploy) needs two edits:
1. add a `test` entry to `STAGERZ_ENVIRONMENTS` (its URL and publishable key; publishable keys are public by design);
2. add a hostname line to `STAGERZ_HOST_ENVIRONMENT`.

No application logic changes.

## 2. Failure behaviour (fail closed)

- On an unmapped host, or a local host without a configured key:
  - **no Supabase client is created**;
  - `SUPA_URL` / `SUPA_KEY` stay `null`;
  - `startupFailure` is set to `unknown-host` or `environment-not-configured`.
- The existing Phase 21.2 startup guard then keeps the app on the boot screen:
  - `checkSessionAndStart()`, `goTo()` and auth-listener registration never run;
  - no request is sent to any backend.
- **There is no silent fallback to production.**
- **Message** (fixed text, via `textContent`): *"This address is not configured for STAGERZ."* The existing generic message stays for every other failure code.
- **Diagnostics:** the console logs the failure code only. The hostname is not echoed into the DOM.

## 3. Behaviour change assessment

| Surface | Before | After |
|---|---|---|
| `stagerz.app`, `www.stagerz.app`, `aquamarine-puppy-beccd9.netlify.app` | Production URL and key; redirect `https://stagerz.app` | **Identical values** (verified by a static test against the previous constants) |
| Netlify deploy previews / other branch deploys | Talked to **production** | **Blocked** (fail closed), until a test backend is mapped. This is intended: previews must not touch production |
| `localhost` | Talked to **production** | Talks to the local stack only; blocked if no local key is configured |
| Other or unknown hosts | Talked to production | Blocked |

## 4. Tests

`tests/environment-selection.test.ts` (Deno, offline). It extracts the marked block from `index.html` and asserts:
1. each production hostname selects production;
2. the production URL, key and redirect equal the previous hard-coded values;
3. localhost and 127.0.0.1 select `local` and never the production URL;
4. a local host without a key fails closed;
5. unknown hosts (preview, mirror, empty, IP, look-alike `stagerz.app.evil.example`, `STAGERZ.APP` casing) fail closed;
6. the redirect follows the selected environment;
7. the local-key getter is never called for production hosts.
