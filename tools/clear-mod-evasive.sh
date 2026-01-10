#!/bin/bash
# Clear mod_evasive lockout files from the dev container
# Run this if you get 403 Forbidden errors from hitting the site too fast

docker exec e2devapp rm -f /tmp/dos-* 2>/dev/null
echo "Cleared mod_evasive lockouts"
