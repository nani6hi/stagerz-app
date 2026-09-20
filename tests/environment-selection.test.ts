// tests/environment-selection.test.ts
//
// Phase 22.3 / 22.4 / 22.5 -- offline checks for the hostname -> environment selection in
// index.html (the block between "STAGERZ ENVIRONMENT SELECTION (BEGIN)" and
// "(END)"). Run from the repository root:
//
//   deno test --allow-read tests/environment-selection.test.ts
//
// The block is evaluated in isolation; no network, no browser, no Supabase.

import { assert, assertEquals } from "jsr:@std/assert@1";

const PRODUCTION_URL = "https://kbnmkyvbwkuvcklywdhk.supabase.co";
const PRODUCTION_REDIRECT = "https://stagerz.app";

type Selection = {
  ok: boolean;
  reason?: string;
  name?: string;
  supabaseUrl?: string;
  supabaseKey?: string;
  authRedirectUrl?: string;
};

async function loadBlock() {
  const html = await Deno.readTextFile(new URL("../index.html", import.meta.url));
  const begin = html.indexOf("// === STAGERZ ENVIRONMENT SELECTION (BEGIN) ===");
  const end = html.indexOf("// === STAGERZ ENVIRONMENT SELECTION (END) ===");
  assert(begin >= 0 && end > begin, "environment selection markers not found in index.html");
  const block = html.slice(begin, end);
  // deno-lint-ignore no-explicit-any
  const factory = new Function(block + "\nreturn { STAGERZ_ENVIRONMENTS, STAGERZ_HOST_ENVIRONMENT, stagerzSelectEnvironment };") as () => any;
  return factory() as {
    STAGERZ_ENVIRONMENTS: Record<string, { supabaseUrl: string; supabaseKey: string | null; authRedirectUrl: string | null }>;
    STAGERZ_HOST_ENVIRONMENT: Record<string, string>;
    stagerzSelectEnvironment: (host: string, origin: string, getLocalKey?: () => string | null, getLocalUrl?: () => string | null) => Selection;
  };
}

const PRODUCTION_HOSTS = [
  "stagerz.app",
  "www.stagerz.app",
];

Deno.test("production hostnames select production with the unchanged URL, key and redirect", async () => {
  const m = await loadBlock();
  const prodKey = m.STAGERZ_ENVIRONMENTS.production.supabaseKey;
  assert(typeof prodKey === "string" && prodKey.startsWith("sb_publishable_"), "production key must be a publishable key");
  for (const host of PRODUCTION_HOSTS) {
    let localKeyRead = false;
    const s = m.stagerzSelectEnvironment(host, "https://" + host, () => { localKeyRead = true; return "local-key"; });
    assertEquals(s.ok, true, host);
    assertEquals(s.name, "production", host);
    assertEquals(s.supabaseUrl, PRODUCTION_URL, host);
    assertEquals(s.supabaseKey, prodKey, host);
    assertEquals(s.authRedirectUrl, PRODUCTION_REDIRECT, host); // fixed redirect, as before
    assertEquals(localKeyRead, false, "local key getter must not be called on " + host);
  }
});

Deno.test("localhost and 127.0.0.1 select the local environment, never production", async () => {
  const m = await loadBlock();
  for (const host of ["localhost", "127.0.0.1"]) {
    const origin = "http://" + host + ":8080";
    const s = m.stagerzSelectEnvironment(host, origin, () => "local-publishable-key");
    assertEquals(s.ok, true, host);
    assertEquals(s.name, "local", host);
    assert(s.supabaseUrl !== PRODUCTION_URL, "local must not use the production URL");
    assertEquals(s.supabaseUrl, "http://127.0.0.1:54321");
    assertEquals(s.supabaseKey, "local-publishable-key");
    assertEquals(s.authRedirectUrl, origin, "redirect must follow the local origin");
  }
});

Deno.test("a local host without a configured key fails closed", async () => {
  const m = await loadBlock();
  for (const getter of [() => null, () => "", undefined]) {
    const s = m.stagerzSelectEnvironment("localhost", "http://localhost:8080", getter);
    assertEquals(s.ok, false);
    assertEquals(s.reason, "environment-not-configured");
    assertEquals(s.supabaseUrl, undefined);
    assertEquals(s.supabaseKey, undefined);
  }
});

