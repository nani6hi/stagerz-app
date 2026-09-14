#!/usr/bin/env bash
# STAGERZ Phase 21.9 -- S-4 frontend error contract: static invariants.
#
# Complements analysis/phase-21.9/error-contract-harness.html, which drives
# the extracted translator and upload guard in a browser. This script needs
# no browser, no server and no network.
#
# Run from the repository root:
#   bash analysis/phase-21.9/static-check.sh
#
# Exit code 0 = all invariants hold, 1 = at least one failed.

cd "$(dirname "$0")/../.." || exit 1
F=index.html
TSV=analysis/phase-21.9/error-codes.tsv
BASE=b1582a92c3dc9190614403434ff7688b66c4267b
fail=0
pass=0

ok()  { printf '  PASS  %-66s (%s)\n' "$1" "$2"; pass=$((pass+1)); }
bad() { printf '  FAIL  %-66s (%s)\n' "$1" "$2"; fail=$((fail+1)); }

count_f()  { local n; n=$(tr -d '\r' < "$1" | grep -c -F -- "$2" || true); echo "${n:-0}"; }
count_re() { local n; n=$(tr -d '\r' < "$1" | grep -c -E -- "$2" || true); echo "${n:-0}"; }

expect_zero_re() {  # description, regex
  local n; n=$(count_re "$F" "$2")
  if [ "$n" -eq 0 ]; then ok "$1" "0"; else bad "$1" "$n"; tr -d '\r' < "$F" | grep -n -E -- "$2" | sed 's/^/          /' | cut -c1-160; fi
}
expect_count_f() {  # description, fixed string, expected
  local n; n=$(count_f "$F" "$2")
  if [ "$n" -eq "$3" ]; then ok "$1" "$n"; else bad "$1" "expected $3, found $n"; fi
}

SRC=$(mktemp); tr -d '\r' < "$F" > "$SRC"
BLOCK=$(mktemp)
awk '/^\/\/ --- BACKEND ERROR CONTRACT \(Phase 21\.9 \/ S-4\) ---/{f=1} f{print} /^\/\/ --- END BACKEND ERROR CONTRACT ---/{f=0}' "$SRC" > "$BLOCK"
trap 'rm -f "$SRC" "$BLOCK"' EXIT

echo "== 1. Inventory and translator map coverage"
rows=$(grep -v '^#' "$TSV" | tail -n +2 | grep -c . || true)
client=$(grep -v '^#' "$TSV" | tail -n +2 | awk -F'\t' '$3=="yes"' | grep -c . || true)
admin=$(grep -v '^#' "$TSV" | tail -n +2 | awk -F'\t' '$3=="no"' | grep -c . || true)
[ "$rows" -eq 58 ] && ok "M-1  inventory lists 58 distinct custom codes" "$rows" || bad "M-1  inventory lists 58 distinct custom codes" "$rows"
[ "$client" -eq 53 ] && ok "M-2  53 authenticated (client-facing) codes" "$client" || bad "M-2  53 authenticated (client-facing) codes" "$client"
[ "$admin" -eq 5 ] && ok "M-3  5 admin-only codes" "$admin" || bad "M-3  5 admin-only codes" "$admin"

blines=$(grep -c . "$BLOCK" || true)
[ "$blines" -gt 20 ] && ok "M-4  translator block extracted between markers" "$blines lines" || bad "M-4  translator block extracted between markers" "$blines lines"

specific_keys=$(awk '/^var BACKEND_ERROR_SPECIFIC = \{/{f=1;next} f&&/^\};/{f=0} f' "$BLOCK" | grep -oE '^ *P[0-9]{4}:' | tr -d ' :' | sort)
group_line() { grep -E "^ *$1: \[" "$BLOCK" | grep -oE "P[0-9]{4}" | sort; }
nf=$(group_line NOT_FOUND_OR_CHANGED); fb=$(group_line FORBIDDEN); ie=$(group_line INTERNAL_ERROR)

