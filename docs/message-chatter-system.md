# Everything2 Message & Chatter System Documentation

**Last Updated**: 2025-11-24
**Purpose**: Comprehensive documentation of E2's messaging infrastructure for private messages and public chatter

## Table of Contents
1. [Overview](#overview)
2. [Database Schema](#database-schema)
3. [Message Types](#message-types)
4. [Message Opcode](#message-opcode)
5. [APIs](#apis)
6. [Special Commands](#special-commands)
7. [Display Functions](#display-functions)
8. [React Migration](#react-migration)

---

## Overview

Everything2's messaging system handles both:
- **Private Messages**: User-to-user or user-to-usergroup messages
- **Public Chatter**: Room-based public chat messages

Both use the same underlying `message` table, differentiated by the `for_user` field:
- `for_user > 0`: Private message to a specific user
- `for_user = 0`: Public chatter message

---

## Database Schema

### `message` Table

Key fields:
```sql
message_id      INT          Primary key, auto-increment
msgtext         TEXT         Message content (HTML allowed from certain bots)
author_user     INT          User ID of sender
for_user        INT          Recipient user ID (0 for public)
for_usergroup   INT          Usergroup ID (for group messages)
room            INT          Room ID (for public messages)
archive         TINYINT      0=active, 1=archived
tstamp          TIMESTAMP    Message timestamp
```

### Message Types by `for_user` Value

| for_user | for_usergroup | room | Type |
|----------|---------------|------|------|
| > 0 | 0 | 0 | Private message to user |
| > 0 | > 0 | 0 | Message to user about usergroup |
| 0 | 0 | > 0 | Public chatter in room |
| 0 | 0 | 0 | Public chatter outside (no room) |

---

## Message Types

### Private Messages

**Characteristics:**
- `for_user` is recipient's user_id
- Can optionally have `for_usergroup` set (group-related messages)
- No `room` field
- User can archive or delete their own messages
- Displayed in Messages nodelet

**Query Example:**
```perl
SELECT * FROM message
WHERE for_user = $user_id
AND archive = 0
ORDER BY tstamp DESC
LIMIT 10
```

### Public Chatter

**Characteristics:**
- `for_user = 0`
- `room` field indicates which room (0 = outside)
- Messages expire after 360 seconds (6 minutes) in production
- Supports special commands (`/me`, `/msg`, `/roll`, etc.)
- Displayed in Chatterbox nodelet
- Cannot be archived (auto-expire)

**Query Example:**
```perl
SELECT * FROM message
WHERE for_user = 0
AND room = $user_room
AND tstamp >= DATE_SUB(NOW(), INTERVAL 360 SECOND)
ORDER BY tstamp DESC
LIMIT 25
```

---

## Message Opcode

**Location**: `ecore/Everything/Delegation/opcode.pm`
**Function**: `sub message` (line 379)

### Flow

```
1. Form submission with op=message
   ↓
2. Security checks:
   - Not a guest user
   - Not borged (suspended from chat)
   - Email verified (for public messages)
   - Not empty message
   ↓
3. Message processing:
   - Parse special commands (/me, /msg, /roll, /fireball, etc.)
   - Validate command syntax
   - Process recipient(s)
   - Handle easter eggs, dice rolls, help topics
   ↓
4. Message storage:
   - Private: INSERT with for_user=$recipient_id
   - Public: INSERT with for_user=0, room=$user_room
   ↓
5. Response:
   - Set sentmessage parameter for display
   - Return to page
```

### Key Security Checks

1. **Guest Check**: `return if $APP->isGuest($USER)`
2. **Borg Check**: `return if $$VARS{borged}`
3. **Email Verification**: Blocks public chat if email unverified
4. **Suspension Check**: Respects chat suspension settings
5. **Message Length**: Trimmed and validated
6. **Ignore List**: Prevents ignored users' messages from displaying

### Message Insertion Points

**Private Message** (line 865):
```perl
$DB->sqlInsert('message', {
    msgtext => $message,
    author_user => $userid,
    for_user => $recip,
    for_usergroup => $ugID
});
```

**Public Chatter** (line 1138):
```perl
$DB->sqlInsert('message', {
    msgtext => $message,
    author_user => getId($USER),
    for_user => 0,
    room => $$USER{in_room}
});
```

---

## APIs

### Private Messages API

**Endpoint**: `/api/messages/`
**File**: `ecore/Everything/API/messages.pm`

#### Routes

| Method | Endpoint | Function | Description |
|--------|----------|----------|-------------|
| GET | `/api/messages/` | `get_all()` | Fetch user's messages |
| GET | `/api/messages/:id` | `get_single_message()` | Get one message |
| POST | `/api/messages/create` | `create()` | Send private message |
| POST | `/api/messages/:id/action/archive` | `archive()` | Archive message |
| POST | `/api/messages/:id/action/unarchive` | `unarchive()` | Unarchive message |
| POST | `/api/messages/:id/action/delete` | `delete()` | Delete message |

#### GET /api/messages/

**Parameters:**
- `limit` (optional): Number of messages (default: 15, max: 100)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
[
  {
    "message_id": 123,
    "author_user": {
      "node_id": 456,
      "title": "username",
      "type": "user"
    },
    "msgtext": "Hello world!",
    "for_user": {
      "node_id": 789,
      "title": "recipient",
      "type": "user"
    },
    "timestamp": "2025-11-24T12:34:56Z",
    "archive": 0,
    "for_usergroup": {
      "node_id": 111,
      "title": "groupname",
      "type": "usergroup"
    }
  }
]
```

#### POST /api/messages/create

**Request:**
```json
{
  "message": "Your message text",
  "for": "username or usergroup"
}
```

**Response:**
```json
{
  "success": true,
  "message_id": 123
}
```

**Notes:**
- Currently only supports private messages
- Does NOT support public chatter (for_user=0)
- Uses blessed node's `deliver_message()` method

### Public Chatter API

**Status**: ⚠️ **NOT YET IMPLEMENTED**

**Proposed Endpoint**: `/api/chatter/`

**Needed Routes:**
- `GET /api/chatter/` - Fetch recent public messages for current room
- Optional: `POST /api/chatter/send` - Send public message (or keep using opcode)

**Proposed Response Format:**
```json
{
  "messages": [
    {
      "message_id": 123,
      "author": {
        "node_id": 456,
        "title": "username",
        "flags": ["@", "+"]
      },
      "msgtext": "Hello room!",
      "timestamp": "2025-11-24T12:34:56Z",
      "room": 789,
      "formatted": "<div>parsed HTML with links</div>"
    }
  ],
  "room": {
    "node_id": 789,
    "title": "Room Name"
  }
}
```

---

## Special Commands

Processed by message opcode before insertion.

### Chat Commands

| Command | Syntax | Effect | Example |
|---------|--------|--------|---------|
| `/me` | `/me action` | Displays as action | `/me waves` → *username waves* |
| `/me's` | `/me's possession` | Possessive action | `/me's hat` → *username's hat* |
| `/sing` | `/sing lyrics` | Musical notes | `/sing hello` → ♫ hello ♫ |
| `/whisper` | `/whisper text` | Small text | `/whisper secret` → <small>secret</small> |

**Synonyms:**
- `/small`, `/aside`, `/ooc`, `/monologue` → `/whisper`
- `/aria`, `/chant`, `/song`, `/rap` → `/sing`

### Private Message Commands

| Command | Syntax | Effect |
|---------|--------|--------|
| `/msg` | `/msg username text` | Send private message |
| `/msg?` | `/msg? username text` | ONO (only if online) |
| `/tell` | `/tell username text` | Alias for /msg |
| `/{users}` | `/{user1 user2} text` | Send to multiple users |

### Special Commands

| Command | Syntax | Effect | Requirements |
|---------|--------|--------|--------------|
| `/roll` | `/roll 3d6+2` | Dice roll | Any user |
| `/flip` | `/flip` | Coin flip (1d2) | Any user |
| `/fireball` | `/fireball username` | Give 5 GP & sanctity | Level 15+, costs egg |
| `/sanctify` | `/sanctify username` | Give 2 GP & sanctity | Level 10+, costs egg |
| `/invite` | `/invite username` | Invite to current room | Any user |
| `/help` | `/help topic` | Get help text | Any user |
| `/sayas` | `/sayas bot message` | Speak as bot | Admin only |

### Easter Egg Commands

Special commands using easter eggs (stored in `$$VARS{easter_eggs}`):
- Costs 1 egg per use
- Valid commands stored in `egg commands` setting
- Examples: `/fireball`, `/sanctify`, `/explode`, `/immolate`, `/conflagrate`, `/singe`, `/limn`

### Dice Rolling

**Format**: `/roll XdY[kZ][+/-N]`
- `X` = number of dice
- `Y` = sides per die
- `kZ` = keep highest Z dice (optional)
- `+/-N` = add/subtract modifier (optional)

**Examples:**
- `/roll 3d6` → rolls 3 six-sided dice
- `/roll 4d6k3` → roll 4d6, keep highest 3
- `/roll 1d20+5` → roll d20 and add 5
- `/roll 1d2` → coin flip

---

## Display Functions

### showchatter

**Location**: `ecore/Everything/Delegation/htmlcode.pm`
**Function**: `sub showchatter` (line 4885)

**Purpose**: Displays public chatter messages in Chatterbox

**Parameters:**
- `$jsoncount` (optional): If truthy, returns JSON instead of HTML

**Logic Flow:**

```
1. Guest check → show registration message
2. Email verification check → show verification requirement
3. Check if earplugs enabled ($$VARS{publicchatteroff})
4. Fetch ignore list for current user
5. Query messages:
   WHERE for_user = 0
   AND room = $$USER{in_room}
   AND tstamp >= (now - 360 seconds)
   AND author_user NOT IN (ignore_list)
   ORDER BY tstamp DESC
   LIMIT 25
6. Process each message:
   - Escape angle brackets (unless from bot)
   - Close dangling square brackets
   - Parse E2 links
   - Add user flags (@, $, +, %)
   - Format special commands (/me, /sing, /whisper, etc.)
   - Handle Halloween costumes (if special date)
7. Return HTML or JSON
```

**Special Processing:**

- **Bots**: No HTML escaping for: Virgil (1080927), CME (839239), Klaproth (952215), root (113)
- **User Flags**:
  - `@` = Admin (god)
  - `$` = Editor (no god)
  - `+` = Chanop
  - `%` = Developer
- **Special Commands**: Processed into italics, small caps, or other formatting

### testshowmessages

**Location**: `ecore/Everything/Delegation/htmlcode.pm`
**Function**: `sub testshowmessages` (line 10926)

**Purpose**: Displays private messages (used by Messages nodelet)

**Parameters:**
- `$maxmsgs` (optional): Number of messages to show (default: 10, max: 100)
- `$showOpts` (optional): Display options string

**Display Options** (single character flags):
- `j` - Return JSON format
- `d` - Show date
- `t` - Show time
- `a` - Show archived messages
- `A` - Hide archived messages (default)
- `g` - Show group messages
- `G` - Hide group messages

**Query:**
```perl
SELECT * FROM message
WHERE for_user = $user_id
[AND author_user = $filterUser]  # if filtering by sender
[AND for_usergroup = 0|!=0]      # if filtering group messages
[AND archive = 0|!=0]             # if filtering archived
ORDER BY tstamp [ASC|DESC]        # based on preference
LIMIT $maxmsgs
```

**Message Rendering:**
- Escapes HTML for non-bot senders
- Parses E2 links
- Displays author, timestamp, message text
- Shows reply links (if enabled in VARS)
- Shows archive/delete actions

---

## React Migration

### Current Status (as of 2025-11-24)

#### Messages Nodelet

**Status**: ✅ React component created, needs integration

**Component**: `react/components/Nodelets/Messages.js`
**Portal**: `react/components/Portals/MessagesPortal.js`

**Features:**
- Fetches messages via `/api/messages/`
- Toggle between inbox and archived
- Archive/unarchive/delete actions
- Displays author, timestamp, message text with link parsing
- Error handling and loading states

**Still Needed:**
- Integration with E2ReactRoot
- Initial data loading in Application.pm
- Tests
- Update Perl nodelet stub to return empty string

#### Chatterbox Nodelet

**Status**: ✅ React component created, needs chatter API

**Component**: `react/components/Nodelets/Chatterbox.js`
**Portal**: `react/components/Portals/ChatterboxPortal.js`

**Current Implementation:**
- Message input form (React controlled)
- Borg status display
- Help links
- Room topic display
- Placeholder divs for chatter display

**Still Needed:**
- `/api/chatter/` endpoint to fetch public messages
- Polling mechanism for real-time updates (every 5-10 seconds)
- Special command rendering (client-side or server-rendered)
- Integration with E2ReactRoot
- Initial data loading in Application.pm
- Tests
- Update Perl nodelet stub to return empty string

### Migration Strategy

**Phase 1: Messages Nodelet** (Simpler)
1. ✅ Create React component
2. Create tests
3. Add data loading to `buildNodeInfoStructure()`
4. Integrate with E2ReactRoot
5. Update Perl stub
6. Deploy and test

**Phase 2: Chatterbox Nodelet** (More Complex)
1. ✅ Create React component
2. Create `/api/chatter/` endpoint:
   ```perl
   package Everything::API::chatter;

   sub get_recent {
     # Fetch public messages for user's room
     # Similar to showchatter logic
     # Return JSON with formatted messages
   }
   ```
3. Implement polling in React (setInterval)
4. Handle special command display
5. Create tests
6. Add data loading to `buildNodeInfoStructure()`
7. Integrate with E2ReactRoot
8. Update Perl stub
9. Deploy and test

**Phase 3: Cleanup**
1. Remove legacy AJAX `showchatter` calls
2. Remove legacy form submission (migrate to API)
3. Update `legacy.js` to remove message/chatter AJAX
4. Document changes in `docs/changelog-2025-11.md`

### API Design for Chatter

**Recommended Implementation:**

```perl
# ecore/Everything/API/chatter.pm
package Everything::API::chatter;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes {
  return {
    '/' => 'get_recent'
  }
}

sub get_recent {
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Get user's current room
  my $room = $USER->{in_room} || 0;

  # Get ignore list
  my $ignore_csr = $DB->sqlSelectMany('ignore_node', 'messageignore',
    'messageignore_id=' . $USER->{user_id});
  my @ignore_list;
  while (my ($u) = $ignore_csr->fetchrow) {
    push @ignore_list, $u;
  }
  my $ignore_str = join(", ", @ignore_list);

  # Build query
  my $where = "for_user=0 AND room=$room";
  $where .= " AND tstamp >= DATE_SUB(NOW(), INTERVAL 360 SECOND)";
  $where .= " AND author_user NOT IN ($ignore_str)" if $ignore_str;

  # Fetch messages
  my $csr = $DB->sqlSelectMany('*', 'message', $where,
    "ORDER BY tstamp DESC LIMIT 25");

  my @messages;
  while (my $msg = $csr->fetchrow_hashref) {
    push @messages, $self->format_chatter_message($msg);
  }

  return [$self->HTTP_OK, {
    messages => [reverse @messages],  # Oldest first
    room => $room
  }];
}

sub format_chatter_message {
  my ($self, $msg) = @_;

  # Format message with user flags, special commands, etc.
  # Return structured data for React to render

  return {
    message_id => int($msg->{message_id}),
    author => $self->APP->node_json_reference($msg->{author_user}),
    msgtext => $msg->{msgtext},
    timestamp => $self->APP->iso_date_format($msg->{tstamp}),
    # Could add: flags, formatted_html, etc.
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Testing Checklist

**Messages Nodelet:**
- [ ] Fetch inbox messages
- [ ] Fetch archived messages
- [ ] Toggle between inbox/archived
- [ ] Archive message
- [ ] Unarchive message
- [ ] Delete message
- [ ] Error handling (network failure, 401, etc.)
- [ ] Link parsing in message text
- [ ] Empty states
- [ ] Loading states

**Chatterbox Nodelet:**
- [ ] Fetch recent chatter
- [ ] Display messages with author and timestamp
- [ ] Poll for updates every 5-10 seconds
- [ ] Send message via form
- [ ] Handle borg status
- [ ] Display user flags (@, $, +)
- [ ] Format special commands (/me, /sing, etc.)
- [ ] Show room topic
- [ ] Empty states (no messages, borgspeak)
- [ ] Error handling

---

## Architecture Diagrams

### Private Message Flow

```
User → Form (op=message) → message opcode
                              ↓
                         Parse /msg command
                              ↓
                         Validate recipient
                              ↓
                         INSERT message table
                              ↓
                         Return with sentmessage
                              ↓
User ← Page reload ← Perl template

-- OR (React) --

User → React Form → POST /api/messages/create
                              ↓
                         deliver_message() method
                              ↓
                         INSERT message table
                              ↓
User ← JSON response ← API

User → React Component → GET /api/messages/
                              ↓
                         SELECT from message table
                              ↓
User ← JSON array ← API
```

### Public Chatter Flow

```
User → Form (op=message) → message opcode
                              ↓
                         Parse message text
                              ↓
                         Process special commands
                              ↓
                         Validate user status
                              ↓
                         INSERT message (for_user=0)
                              ↓
                         Return with sentmessage
                              ↓
User ← Page reload ← showchatter htmlcode

-- OR (React, Proposed) --

User → React Form → POST form (keep opcode)
                              ↓
                         [Same as above]
                              ↓
                         Page reload/AJAX update

User → React Component → GET /api/chatter/
      (polling)             ↓
                         SELECT from message table
                              ↓
                         Format messages
                              ↓
User ← JSON array ← API
```

### Data Flow Comparison

**Current (Perl/Mason):**
```
Request → displayPage()
    → buildNodeInfoStructure() (loads data)
    → nodelet() delegation (renders HTML)
    → AJAX: showchatter (updates chatter)
    → Form submit: op=message (sends message)
```

**Future (React):**
```
Request → displayPage()
    → buildNodeInfoStructure() (loads initial data to window.e2)
    → E2ReactRoot (reads window.e2)
    → Portal → Component
    → Polling: GET /api/chatter/ (updates display)
    → Form submit: POST /api/messages/create (sends message)
```

---

## Appendix: Bot User IDs

Special handling for these bots (no HTML escaping):

| Bot Name | User ID |
|----------|---------|
| root | 113 |
| Virgil | 1080927 |
| CME (Cool Man Eddie) | 839239 |
| Klaproth | 952215 |

---

## Appendix: Configuration

**Relevant Config Values:**
- `chatterbox_cleanup_threshold` - Time before old messages move to publicmessages archive
- `create_room_level` - Minimum level to create rooms
- `environment` - "production" vs "development" (affects message expiry)

**Relevant User Variables:**
- `borged` - User is suspended from chat
- `publicchatteroff` - User has earplugs in
- `hideprivmessages` - Hide private messages in chatterbox
- `easter_eggs` - Number of easter eggs available for special commands
- `showmessages_replylink` - Show reply links in messages
- `pmsgDate`, `pmsgTime` - Show date/time in private messages
- `chatterbox_msgs_ascend` - Message sort order preference
- `powersChatter` - Show user power flags in chatter

---

## References

- **Message Opcode**: `ecore/Everything/Delegation/opcode.pm::message` (line 379)
- **Show Chatter**: `ecore/Everything/Delegation/htmlcode.pm::showchatter` (line 4885)
- **Show Messages**: `ecore/Everything/Delegation/htmlcode.pm::testshowmessages` (line 10926)
- **Messages API**: `ecore/Everything/API/messages.pm`
- **Chatterbox Nodelet**: `ecore/Everything/Delegation/nodelet.pm::chatterbox` (line 45)
- **Messages Nodelet**: `ecore/Everything/Delegation/nodelet.pm::messages` (line 253)
- **React Components**:
  - `react/components/Nodelets/Messages.js`
  - `react/components/Nodelets/Chatterbox.js`

---

**End of Documentation**
