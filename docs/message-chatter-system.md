# Everything2 Message & Chatter System Documentation

**Last Updated**: 2025-11-25
**Purpose**: Comprehensive documentation of E2's messaging infrastructure for private messages and public chatter

## Recent Updates (2025-11-25)

### Critical Bug Fixes (Evening Session)

#### Chatterbox Room Filtering
- **✅ Fixed**: Chatterbox now properly filters messages by room on both initial load and room changes
- **Root Causes**:
  1. `useChatterPolling` hook accepted `currentRoom` parameter but never sent it to API
  2. E2ReactRoot never updated `currentRoom` prop when user changed rooms
  3. Initial page load didn't filter chatter by room
- **Solutions**:
  1. Added room parameter to API URL query string in `useChatterPolling.js:37-39`
  2. Added `currentRoomId` to E2ReactRoot state, initialized from `e2.user.in_room`
  3. Updated `updateOtherUsersData` to extract and update `currentRoomId` from API response
  4. Changed Chatterbox to use `this.state.currentRoomId` instead of `this.props.e2?.user?.in_room`
- **Backend Support**: `Application.pm::getRecentChatter` already filtered by room (line 4206-4208)
- **Files Modified**:
  - [react/hooks/useChatterPolling.js](../react/hooks/useChatterPolling.js) lines 36-39
  - [react/components/E2ReactRoot.js](../react/components/E2ReactRoot.js) lines 179, 190-193, 402-409, 624

