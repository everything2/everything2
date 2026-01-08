# Ajax Htmlcode Calling Map

**Purpose**: Document the call hierarchy of ajax-related htmlcodes to identify safe deletion order.
**Last Updated**: 2026-01-07

## Overview

This document maps where ajax-whitelisted htmlcodes are called from, to determine:
1. Which are still actively rendered
2. Which have been replaced by React
3. Safe deletion order (delete leaves first, then work up to roots)

## ajax_update_page Whitelist

The following htmlcodes are whitelisted in `ajax_update_page` (htmlpage.pm lines 1493-1522):

```perl
my %valid = (
  # nodeletsection - REMOVED (2026-01-07): React NodeletSection.js handles this
  # ilikeit - REMOVED (2026-01-07): React ILikeItButton + /api/ilikeit
  coolit =>            [],
  ordernode =>         [],
  favorite_noder =>    [],
  nodenote =>          [ $anything ],
  # bookmarkit - REMOVED (2026-01-07): window.toggleBookmark + /api/cool/bookmark
  weblogform =>        [ $node_id , $anything ],
  categoryform =>      [ $node_id , $anything ],
  # voteit - REMOVED (2026-01-07): React WriteupDisplay + /api/vote
  writeuptools =>      [ $node_id , $anything ],
  drafttools =>        [ $node_id , $anything ],
  writeupmessage =>    [ $anything , $node_id ],
  # writeupcools - REMOVED (2026-01-07): React WriteupDisplay + /api/cool
  # showmessages - REMOVED (2026-01-07): React Messages nodelet + /api/messages
  # testshowmessages - REMOVED (2026-01-07): React Messages nodelet + /api/messages
  # showchatter - REMOVED (2026-01-07): React Chatterbox + /api/chatter
  # displaynltext2 - REMOVED (2026-01-07): Dead code
  # movenodelet - REMOVED (2026-01-07): opcode + htmlcode removed, React Settings.js + /api/nodelets
  setdraftstatus =>    [ $node_id ],
  parentdraft =>       [ $node_id ],
  listnodecategories =>[ $node_id ],
  # zenDisplayUserInfo - REMOVED (2026-01-07): React UserDisplay.js renders #userinfo dl
  # messageBox - REMOVED (2026-01-07): React MessageBox.js + /api/messages/create
  # nodeletsettingswidget - REMOVED (2026-01-07): React Settings.js Nodelets tab
  # homenodeinfectedinfo - REMOVED (2026-01-07): React UserDisplay.js + /api/user/cure
  "user searcher" =>   [...],
);
```

---

## Calling Hierarchy

### 1. `ilikeit` - "I Like It" Button

**Status**: ✅ MIGRATED TO REACT - Legacy code still exists but not rendered

**React Replacement**: `ILikeItButton.js` + `/api/ilikeit`

**Legacy Call Chain**:
```
ilikeit (htmlcode.pm:9248)
  ↑ called by
displayWriteupInfo (htmlcode.pm:5884) - info_vote function
  ↑ called by
displaywriteuptitle (htmlcode.pm:1711)
  ↑ called by
[LEGACY: e2node display page - NOW REACT]
```

**Ajax Pattern**: `class="action ajax like{id}:ilikeit:{id}:"`

**Safe to Delete**: YES - React ILikeItButton handles this now

---

### 2. `voteit` - Vote Buttons

**Status**: ✅ MIGRATED TO REACT - Legacy code still exists but not rendered

**React Replacement**: `WriteupDisplay.js` + `/api/vote/writeup/:id`

**Legacy Call Chain**:
```
voteit (htmlcode.pm:2028)
  ↑ called by
displayWriteupInfo (htmlcode.pm:5885) - info_vote function
  ↑ called by
displaywriteuptitle (htmlcode.pm:1711)
  ↑ called by
[LEGACY: e2node display page - NOW REACT]
```

**Ajax Pattern**: `class="ajax voteinfo_{id}:voteit?op=vote&vote__{id}="`

**Also called from**:
- `adminheader` (htmlcode.pm:11733) - `instant ajax adminheader{id}:voteit:{id},5`

**Safe to Delete**: PARTIAL - React handles writeup voting, but adminheader may still use it

---

### 3. `writeupcools` - C! Display/Button

**Status**: ✅ MIGRATED TO REACT - Legacy code still exists but not rendered

**React Replacement**: `WriteupDisplay.js` + `/api/cool/writeup/:id`

