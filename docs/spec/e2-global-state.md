# E2 Global Page State Specification

This document defines the global `window.e2` object that is available on every page load. Controllers and Page classes should use this data rather than duplicating it in `contentData`.

**Generated**: 2025-01-10

---

## Overview

The `e2` global object is built by `Everything::Application::buildNodeInfoStructure()` and passed to React via `Everything::HTMLShell`. It contains user state, current node info, and nodelet-specific data.

React components access this via:
- `window.e2` (global)
- `props.e2` (passed to PageLayout and E2ReactRoot)
- Component state initialized from `e2` properties

---

## Always-Present Properties

These are available on every page load for all users.

### Core Identifiers

| Property | Type | Description |
|----------|------|-------------|
| `e2.node_id` | int | Current page node ID |
| `e2.title` | string | Current page node title |
| `e2.guest` | int (0/1) | Whether current user is guest |
| `e2.nodetype` | string | Current node's type title (e.g., "e2node", "superdoc") |

### Current Node Object

| Property | Type | Description |
|----------|------|-------------|
| `e2.node.node_id` | int | Node ID (same as `e2.node_id`) |
| `e2.node.title` | string | Node title |
| `e2.node.type` | string | Node type title |
| `e2.node.createtime` | int | Unix epoch of creation time |

### User Object

| Property | Type | Description |
|----------|------|-------------|
| `e2.user.node_id` | int | User's node ID |
| `e2.user.title` | string | Username |
| `e2.user.admin` | boolean | Is user a god/admin? |
| `e2.user.editor` | boolean | Is user a Content Editor? |
| `e2.user.chanop` | boolean | Is user a Channel Operator? |
| `e2.user.developer` | boolean | Is user in edev? |
| `e2.user.guest` | boolean | Is user the guest user? |
| `e2.user.in_room` | int | Current room node ID (0 = outside) |

**Logged-in users only:**

| Property | Type | Description |
|----------|------|-------------|
| `e2.user.gp` | int | Current GP balance |
| `e2.user.gpOptOut` | boolean | Has user opted out of GP? |
| `e2.user.experience` | int | Total XP |
| `e2.user.level` | int | User level (0-13) |
| `e2.user.votesleft` | int | Votes remaining today |
| `e2.user.coolsleft` | int | C!s remaining |
| `e2.user.unreadMessages` | int | Count of unread private messages |

### Configuration

| Property | Type | Description |
|----------|------|-------------|
| `e2.use_local_assets` | int (0/1) | Whether to use local assets (dev) |
| `e2.assets_location` | string | CDN URL for assets (empty if local) |
| `e2.lastCommit` | string | Git commit hash of deployed code |
| `e2.architecture` | string | Server architecture info |
| `e2.hasMessagesNodelet` | int (0/1) | Whether user has Messages nodelet |

### Display Preferences

| Property | Type | Description |
|----------|------|-------------|
| `e2.display_prefs` | object | User display preferences |
| `e2.noquickvote` | int (0/1) | Disable quick voting |
| `e2.nonodeletcollapser` | int (0/1) | Disable nodelet collapse buttons |
| `e2.collapsedNodelets` | string | Pipe-separated list of collapsed nodelets |
| `e2.nodeletorder` | array | Ordered list of nodelet names for sidebar |

### Always-Loaded Data

| Property | Type | Description |
|----------|------|-------------|
| `e2.newWriteups` | array | Recent writeups (for mobile nav + nodelets) |

---

## Chatterbox Data

Available when user has a room assignment.

| Property | Type | Description |
|----------|------|-------------|
| `e2.chatterbox.roomName` | string | Current room name ("outside" if room 0) |
| `e2.chatterbox.roomTopic` | string | Current room topic |
| `e2.chatterbox.messages` | array | Initial chatter messages (last 5 minutes) |
| `e2.chatterbox.showMessagesInChatterbox` | int (0/1) | Show mini-messages in chatterbox |
| `e2.chatterbox.miniMessages` | array | Last 5 private messages (if no Messages nodelet) |

---

## Nodelet-Conditional Data

These are loaded only when the user has the corresponding nodelet enabled.

### Epicenter (nodelet ID: 262)

**Note**: Always loaded for logged-in users (regardless of nodelet).

