// tests/environment-selection.test.ts
//
// Phase 22.3 -- offline checks for the hostname -> environment selection in
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
    stagerzSelectEnvironment: (host: string, origin: string, getLocalKey?: () => string | null) => Selection;
  };
}

const PRODUCTION_HOSTS = [
  "stagerz.app",
  "www.stagerz.app",
  "aquamarine-puppy-beccd9.netlify.app",
  "main--aquamarine-puppy-beccd9.netlify.app",
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
