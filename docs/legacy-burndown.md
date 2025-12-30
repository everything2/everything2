# Legacy Code Burn Down List

**Created**: 2025-12-28
**Purpose**: Track remaining legacy code that can be retired as React/API migrations complete

This document identifies legacy htmlcodes, JavaScript, and form-based interactions that can be removed or migrated to the modern React/API architecture.

---

## Executive Summary

| Category | Total Items | Safe to Remove | Conditional | Active/Keep |
|----------|-------------|----------------|-------------|-------------|
| Dead Htmlcodes | 3 | 3 | 0 | 0 |
| Legacy Message System | 6 | 0 | 6 | 0 |
| formxml Variants | 8 | 0 | 8 | 0 |
| Security Htmlcodes | 1 | 0 | 0 | 1 |
| legacy.js Functions | 65 | 8 | 26 | 31 |
| jQuery/jQuery UI | 2 libs | 0 | 2 | 0 |

**Estimated line reduction**:
- Perl htmlcodes: ~1,500 lines (Phase 1-3)
- legacy.js dead code: ~100 lines (immediate)
- legacy.js conditional: ~800 lines (after TipTap migration)
- jQuery migration: ~400 net lines (after vanilla JS conversion)
- Already removed: ~400 lines chatterbox code (December 2025)

**Library bandwidth savings** (after jQuery removal):
- jQuery 1.11.1: 95KB minified
- jQuery UI 1.11.1: 240KB minified
- **Total**: 335KB per authenticated page load

---

## Part 1: Dead Htmlcodes (Safe to Remove Immediately)

These htmlcodes have **zero active callers** and are completely replaced by React components.

### 1.1 `showchatter` (htmlcode.pm:4781)

**Status**: DEAD - Fully replaced by React Chatterbox component

**Evidence**:
- No active calls in production code
- Only references are in legacy.js comments
- React component (`react/components/Nodelets/Chatterbox.js`) receives data directly from Application.pm

**Known Regression**: Dynamic egg commands (`/beer`, `/coffee`, `/hug`, etc. from `egg commands` setting) will lose special formatting when showchatter is removed. Messages stored as `/beer target` will display raw instead of "username buys target a beer". Low priority - egg commands are rarely used and the regression is cosmetic only.

**Action**: Delete function (approximately 220 lines)

### 1.2 `showmessages` (htmlcode.pm:5005)

**Status**: DEAD - Fully replaced by React MessageInbox component

**Evidence**:
- No active calls in production code
- React `MessageInbox.js` and `Messages.js` components handle all message display
- Data flows through `/api/messages` endpoints

**Action**: Delete function (approximately 240 lines)

### 1.3 `borgcheck` (htmlcode.pm:4144)

**Status**: DEAD - Data passed directly to React Epicenter component

**Evidence**:
- Application.pm passes `borgcheck` data structure directly to React
- React Epicenter component receives object with `borged/numborged/currentTime`
- No htmlcode() function calls exist in active code

**Action**: Delete function (approximately 30 lines)

### 1.4 `votehead` / `votefoot` ~~(htmlcode.pm:2065, 3456)~~ **REMOVED 2025-12-28**

**Status**: ✅ REMOVED - Replaced by React WriteupDisplay voting UI

**Evidence**:
- No active callers in production code (only in documentation)
- React `WriteupDisplay.js` handles voting via `/api/vote/writeup/:id` API
- Legacy form submission with `op=vote` no longer needed

**Lines removed**: ~45 lines

---

## Part 2: Legacy Message System (Conditional Retirement)

These components form the legacy message/chat form system. They require React component replacements before removal.

### 2.1 `msgField` (htmlcode.pm:8245)

**Status**: LEGACY - Still has 4 active call sites

**Call Sites**:
| File | Line | Context |
|------|------|---------|
| htmlpage.pm | 1272 | Usergroup page - message to group owner |
| htmlpage.pm | 1279 | Usergroup page - message to group leader |
| htmlpage.pm | 1292 | Usergroup page - message entire usergroup |
| htmlpage.pm | 1301 | Usergroup page - general message field |

