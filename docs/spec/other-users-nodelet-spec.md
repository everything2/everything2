# Other Users Nodelet Specification

**Purpose**: Display real-time list of users in the chatterbox system
**Status**: Implemented (React + API)
**Last verified**: 2026-11-16

---

## Overview

The Other Users nodelet shows who is currently online in the chatterbox, their status, and room information. It provides room switching, cloaking controls, and room creation for authorized users.

---

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `OtherUsers.js` | `react/components/Nodelets/OtherUsers.js` | React UI component |
| `useOtherUsersPolling.js` | `react/hooks/useOtherUsersPolling.js` | Polling hook (2 min interval) |
| `buildOtherUsersData()` | `ecore/Everything/Application.pm` | Server-side data builder |
| `chatroom.pm` | `ecore/Everything/API/chatroom.pm` | API endpoints for room operations |

### Data Flow

1. **Initial load**: `buildOtherUsersData($USER)` generates data during page render
2. **Polling**: `useOtherUsersPolling` refreshes every 2 minutes via `GET /api/chatroom/` (the `/` route → `get_other_users`), sent with `X-Ajax-Idle: 1`. Pauses after 10 min of inactivity or when the tab is hidden, and refreshes on tab focus. It does **not** pause when the nodelet is collapsed.
3. **Actions**: Room changes, cloaking, room creation use dedicated API endpoints

