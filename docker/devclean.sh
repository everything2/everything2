#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Wrapper script for cleaning development environment
exec "$SCRIPT_DIR/devbuild.sh" --clean "$@"