**Migration Path**:
1. Create React `<MessageField>` component
2. Add to `react/components/Documents/Usergroup.js`
3. Use `/api/messages/send` endpoint
4. Remove htmlpage.pm calls
5. Delete msgField htmlcode

**Estimated Effort**: 2-3 hours

### 2.2 `messageBox` (htmlcode.pm:9943)

**Status**: LEGACY - 1 internal call from htmlcode.pm:9396

**Context**: Displays message compose box on user homepages (the "send message to this user" feature)

**Current Implementation**:
```perl
class="expandable ajax replyto$messageID:messageBox:$userID,$showCC,$messageID,$usergroupID"
```

**Migration Path**:
1. Create React `<UserMessageBox>` component
2. Integrate into user display page
3. Use `/api/messages/send` endpoint
4. Remove messageBox htmlcode

**Estimated Effort**: 2-3 hours

### 2.3 `borgspeak` (htmlcode.pm:9840)

**Status**: INTERNAL - Only called by `showchatter` (which is dead)

**Purpose**: Generates random Borg quotes when no chatter messages exist

**Action**: Delete after `showchatter` is removed

**Estimated Effort**: Immediate (approximately 100 lines)

### 2.4 `eddiereply` (htmlcode.pm:5251)

**Status**: INTERNAL - Only called by `showmessages` (which is dead)

**Purpose**: Special formatting for Cool Man Eddie automated messages

**Action**: Delete after `showmessages` is removed

**Estimated Effort**: Immediate (approximately 80 lines)

### 2.5 `writeupmessage` (htmlcode.pm:10328)

**Status**: INTERNAL - Called from htmlcode.pm:6295

**Purpose**: Handles posting messages to writeup authors (the "blab" feature)

**Migration Path**:
1. Create API endpoint for writeup messages (or extend `/api/messages`)
2. Update writeup display React component
3. Remove writeupmessage htmlcode

**Estimated Effort**: 3-4 hours

### 2.6 `sendPrivateMessage` (htmlcode.pm:6784)

**Status**: LEGACY - Core message sending function

**Purpose**: Processes message POST submissions from legacy forms

**Notes**:
- Large function (~700 lines)
- Called by various legacy forms
- Modern equivalent: `Application.pm->send_message()`

**Migration Path**:
1. Ensure all callers use `/api/messages/send` instead
2. Verify no direct POST submissions remain
3. Delete sendPrivateMessage htmlcode

**Estimated Effort**: 4-6 hours (due to verification needed)

---

## Part 3: formxml Variants (Low Priority)

These provide legacy XML export functionality. Removal depends on whether XML export is still needed.

| Htmlcode | Line | Purpose | Usage |
|----------|------|---------|-------|
| formxml | 7580 | Main dispatcher | htmlpage.pm:1803, Controller.pm:39-41 |
| formxml_user | 7599 | User XML export | Indirect via formxml |
| formxml_e2node | 7729 | E2node XML export | Indirect via formxml |
| formxml_writeup | 7840 | Writeup XML export | Indirect via formxml |
| formxml_superdoc | 7888 | Superdoc XML export | Indirect via formxml |
| formxml_usergroup | 8056 | Usergroup XML export | Indirect via formxml |
| formxml_room | 8535 | Room XML export | Indirect via formxml |
| formxml_superdocnolinks | 8556 | Superdoc XML (no links) | Indirect via formxml |

**Decision Needed**: Is XML export still a needed feature? If not, all 8 functions (~400 lines) can be removed.

---

## Part 4: Security Htmlcodes (DO NOT REMOVE)

### 4.1 `screenNotelet` (htmlcode.pm:7964)

**Status**: ACTIVE - Critical security function

**Call Sites**:
- Application.pm:6872
- notelet_editor.pm:92

**Purpose**: XSS filtering for notelet content (strips `<script>` tags)

**Test Coverage**: t/055_notelet_script_filtering.t

**Action**: KEEP - Required for security

---

## Part 5: legacy.js Detailed Analysis

**Current State**: 2,627 lines (was 2,697)

