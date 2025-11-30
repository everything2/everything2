#!/bin/bash
#
# Helper script to set the reCAPTCHA Enterprise API key in development
#
# Usage:
#   ./tools/set-recaptcha-secret.sh <api_key>
#   ./tools/set-recaptcha-secret.sh -f <file_with_api_key>
#
# The API key is written to /etc/everything/recaptcha_enterprise_api_key
# inside the container, and Apache is restarted to pick up the new value.
#
# Note: The project ID and site key are hardcoded in Configuration.pm
#
# Example:
#   ./tools/set-recaptcha-secret.sh 'AIzaSy...'
#   ./tools/set-recaptcha-secret.sh -f ../e2-secrets/recaptcha_enterprise_api_key
#

set -e

CONTAINER="e2devapp"
SECRET_PATH="/etc/everything/recaptcha_enterprise_api_key"

usage() {
    echo "Usage: $0 <api_key>"
    echo "       $0 -f <file_containing_api_key>"
    echo ""
    echo "Sets the reCAPTCHA Enterprise API key in the development container"
    echo "and restarts Apache to pick up the new configuration."
    echo ""
    echo "Options:"
    echo "  -f FILE   Read API key from FILE instead of command line"
    echo "  -h        Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 'AIzaSyBx...'"
    echo "  $0 -f ../e2-secrets/recaptcha_enterprise_api_key"
    echo ""
    echo "Note: The project ID (everything2-production) and site key are"
    echo "hardcoded in Configuration.pm and don't need to be set here."
    exit 1
}

# Check container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '${CONTAINER}' is not running."
    echo "Start the development environment first with ./docker/devbuild.sh"
    exit 1
fi

# Parse arguments
API_KEY=""

if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            if [[ -z "$2" ]]; then
                echo "Error: -f requires a filename"
                exit 1
            fi
            if [[ ! -f "$2" ]]; then
                echo "Error: File '$2' not found"
                exit 1
            fi
            API_KEY=$(cat "$2")
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            API_KEY="$1"
            shift
            ;;
    esac
done

if [[ -z "$API_KEY" ]]; then
    echo "Error: No API key provided"
    usage
fi

# Trim whitespace
API_KEY=$(echo "$API_KEY" | tr -d '[:space:]')

if [[ -z "$API_KEY" ]]; then
    echo "Error: API key is empty after trimming whitespace"
    exit 1
fi

echo "Setting reCAPTCHA Enterprise API key in container..."

# Write API key to container
echo -n "$API_KEY" | docker exec -i "$CONTAINER" tee "$SECRET_PATH" > /dev/null

# Verify it was written
VERIFY=$(docker exec "$CONTAINER" cat "$SECRET_PATH" 2>/dev/null || echo "")
if [[ -z "$VERIFY" ]]; then
    echo "Error: Failed to write API key to container"
    exit 1
fi

# Mask the API key for display (show first 10 and last 5 chars)
API_KEY_LEN=${#API_KEY}
if [[ $API_KEY_LEN -gt 20 ]]; then
    MASKED="${API_KEY:0:10}...${API_KEY: -5}"
else
    MASKED="${API_KEY:0:5}..."
fi

echo "✓ API key written: $MASKED (${API_KEY_LEN} characters)"

# Restart Apache to pick up the new configuration
echo "Restarting Apache..."
docker exec "$CONTAINER" apache2ctl graceful

# Wait a moment for Apache to restart
sleep 2

# Check Apache is running by making a request
if curl -sf http://localhost:9080/ > /dev/null 2>&1; then
    echo ""
    echo "Success! reCAPTCHA Enterprise API key has been set and Apache restarted."
    echo ""
    echo "To verify, test the Sign Up page and check the development log:"
    echo "  docker exec $CONTAINER tail -f /tmp/development.log"
    echo ""
    echo "The log will show:"
    echo "  sign_up Page: recaptcha_enterprise_api_key loaded = AIzaSy..."
    echo "  sign_up Page: recaptcha_enterprise_project_id = everything2-production"
else
    echo "Warning: Apache may not have restarted correctly."
    echo "Check the container logs: docker logs $CONTAINER"
    exit 1
fi
