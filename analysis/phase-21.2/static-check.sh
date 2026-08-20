#!/usr/bin/env bash
# STAGERZ Phase 21.2 -- static startup-resilience and dependency-pinning
# invariants.
#
# Complements analysis/phase-21.2/startup-failure-harness.html: that harness
# drives the guarded initialiser against synthetic globals in a browser,
# this script proves the source-level invariants and needs no browser and
# no server. Section 6 is the only part that touches the network, and it
# is skipped automatically when offline.
#
# Run from the repository root:
#   bash analysis/phase-21.2/static-check.sh
#
# Exit code 0 = all invariants hold, 1 = at least one failed.

cd "$(dirname "$0")/../.." || exit 1
F=index.html
BASE=780d6f92263d51874d660fff53801899f4fff2de
PINNED_URL='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.1/dist/umd/supabase.js'
EXPECT_SHA384='0x8XPoHt08aHZj+RHs8ojmhZ5IDsTLjPgblgWdriayWriqv9dic3Vkv1K2+UqgZV'
EXPECT_SHA256='ed01c1c20daec4e06a08dbbf4fdc7d4a613091f7032a408faee2d6df45acad58'
fail=0
pass=0
skip=0

ok()   { printf '  PASS  %-58s (%s)\n' "$1" "$2"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %-58s (%s)\n' "$1" "$2"; fail=$((fail+1)); }
skipm(){ printf '  SKIP  %-58s (%s)\n' "$1" "$2"; skip=$((skip+1)); }

check_zero() {   # description, fixed-string
  local desc="$1" n
  n=$(grep -c -F "$2" "$F" 2>/dev/null || true); [ -z "$n" ] && n=0
  if [ "$n" -eq 0 ]; then ok "$desc" "0 occurrences"
  else bad "$desc" "$n occurrences"; grep -n -F "$2" "$F" | sed 's/^/          /'; fi
}

check_zero_re() {  # description, extended regex
  local desc="$1" n
  n=$(grep -c -E "$2" "$F" 2>/dev/null || true); [ -z "$n" ] && n=0
  if [ "$n" -eq 0 ]; then ok "$desc" "0 occurrences"
  else bad "$desc" "$n occurrences"; grep -n -E "$2" "$F" | sed 's/^/          /'; fi
}

check_count() {  # description, extended regex, expected count
  local desc="$1" n
  n=$(grep -c -E "$2" "$F" 2>/dev/null || true); [ -z "$n" ] && n=0
  if [ "$n" -eq "$3" ]; then ok "$desc" "$n"
  else bad "$desc" "expected $3, found $n"; fi
}

check_count_f() {  # description, fixed-string, expected count
  local desc="$1" n
  n=$(grep -c -F "$2" "$F" 2>/dev/null || true); [ -z "$n" ] && n=0
  if [ "$n" -eq "$3" ]; then ok "$desc" "$n"
  else bad "$desc" "expected $3, found $n"; fi
}

# Extract an inclusive line range delimited by two anchor regexes.
# Forward slashes are escaped so anchors like '^// --- NAVIGATION ---$'
# can be passed literally.
region() { local a="${1//\//\\/}" b="${2//\//\\/}"; awk "/$a/,/$b/" "$3"; }

# Phase 20.5 precedent: explanatory comments mention identifiers, so a raw
# grep count conflates prose with executable code. Every count below that
# could be inflated by a comment mention matches the *executable* form.

echo "================================================================"
echo "STAGERZ Phase 21.2 -- static startup-resilience invariants"
echo "base commit: $BASE"
echo "================================================================"

echo
echo "1. Dependency is pinned, integrity-checked, and CORS-enabled"
check_zero    "S-1  no floating @2 specifier remains"        "supabase-js@2/"
check_count_f "S-2  exact pinned URL present once"           "$PINNED_URL" 1
check_count_f "S-3  integrity carries the verified SHA-384"  "integrity='sha384-$EXPECT_SHA384'" 1
check_count_f "S-4  crossorigin='anonymous' on the tag"      "crossorigin='anonymous'></script>" 1
check_zero_re "S-5  SDK tag carries no defer/async"          "supabase-js@2\.112\.1.*(defer|async)"
check_count   "S-6  exactly one SDK script tag"              "<script src=.*supabase-js" 1

# S-7 / S-8: position. The SDK tag must sit after </head>, after the boot
# screen markup, and before the application inline script.
head_end=$(grep -n '^</head>$' "$F" | head -1 | cut -d: -f1)
boot_line=$(grep -n 'id="screen-boot"' "$F" | head -1 | cut -d: -f1)
sdk_line=$(grep -n 'supabase-js@2.112.1' "$F" | grep '<script src' | head -1 | cut -d: -f1)
app_line=$(grep -n '^// --- SUPABASE ---$' "$F" | head -1 | cut -d: -f1)
if [ -n "$sdk_line" ] && [ "$sdk_line" -gt "$head_end" ] && [ "$sdk_line" -gt "$boot_line" ]; then
  ok "S-7  SDK tag is after </head> and after boot markup" "head=$head_end boot=$boot_line sdk=$sdk_line"
else
  bad "S-7  SDK tag is after </head> and after boot markup" "head=$head_end boot=$boot_line sdk=$sdk_line"
fi
if [ -n "$sdk_line" ] && [ "$sdk_line" -lt "$app_line" ]; then
  ok "S-8  SDK tag precedes the application script" "sdk=$sdk_line app=$app_line"
else
  bad "S-8  SDK tag precedes the application script" "sdk=$sdk_line app=$app_line"
fi

echo
echo "2. Boot screen is active in static markup"
check_count   "S-9  exactly one 'screen active' in markup"   "class=\"screen active\"" 1
check_count   "S-10 the active screen is #screen-boot"       "class=\"screen active\" id=\"screen-boot\"" 1
screens=$(grep -c -E '<div class="screen( active)?" id="screen-' "$F")
if [ "$screens" -eq 21 ]; then ok "S-11 screen count is 21 (20 + boot)" "$screens"
else bad "S-11 screen count is 21 (20 + boot)" "found $screens"; fi
check_count   "S-12 .screen enumerated in exactly one place" "querySelectorAll\('\.screen'\)" 1
check_count   "S-13 #bootMessage defined once"               "id=\"bootMessage\"" 1
check_count   "S-14 #bootActions defined once"               "id=\"bootActions\"" 1
boot_btns=$(region 'id="screen-boot"' '^</div>$' "$F" | grep -c '<button')
boot_ctrls=$(region 'id="screen-boot"' '^</div>$' "$F" | grep -c -E '<(button|input|a |select|textarea)')
# The §6.3 invariant: the boot screen may carry exactly one control, and
# that control must not reach supabaseClient. Adding another is a defect.
if [ "$boot_btns" -eq 1 ] && [ "$boot_ctrls" -eq 1 ]; then
  ok "S-15 boot screen carries exactly one control" "1 button, 1 control"
else bad "S-15 boot screen carries exactly one control" "buttons=$boot_btns controls=$boot_ctrls"; fi
n=$(region 'id="screen-boot"' '^</div>$' "$F" | grep -c 'supabaseClient')
if [ "$n" -eq 0 ]; then ok "S-15b boot screen never reaches supabaseClient" "0"
else bad "S-15b boot screen never reaches supabaseClient" "$n"; fi
check_count   "S-16 the control is location.reload()"        "onclick=\"location.reload\(\)\"" 1

echo
echo "3. Startup is guarded"
check_zero    "S-17 no unguarded top-level createClient"     "var supabaseClient = supabase.createClient"
check_count   "S-18 supabaseClient initialised to null"      "^var supabaseClient = null;$" 1
check_count   "S-19 startupFailure initialised to null"      "^var startupFailure = null;$" 1
check_count   "S-20 exactly one createClient assignment"     "supabaseClient = supabase\.createClient" 1
check_count   "S-21 typeof guard precedes any read"          "typeof supabase === 'undefined'" 1
check_count   "S-22 createClient shape is checked"           "typeof supabase\.createClient !== 'function'" 1
check_count   "S-23 onAuthStateChange is guarded"            "^if\(supabaseClient\)\{$" 1
# D-1: the null check alone is not enough -- the registration call itself
# must be inside a try/catch that routes into the existing failure state.
auth_region=$(region '^if\(supabaseClient\)\{$' '^\}$' "$F")
n_try=$(printf '%s' "$auth_region" | grep -c '^  try{$')
n_reg=$(printf '%s' "$auth_region" | grep -c 'supabaseClient\.auth\.onAuthStateChange')
n_cat=$(printf '%s' "$auth_region" | grep -c "startupFailure = 'client-init-failed';")
if [ "$n_try" -eq 1 ] && [ "$n_reg" -eq 1 ] && [ "$n_cat" -eq 1 ]; then
  ok "S-23b D-1: registration inside try/catch -> startupFailure" "try=1 reg=1 catch=1"
else
  bad "S-23b D-1: registration inside try/catch -> startupFailure" "try=$n_try reg=$n_reg catch=$n_cat"
fi
check_count   "S-24 init checks startupFailure first"        "if\(startupFailure\)\{ showStartupFailure\(startupFailure\); return; \}" 1
init_try=$(region "addEventListener\('DOMContentLoaded'" '^\}\);$' "$F" | grep -c 'try{')
init_catch=$(region "addEventListener\('DOMContentLoaded'" '^\}\);$' "$F" | grep -c '}catch(e){')
if [ "$init_try" -eq 1 ] && [ "$init_catch" -eq 1 ]; then ok "S-25 init body wrapped in try/catch" "1 try, 1 catch"
else bad "S-25 init body wrapped in try/catch" "try=$init_try catch=$init_catch"; fi

echo
echo "4. Failure text leaks nothing"
check_count   "S-26 showStartupFailure defined once"         "^function showStartupFailure\(code\)\{$" 1
fn=$(region '^function showStartupFailure' '^\}$' "$F")
n=$(printf '%s' "$fn" | grep -c 'textContent')
if [ "$n" -ge 1 ]; then ok "S-27 writes via textContent" "$n"
else bad "S-27 writes via textContent" "$n"; fi
for forbidden in 'innerHTML' 'e.message' 'e.stack' 'SUPA_KEY' 'SUPA_URL' 'cdn.jsdelivr'; do
  n=$(printf '%s' "$fn" | grep -c -F "$forbidden")
  if [ "$n" -eq 0 ]; then ok "S-28 no '$forbidden' in failure text path" "0"
  else bad "S-28 no '$forbidden' in failure text path" "$n"; fi
done
n=$(printf '%s' "$fn" | grep -c "msg.textContent = 'STAGERZ could not start")
if [ "$n" -eq 1 ]; then ok "S-29 single fixed literal message (Q-6/Q-7)" "1"
else bad "S-29 single fixed literal message (Q-6/Q-7)" "$n"; fi

echo
echo "5. Scope boundaries -- what this phase must NOT have changed"
# Q-4: no watchdog, no startup timeout in this phase.
check_zero_re "S-30 no startup watchdog/timeout added"       "setTimeout\(function\(\)\{[^}]*screen-boot"
check_zero    "S-31 no global error handler added"           "window.onerror"
check_zero    "S-32 no unhandledrejection handler added"     "unhandledrejection"
check_zero    "S-33 no Content-Security-Policy added"        "Content-Security-Policy"
check_zero    "S-34 no service worker added"                 "serviceWorker"

if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  git show "$BASE:index.html" > /tmp/p212-base.html 2>/dev/null

  cmp_region() {  # desc, start-anchor, end-anchor, strip-indent(0|1)
    local desc="$1" a="$2" b="$3" strip="$4" cur base
    cur=$(region "$a" "$b" "$F")
    base=$(region "$a" "$b" /tmp/p212-base.html)
    if [ "$strip" -eq 1 ]; then
      cur=$(printf '%s' "$cur"  | sed 's/^[[:space:]]*//')
      base=$(printf '%s' "$base" | sed 's/^[[:space:]]*//')
    fi
    if [ -z "$base" ]; then bad "$desc" "base region empty -- anchor drift"; return; fi
    if [ "$cur" = "$base" ]; then ok "$desc" "byte-identical to base"
    else bad "$desc" "differs from base"; diff <(printf '%s' "$base") <(printf '%s' "$cur") | sed 's/^/          /'; fi
  }

  cmp_region "S-35 goTo() unchanged"                  '^// --- NAVIGATION ---$' '^// --- TOAST ---$' 0
  cmp_region "S-36 checkSessionAndStart() unchanged"  '^async function checkSessionAndStart\(\)\{$' '^\}$' 0
  cmp_region "S-37 enterApp() unchanged"              '^function enterApp\(\)\{$' '^\}$' 0
  cmp_region "S-38 onAuthStateChange body unchanged"  "onAuthStateChange\(async function" '^[[:space:]]*\}\);$' 1

  base_screens=$(grep -c -E '<div class="screen( active)?" id="screen-' /tmp/p212-base.html)
  if [ "$base_screens" -eq 20 ]; then ok "S-39 base had 20 screens, now 21" "$base_screens -> $screens"
  else bad "S-39 base had 20 screens, now 21" "base=$base_screens"; fi

  # Executable dereferences only -- 'supabaseClient.' followed by an
  # identifier. Prose mentions end the sentence or close a backtick and
  # are correctly excluded (Phase 20.5 precedent).
  deref_base=$(grep -c -E 'supabaseClient\.[a-zA-Z_]' /tmp/p212-base.html)
  deref_cur=$(grep -c -E 'supabaseClient\.[a-zA-Z_]' "$F")
  if [ "$deref_base" -eq "$deref_cur" ] && [ "$deref_cur" -eq 12 ]; then
    ok "S-40 supabaseClient call sites unchanged at 12" "$deref_cur"
  else bad "S-40 supabaseClient call sites unchanged at 12" "base=$deref_base now=$deref_cur"; fi

  # Every one of those 12 must remain unreachable while the client is
  # null, which the guards enforce rather than the call sites themselves.
  ungrd=$(grep -n -E 'supabaseClient\.[a-zA-Z_]' "$F" | grep -c -E 'onAuthStateChange')
  if [ "$ungrd" -eq 1 ]; then ok "S-40b onAuthStateChange is the only top-level site" "1"
  else bad "S-40b onAuthStateChange is the only top-level site" "$ungrd"; fi
  rm -f /tmp/p212-base.html
else
  skipm "S-35..S-40 base-commit comparisons" "commit $BASE not reachable"
fi

echo
echo "6. Structural integrity"
for pair in '{ }' '( )' '[ ]'; do
  set -- $pair
  o=$(tr -cd "$1" < "$F" | wc -c); c=$(tr -cd "$2" < "$F" | wc -c)
  if [ "$o" -eq "$c" ]; then ok "S-41 '$1$2' balanced" "$o"
  else bad "S-41 '$1$2' balanced" "open=$o close=$c"; fi
done
# Line endings must be read authoritatively. Git Bash translates CRLF to LF
# on read, so a plain `grep $'\r'` reports LF for a CRLF working tree and
# cannot detect a mixed-ending file at all. `git ls-files --eol` reports the
# real index and working-tree endings.
eol=$(git ls-files --eol "$F" 2>/dev/null | awk '{print $1" "$2}')
case "$eol" in
  "i/lf w/crlf")  ok  "S-42 endings: LF in index, CRLF in worktree" "core.autocrlf=true" ;;
  "i/lf w/lf")    ok  "S-42 endings: LF in index and worktree"      "$eol" ;;
  *mixed*)        bad "S-42 mixed line endings introduced"          "$eol" ;;
  "")             skipm "S-42 line-ending check" "git ls-files unavailable" ;;
  *)              bad "S-42 unexpected line-ending state"           "$eol" ;;