mapped_total=$( (echo "$specific_keys"; echo "$nf"; echo "$fb"; echo "$ie") | grep -c . )
mapped_unique=$( (echo "$specific_keys"; echo "$nf"; echo "$fb"; echo "$ie") | grep . | sort -u | grep -c . )
[ "$mapped_total" -eq 53 ] && ok "M-5  translator maps exactly 53 codes" "$mapped_total" || bad "M-5  translator maps exactly 53 codes" "$mapped_total"
[ "$mapped_unique" -eq "$mapped_total" ] && ok "M-6  no code mapped twice" "$mapped_unique unique" || bad "M-6  no code mapped twice" "$mapped_unique unique of $mapped_total"
printf '        specific=%s grouped NOT_FOUND_OR_CHANGED=%s FORBIDDEN=%s defensive INTERNAL_ERROR=%s\n' \
  "$(echo "$specific_keys" | grep -c .)" "$(echo "$nf" | grep -c .)" "$(echo "$fb" | grep -c .)" "$(echo "$ie" | grep -c .)"

mismatch=0
while IFS=$'\t' read -r code token cf cls cat by; do
  case "$code" in ''|\#*|code) continue ;; esac
  if [ "$cf" = "no" ]; then
    if grep -q -E "(^ *$code:|'$code')" "$BLOCK"; then echo "          admin code $code present in translator"; mismatch=$((mismatch+1)); fi
    continue
  fi
  case "$cls" in
    specific)
      line=$(awk '/^var BACKEND_ERROR_SPECIFIC = \{/{f=1;next} f&&/^\};/{f=0} f' "$BLOCK" | grep -E "^ *$code:")
      echo "$line" | grep -q "category: '$cat'" || { echo "          $code expected specific $cat: ${line:-missing}"; mismatch=$((mismatch+1)); } ;;
    grouped|defensive)
      grp=$(grep -E "^ *$cat: \[" "$BLOCK")
      echo "$grp" | grep -q "'$code'" || { echo "          $code expected in group $cat"; mismatch=$((mismatch+1)); } ;;
    *) echo "          $code has unknown classification $cls"; mismatch=$((mismatch+1)) ;;
  esac
done < <(grep -v '^#' "$TSV")
[ "$mismatch" -eq 0 ] && ok "M-7  every code classified exactly as the inventory states" "0 mismatches" || bad "M-7  every code classified exactly as the inventory states" "$mismatch mismatches"

extra=$( (echo "$specific_keys"; echo "$nf"; echo "$fb"; echo "$ie") | grep . | while read -r c; do grep -q -P "^$c\t" "$TSV" || echo "$c"; done | grep -c . || true)
[ "$extra" -eq 0 ] && ok "M-8  translator maps no code absent from the inventory" "0" || bad "M-8  translator maps no code absent from the inventory" "$extra"

o_spec=$(grep -n "hasOwnProperty.call(BACKEND_ERROR_SPECIFIC, code)" "$BLOCK" | head -1 | cut -d: -f1)
o_401=$(grep -n "status === 401" "$BLOCK" | head -1 | cut -d: -f1)
o_0=$(grep -n "status === 0" "$BLOCK" | head -1 | cut -d: -f1)
if [ -n "$o_spec" ] && [ -n "$o_401" ] && [ -n "$o_0" ] && [ "$o_spec" -lt "$o_401" ] && [ "$o_spec" -lt "$o_0" ]; then
  ok "M-9  code lookup precedes every HTTP-status rule" "code@$o_spec 401@$o_401 0@$o_0"
else bad "M-9  code lookup precedes every HTTP-status rule" "code@$o_spec 401@$o_401 0@$o_0"; fi

auth_rule=$(grep -E "category = 'AUTH_REQUIRED'" "$BLOCK")
if echo "$auth_rule" | grep -q "code === 'PGRST301'" && echo "$auth_rule" | grep -q "code === 'PGRST302'" && echo "$auth_rule" | grep -q "code === 'PGRST303'"; then
  ok "M-10 session rule maps PGRST301, PGRST302 and PGRST303 to AUTH_REQUIRED" "all three"
else bad "M-10 session rule maps PGRST301, PGRST302 and PGRST303 to AUTH_REQUIRED" "${auth_rule:-rule not found}"; fi