**Already Removed** (December 2025):
- Lines 1711-2109 (~400 lines) - Legacy chatterbox polling, message parsing, rendering
- All chatterbox pages (chatterlight, chatterlight_classic, chatterlighter) are now React
- **Phase J1 Complete (2025-12-29)**: Removed 70 lines of dead jQuery code

---

### 5.1 Safe to Remove (Dead Code)

| Function/Section | Lines | Purpose | Status |
|-----------------|-------|---------|--------|
| `replyToCB()` | 6-19 | Legacy chatterbox reply helper | ✅ REMOVED 2025-12-29 |
| `replyTo()` | 1763-1768 | Message Inbox 2 reply function | ✅ REMOVED 2025-12-29 |
| `clearReply()` | 1770-1772 | Message Inbox 2 clear | ✅ REMOVED 2025-12-29 |
| `checkAll()` | 1774-1779 | Message Inbox 2 select all | ✅ REMOVED 2025-12-29 |
| `ts_getInnerText()` (duplicate) | 1521-1541, 1544-1563 | Table sorting helper | Pending - duplicate function definitions |
| Removed chatter code comments | 1706-1722 | Comments documenting removed code | ✅ REMOVED 2025-12-29 |
| `contentRefreshInterval`, `statusId` | 1719-1720 | Legacy chatterbox globals | ✅ REMOVED 2025-12-29 |
| `InDebugMode()` | 1714-1716 | Chatterlight debug helper | ✅ REMOVED 2025-12-29 |

**Phase J1 Complete**: 70 lines removed, ~30 lines remaining (duplicate ts_getInnerText)

---

### 5.2 Conditional Removal (Needs Verification)

| Function/Section | Lines | Purpose | Dependencies |
|-----------------|-------|---------|--------------|
| **tinyMCE Settings** | 87-107 | WYSIWYG editor config | Check if tinyMCE is still used anywhere; TipTap now primary editor |
| **e2.htmlFormattingAids** | 487-571 | tinyMCE/QuickTags toggle | Same as above - may be dead |
| **edToolbar/edButtons** | 1818-2609 | JS QuickTags HTML toolbar | See deep-dive analysis below |
| **Bookmark sortlist** | 1502-1654 | Bookmark sorting functions | Only used on legacy bookmark edit page |
| **Settings script** | 1433-1498 | Theme preview, nodelet drag | May still be used on Settings page |

**Conditional Removal Total**: ~800 lines (if TipTap fully replaces legacy editors)

---

### 5.2.1 Deep Dive: edButtons/edToolbar System

The JS QuickTags system (`edToolbar`/`edButtons`) is a legacy HTML formatting toolbar that provides quick-insert buttons for E2-specific markup (bold, italic, links, blockquotes, etc.).

**How it works**:
1. Textareas with `class="formattable"` trigger `e2.htmlFormattingAids` (line 584)
2. `htmlFormattingAids` can activate either tinyMCE (WYSIWYG) or `edToolbar` (QuickTags)
3. User preference stored in `settings_useTinyMCE` user var
4. `edToolbar(id)` function renders button bar above the textarea (line 2334)
5. `edButtons` array defines 26 formatting buttons (lines 1818-2120)

**Current Usage - `.formattable` textareas**:

| Location | File | Line | Status |
|----------|------|------|--------|
| **writeup_doctext** | htmlcode.pm `editwriteup` | 10640 | **REPLACED** - InlineWriteupEditor (TipTap) on E2NodeDisplay, Writeup, Draft pages |
| **user_doctext** | htmlpage.pm user edit | 767 | **ACTIVE** - User bio editing on user display page (legacy) |
| **category_doctext** | htmlpage.pm category edit | 2994 | **ACTIVE** - Category description editing (legacy form) |
| **CreateCategory.js** | React component | 193 | **DEAD CLASS** - Has `formattable` class but React doesn't trigger `htmlFormattingAids` (should be removed) |

