#!/bin/bash
#
# generate-test-messages.sh - Creates test messages for pagination testing
#
# Usage:
#   ./tools/generate-test-messages.sh [count] [target_user]
#
# Arguments:
#   count       - Number of messages to create (default: 1000)
#   target_user - Username to receive messages (default: e2e_admin)
#
# Examples:
#   ./tools/generate-test-messages.sh           # Creates 1000 messages for e2e_admin
#   ./tools/generate-test-messages.sh 500       # Creates 500 messages for e2e_admin
#   ./tools/generate-test-messages.sh 100 root  # Creates 100 messages for root
#
# The script creates messages from multiple test users to simulate realistic
# inbox conditions for testing pagination, filtering, and performance.
#

set -e

COUNT=${1:-1000}
TARGET_USER=${2:-e2e_admin}

echo "=== Message Generator for Pagination Testing ==="
echo "Creating $COUNT messages for user: $TARGET_USER"
echo ""

# Get target user ID (look up the user nodetype ID via subquery)
TARGET_ID=$(docker exec e2devdb mysql -u root -pblah everything -N -e \
  "SELECT n.node_id FROM node n WHERE n.title='$TARGET_USER' AND n.type_nodetype = (SELECT nt.nodetype_id FROM nodetype nt JOIN node nn ON nt.nodetype_id = nn.node_id WHERE nn.title='user' LIMIT 1)" 2>/dev/null)

if [ -z "$TARGET_ID" ]; then
  echo "ERROR: User '$TARGET_USER' not found in database"
  exit 1
fi

echo "Target user ID: $TARGET_ID"

# Define sender users (using existing test users)
# These are created by tools/seeds.pl
SENDERS=(
  "113:root"
  "2205753:genericdev"
  "2205757:e2e_editor"
  "2205758:e2e_developer"
  "2205759:e2e_chanop"
  "2205760:e2e_user"
)

# Sample message templates for variety
TEMPLATES=(
  "Test message #%d - This is a test message for pagination testing."
  "Message %d: Lorem ipsum dolor sit amet, consectetur adipiscing elit."
  "Automated test #%d - Checking inbox functionality and scrolling."
  "Pagination test message %d - Verifying large message list handling."
  "[Test %d] Important notification about system status."
  "Re: Discussion thread - Reply #%d to the ongoing conversation."
  "FYI: Update %d - Just wanted to let you know about this change."
  "Question %d: Can you help me understand how this feature works?"
  "Reminder %d: Don't forget about the upcoming deadline."
  "Note #%d: Some additional context for the previous message."
)

echo ""
echo "Generating $COUNT messages..."
echo ""

# Build SQL statements in batches for performance
BATCH_SIZE=100
BATCH_COUNT=0
SQL_VALUES=""

for i in $(seq 1 $COUNT); do
  # Select random sender
  SENDER_ENTRY=${SENDERS[$((RANDOM % ${#SENDERS[@]}))]}
  SENDER_ID=${SENDER_ENTRY%%:*}

  # Skip if sender is same as target
  if [ "$SENDER_ID" = "$TARGET_ID" ]; then
    SENDER_ENTRY=${SENDERS[0]}  # Fall back to root
    SENDER_ID=${SENDER_ENTRY%%:*}
  fi

  # Select random message template and format it
  TEMPLATE=${TEMPLATES[$((RANDOM % ${#TEMPLATES[@]}))]}
  MESSAGE=$(printf "$TEMPLATE" $i)

  # Escape single quotes for SQL
  MESSAGE=${MESSAGE//\'/\'\'}

  # Add to batch
  if [ -n "$SQL_VALUES" ]; then
    SQL_VALUES="$SQL_VALUES,"
  fi

  # Spread timestamps over the last 30 days for realistic testing
  # Each message is offset by a random number of seconds (up to 30 days worth)
  OFFSET=$((RANDOM % 2592000))  # 30 days in seconds

  SQL_VALUES="$SQL_VALUES
    ('$MESSAGE', $SENDER_ID, DATE_SUB(NOW(), INTERVAL $OFFSET SECOND), $TARGET_ID, 0, 0, 0)"

  BATCH_COUNT=$((BATCH_COUNT + 1))

  # Execute batch when full
  if [ $BATCH_COUNT -ge $BATCH_SIZE ] || [ $i -eq $COUNT ]; then
    docker exec e2devdb mysql -u root -pblah everything -e \
      "INSERT INTO message (msgtext, author_user, tstamp, for_user, room, archive, for_usergroup) VALUES $SQL_VALUES" 2>/dev/null

    echo "  Created messages $((i - BATCH_COUNT + 1)) to $i..."

    SQL_VALUES=""
    BATCH_COUNT=0
  fi
done

echo ""
echo "=== Generation Complete ==="

# Show final count
FINAL_COUNT=$(docker exec e2devdb mysql -u root -pblah everything -N -e \
  "SELECT COUNT(*) FROM message WHERE for_user=$TARGET_ID AND archive=0" 2>/dev/null)

echo "Total active messages for $TARGET_USER: $FINAL_COUNT"
echo ""
echo "To test pagination:"
echo "  1. Log in as $TARGET_USER"
echo "  2. Visit /title/Message+Inbox"
echo "  3. Check pagination controls and page navigation"
echo ""
echo "To clean up test messages:"
echo "  docker exec e2devdb mysql -u root -pblah everything -e \\"
echo "    \"DELETE FROM message WHERE for_user=$TARGET_ID AND msgtext LIKE 'Test message #%'\""