echo "== 2. No raw backend text reaches the user"
expect_zero_re "R-1  no legacy raw-message variables remain"            "\b(realMsg|closeMsg|editMsg|metaErrMsg|cleanupErrMsg|friendlyMsg)\b"
expect_zero_re "R-2  no error.hint / error.details read anywhere"      "[Ee]rror\.(hint|details)|\.error\.(hint|details)"
expect_zero_re "R-3  no JSON.stringify of an error object"              "JSON\.stringify\([A-Za-z]*([Ee]rr|[Rr]esult|[Rr]es)[A-Za-z]*(\.error)?\)"
expect_zero_re "R-4  no showToast argument reads .message"              "showToast\([^;]*\.message"
expect_zero_re "R-5  no textContent/innerHTML assignment reads .error.message" "(textContent|innerHTML)[^;]*\.error\.message"
expect_zero_re "R-6  no raw 'unknown error' suffix copy remains"        "unknown error'"
calls=$(grep -v -E "^ *//|function backendErrorMessage\(" "$SRC" | grep -o -E "backendErrorMessage\(" | grep -c . || true)
literal=$(grep -v -E "^ *//" "$SRC" | grep -o -E "backendErrorMessage\([A-Za-z.]+, '[^']+'\)" | grep -c . || true)
[ "$calls" -eq "$literal" ] && ok "R-7  every translator call passes a literal fallback" "$literal/$calls" || bad "R-7  every translator call passes a literal fallback" "$literal/$calls"