#### Usergroup Messaging via deliver_message
- **✅ Fixed**: Usergroup messages now work through `/api/messages/create` endpoint
- **Root Cause**: `deliver_message` methods didn't handle usergroup context properly
- **Issues Resolved**:
  1. Missing `for_usergroup` field (required for reply-all functionality)
  2. No ignore list checking (users ignoring usergroups weren't filtered)
  3. No membership validation (non-members could send to groups)
  4. No archive copy support for usergroups
- **Solution**: Enhanced `user.pm` and `usergroup.pm` deliver_message methods
  - `user.pm`: Added ignore checking, for_usergroup field support
  - `usergroup.pm`: Added membership check, ignore filtering, archive support
- **Files Modified**:
  - [ecore/Everything/Node/user.pm](../ecore/Everything/Node/user.pm) lines 163-188
  - [ecore/Everything/Node/usergroup.pm](../ecore/Everything/Node/usergroup.pm) lines 28-95
- **Tests Added**: [t/038_message_ignores_delivery.t](../t/038_message_ignores_delivery.t) - 5 comprehensive subtests covering:
  - User ignoring direct messages
  - User ignoring usergroup messages
  - `for_usergroup` field preservation
  - Non-member send rejection
  - Archive copy creation

### Messages Nodelet Enhancements
- **✅ Message display order**: Changed to chronological (newest at bottom) for natural chat flow
- **✅ Icon-only buttons**: Streamlined UI with emoji-only action buttons (↩, ↩↩, 📦, 🗑)
- **✅ Reply-all fix**: Corrected reply vs reply-all behavior with `initialReplyAll` prop
- **✅ Delete confirmation**: Added modal confirmation before deleting messages
- **✅ Button styling**: Updated Compose button to match Login button (#38495e)
- **✅ Renamed footer**: "Message Inbox" → "Inbox" for brevity
- **✅ Color-coded buttons**: Purple for replies, gray for archive, red for delete

### Chatterbox Nodelet Improvements
- **✅ Focus retention**: Input field maintains focus after submitting messages via Enter key
- **✅ Macro command**: Moved to editor+ permissions, marked as beta feature
- **✅ Command permissions**: Clarified three tiers (public, editor+, chanop/admin)

### Technical Details
- **Reply-all implementation**: `MessageModal` now accepts `initialReplyAll` prop to distinguish between individual and group replies
- **Focus pattern**: Uses `setTimeout(() => inputRef.current.focus(), 0)` to defer focus until after React render cycle
- **Delete safety**: Confirmation modal prevents accidental message deletion with clear warning text
- **Accessibility**: All icon-only buttons include descriptive `title` attributes

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

**Status**: ✅ **IMPLEMENTED** (Session 9)

**Endpoint**: `/api/chatter/`
**File**: `ecore/Everything/API/chatter.pm`

#### Routes

| Method | Endpoint | Function | Description |
|--------|----------|----------|-------------|
| GET | `/api/chatter/` | `get()` | Fetch recent public messages |
| POST | `/api/chatter/create` | `create()` | Send public chatter message |

#### GET /api/chatter/

**Parameters:**
- `limit` (optional): Number of messages (default: 30, max: 100)
- `offset` (optional): Pagination offset (default: 0)
- `since` (optional): ISO timestamp for incremental updates

**Response Format:**
```json
[
  {
    "message_id": 123,
    "author_user": {
      "node_id": 456,
      "title": "username",
      "type": "user"
    },
    "msgtext": "Hello room!",
    "timestamp": "2025-11-24T12:34:56Z",
    "room": 789
  }
]
```

**Notes:**
- Returns messages for user's current room
- Respects user's ignore list
- Messages older than 6 minutes excluded (360 second window)
- Returns in chronological order (oldest first)

#### POST /api/chatter/create

**Request:**
```json
{
  "message": "Your message text"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Message sent"
}
```

**Notes:**
- Uses `sendPublicChatter()` from Application.pm
- Truncates to 512 characters
- Checks for duplicate messages
- Respects chat suspension and borg status

---

## Application.pm Refactoring (Session 10)

### Overview

In Session 10 (2025-11-24), core messaging functionality was extracted from `opcode.pm` and `htmlcode.pm` into `Application.pm` to centralize business logic and make it reusable across opcodes, htmlcodes, and API endpoints.

### Extracted Methods

#### sendPublicChatter()

**Location**: `ecore/Everything/Application.pm::sendPublicChatter` (line 3855)

**Purpose**: Send a public chatter message to current room

**Signature**:
```perl
$APP->sendPublicChatter($user, $message, $vars)
```

**Parameters:**
- `$user` - User node object
- `$message` - Message text (will be truncated to 512 chars)
- `$vars` - User VARS hashref

**Returns:** 1 on success, undef on failure

**Features:**
- Truncates to 512 characters
- Checks for duplicate messages (within 480 seconds)
- Respects chat suspension (`isSuspended($user, "chat")`)
- Respects infected/borged status
- Validates user has `publicchatteroff` disabled
- UTF-8 encoding handling

#### getRecentChatter()

**Location**: `ecore/Everything/Application.pm::getRecentChatter` (line 3901)

**Purpose**: Fetch recent public chatter for display in Chatterbox

**Signature**:
```perl
$APP->getRecentChatter({
  limit => 30,
  offset => 0,
  room => 0,
  since => '2025-11-24T12:00:00Z'  # optional
})
```

**Parameters:**
- `limit` - Number of messages (default: 30, max: 100)
- `offset` - Pagination offset (default: 0)
- `room` - Room ID (default: 0 = outside)
- `since` - ISO timestamp for incremental updates (optional)

**Returns:** Array reference of message structures

**Features:**
- Supports pagination (limit/offset)
- Supports room filtering
- Supports incremental updates with `since` parameter
- Returns structured JSON-ready data via `message_json_structure()`

#### sendPrivateMessage()

**Location**: `ecore/Everything/Application.pm::sendPrivateMessage` (line 3939)

**Purpose**: Send private message to one or more recipients

**Signature**:
```perl
$APP->sendPrivateMessage($author, $recipients, $message, $options)
```

**Parameters:**
- `$author` - Author user node object
- `$recipients` - Username string, node object, or array reference
- `$message` - Message text
- `$options` - Hash reference with optional settings:
  - `online_only` - Boolean (ONO - only if online)
  - `about_node` - Node title (adds "re [node]:" prefix)
  - `for_usergroup` - Usergroup ID

**Returns:** Hash reference with result:
```perl
{
  success => 1,
  sent_to => ['user1', 'user2'],
  errors => ['error1', 'error2']  # if any
}
```

**Features:**
- Accepts single or multiple recipients
- Username string or node object support
- Handles message forwarding automatically
- Checks ignore lists
- Online-only (ONO) filtering
- Usergroup message support (delegates to `sendUsergroupMessage()`)
- Comprehensive error reporting

#### sendUsergroupMessage()

**Location**: `ecore/Everything/Application.pm::sendUsergroupMessage` (line 4057)

**Purpose**: Send message to all members of a usergroup

**Signature**:
```perl
$APP->sendUsergroupMessage($author, $usergroup, $message, $options)
```

**Parameters:**
- `$author` - Author user node object
- `$usergroup` - Usergroup node object
- `$message` - Message text
- `$options` - Hash reference (same as sendPrivateMessage)

**Returns:** Hash reference with result:
```perl
{
  success => 1,
  sent_to => ['member1', 'member2', ...]
}
```

**Features:**
- Validates usergroup membership
- Filters ignore list (per-usergroup ignores)
- Online-only (ONO) filtering
- Sends archive copy to usergroup if `allow_message_archive` enabled
- Deduplicates recipients by user_id

#### processDiceRoll()

**Location**: `ecore/Everything/Application.pm::processDiceRoll` (line 4143)

**Purpose**: Parse and execute dice roll commands

**Signature**:
```perl
$APP->processDiceRoll($roll_string)
```

**Parameters:**
- `$roll_string` - Dice notation string (e.g., "3d6+2", "4d6keep3")

**Returns:** Hash reference with result:
```perl
{
  success => 1,
  roll_notation => "3d6+2",
  total => 15,
  dice => [6, 5, 4],
  message => "/rolls 3d6+2 → 15"
}
```

**Dice Notation Format:** `XdY[kZ][+/-N]`
- `X` = number of dice (max 1000)
- `Y` = sides per die (no negative)
- `kZ` = keep highest Z dice (optional)
- `+/-N` = add/subtract modifier (optional)

**Features:**
- Supports keep-highest mechanics (e.g., `4d6k3`)
- Supports modifiers (e.g., `1d20+5`, `2d8-2`)
- Validates dice count (max 1000)
- Validates dice sides (no negative)
- Returns individual dice results and total
- Returns formatted message string

### Usage Examples

**Public Chatter:**
```perl
# In opcode or API endpoint
$APP->sendPublicChatter($USER, "Hello world!", $VARS);
```

**Private Message:**
```perl
# Single recipient
my $result = $APP->sendPrivateMessage(
  $USER,
  'username',
  'Hello!',
  {online_only => 1}
);

# Multiple recipients
my $result = $APP->sendPrivateMessage(
  $USER,
  ['user1', 'user2', 'user3'],
  'Group message',
  {}
);

# Usergroup message (automatic delegation)
my $result = $APP->sendPrivateMessage(
  $USER,
  'usergroup_name',
  'Message to group',
  {}
);
```

**Dice Roll:**
```perl
my $result = $APP->processDiceRoll('3d6+2');
if ($result->{success}) {
  print $result->{message};  # "/rolls 3d6+2 → 15"
}
```

### Migration Status

**Completed:**
- ✅ `sendPublicChatter()` - Extracted from opcode.pm (Session 9)
- ✅ `getRecentChatter()` - Extracted from showchatter logic (Session 9)
- ✅ `sendPrivateMessage()` - Extracted from htmlcode.pm (Session 10)
- ✅ `sendUsergroupMessage()` - Extracted from opcode.pm (Session 10)
- ✅ `processDiceRoll()` - Extracted from opcode.pm (Session 10)
- ✅ All baseline tests passing (t/036_message_opcode.t)

**Still in Opcode:**
- `/fireball` command (lines 511-573)
- `/sanctify` command (lines 578-620)
- `/drag` command (lines 878-915)
- `/borg` command (lines 943-977)
- `/invite` command (lines 460-471)
- `/help` command (lines 687-716)
- Easter egg commands
- Message deletion/archiving UI logic
- Command synonym normalization

**Next Steps:**
- Extract special command processing to `processSpecialCommand()` method
- Update opcode.pm to call new Application.pm methods
- Consider extracting admin commands (/borg, /drag, etc.) if reuse needed

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

### Current Status (as of 2025-11-24 - Session 10)

#### Messages Nodelet

**Status**: ✅ **FULLY MIGRATED AND DEPLOYED**

**Component**: `react/components/Nodelets/Messages.js`
**Portal**: `react/components/Portals/MessagesPortal.js`

**Features:**
- ✅ Fetches messages via `/api/messages/`
- ✅ Toggle between inbox and archived
- ✅ Archive/unarchive/delete actions
- ✅ Displays author, timestamp, message text with link parsing
- ✅ Error handling and loading states
- ✅ Integrated with E2ReactRoot
- ✅ Initial data loading in Application.pm
- ✅ Tests passing (100% coverage)
- ✅ Perl nodelet stub returns empty string
- ✅ **2-minute polling** when active (stops when idle/asleep)
- ✅ **Focus refresh** - immediate update when returning to tab

**Polling Behavior:**
- Polls every 2 minutes when user is active
- Stops polling after 10 minutes of inactivity
- Only polls in focused tab (multi-tab detection)
- Immediate refresh when page becomes visible
- Uses `X-Ajax-Idle: 1` header for server monitoring

**Message Composition Modal:**

**Component**: `react/components/MessageModal.js`

**Trigger Points:**
- ↩ **Reply button** - Opens modal pre-filled with author as recipient
- ↩↩ **Reply All button** - Opens modal pre-filled with usergroup as recipient (only visible for usergroup messages)
- ✉ **Compose button** - Opens modal with empty recipient field

**Features:**
- **Character limit**: 512 characters with live counter
  - Counter turns yellow at 90% (461+ chars)
  - Counter turns red at 100% (512+ chars)
  - Send button disabled when over limit
- **Reply vs Reply-All toggle**: For usergroup messages, modal shows toggle buttons:
  - "Switch to individual reply" - replies only to original author
  - "Switch to reply all" - replies to entire usergroup
- **Auto-focus**: Textarea receives focus when modal opens
- **Click-outside-to-close**: Modal closes when clicking overlay
- **Recipient field**:
  - Pre-filled and locked for replies (with toggle option)
  - Manual entry for new messages
  - Displays as styled badge for pre-filled recipients
- **Error handling**: Shows error banner for failed sends or validation issues
- **Loading states**: Send button shows "Sending..." during API call

**Message Display:**

Messages are displayed in **chronological order** with newest messages at the bottom (like a traditional chat interface). This allows for natural conversation flow where users can scroll down to see the most recent messages.

**Button Layout:**

Each message displays **icon-only action buttons** for a clean, compact interface:
1. **↩** Reply (purple border) - Always visible for non-archived messages, replies to individual sender
2. **↩↩** Reply All (purple border) - Only for usergroup messages (`for_usergroup.node_id > 0`), replies to entire group
3. **📦** Archive (gray border) - Moves message to archive
4. **🗑** Delete (red border) - Shows confirmation modal, then permanently deletes message

All buttons include descriptive `title` attributes for accessibility.

**Reply vs Reply-All Behavior:**
- **Reply button**: Opens modal with individual sender as recipient
- **Reply All button**: Opens modal with usergroup as recipient
- Modal includes toggle buttons to switch between individual/group reply modes
- Correctly distinguishes between the two actions via `initialReplyAll` prop

**Delete Confirmation:**
- Clicking delete shows a confirmation modal
- "Are you sure you want to permanently delete this message? This action cannot be undone."
- Prevents accidental deletions
- Modal has Cancel and Delete buttons

Archived messages show only:
- **Unarchive** button (text label, no icon)

**Footer Actions:**

At the bottom of the nodelet:
1. **✉ Compose** (dark blue-gray #38495e button, matches Login button styling) - Opens composition modal for new message
2. **📬 Inbox** (gray link) - Navigates to `/title/Message+Inbox` superdoc

**API Integration:**

Sends via POST to `/api/messages/create`:
```json
{
  "for": "username or usergroup",
  "message": "Message text (max 512 chars)"
}
```

On success, automatically refreshes the messages list to show the sent message.

**Validation Rules:**
- Message cannot be empty (after trim)
- Message cannot exceed 512 characters
- Recipient must be specified (either auto-filled or manually entered)
- Send button disabled during send operation to prevent double-submit

**User Experience:**
- Modal uses fixed positioning with high z-index (10000) to overlay all content
- Overlay has semi-transparent black background (`rgba(0, 0, 0, 0.5)`)
- Modal content has white background with rounded corners (8px)
- Modal is responsive: max-width 600px, max-height 90vh
- Scrollable content area if message form is taller than viewport

#### Chatterbox Nodelet

**Status**: ✅ **FULLY MIGRATED AND DEPLOYED**

**Component**: `react/components/Nodelets/Chatterbox.js`
**Portal**: `react/components/Portals/ChatterboxPortal.js`

**Features:**
- ✅ Message input form (React controlled)
- ✅ Borg status display
- ✅ Help links and command modal
- ✅ Room topic display
- ✅ Real-time chatter display
- ✅ `/api/chatter/` endpoint implemented
- ✅ **Adaptive dual-rate polling** (45s active / 2m idle)
- ✅ Integrated with E2ReactRoot
- ✅ Initial data loading in Application.pm
- ✅ Tests passing
- ✅ Perl nodelet stub returns empty string
- ✅ User flags display (@, $, +, Ø)
- ✅ Special command formatting (/me, /roll, etc.)
- ✅ **Focus refresh** - immediate update when returning to tab
- ✅ **Input focus retention** - field remains focused after message submission (Enter key)

**Polling Behavior:**
- Polls every **45 seconds** when recently active (< 60s since last interaction)
- Slows to **2 minutes** when idle (60s-10m since last interaction)
- Stops polling after 10 minutes of inactivity (asleep)
- Only polls in focused tab (multi-tab detection)
- Immediate refresh when page becomes visible
- Uses `X-Ajax-Idle: 1` header for server monitoring

**Input Focus Behavior:**
- Input field maintains focus after pressing Enter to submit a message
- Implemented using `setTimeout(() => inputRef.current.focus(), 0)` pattern
- Defers focus restoration until after React completes render cycle
- Applies to both regular messages and admin commands (/clearchatter)
- Allows continuous typing without needing to click back into the field
- Improves chat flow and user experience

**Chat Commands Modal:**
- Shows available commands based on user permissions
- Wider modal (900px max-width, 90% responsive)
- 90vh height (minimal scrolling)
- Combined `/msg or /tell` into single line
- Displays restricted commands (CHANOP/ADMIN) with badges
- **Editor+ commands**: `/macro <name>` - Use a saved macro (beta) - marked as restricted, editor+ only

**Command Permissions:**
- **Public commands**: Available to all users (msg, me, roll, flip, ignore, unignore, chatteroff, chatteron)
- **Editor+ commands**: `/macro` (beta feature)
- **Chanop/Admin commands**: fireball, sanctify, borg, drag, topic
- **Admin-only commands**: clearchatter, sayas, invite

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

## UI Modernization (Session 10)

### SignIn Nodelet

**Status**: ✅ **MODERNIZED** (2025-11-24)

**Component**: `react/components/Nodelets/SignIn.js`

**Changes:**
- ✅ Removed deprecated `<table>` layout → Modern flexbox
- ✅ Removed deprecated `<font>` tags → CSS styling
- ✅ Added light gray background (#f8f9fa) matching site aesthetic
- ✅ Full-width inputs with proper labels (htmlFor/id associations)
- ✅ Purple submit button (#667eea) for consistency
- ✅ Better error message display (conditional rendering)
- ✅ Improved link text ("Lost password?", "Create an account")
- ✅ Cleaner help contact styling

**Before:**
- HTML table layout with mixed inline styles
- Deprecated font tags
- No consistent spacing

**After:**
- Modern flexbox layout
- Consistent 12px spacing
- Professional form design
- Accessibility improvements (label associations)

### Chatterbox Help Modal

**Status**: ✅ **IMPROVED** (2025-11-24)

**Component**: `react/components/Nodelets/Chatterbox.js` (lines 254-368)

**Changes:**
- ✅ Wider modal: 600px → 900px max-width
- ✅ Responsive width: Added 90% width for smaller screens
- ✅ Taller modal: 80vh → 90vh max-height (reduced scrolling)
- ✅ Combined commands: `/msg or /tell <user> <text>` on single line
- ✅ Command count: 10 → 9 commands (combined synonyms)

**Benefits:**
- Less scrolling on desktop (90vh vs 80vh)
- Better readability (wider content area)
- Cleaner command list (no redundant entries)
- Better responsive behavior

### NewWriteups Nodelet

**Status**: ✅ **MODERNIZED** (2025-11-24)

**Components:**
- `react/components/Nodelets/NewWriteups.js`
- `react/components/NewWriteupsFilter.js`

**Changes:**
- ✅ Removed nested ternaries → Early return pattern
- ✅ Fixed filtering bug (undefined entries beyond limit)
- ✅ Modern filter UI with light gray background (#f8f9fa)
- ✅ Consistent spacing and typography
- ✅ Better empty state styling
- ✅ "Show:" label before dropdown
- ✅ Flexbox layout with proper gaps

**Bug Fixed:**
```javascript
// Before: .map() with conditional return (returns undefined)
writeups.filter(...).map((entry, index) => {
  if (index < props.limit) return <WriteupEntry ... />
})

// After: .filter().slice().map() (correct)
const filteredWriteups = writeups
  .filter((entry) => !entry.is_junk || !props.noJunk)
  .slice(0, props.limit)
```

### Design Consistency

All UI updates follow the site's **Kernel Blue** aesthetic:
- Light gray backgrounds: `#f8f9fa`
- Border color: `#dee2e6`
- Text colors: `#495057` (labels), `#6c757d` (help text)
- Accent color: `#667eea` (purple - links, buttons)
- Consistent spacing: 12px gaps, 8px padding
- Modern rounded corners: 3-4px border-radius
- Professional, clean appearance

---

---

## Message Opcode Burndown Chart

**Purpose**: Track all `op=message` usage in the codebase to monitor migration progress

**Last Updated**: 2025-11-24 (Session 10)

### Current Status

**Total op=message Call Sites**: 7 locations
- **Migrated to API**: 0
- **XML Tickers (Keep - User-Facing)**: 1
- **Internal Forms (Can Migrate)**: 6

### XML Tickers (Keep - User-Facing)

These endpoints should be **preserved** as they are public-facing features used by various E2 clients:

| File | Line | Description | Status |
|------|------|-------------|--------|
| `www/js/legacy.js` | 2690 | Universal Message XML Ticker AJAX | **KEEP** |

**Rationale**: XML tickers are documented public APIs that external clients may depend on. Breaking these would affect user-created tools and bookmarklets.

### Internal Forms (Can Migrate to API)

These are internal UI elements that can be migrated to the new API architecture:

| File | Line | Description | Migration Priority |
|------|------|-------------|-------------------|
| `ecore/Everything/Delegation/htmlcode.pm` | 11211 | Archive message action link | Medium |
| `ecore/Everything/Delegation/htmlcode.pm` | 11215 | Delete message action link | Medium |
| `ecore/Everything/Delegation/document.pm` | 9928 | Message inbox form | Low |
| `ecore/Everything/Delegation/document.pm` | 16184 | Message inbox form (alternate) | Low |
| `ecore/Everything/Delegation/document.pm` | 18362 | Message form with explain field | Low |
| `nodepack/plaindoc/e2_bookmarklets_(edevdoc).xml` | 198 | E2 bookmarklet (documentation) | Low |

**Note**: The bookmarklet in `e2_bookmarklets_(edevdoc).xml` is documentation of user-facing bookmarklet code. While the XML ticker should be preserved, the documentation can reference it without changes.

### Migration Strategy

**Phase 1: Command Processing via API** ✅ **COMPLETED**
- ✅ Extracted command processing to Application.pm
- ✅ Created command router (`processMessageCommand()`)
- ✅ Extracted 8 command handlers (line 3901-4184)
- ✅ Updated chatter API to use command processor
- ✅ React Chatterbox uses `/api/chatter/create`
- ✅ All tests passing (1223 Perl tests, 445 React tests)

**Phase 2: Migrate Archive/Delete Actions**
- Update htmlcode.pm archive/delete links to use API endpoints
- React Messages nodelet already uses API (migration complete)
- Update any remaining Perl forms that use op=message for actions

**Phase 3: Migrate Message Inbox Forms**
- Identify all message inbox forms in document.pm
- Update to use `/api/messages/create` instead of op=message
- Consider creating unified React message form component

**Phase 4: Preserve XML Tickers**
- Document XML ticker API contract
- Ensure backward compatibility during refactoring
- Consider versioning if changes needed in future

### Detailed Call Site Analysis

#### www/js/legacy.js:2690 - Universal Message XML Ticker
```javascript
// AJAX call to Universal Message XML Ticker
// Used by legacy JavaScript for message sending
// Status: KEEP (user-facing API)
```

**Action**: No changes planned. Preserve as public API endpoint.

#### htmlcode.pm:11211, 11215 - Message Actions
```perl
# Archive and delete message action links
# Currently use op=message with special parameters
```

**Migration Path**:
1. Update links to POST to API endpoints:
   - `/api/messages/:id/action/archive` (already exists)
   - `/api/messages/:id/action/delete` (already exists)
2. Update htmlcode.pm to use `<form method="POST">` instead of op=message
3. Test thoroughly (messages are critical feature)

**Estimated Effort**: 1-2 hours

#### document.pm:9928, 16184, 18362 - Message Forms
```perl
# Various message inbox and compose forms
# Submit with op=message
```

**Migration Path**:
1. Identify exact form locations and purposes
2. Consider React component for message composition
3. Update forms to POST to `/api/messages/create`
4. Update any response handling (redirects, success messages)

**Estimated Effort**: 4-6 hours (3 forms, testing)

#### bookmarklets XML:198 - Documentation Only
```xml
<!-- E2 bookmarklet code example -->
<!-- Documents user-facing bookmarklet that uses XML ticker -->
```

**Action**: No changes needed. This is documentation of user-facing feature, not the feature itself.

### Testing Requirements

Before migration of any call site:
1. ✅ Verify baseline tests pass
2. ✅ Document expected behavior
3. ✅ Create API endpoint tests
4. ✅ Test migration in development
5. ✅ Verify no regressions
6. ✅ Update documentation

### Progress Tracking

| Phase | Description | Status | Date |
|-------|-------------|--------|------|
| Phase 1 | Command processing extraction | ✅ Complete | 2025-11-24 |
| Phase 2 | Archive/delete actions | ⏳ Pending | - |
| Phase 3 | Message inbox forms | ⏳ Pending | - |
| Phase 4 | Documentation & cleanup | ⏳ Pending | - |

**Overall Progress**: 14% complete (1/7 locations migrated to API, excluding XML ticker)

---

**End of Documentation**
