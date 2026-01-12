# User VARS Reference

This document catalogs all known user VARS (settings) stored in the `setting` table's `vars` field. As we migrate away from this legacy storage format toward JSON-based settings, this reference helps track what can be cleaned up.

**Last Updated**: 2026-01-10

## Storage Format

VARS are stored as ampersand-separated key=value pairs in the `setting.vars` column:
```
key1=value1&key2=value2&key3=value3
```

The `setting` table links to users via `setting_id = user.node_id`.

## Access Methods

```perl
# Hashref access (legacy delegation code)
$VARS->{key_name}
$$VARS{key_name}

# Blessed object access (modern Controller/Page code)
$REQUEST->user->VARS->{key_name}
$user->VARS->{key_name}

# Setters
Everything::setVars($USER, $VARS);
$user->set_vars($VARS);
```

---

## Active VARS Keys

### Nodelet & Sidebar Configuration

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `nodelets` | CSV node_ids | Comma-separated list of enabled nodelet node IDs. If 'Epicenter' nodelet is not selected, its functions are placed in the page header. | Guest defaults | Controller.pm, Application.pm |
| `personal_nodelet` | HTML | User's custom nodelet HTML content | Empty | htmlcode.pm |
| `collapsedNodelets` | String | Tracks which nodelets are collapsed | Empty | Controller.pm |

### Display Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `userstyle` | node_id | Stylesheet node selection | System default | Application.pm |
| `repThreshold` | 0-50 or 'none' | Hide writeups below this reputation in New Writeups and e2nodes | 'none' | document.pm, htmlcode.pm |
| `num_newwus` | 1-40 | Number of new writeups to show | 15 | Application.pm |
| `noSoftLinks` | Boolean | Hide softlinks from e2node and writeup pages | 0 | Node/e2node.pm, htmlcode.pm |
| `hidenodeshells` | Boolean | Hide nodeshell (incomplete) nodes in search results and softlinks | 0 | Application.pm |
| `hideauthore2node` | Boolean (inverse) | When 1, hides who created a writeup page title (e2node) | 0 (show) | htmlcode.pm |

### Voting & Interactions

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `votesafety` | Boolean | Ask for confirmation when voting | 0 | preferences.pm |
| `coolsafety` | Boolean | Ask for confirmation when cooling writeups | 0 | preferences.pm |
| `anonymousvote` | 0/1/2 | Anti-bias voting: 0=always show author, 1=hide until voted, 2=hide with clickable link | 0 | htmlcode.pm, preferences.pm |

### Writeup Display Format

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `wuhead` | Format codes | Metadata displayed above writeups. Format: comma-separated codes like "c:type,c:author,c:audio,c:length,c:hits,r:dtcreate" | See note | document.pm |
| `wufoot` | Format codes | Metadata displayed below writeups. Format: comma-separated codes like "l:kill,c:vote,c:cfull,c:sendmsg,c:addto,r:social" | See note | document.pm |
| `nokillpopup` | Boolean (value=4) | Admin tools always visible, no pop-up. Only for specific gods. | Not set | opcode.pm |
| `info_authorsince_off` | Boolean (inverse) | When 1, hides how long ago the author was here | 0 (show) | WriteupDisplay.js |

**wuhead options:** audio (links to audio files), length (word count), hits (hit counter, default ON), dtcreate (creation time, default ON)

**wufoot options:** sendmsg (message box, default ON), addto (bookmark/category tool, default ON), social (social sharing, default ON)

### Homenode Privacy

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `hidemsgme` | Boolean | Hide the user /msg box on homenodes | 0 | document.pm |
| `hidemsgyou` | Boolean | Hide the '/msgs from me' link to Message Inbox on homenodes | 0 | document.pm |
| `hidevotedata` | Boolean | Hide vote and C! data on homenode | 0 | document.pm |
| `hidehomenodeUG` | Boolean | Hide usergroups list on homenode | 0 | document.pm |
| `hidehomenodeUC` | Boolean | Hide categories list on homenode | 0 | document.pm |
| `showrecentwucount` | Boolean | Show recent writeup count on homenode | 0 | document.pm |
| `hidelastnoded` | Boolean (inverse) | When 1, hides link to user's most recent writeup | 0 (show) | document.pm |
| `hidelastseen` | Boolean | Hide "last seen" timestamp from other users | 0 | document.pm |

