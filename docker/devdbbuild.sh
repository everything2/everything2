#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Wrapper script for database-only builds
exec "$SCRIPT_DIR/devbuild.sh" --db-only "$@"