**Migration Status**:
- **E2Node/Writeup pages**: ✅ COMPLETE - `InlineWriteupEditor.js` uses TipTap with its own toolbar
- **Draft page**: ✅ COMPLETE - `InlineWriteupEditor.js` embedded
- **E2 Editor Beta**: ✅ COMPLETE - `EditorBeta.js` uses TipTap with full toolbar
- **User bio editing**: ❌ PENDING - Still uses legacy htmlpage with `class="formattable"`
- **Category editing**: ❌ PENDING - Still uses legacy htmlpage with `class="formattable"`

**tinyMCE Status**:
- External library: `https://s3-us-west-2.amazonaws.com/jscssw.everything2.com/tiny_mce/tiny_mce.js`
- User preference `settings_useTinyMCE` still tracked in Controller.pm (line 137)
- **Marked DEPRECATED** in user-vars-reference.md
- Cookie deleted on every page load (line 1434): `e2.deleteCookie('settings_useTinyMCE')`

**Removal Blockers**:
1. **User bio editing** - Need React UserEdit page or inline TipTap editor
2. **Category editing** - Need React CategoryEdit page or migrate to API
3. Both require new Everything::Page classes + React components

**Removal Order**:
1. Create React UserEdit component → Remove user_doctext formattable
2. Create React CategoryEdit component → Remove category_doctext formattable
3. Remove `e2.htmlFormattingAids` (lines 487-571)
4. Remove `edToolbar`/`edButtons` system (lines 1818-2609)
5. Remove tinyMCE settings (lines 87-107)
6. Remove `settings_useTinyMCE` user var from preferences.pm

**Impact**: ~850 lines removal from legacy.js after user/category editing migrated

**edButtons Definition (26 active buttons)**:

| ID | Label | Tag | Description |
|----|-------|-----|-------------|
| ed_strong | b | `<strong>` | Bold text |
| ed_em | i | `<em>` | Italics (emphasis) |
| ed_hardlink | link | `[...]` | E2 hard link |
| ed_pipe_link | pipe link | `[...\|...]` | Pipe link (display different from target) |
| ed_ul | ul | `<ul>` | Bulleted list |
| ed_ol | ol | `<ol>` | Numbered list |
| ed_li | li | `<li>` | List item |
| ed_block | b-quote | `<blockquote>` | Block quote |
| ed_h1 | h1 | `<h1>` | Top-level heading |
| ed_h2 | h2 | `<h2>` | Second-level heading |
| ed_h3 | h3 | `<h3>` | Third-level heading |
| ed_h4 | h4 | `<h4>` | Fourth-level heading |
| ed_p | p | `<p>` | Paragraph |
| ed_code | code | `<code>` | Inline code |
| ed_pre | pre | `<pre>` | Pre-formatted text |
| ed_dl | dl | `<dl>` | Definition list |
| ed_dt | dt | `<dt>` | Definition title |
| ed_dd | dd | `<dd>` | Definition description |
| ed_ins | ins | `<ins>` | Inserted text |
| ed_del | del | `<del>` | Deleted/strikethrough text |

*Commented out buttons*: ed_link (duplicate), ed_img (no images), ed_table/ed_tr/ed_td (tables not allowed), ed_nobr, ed_footnote, ed_via

**TipTap Equivalent Coverage**:
All of these buttons have TipTap equivalents in `InlineWriteupEditor.js` and `EditorBeta.js`:
- Text formatting: Bold, Italic via TipTap marks
- Links: E2LinkExtension handles `[link]` and `[link|display]` syntax
- Lists: TipTap BulletList, OrderedList, ListItem
- Headings: TipTap Heading extension (levels 1-6)
- Block elements: TipTap Blockquote, CodeBlock
- Definition lists: Currently handled as raw HTML in TipTap

**Conclusion**: TipTap provides complete parity with edToolbar. Once user/category editing is migrated to React, the entire edToolbar system can be removed

---

### 5.3 Active/Required Code (DO NOT REMOVE)