### Notifications

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `no_notify_kill` | Boolean (inverse) | When 1, don't notify when writeups are deleted | 0 (notify) | Application.pm |
| `no_editnotification` | Boolean (inverse) | When 1, don't notify when writeups are edited by staff | 0 (notify) | Application.pm |
| `no_coolnotification` | Boolean (inverse) | When 1, don't notify when writeups get C!ed | 0 (notify) | Application.pm |
| `no_likeitnotification` | Boolean (inverse) | When 1, don't notify when Guest Users like writeups | 0 (notify) | Application.pm |
| `no_bookmarknotification` | Boolean (inverse) | When 1, don't notify when writeups get bookmarked | 0 (notify) | Application.pm |
| `no_bookmarkinformer` | Boolean (inverse) | When 1, don't tell others when you bookmark | 0 (inform) | Application.pm |
| `anonymous_bookmark` | Boolean | Bookmark anonymously (only applies when informing) | 0 | Application.pm |
| `no_socialbookmarknotification` | Boolean (inverse) | When 1, don't notify of social bookmarks | 0 (notify) | Application.pm |
| `no_socialbookmarkinformer` | Boolean (inverse) | When 1, don't inform of your social bookmarks | 0 (inform) | Application.pm |
| `no_discussionreplynotify` | Boolean (inverse) | When 1, don't notify of usergroup discussion replies | 0 (notify) | Application.pm |
| `nosocialbookmarking` | Boolean | Disable social sharing buttons on your writeups (also hides on others') | 0 | document.pm |

### Writeup Publishing

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `defaultpostwriteup` | Boolean | Publish immediately by default (vs. save as draft) | 0 | htmlcode.pm |
| `HideNewWriteups` | Boolean | Hide your new writeups by default in New Writeups. Some writeups (daylogs, maintenance) always default to hidden. | 0 | htmlcode.pm |
| `GPoptout` | Boolean | Opt out of the GP (points) system | 0 | Application.pm |

### Time & Localization

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `localTimeUse` | Boolean | Enable timezone offset calculations | 0 | Application.pm |
| `localTimeOffset` | Integer | Seconds offset from server time (-43200 to +46800) | 0 | Application.pm |
| `localTimeDST` | Boolean | Apply Daylight Saving Time adjustment (+1 hour) | 0 | Application.pm |
| `localTime12hr` | Boolean | Use 12-hour time format (AM/PM) | 0 | Application.pm |

### User Statistics & Tracking

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `oldGP` | Integer | Cached GP for change detection notifications | - | Application.pm |
| `oldexp` | Integer | Cached XP for change detection notifications | - | Application.pm |
| `numwriteups` | Integer | Cached writeup count for Node-Fu calculation | - | Application.pm |
| `favorite_limit` | Integer | How many favorites to show | 15 | document.pm |

### Game Systems

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `easter_eggs` | Integer | Current Easter Egg count (game currency) | 0 | Application.pm, document.pm |
| `easter_eggs_bought` | Integer | Lifetime Easter Eggs acquired | 0 | Application.pm |
| `tokens` | Integer | Virtual tokens from wheel spins | 0 | Application.pm |
| `tokens_bought` | Integer | Lifetime tokens acquired | 0 | Application.pm |
| `spin_wheel` | Integer | Total wheel spins (1000+ = achievement) | 0 | API/wheel.pm |

### User State

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `borged` | Timestamp | Unix timestamp when user was "borged" | - | Application.pm |
| `numborged` | Integer | Borg duration multiplier (300 + 60*N seconds) | 0 | Application.pm |
| `lockedin` | Timestamp | Unix timestamp until user is locked | - | Application.pm |
| `infected` | Boolean | User infection status flag | 0 | Application.pm |

### Notelet (Personal Nodelet)

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `noteletRaw` | HTML | Raw user notelet content (max 32,768 chars) | Empty | htmlcode.pm |
| `noteletScreened` | HTML | Processed/rendered notelet for display | Empty | htmlcode.pm |
| `noteletLocked` | Boolean | Prevent notelet editing | 0 | htmlcode.pm |
| `noteletKeepComments` | Boolean | Keep HTML comments when editing | 0 | htmlcode.pm |
| `lockCustomHTML` | Boolean | Prevent custom HTML editing | 0 | htmlcode.pm |

### Chat & Messaging

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `chatmacro_*` | String | User-defined chat macros (dynamic keys) | - | htmlcode.pm |
| `getofflinemsgs` | Boolean | Get online-only usergroup messages while offline | 0 | Application.pm |

### Vitals Nodelet Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `vit_hidemaintenance` | Boolean | Hide maintenance sections | 0 | API/preferences.pm |
| `vit_hidenodeinfo` | Boolean | Hide node info sections | 0 | API/preferences.pm |
| `vit_hidenodeutil` | Boolean | Hide node utility sections | 0 | API/preferences.pm |
| `vit_hidelist` | Boolean | Hide list sections | 0 | API/preferences.pm |
| `vit_hidemisc` | Boolean | Hide miscellaneous sections | 0 | API/preferences.pm |

### Epicenter Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `cools` | Integer | "Cool" count displayed in Epicenter | - | htmlcode.pm |
| `ebu_showdevotion` | Boolean | Show devotion stat | 0 | htmlcode.pm |
| `ebu_showaddiction` | Boolean | Show addiction stat | 0 | htmlcode.pm |
| `ebu_newusers` | Boolean | Show new users section | 0 | htmlcode.pm |
| `ebu_showrecent` | Boolean | Show recent writeups section | 0 | htmlcode.pm |

### Content & Node Relationships

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `nodetrail` | CSV node_ids | Breadcrumb trail of recently visited nodes | - | Application.pm |
| `unfavoriteusers` | CSV user_ids | Users to hide/deemphasize in New Writeups | - | Application.pm |
| `can_weblog` | CSV node_ids | Weblog destinations user can post to | - | htmlcode.pm |
| `bookbucket` | CSV node_ids | Bookmarked nodes | - | document.pm |

### New Writeups Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `nw_nojunk` | Boolean | Hide junk writeups in New Writeups | 0 | API/preferences.pm |
| `edn_hideutil` | Boolean | Hide utility sections | 0 | API/preferences.pm |
| `edn_hideedev` | Boolean | Hide edev sections | 0 | API/preferences.pm |

### UI Behavior

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `autoChat` | Boolean | Auto-chat feature flag | 0 | Controller.pm |
| `inactiveWindowMarker` | Boolean | Inactive window marker flag | 0 | Controller.pm |

### Editor Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `tiptap_editor_raw` | Boolean (0/1) | Default to raw HTML mode in E2 Editor Beta (0=rich text, 1=HTML) | 0 | API/preferences.pm, Page/e2_editor_beta.pm |

### Utility Tool Settings

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `alphabetizer_sep` | String | Separator for alphabetizer tool | - | document.pm |
| `alphabetizer_case` | Boolean | Case-insensitive sorting | 0 | document.pm |
| `alphabetizer_sortorder` | Boolean | Reverse sort order | 0 | document.pm |
| `alphabetizer_format` | Boolean | Convert to E2 links | 0 | document.pm |
| `sqlprompt_wrap` | 0-3 | SQL output format | 0 | document.pm |
| `sqlprompt_nocount` | Boolean | Hide row count in SQL | 0 | document.pm |
| `EDD_Sort` | String | Sort order for Everything Document Directory (0=default, idA/idD, nameA/nameD, authorA/authorD, createA/createD) | 0 | Page/everything_document_directory.pm |
| `ListNodesOfType_Type` | Integer | Last selected node type ID in List Nodes of Type tool | - | Page/list_nodes_of_type.pm |

### Modern Settings (JSON)

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `settings` | JSON | Structured settings object for new features | {} | API/preferences.pm |
| `preference_last_update_time` | Epoch | Cache invalidation timestamp | - | API/preferences.pm |

---

## Data Storage Notes

### Checkbox Types
- **Regular checkbox**: Checked = 1, Unchecked = 0 (or absent)
- **Inverse checkbox**: Checked = 0 (or absent), Unchecked = 1 - indicated by "(inverse)" in description

### Non-VARS Storage
Some "preferences" aren't stored in VARS:
- **Favorite noders**: Stored in `links` table with `favorite` linktype
- **Message blocking**: Stored in `messageignore` table
- **Notification preferences**: Some stored in VARS `settings` JSON field

---

## Deprecated VARS Keys

These keys are no longer used and can be cleaned up from user settings:

### Removed in 2026-01 (React Migration Completion)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `fxDuration` | **DEPRECATED** | jQuery animation duration (0=instant, 100-1000ms). All AJAX animations removed - React uses CSS transitions. | 2026-01-09 |
| `noquickvote` | **DEPRECATED** | Toggle between AJAX and page-reload voting. All voting is now React/API-based. | 2026-01-09 |
| `listcode_smaller` | **DEPRECATED** | Display code listings in smaller font. The `listcode` htmlcode has been removed - all code is now on GitHub. | 2026-01-07 |

### Removed in 2025-12 (React Migration)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `textareaSize` | **DEPRECATED** | Writeup editor size (small/medium/large). React uses inline editing. | 2025-12-21 |
| `settings_useTinyMCE` | **DEPRECATED** | Enable WYSIWYG editor. React uses inline editing - TinyMCE removed. | 2025-12-21 |
| `HideWriteupOnE2node` | **DEPRECATED** | Only show writeup edit box on writeup's own page. React inline editing makes this irrelevant. | 2025-12-21 |
| `nullvote` | **DEPRECATED** | Allow null votes for old browser compatibility. Vote swapping now supported. | 2025-12-18 |
| `nogradlinks` | **SEMI-DEPRECATED** | Disable gradient backgrounds on softlinks. Kernel Blue CSS provides solid background. No UI to set. | 2025-12-18 |
| `noreplacevotebuttons` | **DEPRECATED** | Toggle +/- vs Up/Down voting buttons. React uses caret icons exclusively. | 2025-12-15 |
| `killfloor_showlinks` | **DEPRECATED** | Add HTML links in killing floor display. Killing floor mechanism removed. | 2025-12-07 |

### Removed in 2025-11 (Nodelet Migration)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `nodebucket` | **DEPRECATED** | Legacy node bucket feature removed | 2025-11-30 |
| `mitextarea` | **DEPRECATED** | Larger Message Inbox textarea - React modals handle messaging | 2025-11-30 |
| `splitChatter` | **DEPRECATED** | Max character length for chat splitting. The `chatterSplit` htmlcode removed. | 2025-11-30 |
| `showmessages_replylink` | **DEPRECATED** | Show reply shortcut in legacy messages. React Messages nodelet has built-in reply. | 2025-11-30 |
| `informmsgignore` | **DEPRECATED** | Block notification method (0-3). Modern implementation shows error directly in chatterbox. | 2025-11-30 |
| `sortmyinbox` | **DEPRECATED** | Sort messages in inbox. Modern Message Inbox always sorts by most recent. | 2025-11-30 |
| `noTypoCheck` | **DEPRECATED** | Check for chatterbox command typos. Modern chatterbox validates all commands automatically. | 2025-11-30 |
| `nonodeletcollapser` | **DEPRECATED** | Disable nodelet collapsing. React nodelets always have collapsing enabled. | 2025-11-30 |

### Legacy Keys (Pre-React Migration)

| Key | Status | Notes |
|-----|--------|-------|
| `personalRaw` | **DEPRECATED** | Migrated to `noteletRaw` |
| `personalScreened` | **DEPRECATED** | Migrated to `noteletScreened` |
| `editsize` | **DEPRECATED** | Replaced by `textareaSize` |
| `ebu_showmerit` | **DEPRECATED** | Merit stat display disabled |
| `nohints` | **DEPRECATED** | Show critical writeup hints - hints system removed |
| `nohintSpelling` | **DEPRECATED** | Check for misspellings - hints system removed |
| `nohintHTML` | **DEPRECATED** | Show HTML hints - hints system removed |
| `hintXHTML` | **DEPRECATED** | Show strict HTML hints - hints system removed |
| `hintSilly` | **DEPRECATED** | Show silly hints - hints system removed |

---

## Cleanup Tasks

When migrating to JSON storage, the following cleanup should be performed:

### Phase 1: Remove Dead Code
- [x] Remove `bucketop` and `addbucket` opcodes (2025-11-30)
- [ ] Remove `nodebucket` references from showvars display

### Phase 2: Consolidate Similar Keys
- [ ] Merge `personalRaw`/`personalScreened` into `noteletRaw`/`noteletScreened`
- [ ] Standardize boolean values (some use 0/1, others use presence/absence)

### Phase 3: JSON Migration
- [ ] Define JSON schema for settings
- [ ] Create migration script to convert ampersand-separated to JSON
- [ ] Update getVars/setVars to handle JSON
- [ ] Deprecate ampersand format

---

## Database Queries

```sql
-- Find users with a specific VARS key
SELECT u.title, s.vars
FROM node u
JOIN setting s ON s.setting_id = u.node_id
WHERE s.vars LIKE '%nodebucket%';

-- Count users with deprecated keys
SELECT
  SUM(CASE WHEN vars LIKE '%nodebucket%' THEN 1 ELSE 0 END) as nodebucket_count,
  SUM(CASE WHEN vars LIKE '%personalRaw%' THEN 1 ELSE 0 END) as personalRaw_count
FROM setting;

-- Clean up a specific deprecated key (CAREFUL - backup first!)
-- UPDATE setting SET vars = REPLACE(vars, '&nodebucket=...', '') WHERE vars LIKE '%nodebucket%';
```
