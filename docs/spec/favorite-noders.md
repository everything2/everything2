# Favorite Noders System Specification

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
- `favorite_limit` - Integer, how many writeups to show (default: 15, max: 50, min: 1)
- `unfavoriteusers` - CSV of user IDs whose writeups to hide from New Writeups

### Data Flow

```
User Profile Page
       │
       ▼
favorite_noder htmlcode ──► Creates "favorite!" / "unfavorite!" button
       │
       ▼ (AJAX click)
favorite/unfavorite opcode
       │
       ▼
links table INSERT/DELETE
       │
       ▼
Application.pm (on page load)
       │
       ▼
Queries links table for user's favorites
       │
       ▼
FavoriteNoders React component
```

### Backend Components

#### 1. Favorite/Unfavorite Opcodes
**Location:** `ecore/Everything/Delegation/opcode.pm` (lines 1648-1688)

```perl
sub favorite {
  # Inserts link: from_node=USER, to_node=target_user, linktype=favorite
  $DB->sqlInsert('links', {
    -from_node => getId($USER),
    -to_node => $node_id,
    -linktype => getId($LINKTYPE)
  });
}

sub unfavorite {
  # Deletes link from links table
  $DB->sqlDelete('links',
    "from_node = $uid AND to_node = $node_id AND linktype = $$LINKTYPE{node_id}");
}
```

**Validation:**
- Target must be a `user` nodetype
- Requester must not be a guest

#### 2. Favorite Button Generator
**Location:** `ecore/Everything/Delegation/htmlcode.pm` (lines 8662-8703)

```perl
sub favorite_noder {
  # Only renders on user profile pages (type 15)
  # Checks if link exists to determine button text
  # Returns "favorite!" or "unfavorite!" link with AJAX class
}
```

**Output:**
- AJAX-enabled link with class `ajax favoritenoder:favorite_noder`
- Title tooltip explains the action

#### 3. Data Population for Nodelet
**Location:** `ecore/Everything/Application.pm` (lines 7085-7127)

```perl
# Only loads if nodelet 1876005 is enabled and user is logged in
if($nodelets =~ /1876005/ and not $this->isGuest($USER)) {
  # Query recent writeups from favorited authors
  my $sql = "SELECT node.node_id, node.author_user
    FROM links
    JOIN node ON links.to_node = node.author_user
    WHERE links.linktype = $linktypeIdFavorite
      AND links.from_node = $USER->{user_id}
      AND node.type_nodetype = $typeIdWriteup
    ORDER BY node.node_id DESC
    LIMIT $wuLimit";
}
```

**Returns to frontend:**
- `e2.favoriteWriteups` - Array of {node_id, title, author_id, author_name}
- `e2.favoriteLimit` - User's configured limit

### Frontend Components

#### FavoriteNoders Nodelet
**Location:** `react/components/Nodelets/FavoriteNoders.js`

```javascript
const FavoriteNoders = (props) => {
  // Displays writeups from favorited authors
  // Currently hard-limited to 5 items (see issue #3765)
  const displayWriteups = props.favoriteWriteups.slice(0, 5)

  return (
    <NodeletContainer title="Favorite Noders">
      <ul id="writeup_faves">
        {displayWriteups.map((writeup) => (
          <li>
            <LinkNode nodeId={writeup.node_id} title={writeup.title} />
            {' by '}
            <LinkNode nodeId={writeup.author_id} title={writeup.author_name} />
          </li>
        ))}
      </ul>
    </NodeletContainer>
  )
}
```

#### E2ReactRoot Integration
**Location:** `react/components/E2ReactRoot.js`

```javascript
'favorite_noders': () => (
  <FavoriteNoders
    id="favorite_noders"
    favoriteWriteups={this.state.favoriteWriteups}
    favoriteLimit={this.state.favoriteLimit}
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
| `/api/userinteractions/:id/action/update` | PUT | Update block settings |
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
| Unfavorite Opcode | `1930914` | `unfavorite` |
| Favorite Opcode | `1930913` | `favorite` |
| Favorite Notification | `1930837` | - |
| User Nodetype | `15` | `user` |

### Constants
**Location:** `ecore/Everything/Constants.pm`

```perl
use constant NODELET_FAVORITENODERS => 1876005;
```

## Known Issues

### Issue #3765: Hard-coded 5 writeup limit
The React component hard-codes a limit of 5 writeups regardless of `favorite_limit` setting.

**Current workaround:** `const displayWriteups = props.favoriteWriteups.slice(0, 5)`

**Needed:** A dedicated API endpoint similar to the new writeups API that supports pagination.

### Confusing Terminology
- "Favorite" = follow (positive action)
- "Unfavorite" = hide (negative action, stored in VARS)

These are completely separate systems despite similar names.

### No Dedicated API for Favorites
The favorite/unfavorite actions still use legacy AJAX opcodes rather than a modern REST API.

## User Experience

### Adding a Favorite
1. Navigate to a user's profile page
2. Click "favorite!" link
3. AJAX updates the link to "unfavorite!"
4. User's writeups now appear in Favorite Noders nodelet

### Removing a Favorite
1. Navigate to the favorited user's profile page
2. Click "unfavorite!" link
3. AJAX updates the link to "favorite!"
4. User's writeups no longer appear in nodelet

### Configuring Display Limit
Users can set `favorite_limit` in their settings (via Oracle for admins, or directly in VARS).

## Test Coverage

### Perl Tests
- **Location:** `t/080_userinteractions_api.t`
- Tests the unfavorite/block API (not the favorite linktype system)

### React Tests
- **Location:** `react/components/Nodelets/FavoriteNoders.test.js`
- Tests component rendering, empty states, and display limits

## Future Considerations

1. **Create dedicated API endpoints** for favorite management (`/api/favorites`)
2. **Unify terminology** - rename "unfavorite" to "hide" or "mute"
3. **Add pagination** to the Favorite Noders nodelet
4. **Add favorite count** to user profiles
5. **Notifications** when a favorited user publishes new content