| Function/Section | Lines | Purpose | Why Required |
|-----------------|-------|---------|--------------|
| **e2URL class** | 22-76 | URL parameter parser | Used by `setLastnode` for link tracking |
| **e2 core extensions** | 82-116 | Base e2 object setup | Required for all e2.* functions |
| **Full text search** | 123-163 | Adds full-text search checkbox | Active feature on search form |
| **e2.activate/add** | 177-246 | jQuery plugin binding system | Core to legacy UI still in use |
| **e2.periodical** | 259-300 | Interval management | Used by remaining AJAX features |
| **Cookie helpers** | 307-324 | getCookie/setCookie/deleteCookie | Used by theme preview, settings |
| **e2.confirmop** | 399-423 | Confirmation dialogs | Used by vote buttons, admin actions |
| **expandable inputs** | 593-658 | Auto-expanding textareas | Used on writeup forms |
| **widgets** | 660-715 | Show/hide widget triggers | Used on various settings panels |
| **readonly textarea** | 717-730 | Prevent editing readonly fields | Used in draft review |
| **wuformaction** | 732-746 | Writeup form op switching | Used by vote/category forms |
| **lastnode tracking** | 749-773 | Add lastnode_id to links | Active softlink tracking |
| **beforeunload warning** | 776-827 | Unsaved changes warning | Active for all textareas |
| **e2.ajax.*** | 831-1231 | Core AJAX framework | Used by voting, forms, nodelets |
| **sortable nodelets** | 1332-1358 | Drag-drop nodelet reordering | Active feature |
| **ajax triggers** | 1360-1420 | AJAX form binding | Used by vote buttons, forms |
| **#messagebox submit** | 1677-1710 | API-based message box | Modern replacement (uses /api/messages) |
| **linknodetitle** | 1658-1675 | E2 link parsing | Used by e2.linkparse |
| **EncodeHtml/DecodeHtml** | 1742-1748 | HTML entity helpers | Generic utility |
| **SwapGravatars** | 1750-1757 | Gravatar type switcher | Used on settings |
| **GA4 analytics** | 2611-2646 | Google Analytics tracking | Active analytics |
| **toggleEditorCool/Bookmark** | 2648-2696 | Page header buttons | Active until React header |

**Active Code Total**: ~1,400 lines (must keep)

---

### 5.4 legacy.js Removal Priority

**Phase 1: Dead Code Cleanup (~100 lines)**
```javascript
// Remove these immediately:
- replyToCB() - lines 6-19
- replyTo(), clearReply(), checkAll() - lines 1763-1779
- Duplicate ts_getInnerText() - lines 1544-1563
- InDebugMode() - lines 1714-1716
- contentRefreshInterval, statusId - lines 1719-1720
- REMOVED: comments - lines 1246-1304
```

**Phase 2: Editor Cleanup (~800 lines, after TipTap migration)**
```javascript
// Verify TipTap covers all use cases, then remove:
- e2.tinyMCESettings - lines 87-107
- e2.htmlFormattingAids - lines 487-571
- edToolbar system - lines 1818-2609
- e2.divertWrite - lines 458-483
```

**Phase 3: Form Migration (~300 lines, after React forms)**
```javascript
// After all legacy forms are React:
- e2.ajax.* framework - lines 831-1231
- wuformaction handler - lines 732-746
- Most of beforeunload warnings - lines 776-827
```

---

### 5.5 legacy.js Function Reference

For tracking purposes, here's every function defined in legacy.js:

| Function | Line | Status |
|----------|------|--------|
| `replyToCB` | 6 | DEAD |
| `e2URL` (class) | 22 | ACTIVE |
| `e2.inclusiveSelect` | 182 | ACTIVE |
| `e2.add` | 191 | ACTIVE |
| `e2.activate` | 200 | ACTIVE |
| `e2.getUniqueId` | 250 | ACTIVE |
| `e2.periodical` | 259 | ACTIVE |
| `e2.now` | 303 | ACTIVE |
| `e2.getCookie` | 307 | ACTIVE |
| `e2.setCookie` | 312 | ACTIVE |
| `e2.deleteCookie` | 322 | ACTIVE |
| `e2.getFocus` | 328 | ACTIVE |
| `e2.getSelectedText` | 336 | ACTIVE |
| `e2.heightToScrollHeight` | 345 | ACTIVE |
| `e2.startText` | 353 | ACTIVE |
| `e2.vanish` | 368 | ACTIVE |
| `e2.setLastnode` | 378 | ACTIVE |
| `e2.confirmop` | 399 | ACTIVE |
| `e2.loadScript` | 427 | ACTIVE |
| `e2.doWithLibrary` | 441 | CONDITIONAL |
| `e2.divertWrite` | 458 | CONDITIONAL |
| `e2.htmlFormattingAids` | 487 | CONDITIONAL |
| `e2.iebuttonfix` | 574 | DEAD (IE7) |
| `expandableTextarea` | 627 | ACTIVE |
| `expandableInput` | 634 | ACTIVE |
| `e2.ajax.htmlcode` | 848 | ACTIVE |
| `e2.ajax.update` | 886 | ACTIVE |
| `e2.ajax.varChange` | 907 | ACTIVE |
| `e2.ajax.starRateNode` | 913 | ACTIVE |
| `e2.ajax.addRobot` | 926 | ACTIVE |
| `e2.ajax.addList` | 968 | ACTIVE |
| `e2.ajax.listManager` | 979 | ACTIVE |
| `e2.ajax.updateList` | 989 | ACTIVE |
| `e2.ajax.insertListItem` | 1024 | ACTIVE |
| `e2.ajax.removeListItem` | 1050 | ACTIVE |
| `e2.ajax.dismissListItem` | 1058 | ACTIVE |
| `e2.ajax.periodicalUpdater` | 1072 | ACTIVE |
| `e2.ajax.updateTrigger` | 1080 | ACTIVE |
| `e2.ajax.triggerUpdate` | 1117 | ACTIVE |
| `ts_getInnerText` | 1521 | CONDITIONAL |
| `parse_list_to_array` | 1565 | CONDITIONAL |
| `sort` | 1588 | CONDITIONAL |
| `mysortfn_by_attribute` | 1627 | CONDITIONAL |
| `ts_sort_numeric` | 1638 | CONDITIONAL |
| `linknodetitle` | 1658 | ACTIVE |
| `InDebugMode` | 1714 | DEAD |
| `EncodeHtml` | 1742 | ACTIVE |
| `DecodeHtml` | 1746 | ACTIVE |
| `SwapGravatars` | 1750 | ACTIVE |
| `replyTo` | 1763 | DEAD |
| `clearReply` | 1770 | DEAD |
| `checkAll` | 1774 | DEAD |
| `edButton` (class) | 1822 | CONDITIONAL |
| `edLink` | 2129 | CONDITIONAL |
| `edShowButton` | 2143 | CONDITIONAL |
| `edShowLinks` | 2172 | CONDITIONAL |
| `edAddTag` | 2181 | CONDITIONAL |
| `edRemoveTag` | 2188 | CONDITIONAL |
| `edCheckOpenTags` | 2197 | CONDITIONAL |
| `edCloseAllTags` | 2213 | CONDITIONAL |
| `edQuickLink` | 2220 | CONDITIONAL |
| `edSpell` | 2237 | CONDITIONAL |
| `literalize` | 2269 | CONDITIONAL |
| `autoFormat` | 2306 | CONDITIONAL |
| `edToolbar` | 2334 | CONDITIONAL |
| `edShowExtra` | 2371 | CONDITIONAL |
| `edHideExtra` | 2381 | CONDITIONAL |
| `edInsertTag` | 2393 | CONDITIONAL |
| `edInsertContent` | 2462 | CONDITIONAL |
| `edInsertLink` | 2489 | CONDITIONAL |
| `edInsertExtLink` | 2506 | CONDITIONAL |
| `edInsertImage` | 2523 | CONDITIONAL |
| `edInsertFootnote` | 2535 | CONDITIONAL |
| `countInstances` | 2568 | CONDITIONAL |
| `edInsertVia` | 2573 | CONDITIONAL |
| `edSetCookie` | 2585 | CONDITIONAL |
| `edShowExtraCookie` | 2592 | CONDITIONAL |
| `gtag` | 2613 | ACTIVE |
| `toggleEditorCool` | 2650 | ACTIVE |
| `toggleBookmark` | 2674 | ACTIVE |

---

## Migration Priority Order

