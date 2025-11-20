# Everything2 Notification System

**Last Updated**: 2025-11-20
**Status**: Active (uses evalCode - scheduled for migration)

## Executive Summary

Everything2's notification system provides real-time user notifications for events like votes, comments, achievements, and content changes. The system uses **dynamic code evaluation** (`evalCode`) to render notification messages, which needs to be migrated to a delegation-based approach for security and maintainability.

## Architecture Overview

### Components

1. **Notification Nodes** - Template definitions in `nodepack/notification/*.xml`
2. **Notified Table** - Active notifications per user in database
3. **Rendering Engine** - Dynamic code execution in `notificationsJSON()` function
4. **Delivery System** - `addNotification()` / `add_notification()` functions

### Data Flow

```
Event Occurs (vote, comment, etc.)
  ↓
addNotification(notification_id, user_id, args)
  ↓
sqlInsert into 'notified' table
  ↓
User requests notifications
  ↓
notificationsJSON() retrieves from DB
  ↓
evalCode() dynamically creates subroutine from {code} field
  ↓
Execute subroutine with $args
  ↓
Return formatted HTML notification
```

## Notification Node Structure

### XML Schema

Each notification is a node with type `notification` (type_nodetype: 1930710):

```xml
<node>
  <code>Perl code that generates display text</code>
  <invalid_check>Optional: Perl code to check if still valid</invalid_check>
  <hourLimit>72</hourLimit>
  <description>Human-readable description</description>
  <node_id>1931728</node_id>
  <title>achievement</title>
  <type_nodetype>1930710</type_nodetype>
</node>
```

### Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `code` | Perl code | Generates notification HTML | `return "Someone upvoted ".linkNode($$args{node_id});` |
| `invalid_check` | Perl code | Validates notification is still relevant | `return !getNodeById($$args{node_id});` |
| `hourLimit` | Integer | Hours notification stays visible | `72` |
| `description` | String | What triggers this notification | "a writeup of yours gets voted on" |

### Code Execution Context

The `code` and `invalid_check` fields are executed with access to:

```perl
my $args = {
  # Context-specific data passed when notification was created
  node_id => 12345,
  user_id => 67890,
  # ... other event-specific data
};
```

## Current Implementation

### Location: `htmlcode.pm:11245-11357`

### Function: `notificationsJSON()`

**Purpose**: Retrieves and renders notifications for a user

**Process**:

1. **Query Database** - Get unseen notifications for user
2. **Load Notification Templates** - Fetch notification node by ID
3. **Dynamic Subroutine Creation** - Use evalCode to create rendering function
4. **Invalid Check** - Optionally validate notification is still relevant
5. **Render** - Execute code with args, format output
6. **Return** - JSON-compatible hash of rendered notifications

### Key Code Section (Lines 11325-11330):

```perl
my $evalNotify = sub {
  my $notifyCode = shift;
  my $wrappedNotifyCode = "sub { my \$args = shift; 0; $notifyCode };";
  my $wrappedSub = evalCode($wrappedNotifyCode);
  return &$wrappedSub($args);
};
```

**What This Does**:
1. Takes notification code as string
2. Wraps it in a subroutine definition with `$args` parameter
3. Uses `evalCode()` to compile string into executable subroutine
4. Executes compiled subroutine with notification arguments
5. Returns result (rendered HTML string or validation boolean)

### Usage Pattern:

```perl
# Display code execution:
my $html = &$evalNotify($notification->{code});

# Invalid check execution:
if ($invalidCheckCode ne '' && &$evalNotify($invalidCheckCode)) {
  # Notification is invalid, delete it
  $DB->sqlDelete('notified', 'notified_id = ' . int($$notify{notified_id}));
}
```

## Database Schema

### `notified` Table

Stores active notifications for users:

| Column | Type | Purpose |
|--------|------|---------|
| `notified_id` | INT PRIMARY KEY | Unique notification instance ID |
| `notification_id` | INT | Reference to notification node |
| `user_id` | INT | User receiving notification |
| `args` | TEXT (JSON) | Context data for notification |
| `notified_time` | DATETIME | When notification was created |
| `is_seen` | BOOLEAN | Whether user has seen it |
| `reference_notified_id` | INT | For notification sharing/referencing |

### Example Data:

```sql
notified_id: 12345
notification_id: 1961735  -- "voting" notification
user_id: 67890
args: {"node_id": 98765, "weight": 1, "amount": 1}
notified_time: 2025-11-20 14:30:00
is_seen: 0
```

## Notification Types (23 Total)

### Complete List:

| Notification | Description | Key Args |
|--------------|-------------|----------|
| **achievement** | User earned achievement | `achievement_id` |
| **author_removed_writeup** | Author deleted own writeup | `node_id`, `title` |
| **blankedwriteup** | Writeup was blanked | `node_id`, `title` |
| **bookmark** | Node was bookmarked | `node_id` |
| **chanop_borged_user** | User was borged by chanop | `user_id` |
| **chanop_dragged_user** | User was dragged by chanop | `user_id` |
| **cooled** | Writeup was cooled | `node_id` |
| **draft_for_review** | Draft submitted for review | `node_id` |
| **e2poll** | E2 poll created | `node_id` |
| **editor_removed_writeup** | Editor deleted writeup | `node_id`, `title`, `author` |
| **experience** | Experience points changed | `amount` |
| **favorite** | Node was favorited | `node_id` |
| **frontpage** | Writeup hit front page | `node_id` |
| **gp** | GP (Golden Peach) awarded | `amount` |
| **mostwanted** | Writeup on most wanted list | `node_id` |
| **newbiewriteup** | New user's first writeup | `node_id`, `author` |
| **newcomment** | Comment on user's writeup | `node_id`, `comment_id` |
| **newdiscussion** | New discussion post | `node_id` |
| **nodenote** | Node note added (editors) | `node_id`, `note` |
| **socialbookmark** | Social bookmark shared | `node_id`, `service` |
| **voting** | Writeup voted on | `node_id`, `weight`, `amount` |
| **weblog** | Weblog entry posted | `node_id` |
| **writeupedit** | Writeup was edited | `node_id`, `author` |

### Example Notification Definitions:

#### Achievement Notification

```xml
<code>return "You earned the ".getNodeById($$args{achievement_id})->{display}." achievement!";</code>
<invalid_check></invalid_check>
<hourLimit>72</hourLimit>
```

**Rendered Output**: "You earned the Cooled 50 achievement!"

#### Voting Notification

```xml
<code>my $str;
if ($$args{weight} > 0) {
  $str .= "Someone upvoted ";
}
else {
  $str .= "Someone downvoted ";
  $$args{amount} = -1 * $$args{amount};
}

if ($$args{node_id}) {
  $str .= linkNode($$args{node_id});
}
return $str;</code>
```

**Rendered Output**: "Someone upvoted [My Great Writeup]"

## Security Concerns

### Current Issues

1. **Arbitrary Code Execution**: `evalCode()` executes arbitrary Perl from database
2. **No Sandboxing**: Code runs with full application privileges
3. **Injection Risk**: Malicious notification code could compromise system
4. **No Validation**: Code is not validated before execution
5. **Profiling Blind Spot**: Cannot profile performance of eval'd code

### Access Control

**Mitigations**:
- Only admins can create/modify notification nodes
- Notifications stored in controlled XML files, not editable via web
- Code review required for notification changes

**Remaining Risk**: High - eval() of any code is inherently dangerous

## Migration Plan

### Target Architecture: Delegation Pattern

Similar to achievements, migrate to `Everything::Delegation::notification`:

```perl
package Everything::Delegation::notification;

sub achievement {
  my ($DB, $APP, $args) = @_;

  my $achievement = getNodeById($args->{achievement_id});
  return "You earned the " . $achievement->{display} . " achievement!";
}

sub voting {
  my ($DB, $APP, $args) = @_;

  my $str = $args->{weight} > 0 ? "Someone upvoted " : "Someone downvoted ";
  $str .= linkNode($args->{node_id}) if $args->{node_id};
  return $str;
}

# ... 21 more notification functions
```

### Migration Steps

**Phase 1: Create Delegation Module (Week 1)**
1. Create `Everything::Delegation::notification` module
2. Define function signature: `sub notification_name { my ($DB, $APP, $args) = @_; ... }`
3. Add boilerplate and documentation

**Phase 2: Migrate Notification Code (Week 1-2)**

For each of 23 notifications:
1. Extract code from XML `<code>` field
2. Convert to static Perl function in delegation module
3. Test with sample args
4. Verify output matches original

**Phase 3: Update Rendering Logic (Week 2)**

In `notificationsJSON()` function:
1. Replace evalCode with delegation lookup
2. Add error handling for missing delegations
3. Keep same function signature and return format

**Example**:

```perl
# BEFORE (line 11325-11330):
my $evalNotify = sub {
  my $notifyCode = shift;
  my $wrappedNotifyCode = "sub { my \$args = shift; 0; $notifyCode };";
  my $wrappedSub = evalCode($wrappedNotifyCode);
  return &$wrappedSub($args);
};

# AFTER:
my $renderNotification = sub {
  my $notificationTitle = $notification->{title};
  $notificationTitle =~ s/[\s-]/_/g;
  $notificationTitle = lc($notificationTitle);

  if (my $delegation = Everything::Delegation::notification->can($notificationTitle)) {
    return $delegation->($DB, $APP, $args);
  } else {
    $APP->devLog("ERROR: Notification '$notification->{title}' has no delegation");
    return "Notification error";
  }
};
```

**Phase 4: Migrate Invalid Checks (Week 2)**

