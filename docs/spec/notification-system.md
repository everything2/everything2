# Everything2 Notification System

**Last Updated**: 2026-01-17
**Status**: Active - Partially Migrated to Delegation Pattern
**Audit Status**: Reviewed with identified issues

## Executive Summary

Everything2's notification system provides user notifications for events like votes, comments, achievements, and content changes. The system has been **partially migrated** from dynamic code evaluation (`evalCode`) to a static delegation-based approach. This document covers the current architecture, identified issues, and remaining migration work.

## Architecture Overview

### Components

1. **Notification Nodes** - Template definitions in `nodepack/notification/*.xml`
2. **Notified Table** - Active notifications per user in database
3. **Delegation Module** - `Everything::Delegation::notification` with 23 rendering functions
4. **Rendering Engine** - `getRenderedNotifications()` in `Application.pm`
5. **Delivery System** - `add_notification()` in `Application.pm`
6. **API Endpoints** - `Everything::API::notifications` (get_all, dismiss)

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
   - Examples: voting, cooled, achievement, experience, gp, frontpage, favorite, bookmark

2. **Broadcast Notifications**: Available to all users subscribed to that notification type
   - `notified.user_id = notification_id` (the notification type's node ID)
   - Examples: nodenote, e2poll, draft_for_review, newbiewriteup, weblog, newdiscussion

### Complete List (23 Notification Types)

| Notification | Pattern | Target Audience | Description |
|--------------|---------|-----------------|-------------|
| achievement | Direct | Node author | User earned an achievement |
| author_removed_writeup | Direct | Node author | Author deleted their own writeup |
| blankedwriteup | Broadcast | Editors | A writeup was blanked |
| bookmark | Direct | Node author | Node was bookmarked by another user |
| chanop_borged_user | Broadcast | Chanops | A user was borged |
| chanop_dragged_user | Broadcast | Chanops | A user was dragged |
| cooled | Direct | Node author | Writeup was C!'d (cooled) |
| draft_for_review | Broadcast | Editors | Draft submitted for review |
| e2poll | Broadcast | All users | New poll created |
| editor_removed_writeup | Direct | Node author | Editor removed a writeup |
| experience | Direct | Target user | XP gained or lost |
| favorite | Direct | Node author | Node was favorited |
| frontpage | Direct | Node author | Content hit front page |
| gp | Direct | Target user | GP (Golden Peach) awarded |
| mostwanted | Direct | Request filler | Most Wanted request filled |
| newbiewriteup | Broadcast | Editors | New user published first writeup |
| newcomment | Direct | Discussion participants | Comment posted |
| newdiscussion | Broadcast | Usergroup members | New discussion started |
| nodenote | Broadcast | Editors | Node note posted |
| socialbookmark | Direct | Node author | Content shared externally |
| voting | Direct | Node author | Writeup voted on |
| weblog | Broadcast | Usergroup members | Weblog entry posted |
| writeupedit | Direct | Node author | Editor edited writeup |

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
- `ecore/Everything/Delegation/notification.pm` - 23 rendering functions
- `ecore/Everything/API/notifications.pm` - REST endpoints
- `react/components/Nodelets/Notifications.js` - UI component

### Rendering Flow (Application.pm:8243-8342)

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
**Called From**: `getRenderedNotifications()` in `Application.pm:8330`

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
| newcomment | ✓ | Node exists |
| newdiscussion | ✓ | Discussion node exists |
| nodenote | ✓ | Node exists AND nodenote record exists |
| socialbookmark | ✓ | Writeup node exists |
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

**Location**: `Application.pm:8274-8295`

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

**Problem**: Passes empty string `''` instead of `undef` for user_id. In `add_notification()`, line 3791:
```perl
$user_id ||= $notification_id;
```
The `||` operator treats `''` as false, so it defaults to `$notification_id` correctly. However, this is fragile.

**Recommendation**: Fix for consistency:
```perl
$APP->add_notification( 'e2poll', undef, { e2poll_id => $poll_id } );
```

### Issue #3: Legacy Code in XML Files

**Status**: 19 of 23 notification XML files still contain legacy `<code>` fields that are NO LONGER USED since `getRenderedNotifications()` now calls delegation functions directly.

**Already Empty (4 notifications)**:
- socialBookmark
- voting
- weblog
- writeupedit

**Still Have Legacy Code (19 notifications)**:
All other notifications still have code in XML that should be cleared for clarity.

**Action Required**: Clear `<code>` and `<invalid_check>` from XML files since delegation module handles rendering.

### Issue #4: Missing hourLimit Values (FIXED)

Two notification types had no `<hourLimit>` field in their XML:
- `voting` (node_id: 1961735)
- `writeupedit` (node_id: 1981770)

**Root Cause Analysis**: With `hourLimit = 0`, the SQL query's calculation:
```sql
(hourLimit * 3600 - $currentTime + UNIX_TIMESTAMP(notified.notified_time)) AS timeLimit
```
would immediately produce a negative value, causing the `HAVING (timeLimit > 0)` clause to filter out ALL notifications of these types.

**Fix Applied**: Added `<hourLimit>72</hourLimit>` to both XML files. The database also needed direct UPDATE since nodepack only affects new node creation:
```sql
UPDATE notification SET hourLimit = 72 WHERE notification_id IN (1961735, 1981770);
```

### Issue #5: Regex-Based Permission Checking (FRAGILE)

**Location**: `Application.pm:8234-8238`, `API/notifications.pm:127-131`

**Current Approach**:
```perl
return 0 if (!$isCE && ($$notification{description} =~ /node note/));
return 0 if (!$isCE && ($$notification{description} =~ /new user/));
```

**Problem**: Permission is based on regex matching against the description field. This is fragile.

**Recommendation**: Add explicit permission fields to notification table:
- `requires_editor` BOOLEAN
- `requires_chanop` BOOLEAN
- `requires_coder` BOOLEAN

## Test Coverage

### Existing Test Files

| File | Purpose | Coverage |
|------|---------|----------|
| `t/013_notification_rendering.t` | Tests all 23 delegation functions | Good - comprehensive |
| `t/040_notifications_api.t` | Tests dismiss endpoint | Good - permission checks |
| `t/049_notifications.t` | Tests broadcast/direct patterns + isolation | Good - comprehensive |

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

1. Created `Everything::Delegation::notification` with 23 rendering functions
2. Updated `getRenderedNotifications()` to use delegation instead of evalCode
3. Added comprehensive rendering tests in `t/013_notification_rendering.t`
4. Added friendly descriptions to Settings page
5. ~~**Add Missing hourLimit**: Set defaults for voting and writeupedit~~ ✓ DONE
6. ~~**Add Missing Tests**: Cross-user isolation and subscription filtering tests~~ ✓ DONE
7. ~~**Migrate invalid_check to is_valid functions**~~ ✓ DONE - 16 validity check functions added

### Remaining Work

1. **Clear Legacy XML Code**: Empty `<code>` and `<invalid_check>` from 19 XML files
2. **Fix polls.pm**: Change empty string to undef in add_notification call
3. **Add Permission Fields**: Replace regex-based permission with explicit boolean fields

### Future Enhancements

4. **Cleanup mechanism**: Invalid notifications remain in `notified` table forever. Consider a periodic job to purge notifications that have been invalid for X days.
5. **Bulk operations**: API only supports dismissing one notification at a time. Add "dismiss all" or "mark all as read" endpoint.
6. **Broadcast dismissal optimization**: Each broadcast dismissal creates a new row in `notified` with `reference_notified_id`. For high-traffic broadcasts, this could grow the table significantly. Consider alternative approaches.

## API Documentation

### `add_notification()`

**Location**: `Application.pm:3785`

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
# Direct notification to specific user
$APP->add_notification('voting', $author_id, { node_id => $writeup_id, weight => 1 });

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
| bookmark | 1931545 |
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
| socialBookmark | 1936586 |
| voting | 1961735 |
| weblog | 1930850 |
| writeupedit | 1981770 |

---

**Document Version**: 2.1
**Author**: System audit
**Last Updated**: 2026-01-17
**Next Review**: After remaining migration work complete