### Phase 1: Immediate (No Dependencies)
1. Remove `showchatter` - 220 lines
2. Remove `showmessages` - 240 lines
3. Remove `borgcheck` - 30 lines
4. Remove `borgspeak` - 100 lines
5. Remove `eddiereply` - 80 lines

**Total Phase 1**: ~670 lines

### Phase 2: React Message Components
1. Create `<MessageField>` component
2. Create `<UserMessageBox>` component
3. Update Usergroup.js with message forms
4. Update user display with message box
5. Remove `msgField` - 107 lines
6. Remove `messageBox` - 97 lines
7. Remove legacy.js `replyToCB` and related - ~100 lines

**Total Phase 2**: ~300 lines + new React components

### Phase 3: Writeup Messaging
1. Create/extend API for writeup messages
2. Update WriteupDisplay.js
3. Remove `writeupmessage` - 50 lines
4. Remove `sendPrivateMessage` - 700 lines

**Total Phase 3**: ~750 lines

### Phase 4: XML Export (Optional)
1. Decide if XML export is needed
2. If not, remove all formxml_* functions - 400 lines

**Total Phase 4**: ~400 lines (optional)

---

## Verification Commands

Before removing any code, verify no active usage:

```bash
# Check for htmlcode calls
grep -rn "htmlcode('showchatter'" ecore/ templates/

# Check for direct function calls
grep -rn "showchatter(" ecore/ --include="*.pm"

# Check template usage
grep -rn "showchatter" templates/
```

---

## Part 6: jQuery and jQuery UI Analysis

**Last Updated**: 2025-12-29

Everything2 uses jQuery 1.11.1 and jQuery UI 1.11.1 loaded on all authenticated pages. This section documents jQuery usage across the codebase and identifies what must be replaced before jQuery can be removed.

### 6.1 jQuery Loading Summary

| Library | Version | Loaded On | Source |
|---------|---------|-----------|--------|
| jQuery | 1.11.1 | All auth pages | `jscssw.everything2.com/jquery.min.1.11.1.js` |
| jQuery UI | 1.11.1 | All auth pages | `jscssw.everything2.com/jquery-ui-1.11.1.min.js` |

**Note**: Guest pages do NOT load jQuery - React handles all guest UI.

### 6.2 jQuery Usage by Category

#### 6.2.1 DOM Query Calls (134 total in legacy.js)

| Pattern | Count | Primary Usage |
|---------|-------|---------------|
| `$('#id')` | 67 | Element selection |
| `$('.class')` | 31 | Class selection |
| `$('element')` | 18 | Tag selection |
| `$(this)` | 12 | Context wrapping |
| `$(document)` | 6 | Document ready/events |

#### 6.2.2 Animation Calls (20 total)

| Method | Count | Usage |
|--------|-------|-------|
| `.fadeIn()` | 4 | AJAX response display |
| `.fadeOut()` | 3 | Element hide |
| `.show()` | 6 | Toggle visibility |
| `.hide()` | 5 | Toggle visibility |
| `.toggle()` | 2 | Widget panels |

### 6.3 Active jQuery UI Widgets

These jQuery UI widgets are actively used and require vanilla JS replacements:

| Widget | Location | Usage | Replacement Strategy |
|--------|----------|-------|---------------------|
| **Sortable** | legacy.js:1332-1358 | Nodelet reordering on Settings page | HTML5 Drag & Drop API |
| **Draggable** | legacy.js:1433-1498 | Theme preview positioning | CSS transform + mouse events |
| **Dialog** | legacy.js:776-827 | Unsaved changes warning (`beforeunload`) | Native `confirm()` or React Modal |

**Note**: The Dialog widget is used sparingly - most confirmation uses native browser `confirm()` via `e2.confirmop`.

### 6.4 e2.ajax System (Critical Blocker)

The `e2.ajax.*` namespace (legacy.js:842-1231, ~390 lines) is the largest jQuery dependency and is deeply integrated across the site.

