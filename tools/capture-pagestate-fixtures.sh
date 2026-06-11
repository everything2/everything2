#!/bin/bash
# Capture real, normalized /api/pagestate payloads as React test fixtures -- the
# "fixtures that match" contract. Re-run after the pagestate contract changes so the
# Document-component tests stay pinned to what the server actually emits.
#
#   usage: tools/capture-pagestate-fixtures.sh [base_url] [SPEC ...]
#   SPEC  = node_id            (display view)
#         | node_id:displaytype  (e.g. 113:edit, 113:editvars)
#
#   Authed capture (for logged-in / admin-only views: user_edit, dbtable, setting, ...):
#     E2_LOGIN_USER=root E2_LOGIN_PASS=blah tools/capture-pagestate-fixtures.sh ... 113:edit 160
#   logs in first and sends the session cookie with each capture.
set -e
BASE="${1:-http://localhost:9080}"; shift || true
SPECS=("$@"); [ ${#SPECS[@]} -eq 0 ] && SPECS=(124 113)
DEST="react/__fixtures__/pagestate"; mkdir -p "$DEST"

COOKIE=""
if [ -n "$E2_LOGIN_USER" ] && [ -n "$E2_LOGIN_PASS" ]; then
  COOKIE=$(curl -s -i -X POST "$BASE/api/sessions/create" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$E2_LOGIN_USER\",\"passwd\":\"$E2_LOGIN_PASS\"}" \
    | grep -i '^set-cookie:' | sed 's/^[Ss]et-[Cc]ookie: //;s/;.*//')
  [ -n "$COOKIE" ] && echo "  logged in as $E2_LOGIN_USER" || { echo "  LOGIN FAILED for $E2_LOGIN_USER"; exit 1; }
fi

for spec in "${SPECS[@]}"; do
  nid="${spec%%:*}"; dt="display"; [ "$spec" != "$nid" ] && dt="${spec#*:}"
  url="$BASE/api/pagestate?node_id=$nid&displaytype=$dt"
  json=$(curl -s ${COOKIE:+--cookie "$COOKIE"} "$url")
  type=$(echo "$json" | python3 -c "import json,sys; print((json.load(sys.stdin).get('contentData') or {}).get('type','unknown'))")
  echo "$json" | python3 -m json.tool > "$DEST/$type.json"
  echo "  captured $type (node $nid, dt $dt) -> $DEST/$type.json ($(wc -c < "$DEST/$type.json") bytes)"
done