| Property | Type | Description |
|----------|------|-------------|
| `e2.epicenter.showEpicenterZen` | boolean | Show header bar (if no Epicenter nodelet) |
| `e2.epicenter.localTimeUse` | boolean | User prefers local time |
| `e2.epicenter.userSettingsId` | int | Node ID of user settings page |
| `e2.epicenter.helpPage` | string | Help page title based on level |
| `e2.epicenter.borgcheck` | object | Borg status if borged |
| `e2.epicenter.experienceGain` | int | XP gained since last page (if positive) |
| `e2.epicenter.gpGain` | int | GP gained since last page (if positive) |
| `e2.epicenter.serverTime` | string | Formatted server time |
| `e2.epicenter.localTime` | string | Formatted local time (if enabled) |

### Master Control (editors/admins only)

| Property | Type | Description |
|----------|------|-------------|
| `e2.masterControl.adminSearchForm` | object | Node search form data |
| `e2.masterControl.ceSection` | object | Content Editor tools data |
| `e2.masterControl.nodeNotesData` | object | Node notes for current node |
| `e2.masterControl.nodeToolsetData` | object | Admin node tools (gods only) |
| `e2.masterControl.adminSection` | object | Admin section visibility |
| `e2.currentUserId` | int | Current user ID (for note editing) |

### New Logs (nodelet ID: 1923735)

| Property | Type | Description |
|----------|------|-------------|
| `e2.daylogLinks` | array | Recent daylog date links |

### Recommended Reading / ReadThis (nodelet IDs: 2027508, 1157024)

| Property | Type | Description |
|----------|------|-------------|
| `e2.coolnodes` | array | Cool user picks |
| `e2.staffpicks` | array | Staff picks |
| `e2.news` | array | News for Noders entries (ReadThis only) |

### Random Nodes (nodelet ID: 457857)

| Property | Type | Description |
|----------|------|-------------|
| `e2.randomNodes` | array | Random node suggestions |

### Neglected Drafts (nodelet ID: 2051342)

| Property | Type | Description |
|----------|------|-------------|
| `e2.neglectedDrafts` | object | Drafts needing attention |

### Quick Reference (nodelet ID: 2146276)

| Property | Type | Description |
|----------|------|-------------|
| `e2.quickRefSearchTerm` | string | Current node title for external lookups |

### Statistics (nodelet ID: 838296)

| Property | Type | Description |
|----------|------|-------------|
| `e2.statistics.personal` | object | XP, level, writeups, GP |
| `e2.statistics.fun` | object | Node-fu, trinkets, stars, eggs, tokens |
| `e2.statistics.advancement` | object | Merit, LF, devotion stats |

### Notelet (nodelet ID: 1290534)

| Property | Type | Description |
|----------|------|-------------|
| `e2.noteletData.isLocked` | int (0/1) | Whether notelet is locked |
| `e2.noteletData.hasContent` | int (0/1) | Whether notelet has content |
| `e2.noteletData.content` | string | Screened HTML content |
| `e2.noteletData.isGuest` | int (0/1) | Is guest user |

### Categories (nodelet ID: 1935779)

| Property | Type | Description |
|----------|------|-------------|
| `e2.currentNodeId` | int | Current node ID (for category ops) |
| `e2.nodeCategories` | array | Categories containing current node |

### Most Wanted (nodelet ID: 1986723)

| Property | Type | Description |
|----------|------|-------------|
| `e2.bounties` | array | Active bounty requests |

### Recent Nodes (nodelet ID: 1322699)

| Property | Type | Description |
|----------|------|-------------|
| `e2.recentNodes` | array | User's recently visited nodes |

### Favorite Noders (nodelet ID: 1876005)

| Property | Type | Description |
|----------|------|-------------|
| `e2.favoriteWriteups` | array | Recent writeups from favorited users |
| `e2.favoriteLimit` | int | Max writeups to show |

### Personal Links (nodelet ID: 174581)

| Property | Type | Description |
|----------|------|-------------|
| `e2.personalLinks` | array | User's personal link titles |
| `e2.currentNodeTitle` | string | Current node title (for adding) |
| `e2.currentNodeId` | int | Current node ID |

### Current User Poll (nodelet ID: 1689202)