**Core Methods**:
```javascript
e2.ajax.htmlcode(code, params, targetId)  // Call Perl htmlcode, inject result
e2.ajax.update(element, data)             // POST to node, update DOM
e2.ajax.varChange(element, vars)          // Update user variable
e2.ajax.starRateNode(element, rating)     // Star rating submission
e2.ajax.listManager(element, params)      // Manage user lists
e2.ajax.triggerUpdate(triggers, callback) // Batch trigger processing
```

**Active Callers** (verified December 2025):
- Vote buttons (C!, upvote, downvote)
- Star ratings on writeups
- Nodelet refresh buttons
- List management (bookmarks, ignore lists)
- Variable change forms (settings toggles)

**Migration Path**:
1. Each `e2.ajax.*` call must be replaced with a dedicated `/api/` endpoint
2. React components use `fetch()` directly
3. Remaining legacy forms converted one-by-one

### 6.5 jQuery Removal Blockers

| Blocker | Severity | Required Work |
|---------|----------|---------------|
| **Sortable nodelets** | HIGH | HTML5 DnD implementation (~4 hours) |
| **e2.ajax system** | HIGH | Gradual API migration (ongoing) |
| **TinyMCE integration** | MEDIUM | Complete after TipTap migration |
| **Event handlers** | MEDIUM | Convert `.on()` to `addEventListener` |
| **DOM manipulation** | LOW | Most are simple `querySelector` swaps |

### 6.6 Dead jQuery Code (Safe to Remove)

These jQuery patterns are no longer active:

| Code Section | Lines | Evidence |
|--------------|-------|----------|
| `#message` selector | 6-19 | Legacy chatterbox DOM removed |
| `.chatterbox` handlers | ~50 lines | React Chatterbox replacement |
| `#message_inbox` form | 1763-1779 | React MessageInbox replacement |
| `#chatterlight` selectors | scattered | React chatterlight pages |

### 6.7 jQuery Removal Phases

**Phase J1: Remove Dead jQuery Code (~100 lines)** ✅ COMPLETE 2025-12-29
- ~~Remove `replyToCB()` and chatterbox DOM selectors~~
- ~~Remove message inbox legacy handlers~~
- **Result**: 70 lines removed, no functional impact

**Phase J2: Replace jQuery UI Widgets (~200 lines new code)**
- Implement vanilla JS Sortable for nodelets
- Replace Draggable with CSS transform approach
- Convert Dialog to native confirm or React Modal
- **Dependency**: None (can do immediately)

**Phase J3: Migrate e2.ajax System (~400 lines)**
- Replace `e2.ajax.htmlcode` with direct API calls
- Replace `e2.ajax.update` with fetch + DOM update
- Replace `e2.ajax.varChange` with `/api/settings` POST
- **Dependency**: API endpoints must exist first

**Phase J4: Convert DOM Operations (~600 lines)**
- Replace `$('#id')` with `document.getElementById`
- Replace `$('.class')` with `querySelectorAll`
- Replace `.fadeIn/.fadeOut` with CSS transitions
- Replace `.on('event')` with `addEventListener`
- **Dependency**: Phases J1-J3 complete

**Phase J5: Remove jQuery Load (~0 lines removed, bandwidth saved)**
- Remove jQuery/jQuery UI script tags from templates
- Test all authenticated pages
- **Dependency**: All above phases complete

### 6.8 Estimated Impact

| Phase | Lines Removed | Lines Added | Net Change |
|-------|---------------|-------------|------------|
| J1 | 100 | 0 | -100 |
| J2 | 200 | 200 | 0 |
| J3 | 400 | 300 | -100 |
| J4 | 600 | 400 | -200 |
| **Total** | **1,300** | **900** | **-400** |

**Additional Benefits**:
- Remove 95KB jQuery library load (minified)
- Remove 240KB jQuery UI library load (minified)
- Faster page initialization (no jQuery ready queue)
- Modern vanilla JS is faster than jQuery abstractions

---

## Related Documentation

- [API.md](API.md) - Modern API endpoint documentation
- [changelog-2025-12.md](changelog-2025-12.md) - Recent migration history
- React components: `react/components/Nodelets/Chatterbox.js`, `react/components/Documents/MessageInbox.js`