**Legacy Call Chain**:
```
writeupcools (htmlcode.pm:5486)
  ↑ called by
displayWriteupInfo (htmlcode.pm:5901) - info_c_full function
  ↑ called by
displaywriteuptitle (htmlcode.pm:1711)
  ↑ called by
[LEGACY: e2node display page - NOW REACT]
```

**Ajax Pattern**: `class="action ajax cools{id}:writeupcools:{id}"`

**Safe to Delete**: YES - React WriteupDisplay handles C! now

---

### 4. `coolit` - Editor Cool (Frontpage)

**Status**: ⚠️ STILL ACTIVE - Used in page header for editor frontpage cool

**Call Chain**:
```
coolit (called via ajax_update_page)
  ↑ triggered by
page_actions (htmlcode.pm) - editor cool button
  ↑ rendered by
[page header template]
```

**Ajax Pattern**: `class="action ajax editorcool:coolit"`

**Safe to Delete**: NO - Still used for editor frontpage cool functionality

---

### 5. `bookmarkit` - Bookmark Button

**Status**: ⚠️ MIXED - Old ajax pattern dead, new inline onclick active

**Old Ajax Pattern** (DEAD):
```
bookmarkit (htmlcode.pm:1801)
  ↑ called by
displayWriteupInfo (htmlcode.pm:6050) - info_addto function
  ↑ called by
displaywriteuptitle (htmlcode.pm:1711)
  ↑ called by
[LEGACY: e2node display page - NOW REACT]
```
- Ajax pattern: `class="action ajax bookmark{id}:bookmarkit:{id}"`
- NOT RENDERED anymore

**New Inline Pattern** (ACTIVE):
```
page_actions (htmlcode.pm:10024)
  ↑ rendered by
[page header template]
```
- Uses: `onclick="window.toggleBookmark(...)"`
- Calls: `/api/cool/bookmark/{nodeId}`

**Safe to Delete from Whitelist**: YES - ajax pattern not used
**Safe to Delete htmlcode**: NO - still called for data lookup (but could be refactored)

---

### 6. `favorite_noder` - Favorite User Button

**Status**: ⚠️ STILL ACTIVE - Used in page header

**Call Chain**:
```
favorite_noder (htmlcode.pm)
  ↑ called by
page_actions (htmlcode.pm:10004)
  ↑ rendered by
[page header template]
```

**Ajax Pattern**: Uses opcode pattern via `class="action ajax"`

**Safe to Delete**: NO - Still used in page header

---

### 7. `weblogform` / `categoryform` - Add to Daylog/Category

**Status**: ⚠️ STILL ACTIVE - Used in page header and writeup info

**Call Chain**:
```
weblogform/categoryform
  ↑ called by
displayWriteupInfo (htmlcode.pm:6027-6028) - info_addto function [LEGACY - not rendered]
  ↑ AND called by
page_actions (htmlcode.pm:10026-10027)
  ↑ rendered by
[page header template]
```

**Safe to Delete**: NO - Still used in page_actions

---

### 8. `drafttools` - Draft Management Tools

**Status**: ⚠️ STILL ACTIVE - Used for draft editing

**Call Chain**:
```
drafttools (htmlcode.pm:12212)
  ↑ called by
writeuptools (htmlcode.pm:8893) - redirects for drafts
  ↑ called by
e2node display/draft pages
```

**Ajax Pattern**: `class="action ajax {id}:drafttools:{n},1"`

**Safe to Delete**: NO - Still used for draft management

---

### 9. `writeuptools` - Writeup Admin Tools

**Status**: ⚠️ STILL ACTIVE - Used for writeup editing/admin

**Call Chain**:
```
writeuptools (htmlcode.pm:8880)
  ↑ called by
various admin/editor pages
```

**Safe to Delete**: NO - Still used for admin functions

---

### 10. `nodenote` - Node Notes

**Status**: ⚠️ STILL ACTIVE - Used for CE notes on nodes

**Call Chain**:
```
nodenote (htmlcode.pm)
  ↑ called by
writeuptools (htmlcode.pm:8975)
drafttools (htmlcode.pm:12344)
```

**Ajax Pattern**: `class="ajax nodenotes:nodenote"`

**Safe to Delete**: NO - Still used for editor notes

---

### 11. `listnodecategories` - Category List

**Status**: ⚠️ STILL ACTIVE - Used in multiple places