enclosing_ok() {  # regex for call; prints "ok displaying silent missing..."
  # For every function containing a matching call: if it shows anything to
  # the user (showToast / textContent / innerHTML) it must also call the
  # translator. Functions that display nothing on any path are "silent".
  # The pattern travels through the environment: awk -v would re-process
  # its backslash escapes and break the regex.
  PAT="$1" awk '
    function flush(){ if(fn!="" && hasCall){ if(hasDisplay){ total++; if(hasT) okc++; else missing=missing" "fn } else silent++ } }
    BEGIN { pat = ENVIRON["PAT"] }
    /^(async )?function [A-Za-z0-9_]+\(/ { flush(); fn=$0; sub(/\(.*/,"",fn); sub(/^(async )?function /,"",fn); hasCall=0; hasT=0; hasDisplay=0 }
    $0 ~ pat && fn!="" && $0 !~ /^(async )?function / { hasCall=1 }
    /backendErrorMessage\(/ { hasT=1 }
    /showToast\(|\.textContent *=|\.innerHTML *=/ { hasDisplay=1 }
    END { flush(); print okc+0, total+0, silent+0, missing }' "$SRC"
}
read -r rok rtotal rsilent rmiss < <(enclosing_ok "supaRpc\\('")
rpc_calls=$(grep -c -E "supaRpc\('" "$SRC" || true)
[ "$rpc_calls" -eq 20 ] && ok "R-8  20 supaRpc call sites" "$rpc_calls" || bad "R-8  20 supaRpc call sites" "$rpc_calls"
[ "$rok" -eq 20 ] && [ "$rtotal" -eq 20 ] && [ "$rsilent" -eq 0 ] && ok "R-9  all 20 RPC callers route failures through the translator" "$rok/$rtotal, silent $rsilent" || bad "R-9  all 20 RPC callers route failures through the translator" "$rok/$rtotal silent $rsilent missing:$rmiss"
read -r wok wtotal wsilent wmiss < <(enclosing_ok "supa(Insert|Update|UpdateMinimal|Upsert)\\('")
[ "$wok" -eq "$wtotal" ] && [ "$wtotal" -eq 3 ] && ok "R-10 every displaying direct REST write caller uses the translator" "$wok/$wtotal functions (5 writes); $wsilent silent" || bad "R-10 every displaying direct REST write caller uses the translator" "$wok/$wtotal silent $wsilent missing:$wmiss"
read -r sok stotal ssilent smiss < <(enclosing_ok "storage\\.from\\('collaboration-assets'\\)\\.(upload|download)\\(")
[ "$sok" -eq "$stotal" ] && [ "$stotal" -eq 3 ] && ok "R-11 every Storage upload/download caller uses the translator" "$sok/$stotal functions; $ssilent silent" || bad "R-11 every Storage upload/download caller uses the translator" "$sok/$stotal silent $ssilent missing:$smiss"
expect_count_f "R-12 auth OTP error routed through the translator" "showToast(backendErrorMessage(res.error, 'Could not send email. Please try again.'));" 1
expect_zero_re "R-13 no user-visible Storage path in upload failure copy" "textContent[^;]*storagePath"

echo "== 3. Zero-byte upload guard"
UP=$(mktemp); awk '/^async function uploadCollaborationAsset\(/{f=1} f{print} f&&/^}/{exit}' "$SRC" > "$UP"
g=$(grep -n -F '!(file.size > 0)' "$UP" | head -1 | cut -d: -f1)
d=$(grep -n -F 'getMyDomainId()' "$UP" | head -1 | cut -d: -f1)
u=$(grep -n -F ".upload(" "$UP" | head -1 | cut -d: -f1)
i=$(grep -n -F "supaInsert(" "$UP" | head -1 | cut -d: -f1)
if [ -n "$g" ] && [ -n "$d" ] && [ -n "$u" ] && [ "$g" -lt "$d" ] && [ "$g" -lt "$u" ] && [ "$g" -lt "$i" ]; then
  ok "Z-1  guard precedes identity lookup, Storage upload and insert" "guard@$g id@$d upload@$u insert@$i"
else bad "Z-1  guard precedes identity lookup, Storage upload and insert" "guard@$g id@$d upload@$u insert@$i"; fi
gblock=$(sed -n "${g},$((g+5))p" "$UP")
echo "$gblock" | grep -q "endCollaborationBusy(uploadBtn)" && echo "$gblock" | grep -q "return;" && ok "Z-2  guard releases the busy state and returns" "yes" || bad "Z-2  guard releases the busy state and returns" "no"
rm -f "$UP"

echo "== 4. Edit-path length checks (aligned with create)"
expect_count_f "E-1  message edit rejects > 5000"  "if(newBody.length > 5000){" 1
expect_count_f "E-2  task title edit rejects > 300" "if(newTitle.length > 300){" 1
expect_count_f "E-3  'Message is too long' copy (create + edit + map)" "Message is too long (max 5000 characters)." 3
expect_count_f "E-4  'Title is too long' copy (create + edit + map)" "Title is too long (max 300 characters)." 3

echo "== 5. Existing specific UX preserved"
expect_count_f "U-1  23505 duplicate application handler" "if(errCode === '23505'){" 1
expect_count_f "U-2  'You already applied.' copy"            "showToast('You already applied.');" 1
expect_count_f "U-3  APPLIED button state on duplicate"      "btnEl.textContent = 'APPLIED'; btnEl.disabled = true; btnEl.onclick = null;" 2
expect_count_f "U-4  P0012 handler"                           "if(errCode === 'P0012'){" 1
expect_count_f "U-5  P0013 handler"                           "if(errCode === 'P0013'){" 1
expect_count_f "U-6  'This Wanted is no longer open.' (handler + map)" "This Wanted is no longer open." 2
expect_count_f "U-7  own-Wanted copy (client check + handler + map)" "You cannot apply to your own Wanted." 3
expect_count_f "U-8  P0053 duplicate-credit copy in the map"  "P0053: { category: 'ALREADY_EXISTS', message: 'This participant already has a credit for this collaboration.' }" 1

echo "== 6. Diagnostics hygiene"
expect_count_f "L-1  requestPayload only in the pre-existing REQUEST log" "requestPayload" 1
expect_zero_re "L-2  supaRpc failure log no longer carries params"      "supaRpc FAILED[^;]*params"

echo "== 7. Change scope"
changed=$(git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard)
unexpected=$(echo "$changed" | grep . | sort -u | grep -v -E '^(index\.html|analysis/phase-21\.9/.*|analysis/phase-21\.3/backend-contract\.md|\.apos/PROJECT_CONTEXT\.md)$' | grep -c . || true)
[ "$unexpected" -eq 0 ] && ok "S-1  only approved paths changed vs $BASE" "$(echo "$changed" | grep . | sort -u | tr '\n' ' ')" || bad "S-1  only approved paths changed" "$(echo "$changed" | grep . | sort -u | tr '\n' ' ')"
backend=$(echo "$changed" | grep -c -E '^supabase/|\.sql$|^\.github/' || true)
[ "$backend" -eq 0 ] && ok "S-2  no Edge Function, SQL or workflow file touched" "0" || bad "S-2  no Edge Function, SQL or workflow file touched" "$backend"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
