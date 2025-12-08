# User VARS Reference

This document catalogs all known user VARS (settings) stored in the `setting` table's `vars` field. As we migrate away from this legacy storage format toward JSON-based settings, this reference helps track what can be cleaned up.

**Last Updated**: 2025-11-30

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

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `nodelets` | CSV node_ids | Comma-separated list of enabled nodelet node IDs | Controller.pm, Application.pm |
| `personal_nodelet` | HTML | User's custom nodelet HTML content | htmlcode.pm |
| `collapsedNodelets` | String | Tracks which nodelets are collapsed | Controller.pm |

### Display Preferences

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `repThreshold` | 0-50 or 'none' | Hide writeups below this reputation | document.pm, htmlcode.pm |
| `textareaSize` | 0/1/2 | Writeup editor size (small/medium/large) | htmlcode.pm |
| `num_newwus` | 1-40 | Number of new writeups to show (default: 15) | Application.pm |
| `noquickvote` | Boolean | Disable AJAX quick voting | Controller.pm, Application.pm |
| `nonodeletcollapser` | Boolean | Disable nodelet collapse buttons | Controller.pm, Application.pm |
| `nosocialbookmarking` | Boolean | Disable social sharing buttons | document.pm |
| `hidenodeshells` | Boolean | Hide nodeshell (incomplete) nodes | Application.pm |

### Writeup Display Format

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `wuhead` | Format codes | Metadata displayed above writeups (c:type,c:author,etc.) | document.pm |
| `wufoot` | Format codes | Metadata displayed below writeups | document.pm |
| `nokillpopup` | Boolean | Suppress popup when killing writeups | opcode.pm |
| `anonymousvote` | 0/1/2 | Voting anonymity (0=show, 1=hide, 2=hide with link) | htmlcode.pm |

### Time & Localization

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `localTimeUse` | Boolean | Enable timezone offset calculations | Application.pm |
| `localTimeOffset` | Integer | Hours offset from server time | Application.pm |
| `localTimeDST` | Boolean | Apply Daylight Saving Time adjustment | Application.pm |
| `localTime12hr` | Boolean | Use 12-hour time format | Application.pm |

### User Statistics & Tracking

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `oldGP` | Integer | Cached GP for change detection notifications | Application.pm |
| `oldexp` | Integer | Cached XP for change detection notifications | Application.pm |
| `numwriteups` | Integer | Cached writeup count for Node-Fu calculation | Application.pm |
| `favorite_limit` | Integer | How many favorites to show (default: 15) | document.pm |

### Game Systems

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `easter_eggs` | Integer | Current Easter Egg count (game currency) | Application.pm, document.pm |
| `easter_eggs_bought` | Integer | Lifetime Easter Eggs acquired | Application.pm |
| `tokens` | Integer | Virtual tokens from wheel spins | Application.pm |
| `tokens_bought` | Integer | Lifetime tokens acquired | Application.pm |
| `spin_wheel` | Integer | Total wheel spins (1000+ = achievement) | API/wheel.pm |

### User State

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `borged` | Timestamp | Unix timestamp when user was "borged" | Application.pm |
| `numborged` | Integer | Borg duration multiplier (300 + 60*N seconds) | Application.pm |
| `lockedin` | Timestamp | Unix timestamp until user is locked | Application.pm |
| `infected` | Boolean | User infection status flag | Application.pm |

### Notelet (Personal Nodelet)

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `noteletRaw` | HTML | Raw user notelet content (max 32,768 chars) | htmlcode.pm |
| `noteletScreened` | HTML | Processed/rendered notelet for display | htmlcode.pm |
| `noteletLocked` | Boolean | Prevent notelet editing | htmlcode.pm |
| `noteletKeepComments` | Boolean | Keep HTML comments when editing | htmlcode.pm |
| `lockCustomHTML` | Boolean | Prevent custom HTML editing | htmlcode.pm |

### Chat & Messaging

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `splitChatter` | Integer | Max character length for chat message splitting | htmlcode.pm |
| `chatmacro_*` | String | User-defined chat macros (dynamic keys) | htmlcode.pm |
| `hidemsgme` | Boolean | Prevent "send message" on homenode | document.pm |
| `showmessages_replylink` | Boolean | Show reply shortcut (default: enabled) | htmlcode.pm |
| `informmsgignore` | 0/1/2/3 | **DEPRECATED** Block notification method: 0=private message, 1=chatterbox (deprecated), 2=both (deprecated), 3=none. Values 1 and 2 are treated as 0 (private message only). Modern implementation shows error directly in chatterbox when user tries to send message to blocked user. | Application.pm, preferences.pm |
| `sortmyinbox` | Boolean | **DEPRECATED** Sort messages in inbox. Modern Message Inbox always sorts by most recent first (newest at top). Setting no longer has any effect. | document.pm, preferences.pm |
| `noTypoCheck` | Boolean | **DEPRECATED** Check for chatterbox command typos (e.g., /mgs instead of /msg). Modern chatterbox automatically validates all commands - messages starting with "/" are processed as commands and show errors if invalid. Protection is now built-in. | document.pm, preferences.pm |
| `nonodeletcollapser` | Boolean | **DEPRECATED** Disable nodelet collapsing. Modern React nodelets always have collapsing enabled - clicking nodelet titles toggles content visibility. This is a core UX feature that cannot be disabled. | Application.pm, preferences.pm |

