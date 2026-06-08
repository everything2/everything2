#!/usr/bin/env bash
#
# load-test.sh -- concurrency-ramp load/scale test for Everything2.
#
# Drives ApacheBench (ab) against the running app across a ramp of concurrency
# levels and a set of representative URL shapes, then prints throughput +
# latency-percentile + error-rate tables. Built for the PSGI/Starman cutover:
# run it before/after, or against the mod_perl parity container, to compare.
#
# ab runs INSIDE the app container (that's where ab lives) and hits the app on
# the container's own loopback, so the numbers measure Apache->Starman, not the
# host's docker NAT. Point --container at a mod_perl container to compare.
#
#   tools/load-test.sh                          # defaults: e2devapp, ramp 1..50
#   tools/load-test.sh --requests 1000 --levels "1 5 10 25 50 100"
#   tools/load-test.sh --container e2devapp_mp  # compare against mod_perl
#   tools/load-test.sh --backend                # hit Starman :5000 directly (skip Apache)
#   tools/load-test.sh --no-encoding            # don't send Accept-Encoding
#
# NOTE on "Failed requests": E2 pages are dynamic (timestamps, CSRF, nodelets),
# so response bodies vary in length request-to-request. Plain ab counts that as a
# "failure". We pass -l (accept variable length) so only REAL errors (non-2xx,
# resets, timeouts) are counted. The per-URL "non2xx" column is the honest signal.
#
set -u

CONTAINER="e2devapp"
REQUESTS=500
LEVELS="1 5 10 20 50"
PORT=80                      # Apache (full Apache->Starman path)
ACCEPT_ENCODING="gzip, deflate, br"

while [ $# -gt 0 ]; do
  case "$1" in
    --container) CONTAINER="$2"; shift 2 ;;
    --requests)  REQUESTS="$2"; shift 2 ;;
    --levels)    LEVELS="$2"; shift 2 ;;
    --backend)   PORT=5000; shift ;;             # hit Starman directly, bypass Apache
    --port)      PORT="$2"; shift 2 ;;
    --no-encoding) ACCEPT_ENCODING=""; shift ;;
    -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Representative E2 workload. Each entry is "label|path". Discover a stable node
# id at runtime so the script survives reseeds.
NODEID="$(docker exec -i e2devdb mysql -u root -pblah -N -e \
  "SELECT node_id FROM everything.node WHERE title='Cool Archive' LIMIT 1;" 2>/dev/null | tr -d '[:space:]')"
NODEID="${NODEID:-529746}"

URLS=(
  "front-page (/)            |/"
  "node render (/node/<id>)  |/node/${NODEID}"
  "title route (/title/...)  |/title/Cool+Archive"
  "api json (/api/nodes/<id>)|/api/nodes/${NODEID}"
  "static css                |/css/1973976.css"
)

echo "=================================================================================="
echo " E2 load test  |  container=${CONTAINER}  port=${PORT}  requests=${REQUESTS}/level"
echo " concurrency ramp: ${LEVELS}   Accept-Encoding: ${ACCEPT_ENCODING:-<none>}"
echo " node id under test: ${NODEID}"
echo "=================================================================================="

# Sanity: is ab present and the target reachable?
if ! docker exec "$CONTAINER" sh -c 'command -v ab >/dev/null'; then
  echo "ERROR: ab (apache2-utils) not found in container ${CONTAINER}" >&2; exit 1
fi
if ! docker exec "$CONTAINER" sh -c "curl -s -o /dev/null http://localhost:${PORT}/ 2>/dev/null"; then
  echo "ERROR: http://localhost:${PORT}/ not reachable inside ${CONTAINER}" >&2; exit 1
fi

# Run one ab pass; echo a parsed, tab-separated row. Args: concurrency, url
run_ab() {
  local conc="$1" url="$2"
  local hdr=()
  [ -n "$ACCEPT_ENCODING" ] && hdr=(-H "Accept-Encoding: ${ACCEPT_ENCODING}")
  # -l accept variable length (dynamic pages); -r don't exit on socket errors
  local out
  out="$(docker exec "$CONTAINER" ab -l -r -n "$REQUESTS" -c "$conc" "${hdr[@]}" \
        "http://localhost:${PORT}${url}" 2>/dev/null)"
  local rps mean p50 p95 p99 failed non2xx
  rps="$(  printf '%s\n' "$out" | awk -F'[: ]+' '/Requests per second/   {print $4}')"
  mean="$( printf '%s\n' "$out" | awk -F'[: ]+' '/Time per request.*mean\)/{print $4; exit}')"
  failed="$(printf '%s\n' "$out" | awk -F'[: ]+' '/Failed requests/      {print $3}')"
  non2xx="$(printf '%s\n' "$out" | awk -F'[: ]+' '/Non-2xx responses/    {print $3}')"
  p50="$( printf '%s\n' "$out" | awk '/^  50%/{print $2}')"
  p95="$( printf '%s\n' "$out" | awk '/^  95%/{print $2}')"
  p99="$( printf '%s\n' "$out" | awk '/^  99%/{print $2}')"
  printf "  %-6s %10s %9s %7s %7s %7s %8s %8s\n" \
    "$conc" "${rps:-ERR}" "${mean:-?}" "${p50:-?}" "${p95:-?}" "${p99:-?}" "${failed:-?}" "${non2xx:-0}"
}

for entry in "${URLS[@]}"; do
  label="${entry%%|*}"; path="${entry##*|}"
  echo ""
  echo ">>> ${label}   [${path}]"
  printf "  %-6s %10s %9s %7s %7s %7s %8s %8s\n" "conc" "req/s" "mean_ms" "p50" "p95" "p99" "lenvar" "non2xx"
  for c in $LEVELS; do
    run_ab "$c" "$path"
  done
done

echo ""
echo "Done. 'lenvar' = ab's variable-length count (expected for dynamic pages, NOT errors)."
echo "      'non2xx' = real HTTP errors. Watch req/s scaling + p95/p99 under rising concurrency."
