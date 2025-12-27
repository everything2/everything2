#!/bin/bash
# log-rate-limit-block.sh
# Called by mod_evasive DOSSystemCommand when an IP is rate-limited
# Logs the blocked IP to CloudWatch for monitoring and alerting
#
# Usage: log-rate-limit-block.sh <blocked_ip>

BLOCKED_IP="$1"
LOG_GROUP="/aws/e2/rate-limit-blocks"
LOG_STREAM="rate-limit-blocks"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TIMESTAMP=$(date +%s%3N)

# Exit if no IP provided
if [ -z "$BLOCKED_IP" ]; then
    echo "Usage: $0 <blocked_ip>" >&2
    exit 1
fi

# Create log stream if it doesn't exist (ignore errors if it already exists)
aws logs create-log-stream \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$LOG_STREAM" \
    --region "$REGION" 2>/dev/null || true

# Get the sequence token for the log stream (needed for PutLogEvents)
SEQUENCE_TOKEN=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name-prefix "$LOG_STREAM" \
    --region "$REGION" \
    --query 'logStreams[0].uploadSequenceToken' \
    --output text 2>/dev/null)

# Build the log message as JSON
LOG_MESSAGE=$(cat <<EOF
{"timestamp":"$(date -Iseconds)","blocked_ip":"$BLOCKED_IP","reason":"rate_limit_exceeded","source":"mod_evasive"}
EOF
)

# Send to CloudWatch
if [ "$SEQUENCE_TOKEN" = "None" ] || [ -z "$SEQUENCE_TOKEN" ]; then
    # First log event (no sequence token needed)
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$LOG_STREAM" \
        --log-events "timestamp=$TIMESTAMP,message=$LOG_MESSAGE" \
        --region "$REGION" 2>/dev/null
else
    # Subsequent log events need the sequence token
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$LOG_STREAM" \
        --log-events "timestamp=$TIMESTAMP,message=$LOG_MESSAGE" \
        --sequence-token "$SEQUENCE_TOKEN" \
        --region "$REGION" 2>/dev/null
fi

# Also log locally for debugging
echo "$(date -Iseconds) RATE_LIMIT_BLOCK: $BLOCKED_IP" >> /var/log/apache2/rate-limit-blocks.log
