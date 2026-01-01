# XP Recalculation System Specification

## Overview

The XP Recalculation system was created in October 2008 to migrate users from the old XP calculation method to a new system. It allows legacy users (who joined before October 29, 2008) to convert their XP to the new formula, with any excess XP converted to GP as a one-time bonus.

## Related Documents

| Document | Type | Purpose |
|----------|------|---------|
| Recalculate XP | Superdoc | User-facing tool to perform XP recalculation |
| Recalculated Users | Oppressor Superdoc | Admin view listing all users who have recalculated |

## Key Data Points

### Magic Numbers

- **Node ID 1960662**: Users with `user_id` greater than this joined after October 29, 2008 and don't need recalculation
- **Node ID 1959368**: The Recalculate XP superdoc node
- **Node ID 1960696**: The Recalculated Users oppressor superdoc node

### XP Formula Constants

```
Writeup Bonus: 5 XP per writeup
Cool Bonus: 20 XP per C! received
```

### New XP Calculation Formula

```
newXP = (writeupCount * 5)
      + (upvotes + upcache + heavenTotalReputation)
      + ((coolCount + coolcache + NodeHeavenCoolCount) * 20)
```

Where:
- `writeupCount` = Total active writeups by user
- `upvotes` = Upvotes received on current drafts
- `upcache` = Cached upvotes from deleted content (from `xpHistoryCache`)
- `heavenTotalReputation` = Sum of reputation from Node Heaven writeups
- `coolCount` = C!s on current content
- `coolcache` = Cached C!s from deleted content (from `xpHistoryCache`)
- `NodeHeavenCoolCount` = C!s on content in Node Heaven

## Database Tables

### `xpHistoryCache`

Stores cached voting history for users who haven't recalculated yet:

| Column | Type | Description |
|--------|------|-------------|
| `xpHistoryCache_id` | int | User ID (FK to user) |
| `upvotes` | int | Accumulated upvotes from deleted content |
| `cools` | int | Accumulated C!s from deleted content |

This table is:
- **Updated** when drafts are deleted (via `draft_delete` maintenance function)
- **Deleted** when user recalculates their XP (entry removed after recalculation)
- **Only populated** for users with `user_id < 1960662` (joined before Oct 29, 2008)

### `user` table fields

| Field | Description |
|-------|-------------|
| `experience` | Current XP total |
| `GP` | Current GP total |

### `setting` table (user vars)

| Variable | Description |
|----------|-------------|
| `hasRecalculated` | Set to 1 after user recalculates (prevents re-running) |

## Access Control

### Recalculate XP (superdoc)

- **Available to**: Users who joined before October 29, 2008
- **Restricted if**: `hasRecalculated` var is already set to 1
- **Admin override**: Gods can recalculate any user's XP via the `targetUser` field

### Recalculated Users (oppressor_superdoc)

- **Available to**: Editors only (oppressor_superdoc type)
- **Purpose**: Audit trail of who has recalculated

## Workflow

### User Flow

1. User visits Recalculate XP page
2. System checks eligibility:
   - Must have joined before Oct 29, 2008 (`user_id <= 1960662`)
   - Must not have `hasRecalculated = 1` in vars
3. System displays:
   - Current XP
   - Writeup count
   - Upvotes received
   - C!s received
   - Calculated new XP
   - Bonus GP (if current XP > new XP)
4. User confirms with checkbox
5. System:
   - Logs the action to security log
   - Adjusts XP: `adjustExp($user, -currentXP)` then `adjustExp($user, newXP)`
   - Sets `hasRecalculated = 1`
   - Deletes user's `xpHistoryCache` entry
   - If bonus: Adds `(oldXP - newXP)` to user's GP

### Admin Flow

Gods can recalculate other users by:
1. Entering username in "Target user" field
2. System looks up user and displays their stats
3. Confirmation and recalculation proceeds as normal

## Maintenance Integration

### `draft_delete` function

When a draft/writeup is deleted, the `draft_delete` maintenance function:

1. Checks if author joined before Oct 29, 2008
2. If so, retrieves current `xpHistoryCache` for that user
3. Calculates upvotes from the deleted content
4. Updates `xpHistoryCache` with accumulated totals

This ensures that even deleted content's votes count toward the recalculation.

## SQL Queries Used

### Get users who have recalculated

```sql
SELECT user.user_id, user.experience
FROM setting, user
WHERE setting.setting_id = user.user_id
AND setting.vars LIKE '%hasRecalculated=1%'
```

### Get writeup count

```sql
SELECT COUNT(*)
FROM node, writeup
WHERE node.node_id = writeup.writeup_id
AND node.author_user = $uid
```

### Get upvotes on drafts

```sql
SELECT COUNT(vote_id) FROM vote WHERE weight > 0 AND vote_id = ?
```

### Get Node Heaven reputation total

```sql
SELECT SUM(heaven.reputation) AS totalReputation
FROM heaven
WHERE heaven.type_nodetype = 117
AND heaven.author_user = $uid
```

### Get cool count

```sql
SELECT COUNT(*)
FROM node
JOIN coolwriteups ON node_id = coolwriteups_id
WHERE node.author_user = $uid
```

### Get Node Heaven cool count

```sql
SELECT COUNT(*)
FROM coolwriteups, heaven
WHERE coolwriteups_id = node_id
AND author_user = $uid
```

## Security Considerations

- All recalculations are logged via `$APP->securityLog()`
- Users can only recalculate once (`hasRecalculated` flag)
- Confirmation checkbox required before execution
- Gods have override capability for admin purposes

## Current Status

This feature is essentially **frozen functionality** - it was designed for a one-time migration in 2008. The system still works but:

- New users (post-2008) cannot use it
- Most legacy users have likely already recalculated
- The `xpHistoryCache` maintenance continues for remaining legacy users

## Migration Notes

When migrating to React:

1. **Recalculate XP** (superdoc): Could be migrated, but low usage
2. **Recalculated Users** (oppressor_superdoc): Simple list view, easy migration

Key considerations:
- Preserve all eligibility checks
- Maintain security logging
- Keep the confirmation workflow
- The `xpHistoryCache` logic in `draft_delete` should remain in Perl

---

*Last updated: December 31, 2025*