---

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/chatroom/` | GET | Fetch current other users data (route `/` → `get_other_users`) |
| `/api/chatroom/change_room` | POST | Change user's current room |
| `/api/chatroom/set_cloaked` | POST | Toggle user visibility (cloak) |
| `/api/chatroom/create_room` | POST | Create a new room |
| `/api/chatroom/lock_room` | POST | Admin-only: set `roomlocked` on a room (used by `Documents/Room.js`, not the nodelet) |

All chatroom endpoints reject guests (`unauthorized_if_guest`).

---

## Data Structure

```javascript
{
  userCount: 15,
  currentRoomUserCount: 6,
  currentRoom: "outside",
  currentRoomId: 0,
  rooms: [
    {
      title: "Outside",  // always populated (#3990); room 0 is "Outside"
      users: [
        {
          userId: 123,
          username: "username",
          displayName: "username",  // or costume name during Halloween
          isCurrentUser: true,
          flags: [
            { type: "god" },
            { type: "editor" },
            { type: "chanop" },
            { type: "borged" },
            { type: "invisible" },
            { type: "newuser", days: 5, veryNew: false },
            { type: "room", roomId: 456, roomTitle: "Private Room" }
          ],
          action: {
            type: "action",
            verb: "eating",
            noun: "a carrot"
          }
          // OR
          action: {
            type: "recent",
            nodeId: 789,
            nodeTitle: "Writeup Title",
            parentTitle: "Node Title"
          }
        }
      ]
    }
  ],
  availableRooms: [
    { room_id: 0, title: "outside" },
    { room_id: 123, title: "Private Room" }
  ],
  canCloak: true,
  isCloaked: false,
  canCreateRoom: true,
  createRoomSuspended: false,
  suspension: null  // or { type: "temporary", seconds_remaining: 300 } / { type: "indefinite" }
}
```

---

## User Flags (Badges)

Flags appear in brackets after the username: `[@ $ + Ø i ~]`

| Flag | Type | Display | Visibility | Condition |
|------|------|---------|------------|-----------|
| Gods | `god` | `@` | All | `isAdmin(user)` AND not hiding symbol |
| Editors | `editor` | `$` | All | `isEditor(user, "nogods")` AND not god AND not hiding |
| Chanops | `chanop` | `+` | All | `isChanop(user, "nogods")` |
| Borged | `borged` | `Ø` | Editors/Chanops | `borgd` flag in room table |
| Invisible | `invisible` | red `i` | Editors/Chanops/Infravision | `visible=1` in room table |
| New User | `newuser` | days count | Editors/Admins | Account age ≤ 30 days |
| Room | `room` | `~` | All | User in different room, viewer in room 0 |

**Note**: Editors who are also gods show only `@`, not both `@` and `$`.

### New User Styling

- **≤3 days**: Bold (`<strong class="newdays">`) with "very new user" tooltip
- **4-30 days**: Normal (`<span class="newdays">`) with "new user" tooltip
- **>30 days**: No indicator

---

## User Actions

Random fun text shown after username (2% probability per user):

### Conditions
- **Viewer** has `showuseractions` VARS preference enabled
- Not the current user (`!sameUser`)
- Random chance: `0.02 > rand()`

### Verbs (29 options including blank)
```
eating, watching, stalking, filing, noding, amazed by, tired of,
crying for, thinking of, fighting, bouncing towards, fleeing from,
diving into, wishing for, skating towards, playing with, upvoting,
learning of, teaching, getting friendly with, frowned upon by,
sleeping on, getting hungry for, touching, beating up, spying on,
rubbing, caressing, "" (blank)
```

### Nouns (34 options)
```
a carrot, some money, EDB, nails, some feet, a balloon, wheels,
soy, a monkey, a smurf, an onion, smoke, the birds, you!,
a flashlight, hash, your speaker, an idiot, an expert, an AI,
the human genome, upvotes, downvotes, their pants, smelly cheese,
a pink elephant, teeth, a hippopotamus, noders, a scarf, your ear,
killer bees, an angst sandwich, Butterfinger McFlurry
```

### Recent Noding

Alternative to random action (2% probability):
- **Viewer** has `showuseractions` enabled (no `!sameUser` check here, so it can fire for yourself)
- Listed user noded within last week (604800 seconds)
- Last node not hidden (`notnew` flag)
- Shows: "has recently noded [link to writeup]"

**Note**: Recent noding takes precedence if both would trigger.

---

## Halloween Costumes

During Halloween period (`inHalloweenPeriod()`, Oct 25 – Nov 2):
- User's `costume` VARS key holds the costume **string** (not a node_id; see halloween-costume-system.md)
- `displayName` is replaced with that string; `username`/`userId` stay real
- Link still points to real user

---

## Visibility (Cloaking)

### Database Field
`visible` in `room` table:
- `0` = visible to all (normal)
- `1` = invisible (cloaked)

### Who Can See Invisible Users
- Editors (`isEditor`)
- Chanops (`isChanop`)
- Users with `infravision` VARS preference

### Query Filter
```perl
unless($user_is_editor || $user_is_chanop || $infravision) {
  $wherestr .= ' AND r.visible=0';
}
```

---

## Sorting Algorithm

Users sorted by:
1. **Current room first**: Users in viewer's room appear first
2. **Room ID descending**: Higher room IDs first
3. **Last node time descending**: Most recent noders first
4. **Active days descending**: Most active users first (from `votesrefreshed` VARS)

```perl
@noderlist = sort {
  ($b->{roomId} == $current_room_id) <=> ($a->{roomId} == $current_room_id)
  || $b->{roomId} <=> $a->{roomId}
  || $b->{lastNodeTime} <=> $a->{lastNodeTime}
  || $b->{activeDays} <=> $a->{activeDays}
} @noderlist;
```

---

## Ignore List

- Users on viewer's ignore list are hidden
- Exception: Admins can see users they've ignored
- Source: `messageignore` table

---

## Room Features

### Room Options Panel
- **Cloaked checkbox**: Toggle visibility (if `canCloak`)
- **New Room button**: Create room (if `canCreateRoom` and not suspended)
- **Room dropdown**: Select destination room
- **Go button**: Change to selected room

### Room Suspension
Users can be locked in a room:
- `suspension.type === "temporary"`: Shows countdown
- `suspension.type !== "temporary"`: "Locked here indefinitely"

### Room Display
- Server always sends `rooms[].title`; the client shows room headers only when `rooms.length > 1`
- Room 0 is titled "Outside" in `rooms` and "outside" in `availableRooms`

---

## Database Schema

### room table
| Field | Purpose |
|-------|---------|
| `member_user` | User node ID |
| `room_id` | Room node ID (0 = outside) |
| `visible` | 0=visible, 1=invisible (cloaked) |
| `borgd` | User is borged |
| `experience` | Cached experience (for sorting) |

### User VARS
| Key | Purpose |
|-----|---------|
| `infravision` | Can see invisible users |
| `showuseractions` | Show random actions and recent noding |
| `hide_chatterbox_staff_symbol` | Hide own staff badge |
| `lastnoded` | Last writeup node_id |
| `votesrefreshed` | Active days (from last login) |
| `costume` | Halloween costume display string |

---

## Related Files

| File | Purpose |
|------|---------|
| `react/components/Nodelets/OtherUsers.js` | React component |
| `react/components/Nodelets/OtherUsers.test.js` | Component tests |
| `react/hooks/useOtherUsersPolling.js` | Polling hook |
| `ecore/Everything/Application.pm` | `buildOtherUsersData()` |
| `ecore/Everything/API/chatroom.pm` | Room API endpoints |

---

*Last verified: 2026-11-16*