esac

echo
echo "7. Live asset verification (network -- optional)"
if command -v curl >/dev/null 2>&1 && curl -sSf -m 20 -o /tmp/p212-sdk.js -D /tmp/p212-hdr.txt "$PINNED_URL" 2>/dev/null; then
  got384=$(openssl dgst -sha384 -binary /tmp/p212-sdk.js 2>/dev/null | openssl base64 -A 2>/dev/null)
  got256=$(sha256sum /tmp/p212-sdk.js | cut -d' ' -f1)
  gotver=$(grep -o 'supabase-js/[0-9]\+\.[0-9]\+\.[0-9]\+' /tmp/p212-sdk.js | sort -u | head -1)
  hdrver=$(grep -i '^x-jsd-version:' /tmp/p212-hdr.txt | tr -d '\r' | awk '{print $2}')
  [ "$got384" = "$EXPECT_SHA384" ] && ok "S-43 live SHA-384 matches integrity attribute" "match" \
                                   || bad "S-43 live SHA-384 matches integrity attribute" "got $got384"
  [ "$got256" = "$EXPECT_SHA256" ] && ok "S-44 live SHA-256 matches recorded value" "match" \
                                   || bad "S-44 live SHA-256 matches recorded value" "got $got256"
  [ "$gotver" = "supabase-js/2.112.1" ] && ok "S-45 bundle self-identifies as 2.112.1" "$gotver" \
                                        || bad "S-45 bundle self-identifies as 2.112.1" "$gotver"
  [ "$hdrver" = "2.112.1" ] && ok "S-46 x-jsd-version is 2.112.1" "$hdrver" \
                            || bad "S-46 x-jsd-version is 2.112.1" "$hdrver"
  grep -qi 'access-control-allow-origin' /tmp/p212-hdr.txt && ok "S-47 CORS header present (SRI enforceable)" "yes" \
                                                           || bad "S-47 CORS header present (SRI enforceable)" "missing"
  rm -f /tmp/p212-sdk.js /tmp/p212-hdr.txt
else
  skipm "S-43..S-47 live asset verification" "network unavailable"
fi

echo
echo "----------------------------------------------------------------"
printf 'RESULT: %s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] && echo "ALL STATIC INVARIANTS HOLD" || echo "STATIC INVARIANTS VIOLATED"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