**Call Chain**:
```
listnodecategories
  ↑ called by
displayWriteupInfo (htmlcode.pm:6064) - info_cats [LEGACY - not rendered]
e2nodebody (htmlcode.pm:8872)
e2nodeListItem (htmlcode.pm:10405)
zenMessage (htmlcode.pm:10657)
```

**Ajax Pattern**: `class="instant ajax categories{id}:listnodecategories?a=1:{id}:"`

**Safe to Delete**: NO - Still used in multiple places

---

### 12. `messageBox` - Message Reply Box

**Status**: ⚠️ POSSIBLY ACTIVE - Need to verify

**Call Chain**:
```
messageBox (htmlcode.pm)
  ↑ called by
zenDisplayUserInfo (htmlcode.pm:9114)
```

**Ajax Pattern**: `class="expandable ajax replyto{id}:messageBox:{params}"`

**Safe to Delete**: INVESTIGATE - May still be used in user profile messages

---

### 13. `ordernode` - Admin Order Lock

**Status**: ⚠️ STILL ACTIVE - Admin function

**Call Chain**:
```
ordernode
  ↑ called by
adminheader (htmlcode.pm:11442)
```

**Ajax Pattern**: `class="ajax adminordernode:ordernode?op=orderlock&unlock=/"`

**Safe to Delete**: NO - Admin function

---

### 14. `setdraftstatus` / `parentdraft` - Draft Status

**Status**: ⚠️ STILL ACTIVE - Draft management

**Call Chain**:
```
setdraftstatus/parentdraft
  ↑ called by
drafttools
adminheader (htmlcode.pm:11730) for parentdraft
```

**Safe to Delete**: NO - Draft management

---

### 15. `homenodeinfectedinfo` - Infection Info (Admin)

**Status**: ✅ REMOVED (2026-01-07) - Migrated to React

**React Replacement**: `UserDisplay.js` + `POST /api/user/cure`

**What it did**: Displayed infection warning and cure button for admins viewing infected user profiles.

**Migration**: Controller::user.pm sends `is_infected` flag, React UserDisplay.js renders warning and cure button for admins.

---

### 16. `nodeletsettingswidget` - Nodelet Settings

**Status**: ⚠️ STILL ACTIVE - Nodelet configuration

**Call Chain**:
```
nodeletsettingswidget
  ↑ rendered in
nodelet headers
```

**Ajax Pattern**: `class="ajax {id}settingswidget:nodeletsettingswidget?showwidget=..."`

**Safe to Delete**: NO - User preference feature

---

## Summary: Safe Deletion Order

### Phase 1: COMPLETED (2026-01-07) - Removed from ajax_update_page whitelist

1. ~~`ilikeit`~~ - REMOVED: React ILikeItButton + /api/ilikeit handles this
2. ~~`voteit`~~ - REMOVED: React WriteupDisplay + /api/vote handles this
3. ~~`writeupcools`~~ - REMOVED: React WriteupDisplay + /api/cool handles this
4. ~~`bookmarkit`~~ - REMOVED: window.toggleBookmark + /api/cool/bookmark handles this

### Phase 1b: COMPLETED (2026-01-07) - Removed from ajax_update_page whitelist

5. ~~`nodeletsection`~~ - REMOVED: React NodeletSection.js handles expand/collapse with pure state
6. ~~`displaynltext2`~~ - REMOVED: Dead code, marked "shouldn't be needed" in legacy.js
7. ~~`showchatter`~~ - REMOVED: React Chatterbox + /api/chatter handles this
8. ~~`showmessages`~~ - REMOVED: React Messages nodelet + /api/messages handles this
9. ~~`testshowmessages`~~ - REMOVED: React Messages nodelet + /api/messages handles this
10. ~~`zenDisplayUserInfo`~~ - REMOVED: React UserDisplay.js renders #userinfo dl (function also removed from htmlcode.pm)
11. ~~`messageBox`~~ - REMOVED: React MessageBox.js + /api/messages/create handles this (function also removed from htmlcode.pm)
12. ~~`nodeletsettingswidget`~~ - REMOVED: React Settings.js Nodelets tab handles this (function also removed from htmlcode.pm)
13. ~~`movenodelet`~~ - REMOVED completely: opcode and htmlcode removed (React Settings.js + /api/nodelets)

### Phase 1c: COMPLETED (2026-01-07) - Dead code removed from htmlcode.pm

Functions that were ONLY called by `nodeletsettingswidget` (which assembled function names dynamically via `htmlcode($name.' nodelet settings', 'inwidget')`):

