# Everything2 Notification System

**Last verified**: 2026-11-16
**Status**: Active - rendering fully on `Everything::Delegation::notification`; many types have **no producer** (see table)
**Audit Status**: Reviewed with identified issues

## Executive Summary

Everything2's notification system provides user notifications for events like votes, comments, achievements, and content changes. The system has been **partially migrated** from dynamic code evaluation (`evalCode`) to a static delegation-based approach. This document covers the current architecture, identified issues, and remaining migration work.

## Architecture Overview

### Components

1. **Notification Nodes** - Template definitions in `nodepack/notification/*.xml`
2. **Notified Table** - Active notifications per user in database
3. **Delegation Module** - `Everything::Delegation::notification` with 22 rendering functions + 15 `*_is_valid` checks (`bookmark` is dormant; `socialbookmark` was deleted in #4332)
4. **Rendering Engine** - `getRenderedNotifications()` in `Application.pm`
5. **Delivery System** - `add_notification()` in `Application.pm`
6. **API Endpoints** - `Everything::API::notifications` (`GET /api/notifications/`, `POST /api/notifications/dismiss`)

### Data Flow

```
Event Occurs (vote, comment, etc.)
  |
add_notification(notification_id, user_id, args)
  |
sqlInsert into 'notified' table
  |
User requests notifications (via API or page load)
  |
getRenderedNotifications() retrieves from DB
  |
Delegation function renders notification text
  |
Return formatted notification data to React UI
```

## Notification Types

### Two Routing Patterns

The system uses two patterns for routing notifications:

1. **Direct Notifications**: Sent to a specific user
   - `notified.user_id = target_user_id`
   - Examples: achievement, favorite, newcomment, newdiscussion

2. **Broadcast Notifications**: Available to all users subscribed to that notification type
   - `notified.user_id = notification_id` (the notification type's node ID)
   - Examples: nodenote, e2poll, draft_for_review, newbiewriteup, blankedwriteup, editor/author_removed_writeup

### Complete List (22 notification nodes in `nodepack/notification/`)

The **Producer** column is the code that currently calls `add_notification` for the type (verified by grep 2026-11-16). Types marked **none** have a renderer, a nodepack node, and a Settings checkbox, but **nothing emits them** — subscribing does nothing. Most lost their producer when the legacy opcodes/evalCode were retired; `chanop_borged_user` was emitted by the borg path of the removed `message` opcode (#4332) and was not carried into `Application.pm`'s borg code.

| Notification | Pattern | Target Audience | Description | Producer |
|--------------|---------|-----------------|-------------|----------|
| achievement | Direct | Achiever | User earned an achievement | `Application` achievement check (opt-in) |
| author_removed_writeup | Broadcast | Editors | Author deleted their own writeup | `Application` writeup-removal path (`user_id` 0 → broadcast) |
| blankedwriteup | Broadcast | Editors | A writeup was blanked | `Delegation::maintenance::writeup_update` |
| bookmark | — | — | *(retired, #4292; CME private message sent instead by `API::cool::_notify_bookmark`)* | none |
| chanop_borged_user | Broadcast | Chanops | A user was borged | **none** |
| chanop_dragged_user | Broadcast | Chanops | A user was dragged | **none** |
| cooled | Direct | Node author | Writeup was C!'d | **none** (`API::cool` sends a Cool Man Eddie private message instead) |
| draft_for_review | Broadcast | Editors | Draft submitted for review | `Delegation::maintenance::draft_update`; `DataStash::neglecteddrafts` (re-notify on neglect) |
| e2poll | Broadcast | All users | New poll created | `API::polls` |
| editor_removed_writeup | Broadcast | Editors | Editor removed a writeup | `Application` writeup-removal path (`user_id` 0 → broadcast) |
| experience | Direct | Target user | XP gained or lost | **none** |
| favorite | Direct | Followers | Favorited author published | `Application::finalize_published_writeup` (opt-in) |
| frontpage | Direct | Node author | Content hit front page | **none** |
| gp | Direct | Target user | GP awarded | **none** |
| mostwanted | Direct | Request filler | Most Wanted request filled | **none** |
| newbiewriteup | Broadcast | Editors | New user published first writeup | `Application::finalize_published_writeup` |
| newcomment | Direct | Usergroup members | Reply posted in a usergroup discussion | `Application::notify_new_comment`, called from `API::debatecomments` (#4661) |
| newdiscussion | Direct | Usergroup members | New discussion started | `Application::notify_new_discussion` (opt-in) |
| nodenote | Broadcast | Editors | Node note posted | `API::nodenotes`, `Application::add_nodenote` |
| voting | Direct | Node author | Writeup voted on | **none** |
| weblog | Broadcast | Usergroup members | Weblog entry posted | **none** |
| writeupedit | Direct | Node author | Editor edited writeup | **none** |

## Database Schema

### `notification` Table

Stores notification type definitions:

| Column | Type | Purpose |
|--------|------|---------|
| `notification_id` | INT PRIMARY KEY | Unique notification type ID |
| `code` | MEDIUMTEXT | Legacy Perl code (being deprecated) |
| `hourLimit` | INT | Hours notification stays visible |
| `description` | MEDIUMTEXT | User-facing description |
| `invalid_check` | MEDIUMTEXT | Legacy validation code |

### `notified` Table

Stores active notification instances:

| Column | Type | Purpose |
|--------|------|---------|
| `notified_id` | INT PRIMARY KEY | Unique notification instance ID |
| `notification_id` | INT | Reference to notification type |
| `user_id` | INT | Target user ID or notification_id for broadcasts |
| `args` | TEXT (JSON) | Context data for notification |
| `notified_time` | DATETIME | When notification was created |
| `is_seen` | BOOLEAN | Whether user has dismissed it |
| `reference_notified_id` | INT | For broadcast dismissal tracking |

## Current Implementation

### Core Files

- `ecore/Everything/Application.pm` - `add_notification()`, `getRenderedNotifications()`, `_canseeNotification()`
- `ecore/Everything/Delegation/notification.pm` - 22 rendering functions + 15 validity checks
- `ecore/Everything/API/notifications.pm` - REST endpoints
- `react/components/Nodelets/Notifications.js` - UI component

### Rendering Flow (`Application::getRenderedNotifications`)

```perl
sub getRenderedNotifications {
  my ($this, $USER, $VARS) = @_;

  # 1. Get user's subscription list from VARS
  # 2. Filter by _canseeNotification() for permission
  # 3. Query database for unseen notifications
  # 4. For each notification:
  #    - Convert title to delegation function name
  #    - Call delegation function with args
  #    - Return structured data
}
```

## Validity Check Functions (is_valid)

Notifications can become invalid when the referenced content is deleted or modified. The delegation module includes `*_is_valid` functions that are called at display time to filter out stale notifications.

### Implementation

**Location**: `ecore/Everything/Delegation/notification.pm`
**Called From**: `getRenderedNotifications()` in `Application.pm`

```perl
my $validityCheck = Everything::Delegation::notification->can($notificationTitle . "_is_valid");
if ($validityCheck) {
    my $is_valid = $validityCheck->($this->{db}, $this, $args);
    next if !$is_valid;  # Skip invalid notifications
}
```

### Validity Functions by Notification Type

| Notification | Has is_valid | Validation Logic |
|--------------|--------------|------------------|
| blankedwriteup | ✓ | Node exists, not a draft, still blank (<20 chars) |
| bookmark | ✓ | Writeup node exists |
| cooled | ✓ | Writeup node exists |
| draft_for_review | ✓ | Draft exists and still pending review |
| e2poll | ✓ | Poll node exists |
| favorite | ✓ | Node exists and is a writeup type |
| frontpage | ✓ | Item not removed from News weblog |
| mostwanted | ✓ | Node exists |
| newbiewriteup | ✓ | Writeup exists, not a draft, not republished |
| newcomment | ✓ | Reply (`node_id`) exists |
| newdiscussion | ✓ | Discussion node exists |
| nodenote | ✓ | Node exists AND nodenote record exists |
| voting | ✓ | Node exists |
| weblog | ✓ | Writeup node exists |
| writeupedit | ✓ | Node exists |
| achievement | — | Always valid (achievements are permanent) |
| author_removed_writeup | — | Always valid (historical record) |
| chanop_borged_user | — | Always valid (audit record) |
| chanop_dragged_user | — | Always valid (audit record) |
| editor_removed_writeup | — | Always valid (historical record) |
| experience | — | Always valid (XP changes are permanent) |
| gp | — | Always valid (GP awards are permanent) |

### Return Values

- `1` = Notification is valid, show it
- `0` = Notification is invalid, filter it out

### Example: nodenote_is_valid

```perl
sub nodenote_is_valid {
    my ($DB, $APP, $args) = @_;

    # Check if the node still exists
    my $node = $DB->getNodeById($args->{node_id});
    return 0 unless $node;

    # Check if the nodenote still exists
    return 1 unless defined $args->{nodenote_id};

    my $note_exists = $DB->sqlSelect('1', 'nodenote',
        "nodenote_id = $args->{nodenote_id}");
    return $note_exists ? 1 : 0;
}
```

## Identified Issues

### Issue #1: Broadcast Notification Query Logic (ANALYZED - NO BUG)

**Location**: `Application::getRenderedNotifications`

**Description**: The SQL query that fetches notifications uses an OR condition:

```sql
WHERE (
  notified.user_id = $$USER{user_id}       -- Direct notifications for this user
  AND notified.is_seen = 0
) OR (
  notified.user_id IN ($otherNotifications)  -- Broadcast notifications
  AND reference.is_seen IS NULL
)
```

**Analysis**: This query is correct. The `$otherNotifications` variable contains notification TYPE IDs that the user is subscribed to. When a broadcast notification is created with `user_id = notification_id`, only users who have that notification_id in their subscription list will see it.

**The reference table logic**: The LEFT JOIN with `reference` table and check for `reference.is_seen IS NULL` correctly filters out broadcasts that THIS user has already dismissed.

**User Reports**: If users report seeing notifications for things "not theirs", it's likely due to:
1. Being subscribed to a broadcast notification type (like nodenote for editors)
2. Misunderstanding that broadcast notifications are SUPPOSED to be shared among subscribers

### Issue #2: Empty String in Polls Notification (MINOR BUG)

**Location**: `ecore/Everything/API/polls.pm:227`

**Current Code**:
```perl
$APP->add_notification( 'e2poll', '', { e2poll_id => $poll_id } );
```

**Status**: Still present as of 2026-11-16.

**Problem**: Passes empty string `''` instead of `undef` for user_id. In `add_notification()`:
```perl
$user_id ||= $notification_id;
```
The `||` operator treats `''` as false, so it defaults to `$notification_id` correctly. However, this is fragile.

**Recommendation**: Fix for consistency:
```perl
$APP->add_notification( 'e2poll', undef, { e2poll_id => $poll_id } );
```

### Issue #3: Legacy Code in XML Files

**Status**: 19 of 22 notification XML files still contain legacy `<code>` fields that are NO LONGER USED since `getRenderedNotifications()` now calls delegation functions directly.

**Already Empty (3 notifications)**:
- voting
- weblog
- writeupedit

(`socialbookmark.xml` was deleted in #4332.)

**Still Have Legacy Code (19 notifications)**:
All other notifications still have code in XML that should be cleared for clarity.

**Action Required**: Clear `<code>` and `<invalid_check>` from XML files since delegation module handles rendering.

### Issue #4: Missing hourLimit Values (FIXED in nodepack/dev; moot without producers)

Two notification types had no `<hourLimit>` field in their XML:
- `voting` (node_id: 1961735)
- `writeupedit` (node_id: 1981770)

**Root Cause Analysis**: With `hourLimit = 0`, the SQL query's calculation:
```sql
(hourLimit * 3600 - $currentTime + UNIX_TIMESTAMP(notified.notified_time)) AS timeLimit
```
would immediately produce a negative value, causing the `HAVING (timeLimit > 0)` clause to filter out ALL notifications of these types.

**Fix Applied** (2026-06, #4194 area): `nodepack/notification/voting.xml` and `writeupedit.xml` now carry `<hourLimit>48</hourLimit>` (dev DB confirms 48). Prod needs a direct `UPDATE notification SET hourLimit = 48 WHERE notification_id IN (1961735, 1981770);` since nodepack only affects new node creation — that prod step was recorded as pending; verify with the readonly query Lambda.

**However:** no code currently emits `voting` or `writeupedit` notifications (see the Producer column above), so even with a sane `hourLimit` these two types never appear. Re-enabling them needs producers in the vote path (`Everything::API::vote` / `Application::castVote`) and the editor writeup-edit path.

### Issue #5: Regex-Based Permission Checking (FRAGILE)

**Location**: `Application::_canseeNotification`, `Everything::API::notifications`

**Current Approach**:
```perl
return 0 if (!$isCE && ($$notification{description} =~ /node note/));
return 0 if (!$isCE && ($$notification{description} =~ /new user/));
return 0 if (!$isCE && ($$notification{description} =~ /(?:blanks|removes) a writeup/));
return 0 if (!$isCE && ($$notification{description} =~ /review of a draft/));
return 0 if (!$isChanop && ($$notification{description} =~ /chanop/));
```

**Problem**: Permission is based on regex matching against the description field. This is fragile.

**Recommendation**: Add explicit permission fields to notification table:
- `requires_editor` BOOLEAN
- `requires_chanop` BOOLEAN
- `requires_coder` BOOLEAN

### Issue #6: newcomment was never delivered (FIXED, #4661)

The `debatecomment_create` maintenance hook read members' notification prefs into a hash from a hashref (never matched) and wrote args (`parent`/`reply`/`root`) the renderer and validity check don't read. The producer is now `Application::notify_new_comment`, called from `API::debatecomments` after a reply is created, with args `{ node_id => reply, uid => replier, root => discussion }`; the renderer shows "[replier] replied in [discussion]". Tested in `t/225_notify_new_comment.t`.

## Test Coverage

### Existing Test Files

| File | Purpose | Coverage |
|------|---------|----------|
| `t/013_notification_rendering.t` | Tests the delegation render functions | Good - comprehensive |
| `t/040_notifications_api.t` | Tests dismiss endpoint | Good - permission checks |
| `t/049_notifications.t` | Tests broadcast/direct patterns + isolation | Good - comprehensive |
| `t/044_message_block_notifications.t` | Message-block interaction | |
| `t/058_notification_preferences_isolation.t` | Per-user preference isolation | |
| `t/111_notified_notified_time.t` | `notified_time` handling (MySQL 8.4) | |
| `t/149_bookmark_notify.t` | CME bookmark messages (cool API) | |
| `t/164_notify_new_discussion.t` | `notify_new_discussion` | |

### Cross-User Isolation Tests (ADDED)

The following tests were added to `t/049_notifications.t`:

1. **Direct notification isolation**: User A cannot see User B's direct notifications
2. **Broadcast subscription filtering**: Only subscribed users see broadcast notifications
3. **Editor-only permissions**: Non-editors cannot see editor-only notifications even when subscribed
4. **Independent dismissal**: Dismissing a broadcast for one user doesn't affect others
5. **Direct notification dismiss isolation**: Separate direct notifications remain independent

All 5 isolation tests pass, confirming the notification routing logic is correct.

### Validity Check Tests (ADDED)

The following tests verify that invalid notifications are filtered at display time:

1. **Voting for deleted node**: Notification is filtered when writeup no longer exists
2. **Nodenote for deleted note**: Notification is filtered when note record is deleted
3. **Valid notification shown**: Confirms notifications for existing content ARE displayed

All validity check tests pass in `t/049_notifications.t`.

## Settings Page Integration

### Friendly Descriptions

The Settings page now displays user-friendly descriptions for each notification type:

**Data Source**: `notification.description` field from database
**Display Format**: "Notify me when [description]"
**Bracket Link Cleanup**: Links like `[XP]` are stripped for plain text display

### UI Components

- `react/components/Documents/Settings.js` - Notifications tab
- `www/css/1973976.css` - `.settings-notification-label`, `.settings-notification-desc`

## Migration Status

### Completed

1. Created `Everything::Delegation::notification` (now 22 rendering functions after socialbookmark removal)
2. Updated `getRenderedNotifications()` to use delegation instead of evalCode
3. Added comprehensive rendering tests in `t/013_notification_rendering.t`
4. Added friendly descriptions to Settings page
5. ~~**Add Missing hourLimit**: Set defaults for voting and writeupedit~~ ✓ DONE
6. ~~**Add Missing Tests**: Cross-user isolation and subscription filtering tests~~ ✓ DONE
7. ~~**Migrate invalid_check to is_valid functions**~~ ✓ DONE - 15 validity check functions (socialbookmark's removed in #4332)
8. ~~**Restore producers lost in API migrations**~~ partially: favorite + newbiewriteup (#4314), newdiscussion (`notify_new_discussion`)

### Remaining Work

0. **Restore or retire producer-less types**: voting, writeupedit, cooled, experience, gp, frontpage, mostwanted, weblog, chanop_borged_user, chanop_dragged_user (see table)
1. **Clear Legacy XML Code**: Empty `<code>` and `<invalid_check>` from 19 XML files
2. **Fix polls.pm**: Change empty string to undef in add_notification call
3. **Add Permission Fields**: Replace regex-based permission with explicit boolean fields

### Future Enhancements

4. **Cleanup mechanism**: Invalid notifications remain in `notified` table forever. Consider a periodic job to purge notifications that have been invalid for X days.
5. **Bulk operations**: API only supports dismissing one notification at a time. Add "dismiss all" or "mark all as read" endpoint.
6. **Broadcast dismissal optimization**: Each broadcast dismissal creates a new row in `notified` with `reference_notified_id`. For high-traffic broadcasts, this could grow the table significantly. Consider alternative approaches.

## API Documentation

### `add_notification()`

**Location**: `Application::add_notification`

**Signature**:
```perl
$APP->add_notification($notification_id, $user_id, $args);
```

**Parameters**:
- `$notification_id`: Notification node ID or title string
- `$user_id`: Target user ID, or undef for broadcast (defaults to notification_id)
- `$args`: Hashref of context data

**Examples**:
```perl
# Direct notification to specific user (illustrative; see Producer column for real callers)
$APP->add_notification('achievement', $user_id, { achievement_id => $ach_id });

# Broadcast notification to all subscribers
$APP->add_notification('e2poll', undef, { e2poll_id => $poll_id });
```

### `/api/notifications` Endpoints

**GET `/api/notifications/`**
Returns all unseen notifications for current user.

**POST `/api/notifications/dismiss`**
Dismisses a notification.
- Body: `{ "notified_id": 12345 }`
- Direct notifications: marks as seen
- Broadcast notifications: creates reference record to hide from this user

## Appendix: Notification Node IDs

| Notification | Node ID |
|--------------|---------|
| achievement | 1931728 |
| author removed writeup | 2047531 |
| blankedwriteup | 2027665 |
| bookmark | 1931545 | *(retired — type no longer emitted, #4292)* |
| chanop borged user | 2054468 |
| chanop dragged user | 2054467 |
| cooled | 1930720 |
| draft for review | 2045486 |
| e2poll | 1930854 |
| editor removed writeup | 2047070 |
| experience | 1930852 |
| favorite | 1930837 |
| frontpage | 1930853 |
| gp | 1959540 |
| mostwanted | 1935408 |
| newbiewriteup | 2016463 |
| newcomment | 1930993 |
| newdiscussion | 1980269 |
| nodenote | 1930989 |
| socialBookmark | 1936586 | *(deleted, #4332)* |
| voting | 1961735 |
| weblog | 1930850 |
| writeupedit | 1981770 |

---

**Document Version**: 2.2
**Author**: System audit
**Last verified**: 2026-11-16 (producer audit added; socialbookmark removed; hourLimit 48; newcomment fixed #4661)
**Next Review**: After remaining migration work complete
