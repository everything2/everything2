# Favorite Noders System Specification

**Last verified**: 2026-11-16

## Overview

The Favorite Noders system allows users to follow other users ("noders") and see their recent writeups in a dedicated nodelet. This is distinct from the "unfavorite" system which hides writeups from users.

**Terminology clarification:**
- **Favorite** = Follow a user to see their writeups in the Favorite Noders nodelet
- **Unfavorite** = Hide a user's writeups from the New Writeups nodelet (confusingly named)

## Current Implementation

### Database Schema

#### `links` Table
Primary storage for favorite relationships.

```sql
CREATE TABLE `links` (
  `from_node` int NOT NULL DEFAULT '0',    -- User who is favoriting
  `to_node` int NOT NULL DEFAULT '0',      -- User being favorited
  `linktype` int NOT NULL DEFAULT '0',     -- Type of link (favorite = 1930912)
  `hits` int NOT NULL DEFAULT '0',         -- Unused for favorites
  `food` int DEFAULT '0',                  -- Unused for favorites
  PRIMARY KEY (`from_node`,`to_node`,`linktype`),
  KEY `to_node` (`to_node`),
  KEY `linktype_fromnode_hits` (`linktype`,`from_node`,`hits`),
  KEY `from_node` (`from_node`)
)
```

#### `linktype` Node
- **Node ID:** `1930912`
- **Title:** `favorite`
- **Type:** `linktype` (nodetype 169632)

#### Related User Settings (VARS)
- `favorite_limit` - Legacy VARS key; **no longer read by any code** (the nodelet query is hard-capped at 5)
- `unfavoriteusers` - CSV of user IDs whose writeups to hide from New Writeups

### Data Flow

```
User Profile Page (React UserDisplay star button)
  or Settings → FavoriteUsersManager
       │
       ▼
POST /api/favorites/:id/action/favorite   (or .../unfavorite)
       │
       ▼
Everything::API::favorites
       │
       ▼
links table INSERT/DELETE
       │
       ▼
Application::buildNodeInfoStructure (on page load, gate 1876005 + non-guest)
       │
       ▼
Everything::PageState::_build_favoriteWriteups — queries links table (LIMIT 5)
       │
       ▼
FavoriteNoders React component
```

### Backend Components

#### 1. Favorites API
**Location:** `ecore/Everything/API/favorites.pm`

The favorite/unfavorite **opcodes** and the `favorite_noder` **htmlcode** were removed (June 2026). Following/unfollowing is now a REST API:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/favorites/` | GET | List users the current user has favorited |
| `/api/favorites/:id` | GET | Favorite status for a specific user (`is_favorited`) |
| `/api/favorites/:id/action/favorite` | POST | Favorite (follow) a user |
| `/api/favorites/:id/action/unfavorite` | POST | Unfavorite (unfollow) a user |

```perl
sub favorite {
  # Inserts link: from_node=USER, to_node=:id, linktype=favorite
  $self->DB->sqlInsert('links', {
    -from_node => $user_id,
    -to_node   => $target_id,
    -linktype  => $linktype_id
  });
}
```

**Validation:**
- Target must exist and be a `user` nodetype
- Cannot favorite yourself
- Guests are rejected (`unauthorized_if_guest` around all actions)
- Favoriting an already-favorited user is idempotent (returns `is_favorited => 1`)

#### 2. Data Population for Nodelet
**Gate:** `Application::buildNodeInfoStructure` (`$nodelets =~ /1876005/` and not guest)
**Assembly:** `Everything::PageState::_build_favoriteWriteups` (moved there in #4257 Phase 2b)

```perl
my $wuLimit = 5;   # hard cap, matches the React display limit (#3765)
my $sql = "SELECT node.node_id, node.author_user
  FROM links
  JOIN node ON links.to_node = node.author_user
  WHERE links.linktype = $linktypeIdFavorite
    AND links.from_node = $USER->{user_id}
    AND node.type_nodetype = $typeIdWriteup
  ORDER BY node.node_id DESC
  LIMIT $wuLimit";