14. ~~`Notelet_nodelet_settings`~~ - REMOVED: Only called by nodeletsettingswidget
15. ~~`Personal_Links_nodelet_settings`~~ - REMOVED: Only called by nodeletsettingswidget
16. ~~`Other_Users_nodelet_settings`~~ - REMOVED: Only called by nodeletsettingswidget
17. ~~`Notifications_nodelet_settings`~~ - REMOVED: Only called by nodeletsettingswidget
18. ~~`Chatterbox_nodelet_settings`~~ - REMOVED: Only called by nodeletsettingswidget

### Phase 2: Needs Investigation

19. ⚠️ `voteit` (admin context) - Check if adminheader still uses ajax pattern (note: voteit already removed from whitelist)

### Phase 3: Still Active - Do Not Delete

20. ❌ `coolit` - Editor frontpage cool
21. ❌ `favorite_noder` - Page header
22. ❌ `weblogform` / `categoryform` - Page header
23. ❌ `drafttools` / `writeuptools` - Draft/writeup management
24. ❌ `nodenote` - Editor notes
25. ❌ `listnodecategories` - Multiple uses
26. ❌ `ordernode` - Admin
27. ❌ `setdraftstatus` / `parentdraft` - Draft management
28. ✅ `homenodeinfectedinfo` - REMOVED (2026-01-07): React UserDisplay.js + /api/user/cure

---

## Dependency Graph

```
[React - ACTIVE]
├── WriteupDisplay.js
│   ├── /api/vote/writeup/:id (replaces voteit for writeups)
│   ├── /api/cool/writeup/:id (replaces writeupcools)
│   └── /api/cool/writeup/:id/bookmark (replaces bookmarkit)
└── ILikeItButton.js
    └── /api/ilikeit (replaces ilikeit)

[Legacy.js - ACTIVE]
├── window.toggleBookmark → /api/cool/bookmark/:id
└── window.toggleEditorCool → /api/cool/frontpage/:id

[ajax_update_page - STILL NEEDED]
├── coolit (editor frontpage cool)
├── favorite_noder (page header)
├── weblogform/categoryform (page header)
├── drafttools/writeuptools (content management)
├── nodenote (editor notes)
├── listnodecategories (multiple)
├── ordernode (admin)
└── setdraftstatus/parentdraft (drafts)

[DEAD CODE - Safe to Remove]
├── ilikeit (in displayWriteupInfo context)
├── voteit (in displayWriteupInfo context)
├── writeupcools (in displayWriteupInfo context)
└── bookmarkit (ajax class pattern)
```

---

## Live Testing Results (2026-01-07)

### Pages Tested for Ajax Class Patterns

| Page | User | Ajax Elements Found |
|------|------|---------------------|
| Writeup (/node/2213557) | e2e_user | NONE |
| Writeup (/node/2213557) | e2e_admin | NONE |
| Settings | e2e_admin | `categoryform` button |
| Findings | e2e_admin | NONE |
| E2 staff (superdoc) | e2e_admin | `categoryform` button |

### Findings

1. **Writeup pages**: Completely React - no ajax patterns
2. **Superdoc pages**: Still using `categoryform` ajax pattern
3. **Settings page**: Still using `categoryform` ajax pattern

The `categoryform` ajax pattern is the **primary remaining active ajax pattern** on standard pages.

---

## Root Functions to Investigate

The following root-level htmlcodes are the "apex" that render ajax patterns:

1. **`displayWriteupInfo`** (htmlcode.pm:5714)
   - Contains: ilikeit, voteit, writeupcools, bookmarkit, weblogform, categoryform, listnodecategories
   - Called by: displaywriteuptitle
   - **Status**: NOT RENDERED (React WriteupDisplay replaced it)
   - **Action**: All ajax patterns within are dead code

2. **`page_actions`** (htmlcode.pm:9968)
   - Contains: toggleBookmark (inline), toggleEditorCool (inline), favorite_noder, weblogform, categoryform
   - Called by: page header template
   - **Status**: STILL RENDERED
   - **Action**: Keep - uses modern inline patterns

3. **`adminheader`** (htmlcode.pm)
   - Contains: voteit, ordernode, parentdraft
   - Called by: admin pages
   - **Status**: STILL RENDERED
   - **Action**: Keep - admin functionality

4. **`writeuptools`** / **`drafttools`** (htmlcode.pm:8880, 12212)
   - Contains: nodenote, drafttools actions
   - Called by: content management pages
   - **Status**: STILL RENDERED
   - **Action**: Keep - content management
