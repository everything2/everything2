#!/bin/bash
#
# Record a watchable video (and stills) of an E2E spec against the dev environment.
#
#   ./tools/e2e-demo.sh discussion-reply-notification
#   E2E_DEMO_PAUSE=2500 ./tools/e2e-demo.sh discussion-reply-notification   # slower
#   E2E_DEMO_DEVICE=mobile ./tools/e2e-demo.sh discussion-reply-notification # phone resolution
#
# Each actor (browser session) in the spec is recorded with a banner naming the user
# and the current step; the sessions are stitched side by side into
# e2e-demos/<name>.mp4. Specs opt in by using tests/e2e/fixtures/demo.js.
# Dev only: never point this at production.
set -euo pipefail
cd "$(dirname "$0")/.."

spec="${1:?usage: $0 <spec name, e.g. discussion-reply-notification>}"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required to stitch the videos" >&2; exit 1; }

rm -rf test-results/demo-raw
status=0
E2E_DEMO=1 npx playwright test "tests/e2e/${spec%.spec.js}.spec.js" --reporter=list --workers=1 || status=$?

echo
ls -1 e2e-demos/*.mp4 2>/dev/null | sed "s/^/video: /"
find e2e-demos -name "*.png" 2>/dev/null | sort | sed "s/^/still: /"
[ "$status" -eq 0 ] && echo "spec passed" || echo "spec FAILED (exit $status) -- the video shows where"
exit "$status"