```

**Returns to frontend:**
- `e2.favoriteWriteups` - Array of `{node_id, title, parent: {node_id, title}, author: {node_id, title}, writeuptype}` (absent if the `favorite` linktype is missing)
- `e2.favoriteLimit` is **no longer sent**

#### 3. Favorite-author notification
`Application::finalize_published_writeup` (called on publish, #4314) sends the `favorite` notification (1930837) to each follower who has enabled it in their notification settings.

### Frontend Components

#### FavoriteNoders Nodelet
**Location:** `react/components/Nodelets/FavoriteNoders.js`

Renders `props.favoriteWriteups.slice(0, 5)` as `<WriteupEntry mode="full">` items in a `ul.infolist.favorite-noders__list`, with an empty state ("No recent writeups from your favorite noders" + hint to use the star icon on profiles). Data is server-baked; no API fetch on page load.

#### E2ReactRoot Integration
**Location:** `react/components/E2ReactRoot.js`

```javascript
'favorite_noders': () => (
  <FavoriteNoders
    id="favorite_noders"
    favoriteWriteups={this.state.favoriteWriteups}
    showNodelet={this.showNodelet}
    nodeletIsOpen={this.state.favoritenoders_show}
  />
)
```

### Related: Unfavorite Users System

The "unfavorite" system (hiding writeups) is separate but often confused with favorites.

#### Storage
- **VARS key:** `unfavoriteusers` (CSV of user IDs)
- **messageignore table:** For blocking private messages

#### API
**Location:** `ecore/Everything/API/userinteractions.pm`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/userinteractions` | GET | List all blocked/hidden users |
| `/api/userinteractions/create` | POST | Add user to hide/block list |
| `/api/userinteractions/:id` | GET | Get block status for user |
| `/api/userinteractions/:id/action/update` | POST | Update block settings (routing is method-agnostic; React uses POST) |
| `/api/userinteractions/:id/action/delete` | DELETE | Remove from lists |

#### Request/Response Format
```javascript
// POST /api/userinteractions/create
{
  "username": "some_user",  // or "node_id": 12345
  "hide_writeups": true,    // Hide from New Writeups
  "block_messages": false   // Block private messages
}

// Response
{
  "success": 1,
  "node_id": 12345,
  "title": "some_user",
  "type": "user",
  "hide_writeups": 1,
  "block_messages": 0
}
```

### Node IDs Reference

| Purpose | Node ID | Title |
|---------|---------|-------|
| Favorite Noders Nodelet | `1876005` | - |
| Favorite Linktype | `1930912` | `favorite` |
| Favorite Notification | `1930837` | - |
| User Nodetype | `15` | `user` |

> The `favorite` (`1930913`) and `unfavorite` (`1930914`) **opcodes were removed** (June 2026), replaced by `Everything::API::favorites`.

### Constants
**Location:** `ecore/Everything/Constants.pm`

```perl
use constant NODELET_FAVORITENODERS => 1876005;
```

## Known Issues

### Issue #3765: Hard-coded 5 writeup limit
Both the server query (`LIMIT 5` in `_build_favoriteWriteups`) and the React component (`slice(0, 5)`) cap at 5. The `favorite_limit` VARS key is ignored.

### Confusing Terminology
- "Favorite" = follow (positive action)
- "Unfavorite" = hide (negative action, stored in VARS)

These are completely separate systems despite similar names.

## User Experience

### Adding a Favorite
1. Navigate to a user's profile page
2. Click the star ("Favorite") button
3. React POSTs `/api/favorites/:id/action/favorite` and flips the button to "Favorited"
4. User's writeups now appear in Favorite Noders nodelet

### Removing a Favorite
1. Navigate to the favorited user's profile page
2. Click the star ("Favorited") button (or remove via Settings → FavoriteUsersManager)
3. React POSTs `/api/favorites/:id/action/unfavorite` and flips the button back to "Favorite"
4. User's writeups no longer appear in nodelet

### Configuring Display Limit
Not currently possible — `favorite_limit` is no longer honored (see #3765).

## Test Coverage

### Perl Tests
- `t/089_favorites_api.t` — favorites API
- `t/080_userinteractions_api.t` — unfavorite/block API

### React Tests
- **Location:** `react/components/Nodelets/FavoriteNoders.test.js`
- Tests component rendering, empty states, and display limits

## Future Considerations

1. **Honor `favorite_limit`** (or retire the key) — needs both the server `LIMIT 5` and the React slice changed.
2. **Unify terminology** - rename "unfavorite" to "hide" or "mute"
3. **Add pagination** to the Favorite Noders nodelet
4. **Add favorite count** to user profiles
5. ~~Notifications when a favorited user publishes~~ — built (`favorite` notification, sent from `finalize_published_writeup`)