Similar process for `invalid_check` field:
1. Most are empty (don't need migration)
2. Non-empty ones become separate validation functions
3. Or inline validation in main delegation function

**Phase 5: Testing (Week 2-3)**

1. Test each notification type with sample data
2. Verify HTML output matches original
3. Test invalid checks
4. Ensure notifications display correctly in UI
5. Performance testing

**Phase 6: Cleanup (Week 3)**

1. Remove evalCode calls from `notificationsJSON()`
2. Empty `<code>` and `<invalid_check>` fields in XML
3. Update documentation
4. Deploy to production

### Effort Estimate

- **Total Time**: 2-3 weeks
- **Complexity**: Medium (23 notifications, straightforward conversion)
- **Risk**: Medium-Low (isolated to notification system, good test coverage possible)

## Testing Strategy

### Unit Tests

Test each delegation function:

```perl
# t/notification_delegations.t
use Test::More;
use Everything::Delegation::notification;

my $mock_db = ...;
my $mock_app = ...;

# Test achievement notification
my $result = Everything::Delegation::notification::achievement(
  $mock_db,
  $mock_app,
  { achievement_id => 12345 }
);
like($result, qr/You earned the .* achievement!/, 'Achievement notification renders');

# Test voting notification
my $result = Everything::Delegation::notification::voting(
  $mock_db,
  $mock_app,
  { node_id => 67890, weight => 1 }
);
like($result, qr/Someone upvoted/, 'Upvote notification renders');
```

### Integration Tests

Test full notification flow:
1. Trigger event (e.g., cast vote)
2. Verify notification added to database
3. Retrieve via `notificationsJSON()`
4. Verify correct rendering

### Comparison Tests

During migration, run both old and new systems in parallel:
1. Execute evalCode version
2. Execute delegation version
3. Compare output
4. Flag any differences

## API Documentation

### `addNotification()`

**Location**: `htmlcode.pm:10098`, delegates to `Application.pm:3615`

**Signature**:
```perl
addNotification($notification_id, $user_id, $args)
```

**Parameters**:
- `$notification_id`: Notification node ID or title
- `$user_id`: User receiving notification (optional, defaults to current user)
- `$args`: Context data (hashref or JSON string)

**Example**:
```perl
htmlcode('addNotification', 'voting', $author_id, {
  node_id => $writeup_id,
  weight => 1,
  amount => 1
});
```

### `notificationsJSON()`

**Location**: `htmlcode.pm:11245-11357`

**Signature**:
```perl
notificationsJSON($wrap)
```

**Parameters**:
- `$wrap`: Boolean - wrap in `<li>` tags with dismiss button

**Returns**:
```perl
{
  1 => { id => 12345, value => "HTML notification", timestamp => 1234567890 },
  2 => { id => 12346, value => "HTML notification", timestamp => 1234567891 },
  ...
}
```

### `canseeNotification()`

**Location**: `htmlcode.pm:11525`

**Purpose**: Check if user can see a specific notification type

**Example**: Node notes only visible to editors

## Performance Characteristics

### Current System

- **Query Cost**: Single complex JOIN per request
- **Eval Cost**: 1-2 evalCode calls per notification (code + invalid_check)
- **Total**: ~10-20 evalCode calls for typical 10 notifications

### Expected After Migration

- **Query Cost**: Same (no change)
- **Function Call Cost**: Direct function calls (fast)
- **Total**: 50-100x faster rendering (no eval overhead)

## Dependencies

### Required Modules

Current:
- `Everything::HTML::evalCode`
- `Everything::HTML::parseLinks`
- `JSON` for args serialization

After migration:
- `Everything::Delegation::notification`
- `Everything::HTML::parseLinks` (keep for link rendering)

## Related Systems

1. **Achievement System** - Triggers achievement notifications
2. **Voting System** - Triggers voting notifications
3. **Comment System** - Triggers newcomment notifications
4. **Content Management** - Triggers various content notifications

## Historical Context

The notification system was designed when:
- All E2 code lived in the database
- Dynamic code execution was the standard pattern
- Security model relied on admin-only access control
- Modern delegation pattern didn't exist

The migration to delegations represents modernization while maintaining functionality.

## Future Enhancements

After migration:

1. **Rich Notifications**: Add HTML5 notification API support
2. **Real-time Updates**: WebSocket push notifications
3. **Notification Grouping**: "3 people upvoted your writeup"
4. **User Preferences**: More granular notification controls
5. **Mobile Support**: Push notifications for mobile app

## Appendix A: Full Notification List

### All 23 Notifications

1. `achievement` - User earned achievement
2. `author_removed_writeup` - Author deleted writeup
3. `blankedwriteup` - Writeup blanked
4. `bookmark` - Node bookmarked
5. `chanop_borged_user` - User borged
6. `chanop_dragged_user` - User dragged
7. `cooled` - Writeup cooled
8. `draft_for_review` - Draft review requested
9. `e2poll` - Poll created
10. `editor_removed_writeup` - Editor deleted writeup
11. `experience` - XP changed
12. `favorite` - Node favorited
13. `frontpage` - Hit front page
14. `gp` - GP awarded
15. `mostwanted` - On most wanted list
16. `newbiewriteup` - Newbie's first writeup
17. `newcomment` - Comment posted
18. `newdiscussion` - Discussion post
19. `nodenote` - Node note (editors only)
20. `socialbookmark` - Social bookmark
21. `voting` - Vote cast
22. `weblog` - Weblog entry
23. `writeupedit` - Writeup edited

## Appendix B: Example Args by Notification Type

### Achievement
```json
{"achievement_id": 1234567}
```

### Voting
```json
{"node_id": 1234567, "weight": 1, "amount": 1}
```

### Comment
```json
{"node_id": 1234567, "comment_id": 7654321}
```

### Editor Removed Writeup
```json
{"node_id": 1234567, "title": "My Writeup", "author": "username"}
```

---

**Document Version**: 1.0
**Author**: System analysis / migration planning
**Next Review**: After delegation migration complete