| Property | Type | Description |
|----------|------|-------------|
| `e2.currentPoll` | object | Active poll data with options and results |

### Usergroup Writeups (nodelet ID: 1924754)

| Property | Type | Description |
|----------|------|-------------|
| `e2.usergroupData` | object | Weblog writeups from selected usergroup |

### Other Users (loaded separately)

| Property | Type | Description |
|----------|------|-------------|
| `e2.otherUsersData` | object | Online users list and room info |

### Messages (loaded separately)

| Property | Type | Description |
|----------|------|-------------|
| `e2.messagesData` | array | Private messages |

### Notifications (loaded separately)

| Property | Type | Description |
|----------|------|-------------|
| `e2.notificationsData` | array | User notifications |

### For Review (loaded separately)

| Property | Type | Description |
|----------|------|-------------|
| `e2.forReviewData` | object | Drafts/nodes awaiting review |

### Developer Nodelet (edev members with nodelet ID: 836984)

| Property | Type | Description |
|----------|------|-------------|
| `e2.developerNodelet.page` | object | Current page info |
| `e2.developerNodelet.news` | object | Edev weblog entries |
| `e2.developerNodelet.sourceMap` | object | Source code locations |

---

## contentData Convention

The `contentData` object is for **page-specific data only**. Controllers should:

1. **NOT duplicate** user info (`e2.user` already exists)
2. **NOT duplicate** node info (`e2.node` already exists)
3. **NOT duplicate** permission flags (`e2.user.admin`, `e2.user.editor` exist)
4. **ONLY include** data specific to that page type

### Good Example

```perl
# E2Node controller - only page-specific data
$content_data = {
    type => 'e2node',
    e2node => $e2node_structure,  # writeups, softlinks, etc.
    existing_draft => $draft,      # page-specific
    best_entries => \@best,        # guest nodeshell feature
};
```

### Bad Example (Avoid)

```perl
# DON'T DO THIS - duplicates global state
$content_data = {
    type => 'some_page',
    user => {                      # DUPLICATE of e2.user
        node_id => $user->node_id,
        title => $user->title,
        is_admin => $user->is_admin,
    },
    node_id => $node->node_id,     # DUPLICATE of e2.node_id
    is_editor => $is_editor,       # DUPLICATE of e2.user.editor
};
```

---

## React Access Patterns

### From Document Components

```javascript
// Document components receive both data and user
const MyDocument = ({ data, user }) => {
  // data = contentData from controller
  // user = e2.user (passed by DocumentComponent)

  // DON'T expect data.user - use the user prop
  const isEditor = user.editor
  const userId = user.node_id
}
```

### From E2ReactRoot State

```javascript
// Nodelets get user from state (initialized from e2)
const { user, node, guest } = this.state

// Permission checks
if (user.admin) { /* god powers */ }
if (user.editor) { /* editor powers */ }
```

### Direct Window Access

```javascript
// For utilities or event handlers
const currentNodeId = window.e2.node_id
const isGuest = window.e2.guest === 1
```

---

## Nodelet ID Reference

Quick reference for nodelet-conditional loading:

| Nodelet | ID | Data Properties |
|---------|------|-----------------|
| Epicenter | 262 | `epicenter.*` |
| New Logs | 1923735 | `daylogLinks` |
| Recommended Reading | 2027508 | `coolnodes`, `staffpicks` |
| ReadThis | 1157024 | `coolnodes`, `staffpicks`, `news` |
| Random Nodes | 457857 | `randomNodes` |
| Neglected Drafts | 2051342 | `neglectedDrafts` |
| Quick Reference | 2146276 | `quickRefSearchTerm` |
| Statistics | 838296 | `statistics.*` |
| Notelet | 1290534 | `noteletData.*` |
| Categories | 1935779 | `nodeCategories`, `currentNodeId` |
| Most Wanted | 1986723 | `bounties` |
| Recent Nodes | 1322699 | `recentNodes` |
| Favorite Noders | 1876005 | `favoriteWriteups`, `favoriteLimit` |
| Personal Links | 174581 | `personalLinks`, `currentNodeTitle` |
| Current User Poll | 1689202 | `currentPoll` |
| Usergroup Writeups | 1924754 | `usergroupData` |
| Developer | 836984 | `developerNodelet.*` |
