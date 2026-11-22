# User VARS Reference

This document catalogs all known user VARS (settings) stored in the `setting` table's `vars` field. As we migrate away from this legacy storage format toward JSON-based settings, this reference helps track what can be cleaned up.

**Last Updated**: 2026-11-16
**Last verified: 2026-11-16** — keys cross-checked against literal reads/writes in `ecore/` and `react/` (`$VARS->{…}`, `$$VARS{…}`, `->VARS->{…}`, `$vars->{…}`, preference whitelists). "Files" lists actual readers/writers; the settings UI (`Page/settings.pm` → `Documents/Settings.js` → `POST /api/preferences/set`, whitelist in `API/preferences.pm`) is implied for any key marked **(pref)**. `Everything::Delegation::document`/`opcode` no longer exist, so earlier `document.pm`/`opcode.pm` attributions were removed.

## Storage Format

VARS are stored as ampersand-separated key=value pairs in the `setting.vars` column:
```
key1=value1&key2=value2&key3=value3
```

The `setting` table links to users via `setting_id = user.node_id`.

Encoding (`Application::getVarStringFromHash` / `getVarHashFromStringFast`): keys are sorted, values are URL-escaped; `undef` deletes a key; any **false** value (`0`, `''`) is stored as a single space and reads back as `''` — so a stored `0` comes back as empty string, not `"0"`.

## Access Methods

```perl
# Hashref access (Application.pm, remaining Delegation modules)
$VARS->{key_name}
$$VARS{key_name}
my $VARS = $APP->getVars($USER_hashref);

# Blessed object access (Controller/Page/API code) — Everything::Node::helper::setting
$REQUEST->user->VARS->{key_name}   # lazy, cached on the object
$user->VARS->{key_name}

# Setters
Everything::setVars($USER_hashref, $VARS);   # merges against a fresh DB read, in a transaction
$user->set_vars($VARS);                      # wraps Everything::setVars($self->NODEDATA, ...)
```

`setVars` deletes keys absent from the passed hash, so always pass the full VARS hash. `Everything::Controller::layout` persists in-memory VARS changes at the end of a logged-in page render (e.g. `oldexp`/`oldGP`).

---

## Active VARS Keys

### Nodelet & Sidebar Configuration

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `nodelets` | CSV node_ids | Enabled nodelet node IDs. If Epicenter is absent, its functions go in the page header. | `default_nodelets` (conf) | Application.pm, Controller.pm, Node/user.pm |
| `personal_nodelet` | `<br>`-separated titles | Personal Links nodelet list (not HTML) | Empty | PageState.pm, API/personallinks.pm |
| `collapsedNodelets` | String of `name!` tokens | Which nodelets are collapsed | Empty | Controller.pm, E2ReactRoot.js **(pref)** |
| `nodeletusergroup` | String | Usergroup shown in Usergroup Writeups nodelet | Default group | Application.pm **(pref)** |
| `vit_hide{nodeinfo,maintenance,nodeutil,list,misc}` | Boolean | Hide Vitals nodelet sections | 0 | `Application::display_preferences` → E2ReactRoot.js **(pref)** |
| `edn_hide{edev,util}` | Boolean | Hide Everything Developer nodelet sections | 0 | same **(pref)** |
| `rtn_hide{cwu,edc,nws}` | Boolean | Hide ReadThis nodelet sections | 0 | same **(pref)** |
| `epi_hideces`, `epi_hideadmins` | Boolean | Hide Master Control CE / admin sections | 0 | PageState.pm (`_build_masterControl`) |
| `hidenodenotes` | Boolean | Hide node notes in Master Control | 0 | PageState.pm **(pref)** |

### Display Preferences

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `userstyle` | node_id | Stylesheet selection | System default | Node/user.pm, the_catwalk.pm, theme_nirvana.pm **(pref)** |
| `customstyle` | CSS | User custom CSS | Empty | Node/user.pm, the_catwalk/theme_nirvana, API/customstyle.pm **(pref)** |
| `repThreshold` | 0-50 or 'none' | Hide writeups below this reputation | 'none' | **(pref)** — no reader found outside the settings UI |
| `num_newwus` | 1-40 | Number of new writeups to show | 20 | Application.pm (`display_preferences`), Node/user.pm **(pref)** |
| `nw_nojunk` | Boolean | Hide junk in New Writeups | 0 | Application.pm, E2ReactRoot.js **(pref)** |
| `noSoftLinks` | Boolean | Hide softlinks on e2node/writeup pages | 0 | Controller/e2node.pm, Node/e2node.pm **(pref)** |
| `hidenodeshells` | Boolean | Hide nodeshells in search/softlinks | 0 | **(pref)** — no reader found outside the settings UI |
| `hideauthore2node` | Boolean (inverse) | Hide who created an e2node: the page header leaves out "created by" for you | 0 (show) | Application.pm `display_preferences` → `e2.display_prefs` → PageHeader **(pref)** |