Deno.test("unknown hosts fail closed and never fall back to production", async () => {
  const m = await loadBlock();
  const unknown = [
    // Phase 22.4 Step 2: the two site-level Netlify hosts were removed from the
    // production map, so every Netlify hostname class now fails closed.
    "aquamarine-puppy-beccd9.netlify.app",
    "main--aquamarine-puppy-beccd9.netlify.app",
    "deploy-preview-12--aquamarine-puppy-beccd9.netlify.app",
    "feature-x--aquamarine-puppy-beccd9.netlify.app",
    "nani6hi.github.io",
    "stagerz.app.evil.example",
    "evilstagerz.app",
    "STAGERZ.APP",
    "",
    "192.168.1.10",
    "hasOwnProperty",
    "__proto__",
  ];
  for (const host of unknown) {
    const s = m.stagerzSelectEnvironment(host, "https://" + host, () => "local-key");
    assertEquals(s.ok, false, JSON.stringify(host));
    assertEquals(s.reason, "unknown-host", JSON.stringify(host));
    assertEquals(s.supabaseUrl, undefined);
    assertEquals(s.supabaseKey, undefined);
    assertEquals(s.authRedirectUrl, undefined);
  }
});

Deno.test("every mapped hostname points at a defined environment", async () => {
  const m = await loadBlock();
  for (const [host, env] of Object.entries(m.STAGERZ_HOST_ENVIRONMENT)) {
    assert(env in m.STAGERZ_ENVIRONMENTS, `${host} -> ${env} is not defined`);
  }
});

// Phase 22.4 Step 2 -- architecture invariant. stagerz.app (GitHub Pages) is the
// only canonical public production surface; no Netlify hostname may be accepted
// as production. The Netlify site itself is retained, but only the apex and www
// hosts may select the production backend.
Deno.test("no *.netlify.app hostname is accepted as production", async () => {
  const m = await loadBlock();
  const netlifyHosts = [
    "aquamarine-puppy-beccd9.netlify.app",
    "main--aquamarine-puppy-beccd9.netlify.app",
    "deploy-preview-28--aquamarine-puppy-beccd9.netlify.app",
    "feature-x--aquamarine-puppy-beccd9.netlify.app",
    "6aaedbd3f37b7f0008d4f107--aquamarine-puppy-beccd9.netlify.app",
    "netlify.app",
  ];
  for (const host of netlifyHosts) {
    const s = m.stagerzSelectEnvironment(host, "https://" + host, () => "local-key");
    assertEquals(s.ok, false, host);
    assertEquals(s.reason, "unknown-host", host);
    assertEquals(s.supabaseUrl, undefined, host);
    assertEquals(s.supabaseKey, undefined, host);
  }
  for (const host of Object.keys(m.STAGERZ_HOST_ENVIRONMENT)) {
    assert(!host.includes("netlify.app"), `${host} must not be in the host map`);
  }
});

// ---------------------------------------------------------------------------
// Phase 22.5 -- localStorage['stagerz:local-supabase-url'] override.
//
// Purpose: let a browser served from localhost target a disposable cloud test
// project (T2) for runtime validation, without ever letting a production
// visitor be redirected anywhere. No real T2 project exists yet; the ref used
// below is an obvious placeholder, not a real Supabase project.
// ---------------------------------------------------------------------------

const PLACEHOLDER_T2_URL = "https://notarealprojectref00.supabase.co";
const LOCAL_DEFAULT_URL = "http://127.0.0.1:54321";

Deno.test("no URL override leaves the local default unchanged", async () => {
  // An absent getter, and every value that means "nothing is set", must all
  // leave the shipped default in place -- never fail, never use production.
  const m = await loadBlock();
  const noOverride: Array<(() => string | null) | undefined> = [
    undefined,
    () => null,
    () => "",
    () => "   ",
  ];
  for (const getUrl of noOverride) {
    const s = m.stagerzSelectEnvironment("localhost", "http://localhost:8080", () => "local-key", getUrl);
    assertEquals(s.ok, true);
    assertEquals(s.name, "local");
    assertEquals(s.supabaseUrl, LOCAL_DEFAULT_URL);
    assertEquals(s.supabaseKey, "local-key");
  }
});

Deno.test("a valid non-production Supabase URL is accepted on local hosts", async () => {
  const m = await loadBlock();
  for (const host of ["localhost", "127.0.0.1"]) {
    const origin = "http://" + host + ":8080";
    for (const value of [PLACEHOLDER_T2_URL, PLACEHOLDER_T2_URL + "/", "  " + PLACEHOLDER_T2_URL + "  "]) {
      const s = m.stagerzSelectEnvironment(host, origin, () => "t2-publishable-key", () => value);
      assertEquals(s.ok, true, value);
      assertEquals(s.name, "local", value);
      assertEquals(s.supabaseUrl, PLACEHOLDER_T2_URL, value); // normalised
      assertEquals(s.supabaseKey, "t2-publishable-key", value);
      assertEquals(s.authRedirectUrl, origin, value); // follows the browser origin
    }
  }
});

