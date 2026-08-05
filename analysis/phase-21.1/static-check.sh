#!/usr/bin/env bash
# STAGERZ Phase 21.1 -- static output-escaping invariants.
#
# Complements analysis/phase-21.1/xss-verification.html: that harness proves
# runtime behaviour in a browser, this script proves the source-level
# invariants and needs no browser, no server and no network.
#
# Run from the repository root:
#   bash analysis/phase-21.1/static-check.sh
#
# Exit code 0 = all invariants hold, 1 = at least one failed.

cd "$(dirname "$0")/../.." || exit 1
F=index.html
fail=0
pass=0

check_zero() {   # description, pattern (fixed-string grep)
  local desc="$1"; shift
  local n
  n=$(grep -c -F "$1" "$F" 2>/dev/null || true)
  [ -z "$n" ] && n=0
  if [ "$n" -eq 0 ]; then
    printf '  PASS  %-58s (0 occurrences)\n' "$desc"; pass=$((pass+1))
  else
    printf '  FAIL  %-58s (%s occurrences)\n' "$desc" "$n"; fail=$((fail+1))
    grep -n -F "$1" "$F" | sed 's/^/          /'
  fi
}

check_zero_re() {  # description, extended regex
  local desc="$1"; shift
  local n
  n=$(grep -c -E "$1" "$F" 2>/dev/null || true)
  [ -z "$n" ] && n=0
  if [ "$n" -eq 0 ]; then
    printf '  PASS  %-58s (0 occurrences)\n' "$desc"; pass=$((pass+1))
  else
    printf '  FAIL  %-58s (%s occurrences)\n' "$desc" "$n"; fail=$((fail+1))
    grep -n -E "$1" "$F" | sed 's/^/          /'
  fi
}

check_count() {  # description, extended regex, expected count
  local desc="$1" re="$2" want="$3"
  local n
  n=$(grep -c -E "$re" "$F" 2>/dev/null || true)
  [ -z "$n" ] && n=0
  if [ "$n" -eq "$want" ]; then
    printf '  PASS  %-58s (%s, expected %s)\n' "$desc" "$n" "$want"; pass=$((pass+1))
  else
    printf '  FAIL  %-58s (%s, expected %s)\n' "$desc" "$n" "$want"; fail=$((fail+1))
  fi
}

echo "STAGERZ Phase 21.1 -- static output-escaping invariants"
echo "File: $F ($(wc -l < "$F" | tr -d ' ') lines)"
echo
echo "1. photo_url must never reach an HTML string or a CSS url() expression"
check_zero    "no 'background-image:url(' built in JS strings" "background-image:url("
check_zero_re "no photo_url concatenated into any string"      "photo_url[[:space:]]*\+|\+[[:space:]]*(pub|u)\.photo_url"

echo
echo "2. Dangerous HTML/JS sinks must be absent entirely"
check_zero    "no outerHTML"                                   "outerHTML"
check_zero    "no insertAdjacentHTML"                          "insertAdjacentHTML"
check_zero    "no document.write"                              "document.write"
check_zero    "no eval("                                       "eval("
check_zero    "no new Function"                                "new Function"
check_zero    "no srcdoc"                                      "srcdoc"

echo
echo "3. Helpers are present exactly once and wired to all four avatar sites"
check_count   "safeImageUrl defined once"       "^function safeImageUrl\(" 1
check_count   "applyAvatarImage defined once"   "^function applyAvatarImage\(" 1
check_count   "applyAvatarImage call sites"     "applyAvatarImage\(row\.querySelector" 4
check_count   "safeImageUrl gate call sites"    "var hasPhoto = safeImageUrl\(" 4

echo
echo "4. Corrected HTML-text sinks are escaped"
check_count   "collaboration title (loadMyCollaborations)" "escapeCollaborationHtml\(c\.title\)" 1
check_count   "collaboration title (openCollaboration)"    "escapeCollaborationHtml\(collab\.title\)" 1
check_count   "wanted title (openCollaboration)"           "escapeCollaborationHtml\(wantedTitle\)" 1
# Matched with the surrounding concatenation operators so this counts only the
# two innerHTML sinks corrected by this phase, not the two pre-existing correct
# uses that assign to a variable first (actorName, and name in the credits list).
check_count   "display_name (applicants + participants)"   "\+escapeCollaborationHtml\(pub\.display_name \|\| 'STAGERZ Artist'\)\+" 2
check_count   "display_name pre-existing var assignments untouched" "var (actorName|name) = escapeCollaborationHtml\(pub\.display_name" 2
check_count   "username in metaParts (x2 functions)"       "metaParts\.push\('@'\+escapeCollaborationHtml\(pub\.username\)\)" 2
check_count   "role in metaParts (x2 functions)"           "metaParts\.push\(escapeCollaborationHtml\(prof\.role\)\)" 2
check_count   "location in metaParts (x2 functions)"       "metaParts\.push\(escapeCollaborationHtml\(prof\.location\)\)" 2
check_count   "renderWanted item.loc (wanted_posts.location)" "escapeCollaborationHtml\(item\.loc\)" 1
check_count   "renderWanted item.title"                    "escapeCollaborationHtml\(item\.title\)" 1
check_count   "renderWanted item.comp"                     "escapeCollaborationHtml\(item\.comp\)" 1
check_count   "renderWanted item.cat"                      "escapeCollaborationHtml\(item\.cat\)" 1
check_count   "renderWanted item.role"                     "escapeCollaborationHtml\(item\.role\)" 1
check_count   "asset_type (client-written column)"         "escapeCollaborationHtml\(a\.asset_type\)" 1

echo
echo "5. Trusted static entity-bearing values must NOT be escaped"
check_zero_re "wantedData flag not escaped"       "escapeCollaborationHtml\(item\.flag"
check_zero_re "wantedData badgeText not escaped"  "escapeCollaborationHtml\(item\.badgeText"
check_zero_re "artistDB role not escaped"         "escapeCollaborationHtml\(a\.role\)"
check_zero_re "verifiedBadge fragment not escaped" "escapeCollaborationHtml\(verifiedBadge"
check_zero_re "already-escaped actorName not re-escaped" "escapeCollaborationHtml\(actorName"
check_zero_re "already-escaped sentence not re-escaped"  "escapeCollaborationHtml\(sentence"
check_zero_re "joined metaParts not escaped after join"  "escapeCollaborationHtml\(metaParts"

echo
echo "----------------------------------------------------------------"
printf 'RESULT: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && echo "ALL STATIC INVARIANTS HOLD" || echo "STATIC INVARIANTS VIOLATED"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