### Vitals Nodelet Preferences

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `vit_hidemaintenance` | Boolean | Hide maintenance sections | API/preferences.pm |
| `vit_hidenodeinfo` | Boolean | Hide node info sections | API/preferences.pm |
| `vit_hidenodeutil` | Boolean | Hide node utility sections | API/preferences.pm |
| `vit_hidelist` | Boolean | Hide list sections | API/preferences.pm |
| `vit_hidemisc` | Boolean | Hide miscellaneous sections | API/preferences.pm |

### Epicenter Preferences

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `cools` | Integer | "Cool" count displayed in Epicenter | htmlcode.pm |
| `ebu_showdevotion` | Boolean | Show devotion stat | htmlcode.pm |
| `ebu_showaddiction` | Boolean | Show addiction stat | htmlcode.pm |
| `ebu_newusers` | Boolean | Show new users section | htmlcode.pm |
| `ebu_showrecent` | Boolean | Show recent writeups section | htmlcode.pm |

### Content & Node Relationships

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `nodetrail` | CSV node_ids | Breadcrumb trail of recently visited nodes | Application.pm |
| `unfavoriteusers` | CSV user_ids | Users to hide/deemphasize | htmlcode.pm |
| `can_weblog` | CSV node_ids | Weblog destinations user can post to | htmlcode.pm |
| `bookbucket` | CSV node_ids | Bookmarked nodes | document.pm |

### New Writeups Preferences

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `nw_nojunk` | Boolean | Hide junk writeups in New Writeups | API/preferences.pm |
| `edn_hideutil` | Boolean | Hide utility sections | API/preferences.pm |
| `edn_hideedev` | Boolean | Hide edev sections | API/preferences.pm |

### UI Behavior (Cookie-synced)

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `fxDuration` | Integer | Animation duration (0=instant, 100-1000ms) | Controller.pm |
| `settings_useTinyMCE` | Boolean | Enable WYSIWYG editor | Controller.pm |
| `autoChat` | Boolean | Auto-chat feature flag | Controller.pm |
| `inactiveWindowMarker` | Boolean | Inactive window marker flag | Controller.pm |

### Editor Preferences

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `tiptap_editor_raw` | Boolean (0/1) | Default to raw HTML mode in E2 Editor Beta (0=rich text, 1=HTML) | API/preferences.pm, Page/e2_editor_beta.pm |

### Utility Tool Settings

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `alphabetizer_sep` | String | Separator for alphabetizer tool | document.pm |
| `alphabetizer_case` | Boolean | Case-insensitive sorting | document.pm |
| `alphabetizer_sortorder` | Boolean | Reverse sort order | document.pm |
| `alphabetizer_format` | Boolean | Convert to E2 links | document.pm |
| `sqlprompt_wrap` | 0-3 | SQL output format | document.pm |
| `sqlprompt_nocount` | Boolean | Hide row count in SQL | document.pm |
| `EDD_Sort` | String | Sort order preference for Everything Document Directory (0=default, idA/idD=node_id asc/desc, nameA/nameD=title asc/desc, authorA/authorD=author asc/desc, createA/createD=createtime asc/desc) | Page/everything_document_directory.pm |

### Modern Settings (JSON)

| Key | Type | Description | Files |
|-----|------|-------------|-------|
| `settings` | JSON | Structured settings object for new features | API/preferences.pm |
| `preference_last_update_time` | Epoch | Cache invalidation timestamp | API/preferences.pm |

---

## Deprecated VARS Keys

These keys are no longer used and can be cleaned up from user settings:

### Removed in 2025-12 (React Migration)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `killfloor_showlinks` | **DEPRECATED** | Add HTML links in killing floor display for copy/paste. The killing floor mechanism is no longer used. | 2025-12-07 |

### Removed in 2025-11 (Nodelet Migration)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `nodebucket` | **DEPRECATED** | Legacy node bucket feature removed | 2025-11-30 |
| `mitextarea` | **DEPRECATED** | Larger Message Inbox textarea - no longer needed since all message sending moved to React modals | 2025-11-30 |

### Legacy Keys (Pre-React Migration)

| Key | Status | Notes |
|-----|--------|-------|
| `personalRaw` | **DEPRECATED** | Migrated to `noteletRaw` |
| `personalScreened` | **DEPRECATED** | Migrated to `noteletScreened` |
| `editsize` | **DEPRECATED** | Replaced by `textareaSize` |
| `ebu_showmerit` | **DEPRECATED** | Merit stat display disabled |

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