### Voting & Interactions

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `votesafety` | Boolean | Confirm before voting | 0 | Controller.pm, PageState.pm (`e2.user`), WriteupDisplay.js **(pref)** |
| `coolsafety` | Boolean | Confirm before C!ing | 0 (set to 1 at signup) | same **(pref)** |
| `anonymousvote` | 0/1/2 | Anti-bias voting display | 0 | **(pref)** — no reader found outside the settings UI |
| `cools` | Integer | C!s remaining (→ `e2.user.coolsleft`) | 0 | PageState.pm, Application.pm, Node/user.pm |
| `votetime`, `votesrefreshed` | Timestamp / Integer | Daily vote-refresh bookkeeping | - | Application.pm |

### Writeup Display Format

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `info_authorsince_off` | Boolean (inverse) | Hide how long ago the author was here | 0 (show) | Controller.pm (`build_writeup_viewer_data`), WriteupDisplay.js **(pref)** |

`wuhead`/`wufoot`/`nokillpopup` no longer have readers (only listed in `the_oracle`'s var catalog) — see Deprecated.

### Homenode / Profile

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `mission`, `motto`, `employment`, `specialties` | String | Homenode profile fields | Empty | Node/user.pm, Page/settings.pm |
| `hidemsgme` | Boolean | Hide the /msg box on your homenode | 0 | Node/user.pm, UserDisplay.js **(pref)** |
| `hidemsgyou` | Boolean | Hide "/msgs from me" link | 0 | Controller/user.pm, Controller/usergroup.pm **(pref)** |
| `hidevotedata` | Boolean | Hide "your daily votes and C!s" on your own homenode | 0 | Node/user.pm (`daily_votes_and_cools`), Controller/user.pm **(pref)** |
| `hidehomenodeUG` | Boolean | Hide your usergroups from other members (admins and you still see them; staff groups always show) | 0 | Node/user.pm (`usergroups_visible_to`) **(pref)** |
| `hidehomenodeUC` | Boolean | Hide your categories from other members (admins and you still see them) | 0 | Node/user.pm (`categories_visible_to`) **(pref)** |
| `showrecentwucount` | Boolean | Show recent writeup count | 0 | Controller/user.pm **(pref)** |
| `hidelastnoded` | Boolean (inverse) | Hide link to most recent writeup | 0 (show) | Controller/user.pm, Node/user.pm **(pref)** |
| `hidelastseen` | Boolean | Hide "last seen" | 0 | Controller/user.pm, Node/user.pm, Node/writeup.pm **(pref)** |
| `browser` | String | Last User-Agent (set at login) | - | Request.pm, Controller/user.pm |
| `bookmarks` | CSV node_ids | Bookmark ids shown on settings page | - | Page/settings.pm |

### Notifications

Per-notification-type subscriptions live in the `settings` JSON (`settings.notifications`, keyed by notification node_id; `API/preferences.pm::set_notification_preferences`). The flat keys below are separate opt-outs.

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `no_notify_kill` | Boolean (inverse) | Don't notify when writeups are deleted | 0 | API/admin.pm **(pref)** |
| `no_editnotification` | Boolean (inverse) | Don't notify on staff edits | 0 | **(pref)** — no reader found outside the settings UI |
| `no_coolnotification` | Boolean (inverse) | Don't notify on C! | 0 | API/cool.pm **(pref)** |
| `no_likeitnotification` | Boolean (inverse) | Don't notify on guest "I like it" | 0 | API/ilikeit.pm **(pref)** |
| `no_bookmarknotification` | Boolean (inverse) | Don't notify on bookmarks | 0 | API/cool.pm **(pref)** |
| `no_bookmarkinformer` | Boolean (inverse) | Don't tell others when you bookmark | 0 | API/cool.pm **(pref)** |
| `anonymous_bookmark` | Boolean | Bookmark anonymously: Cool Man Eddie's bookmark message doesn't name you (it does by default) | 0 | API/cool.pm **(pref)** |
| `no_discussionreplynotify` | Boolean (inverse) | Don't notify of usergroup discussion replies | 0 | API/debatecomments.pm, Delegation/maintenance.pm **(pref)** |
| `nosocialbookmarking` | Boolean | Hide social share buttons | 0 | Node/writeup.pm **(pref)** |

### Writeup Publishing

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `defaultpostwriteup` | Boolean | Publish immediately by default | 0 | **(pref)** — no reader found outside the settings UI |
| `HideNewWriteups` | Boolean | Hide your new writeups by default | 0 | **(pref)** — no reader found (PublishModal/InlineWriteupEditor default `hideFromNewWriteups` to false) |
| `GPoptout` | Boolean | Opt out of GP | 0 | Application.pm, PageState.pm, Node/user.pm, gift shop/wheel/bounties/sanctify APIs **(pref)** |
| `tiptap_editor_raw` | Boolean (0/1) | Default to raw HTML mode in the editor | 0 | API/preferences.pm, Page/e2_editor_beta.pm, Page/drafts.pm, `react/components/Editor/useE2Editor.js` + editor components |

### Time & Localization

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `localTimeUse` | Boolean | Enable timezone offset | 0 | Application.pm, PageState.pm, Epicenter.js |
| `localTimeOffset` | Integer | Seconds offset (-43200..+46800) | 0 | Application.pm, API/nodebackup.pm |
| `localTimeDST` | Boolean | +1 hour DST | 0 | Application.pm, API/nodebackup.pm |
| `localTime12hr` | Boolean | 12-hour format | 0 | Application.pm |

### User Statistics & Tracking

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `oldGP` | Integer | Last-seen GP (Epicenter gain display) | - | PageState.pm (`_build_epicenter`), Node/user.pm |
| `oldexp` | Integer | Last-seen XP | - | PageState.pm, Node/user.pm |
| `numwriteups` | Integer | Cached writeup count | - | Application.pm, Controller/user.pm, PageState.pm |
| `hasRecalculated` | Boolean | XP→GP recalculation done | - | API/xp.pm, Page/recalculate_xp.pm |
| `ipaddy` | String | Last-seen IP (IP logging also writes `iplog`) | - | Application.pm, API/admin.pm |
| `recaptcha_score` | Float | Signup reCAPTCHA score | - | Application.pm |
| `created_on` | Epoch | Account creation stamp | - | API/everything_s_best_users.pm |
| `preference_last_update_time` | Epoch | Set to 1 at signup; no reader found | - | Application.pm |

### Game Systems

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `easter_eggs` | Integer | Easter Egg count | 0 | Application.pm, PageState.pm, API/giftshop.pm |
| `easter_eggs_bought` | Integer | Lifetime eggs acquired | 0 | API/giftshop.pm, API/wheel.pm, Delegation/achievement.pm |
| `tokens` | Integer | Tokens | 0 | API/giftshop.pm, API/wheel.pm, Page/the_tokenator.pm |
| `tokens_bought` | Integer | Lifetime tokens acquired | 0 | API/giftshop.pm, API/wheel.pm, Delegation/achievement.pm |
| `spin_wheel` | Integer | Total wheel spins | 0 | API/wheel.pm, Delegation/achievement.pm |
| `chingbought` | Timestamp | Last ching purchase (gift shop cooldown) | - | Page/e2_gift_shop.pm, API/giftshop.pm |
| `Bounty` | Boolean | User has an open bounty | 0 | API/bounties.pm |
| `costume`, `treats` | String / Integer | Halloween costume + treat counter | - | API/costumes.pm, Application.pm |

### User State

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `borged` | Timestamp | When the user was borged (expiry 300 + 60·2·numborged s) | - | Application.pm (`expire_borg_if_due`), API/feed_edb.pm |
| `numborged` | Integer | Borg count multiplier | 1 | Application.pm |
| `lastborg` | Timestamp | Previous borg (set on expiry) | - | Application.pm |
| `lockedin` | Timestamp | Locked in until | - | Page/go_outside.pm |
| `infected` | Boolean | Infection flag | 0 | Application.pm, API/user.pm, API/signup.pm, Controller/user.pm |
| `visible` | Boolean | Cloaked in Other Users (`1` = cloaked) | 0 | Application.pm (`cloak`/`uncloak`) |
| `publicchatteroff` | Boolean | Public chatter suppressed | 0 | Application.pm |
| `infravision` | Boolean | See cloaked users in Other Users (editors/chanops implicitly) | 0 | Application.pm, Node/user.pm |

### Notelet (Personal Nodelet)

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `noteletRaw` | HTML | Raw notelet content (max 32,768 chars) | Empty | Roles/Notelet.pm, Application.pm |
| `noteletScreened` | HTML | Screened notelet for display | Empty | Application.pm (`screen_notelet`), Roles/Notelet.pm |
| `noteletLocked` | Boolean | Prevent notelet editing | 0 | Application.pm |
| `lockCustomHTML` | Boolean | Prevent custom HTML editing | 0 | Application.pm |
| `nodeletKeepComments` / `noteletKeepComments` | Boolean | Keep HTML comments. **Spelling mismatch:** `Roles/Notelet.pm` writes `nodeletKeepComments`, `Application::screen_notelet` reads `noteletKeepComments` | 0 | Roles/Notelet.pm, Application.pm |

### Chat & Messaging

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `chatmacro_*` | String | User-defined chat macros (dynamic keys) | - | Application.pm, Page/settings.pm, Page/macro_faq.pm |
| `getofflinemsgs` | Boolean | Get online-only usergroup messages while offline | 0 | Application.pm, Node/user.pm **(pref)** |
| `ugma_resettime` | Boolean | Usergroup message archive reset-time pref | 0 | API/usergroup_message_archive.pm |

### Everything's Best Users Page

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `ebu_showdevotion` | Boolean | Show devotion stat | 0 | API/everything_s_best_users.pm, EverythingsBestUsers.js |
| `ebu_showaddiction` | Boolean | Show addiction stat | 0 | same |
| `ebu_newusers` | Boolean | Show new users | 0 | same |
| `ebu_showrecent` | Boolean | Show recent | 0 | same |

### Content & Node Relationships

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `nodetrail` | CSV node_ids | Recently visited nodes (Recent Nodes nodelet) | - | PageState.pm (`_build_recentNodes`), Application.pm |
| `unfavoriteusers` | CSV user_ids | Authors hidden in New Writeups | - | Application.pm, API/userinteractions.pm |
| `can_weblog` | CSV node_ids | Weblog destinations | - | Node.pm, Node/user.pm, API/weblog.pm, API/weblogmenu.pm |
| `nameifyweblogs`, `hidden_weblog` | Boolean | Weblog menu display prefs | 0 | API/weblogmenu.pm, Page/edit_weblog_menu.pm |

### Utility Tool Settings

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `alphabetizer_sep` / `_case` / `_sortorder` / `_format` | mixed | Alphabetizer tool options | - | Page/alphabetizer.pm |
| `sqlprompt_wrap` | 0-3 | SQL output format | 0 | Page/sql_prompt.pm, SQLPrompt.js **(pref)** |
| `EDD_Sort` | String | Everything Document Directory sort (0, idA/idD, nameA/nameD, authorA/authorD, createA/createD) | 0 | API/everything_document_directory.pm; written via /api/preferences/set |
| `ListNodesOfType_Type` | Integer | Last node type in List Nodes of Type | - | Page/list_nodes_of_type.pm **(pref)** |
| `ListNodesOfType_Sort` | String | Listing sort (read by The Catwalk) | 0 | Page/the_catwalk.pm |
| `showuseractions` | Boolean | Show user actions in Other Users | 0 | Application.pm (`buildOtherUsersData`) |

### Modern Settings (JSON)

| Key | Type | Description | Default | Files |
|-----|------|-------------|---------|-------|
| `settings` | JSON | Structured settings; currently `notifications` map | {} | API/preferences.pm, Application.pm |

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

These keys are no longer used and can be cleaned up from user settings.

> **Still wired in code (2026-11-16):** these deprecated keys remain in the `API/preferences.pm`
> whitelist **and** the `Page/settings.pm` payload, so the settings UI can still write them:
> `fxDuration`, `noquickvote`, `nonodeletcollapser`, `textareaSize`, `nullvote`, `noreplacevotebuttons`,
> `nogradlinks`, `sortmyinbox`, `noTypoCheck`, `informmsgignore`, `nohints`, `nohintSpelling`, `nohintHTML`,
> `hintXHTML`, `hintSilly`; `killfloor_showlinks` is whitelist-only. `noquickvote`/`nonodeletcollapser` are
> also still emitted as `e2.noquickvote`/`e2.nonodeletcollapser` (no React consumer). `showmessages_replylink`
> is still set to 1 for new users at signup. Cleanup candidates.
>
> **No reader found (not formally deprecated):** `wuhead`, `wufoot`, `nokillpopup`, `bookbucket`,
> `sqlprompt_nocount`, `autoChat` (only `react/test-utils.js`), `inactiveWindowMarker` — only mentioned in
> `Page/the_oracle.pm`'s var catalog, if at all.

### Removed in 2026-06 (socialBookmark opcode retirement, #4332)

The external-site social-bookmark *notifier* (Cool Man Eddie messaging authors when
their writeup was bookmarked to del.icio.us/Digg-era sites) was a dead feature with no
dispatch. Retiring its opcode + notification handler orphaned these two prefs. **Drop
both during the JSON conversion** — nothing reads them anymore.

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `no_socialbookmarknotification` | **DEPRECATED** | "Tell me when my writeups get bookmarked on a social bookmarking site." Only the retired `socialBookmark` opcode/notification consumed it. | 2026-06-20 |
| `no_socialbookmarkinformer` | **DEPRECATED** | "Tell others when I bookmark a writeup on a social bookmarking site." Read only by the retired `socialBookmark` opcode. | 2026-06-20 |

> **Not deprecated (still live), despite similar names:** `nosocialbookmarking` gates the
> Facebook/X/Reddit *share* buttons on writeups (`WriteupDisplay.js`), and
> `no_bookmarknotification` gates the *internal* bookmark notification (`Everything::API::cool`).
> Keep both.

### Removed in 2026-05 (Favorite Noders Cap)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `favorite_limit` | **DEPRECATED** | How many favorite-noder writeups to fetch per page. Server now hardcodes 5 to match the React nodelet's display cap (#3765). Previously defaulted to 15 and could be bumped to 50, causing wasted DB lookups + payload on every page load. | 2026-05-25 |

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
| `personalRaw` | **DEPRECATED** | Migrated to `noteletRaw` on notelet save (`Roles/Notelet.pm`) |
| `personalScreened` | **DEPRECATED** | Migrated to `noteletScreened` |
| `editsize` | **DEPRECATED** | Replaced by `textareaSize` |
| `ebu_showmerit` | **DEPRECATED** | Merit stat display disabled |

### Removed in 2026-01 (Writeup Hints Removal)

| Key | Status | Notes | Removal Date |
|-----|--------|-------|--------------|
| `nohints` | **DEPRECATED** | Show critical writeup hints - hints system removed. UI removed from Settings. | 2026-01-17 |
| `nohintSpelling` | **DEPRECATED** | Check for misspellings - hints system removed. UI removed from Settings. | 2026-01-17 |
| `nohintHTML` | **DEPRECATED** | Show HTML hints - hints system removed. UI removed from Settings. | 2026-01-17 |
| `hintXHTML` | **DEPRECATED** | Show strict HTML hints - hints system removed. UI removed from Settings. | 2026-01-17 |
| `hintSilly` | **DEPRECATED** | Show silly hints - hints system removed. UI removed from Settings. | 2026-01-17 |

---

## Cleanup Tasks

When migrating to JSON storage, the following cleanup should be performed:

### Phase 1: Remove Dead Code
- [x] Remove `bucketop` and `addbucket` opcodes (2025-11-30)
- [ ] Remove `nodebucket`/`bookbucket`/`settings_useTinyMCE` entries from `Page/the_oracle.pm`'s var catalog
- [ ] Drop deprecated keys from the `API/preferences.pm` whitelist and `Page/settings.pm` payload (list above)

### Phase 2: Consolidate Similar Keys
- [~] Merge `personalRaw`/`personalScreened` into `noteletRaw`/`noteletScreened` (on-save migration exists in `Roles/Notelet.pm`)
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