Deno.test("a loopback override with an explicit port is accepted", async () => {
  const m = await loadBlock();
  const s = m.stagerzSelectEnvironment("localhost", "http://localhost:8080", () => "k", () => "http://127.0.0.1:64321");
  assertEquals(s.ok, true);
  assertEquals(s.supabaseUrl, "http://127.0.0.1:64321");
});

Deno.test("the production project URL is rejected by the override denylist", async () => {
  // Derived from the block itself, so the test cannot drift from the constant.
  const m = await loadBlock();
  const productionUrl = m.STAGERZ_ENVIRONMENTS.production.supabaseUrl;
  assert(productionUrl.includes(".supabase.co"), "production URL shape changed");
  for (const host of ["localhost", "127.0.0.1"]) {
    for (const value of [productionUrl, productionUrl + "/", "  " + productionUrl + " "]) {
      const s = m.stagerzSelectEnvironment(host, "http://" + host + ":8080", () => "k", () => value);
      assertEquals(s.ok, false, value);
      assertEquals(s.reason, "environment-not-configured", value);
      assertEquals(s.supabaseUrl, undefined, value);
      assertEquals(s.supabaseKey, undefined, value);
    }
  }
});

Deno.test("malformed and non-Supabase override values fail closed", async () => {
  const m = await loadBlock();
  const rejected = [
    "not a url",
    "javascript:alert(1)",
    "//notarealprojectref00.supabase.co",
    "ftp://notarealprojectref00.supabase.co",
    "http://notarealprojectref00.supabase.co", // http, not https
    "https://notarealprojectref00.supabase.co:443", // explicit port
    "https://notarealprojectref00.supabase.co/rest/v1", // path
    "https://notarealprojectref00.supabase.co?x=1", // query
    "https://user:pw@notarealprojectref00.supabase.co", // credentials
    "https://notarealprojectref00.supabase.co.evil.example", // suffix attack
    "https://evil.example/notarealprojectref00.supabase.co",
    "https://evil.example",
    "https://supabase.co",
    "http://127.0.0.1", // no port
    "http://127.0.0.1:0", // port out of range
    "http://127.0.0.1:99999", // port out of range
    "http://localhost:54321", // only 127.0.0.1 is accepted
    "http://127.0.0.1:54321/rest",
  ];
  for (const value of rejected) {
    const s = m.stagerzSelectEnvironment("localhost", "http://localhost:8080", () => "k", () => value);
    assertEquals(s.ok, false, value);
    assertEquals(s.reason, "environment-not-configured", value);
    assertEquals(s.supabaseUrl, undefined, value);
    assertEquals(s.supabaseKey, undefined, value);
  }
});

Deno.test("production hostnames ignore the URL override entirely", async () => {
  const m = await loadBlock();
  const productionUrl = m.STAGERZ_ENVIRONMENTS.production.supabaseUrl;
  const prodKey = m.STAGERZ_ENVIRONMENTS.production.supabaseKey;
  for (const host of ["stagerz.app", "www.stagerz.app"]) {
    let urlGetterCalled = false;
    let keyGetterCalled = false;
    const s = m.stagerzSelectEnvironment(
      host,
      "https://" + host,
      () => { keyGetterCalled = true; return "local-key"; },
      () => { urlGetterCalled = true; return PLACEHOLDER_T2_URL; },
    );
    assertEquals(s.ok, true, host);
    assertEquals(s.name, "production", host);
    assertEquals(s.supabaseUrl, productionUrl, host); // never the override
    assertEquals(s.supabaseKey, prodKey, host);
    assertEquals(s.authRedirectUrl, "https://stagerz.app", host);
    assertEquals(urlGetterCalled, false, "url override must not be consulted on " + host);
    assertEquals(keyGetterCalled, false, "key override must not be consulted on " + host);
  }
});

Deno.test("only the local environment opts into the URL override", async () => {
  // Structural guarantee: production immunity comes from the data, not from a
  // convention in the selection function.
  const m = await loadBlock();
  assertEquals(
    (m.STAGERZ_ENVIRONMENTS.production as Record<string, unknown>).allowsLocalUrlOverride,
    undefined,
  );
  assertEquals(
    (m.STAGERZ_ENVIRONMENTS.local as Record<string, unknown>).allowsLocalUrlOverride,
    true,
  );
});

Deno.test("an unknown host still fails closed even with a valid override set", async () => {
  const m = await loadBlock();
  for (const host of ["deploy-preview-32--aquamarine-puppy-beccd9.netlify.app", "evil-stagerz.app", ""]) {
    const s = m.stagerzSelectEnvironment(host, "https://" + host, () => "k", () => PLACEHOLDER_T2_URL);
    assertEquals(s.ok, false, host);
    assertEquals(s.reason, "unknown-host", host);
    assertEquals(s.supabaseUrl, undefined, host);
  }
});
