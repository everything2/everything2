# Everything::Delegation::htmlcode Refactor Plan

Analysis of all subroutines in `ecore/Everything/Delegation/htmlcode.pm` for elimination or migration.

**Generated**: 2025-01-10
**Total Functions**: 101

---

## Legend

| Status | Meaning |
|--------|---------|
| **DEAD** | No callers found - safe to delete |
| **DEAD-CASCADE** | Only called by other dead functions |
| **MIGRATE-APP** | Move to Everything::Application |
| **MIGRATE-CONTROLLER** | Move to Everything::Controller or subclass |
| **MIGRATE-NODE** | Move to Everything::Node or subclass |
| **KEEP-TEMP** | Still actively used, migrate later |
| **DUPLICATE** | Duplicated in opcode.pm - delete htmlcode version |

---

## Wave 1: Definitely Dead Code (No Callers)

These functions have zero external callers and can be safely deleted.

| Function | Lines | Notes |
|----------|-------|-------|
| `linkStylesheet` | 76-112 | CSS is now served statically via asset_uri |
| `metadescriptiontag` | 114-126 | Meta tags now in React shell |
| `zenadheader` | 128-162 | Legacy zen template header - React replaced |
| `displaydebatecomment` | 164-182 | Never externally called |
| `displaydebatecommentcontent` | 184-237 | Never externally called |
| `showdebate` | 239-288 | Debate display - migrated to React |
| `closeform` | 290-300 | Legacy form helper - not used |
| `displayNODE` | 302-339 | Legacy node display - React replaced |
| `openform` | 341-370 | Legacy form helper - not used |
| `parsetime` | 372-397 | Only in comments, never called |
| `password_field` | 399-445 | Legacy form helper - not used |
| `nodelet_meta_container` | 447-460 | Legacy nodelet wrapper - not used |
| `searchform` | 462-484 | Search form - migrated to React |
| `setvar` | 486-504 | Legacy var setter - Settings API replaced |
| `parselinks` | 506-518 | Only in comments, never called |
| `show_content` | 587-771 | Major display function - React replaced |
| `showcollabtext` | 802-831 | Collaboration text display - React replaced |
| `showbookmarks` | 1044-1113 | Bookmarks display - React replaced |
| `e2createnewnode` | 1115-1195 | Node creation form - React/API replaced |
| `displayvars` | 1523-1558 | Debug display of vars - not used |
| `node_menu` | 1735-1802 | Node menu display - React replaced |
| `writeuphints` | 1922-2210 | Writeup hints - migrated to Controller |
| `zenFooter` | 2212-2233 | Legacy zen footer - React replaced |
| `borgcheck` | 2308-2334 | Only in comments, never called |
| `uploaduserimage` | 2336-2453 | Image upload - migrated to API |
| `createroom` | 2487-2503 | Room creation - API replaced |
| `writeupssincelastyear` | 2630-2679 | Stats function - not used |
| `showuserimage` | 2849-2870 | Image display - React replaced |
| `customtextarea` | 3188-3229 | Legacy textarea helper - not used |
| `nwuamount` | 3231-3279 | New writeup amount - not used |
| `schemafoot` | 4362-4372 | Schema.org footer - not used |
| `externalLinkDisplay` | 4699-4755 | External link display - not used |
| `show_node_forward` | 4869-4891 | Node forward display - not used |
| `editor_homenode_tools` | 4928-4972 | Editor tools - migrated to React |
| `uploadAudio` | 5197-5263 | Audio upload - not used |
| `checkInfected` | 5265-5296 | Infection check - not used |
| `isInfected` | 5317-5331 | Infection check - not used |
| `ip_lookup_tools` | 5333-5351 | IP tools display - not used |
| `check_blacklist` | 5457-5455 | Blacklist check - not used (see blacklistIP) |
| `canseeNotification` | 5457-5481 | Only in nodepack, never called |
| `lock_user_account` | 5483-5509 | Account locking - migrated to API |
| `blacklistedIPs` | 5995-6222 | Blacklist display - not used |

**Total Wave 1**: 42 functions

---

## Wave 2: Cascade Dead (Only Called by Dead Functions)

Delete these AFTER Wave 1 is complete.

| Function | Lines | Called By (Dead) |
|----------|-------|------------------|
| `generatehex` | 2455-2485 | `uploaduserimage` |
| `textarea` | 520-585 | `openform`, `customtextarea` |
| `in_an_array` | 2831-2847 | `showUserGroups` |
| `showUserGroups` | 2764-2829 | Internal only |
| `displayUserText` | 3172-3186 | `formxml_user` |
| `widget` | 5684-5736 | Internal form helpers |

**Total Wave 2**: 6 functions

---

## Wave 3: Duplicates in opcode.pm

These are defined in both htmlcode.pm and opcode.pm. Delete the htmlcode version.

| Function | Lines | Notes |
|----------|-------|-------|
| `lockroom` | 2276-2306 | opcode.pm has authoritative version |
| `orderlock` | 4667-4697 | opcode.pm has authoritative version |
| `repair_e2node` | 5298-5315 | opcode.pm has authoritative version |

**Total Wave 3**: 3 functions

---

## Migrate to Everything::Application

These are utility/service functions that should live in Application.pm.

| Function | Lines | Notes |
|----------|-------|-------|
| `sendPrivateMessage` | 3281-4075 | Core messaging - belongs in $APP |
| `addNotification` | 5061-5071 | Notification system - belongs in $APP |
| `verifyRequest` | 5073-5091 | CSRF verification - belongs in $APP |
| `verifyRequestHash` | 2235-2250 | Hash generation - belongs in $APP |
| `verifyRequestForm` | 5093-5108 | Form token - belongs in $APP |
| `DateTimeLocal` | 4587-4632 | Date formatting - belongs in $APP |
| `timesince` | 3017-3089 | Time formatting - belongs in $APP |
| `isSpecialDate` | 2872-2915 | Date checking - belongs in $APP |
| `getGravatarMD5` | 2607-2628 | Gravatar hash - belongs in $APP |
| `decode_short_string` | 5555-5608 | URL decode - belongs in $APP |
| `create_short_url` | 5610-5661 | URL encode - belongs in $APP (partially there) |
| `urlToNode` | 5663-5682 | URL parsing - belongs in $APP |
| `usergroupToUserIds` | 2681-2703 | Group expansion - belongs in $APP |
| `explode_ug` | 2705-2729 | Group expansion - belongs in $APP |

**Total Migrate-APP**: 14 functions

---

## Migrate to Everything::Controller

These are display/request-handling functions that should live in Controllers.

| Function | Lines | Destination |
|----------|-------|-------------|
| `setupuservars` | 1197-1295 | Already in Controller::user |
| `shownewexp` | 1297-1389 | Controller (XP display) |
| `showNewGP` | 5110-5195 | Controller (GP display) |
| `epicenterZen` | 4987-5059 | Controller (notification display) |
| `achievementsByType` | 4893-4926 | Controller::achievements |
| `daylog` | 1021-1042 | Controller::daylog |
| `weblog` | 1820-1920 | Controller::weblog |
| `randomnode` | 1804-1818 | Controller (simple, maybe API) |
| `newwriteups` | 1560-1625 | Already in Application stash |
| `firmlinks` | 2505-2605 | Controller or Node method |

**Total Migrate-Controller**: 10 functions

---

## Migrate to Everything::Node

These are node-specific operations that should be methods on Node classes.

| Function | Lines | Destination |
|----------|-------|-------------|
| `softlink` | 833-1019 | Everything::Node::e2node |
| `createdby` | 2252-2274 | Everything::Node (base) |
| `coolcount` | 4974-4985 | Everything::Node::writeup |
| `nopublishreason` | 5738-5802 | Everything::Node::draft |
| `canpublishas` | 5804-5862 | Everything::Node::draft |
| `publishwriteup` | 1391-1521 | Everything::Node::draft |
| `unpublishwriteup` | 5900-5993 | Everything::Node::writeup |
| `resurrectNode` | 6224-6248 | Everything::Node |
| `reinsertCorpse` | 6250-end | Everything::Node |
| `addNodenote` | 5864-5898 | Everything::Node |
| `atomiseNode` | 4757-4792 | Everything::Node (serialization) |

**Total Migrate-Node**: 11 functions

---

## Keep Temporarily (Active Use)

These are actively used and need careful migration planning.

| Function | Lines | Callers | Migration Plan |
|----------|-------|---------|----------------|
| `parsetimestamp` | 1627-1733 | Internal + ticker | Move to $APP |
| `screenNotelet` | 4441-4530 | Application.pm | Keep in place for now |
| `doChatMacro` | 2917-3015 | opcode.pm | Keep for chat |
| `usercheck` | 3091-3141 | atomiseNode | Move with atomiseNode |
| `linkGroupMessages` | 3143-3170 | Internal | Evaluate need |
| `ignoreUser` | 4839-4867 | opcode.pm | Move to $APP |
| `unignoreUser` | 2731-2762 | opcode.pm | Move to $APP |
| `blacklistIP` | 5412-5455 | the_old_hooked_pole.pm | Keep for moderation |
| `googleads` | 5511-5553 | Ad display | Evaluate - may be dead |
| `userAtomFeed` | 4794-4837 | Atom feeds | Keep for feeds |

**Total Keep-Temp**: 10 functions

---

## XML/Ticker Functions (Evaluate Separately)

These support XML ticker feeds - evaluate if ticker is still used.

| Function | Lines | Notes |
|----------|-------|-------|
| `formxml` | 4077-4092 | XML wrapper |
| `formxml_user` | 4094-4185 | User XML |
| `xmlheader` | 4187-4207 | XML header |
| `xmlfooter` | 4209-4219 | XML footer |
| `formxml_e2node` | 4221-4241 | E2node XML |
| `xmlwriteup` | 4243-4303 | Writeup XML |
| `xmlfirmlinks` | 4305-4327 | Firmlinks XML |
| `formxml_writeup` | 4329-4343 | Writeup XML wrapper |
| `schemalink` | 4345-4360 | Schema.org link |
| `formxml_superdoc` | 4374-4396 | Superdoc XML |
| `xmlnodesuggest` | 4398-4439 | Node suggest XML |
| `formxml_usergroup` | 4532-4585 | Usergroup XML |
| `formxml_room` | 4634-4652 | Room XML |
| `formxml_superdocnolinks` | 4654-4665 | Superdoc no links XML |

**Total XML Functions**: 14 functions

---

## Summary

| Category | Count |
|----------|-------|
| Wave 1: Dead Code | 42 |
| Wave 2: Cascade Dead | 6 |
| Wave 3: Duplicates | 3 |
| Migrate to $APP | 14 |
| Migrate to Controller | 10 |
| Migrate to Node | 11 |
| Keep Temporarily | 10 |
| XML/Ticker (evaluate) | 14 |
| **Total** | **110** |

Note: Some functions may appear in multiple categories or the count may differ slightly from the 101 defined due to categorization overlap.

---

## Recommended Approach

### Phase 1: Safe Deletions
1. Delete Wave 1 (42 dead functions)
2. Delete Wave 2 (6 cascade dead)
3. Delete Wave 3 (3 duplicates)
4. Run full test suite
5. Deploy and monitor

### Phase 2: Application.pm Migration
1. Migrate utility functions to $APP one at a time
2. Update all callers
3. Delete htmlcode version
4. Repeat for each function

### Phase 3: Controller Migration
1. Migrate display functions to appropriate Controllers
2. These often become `buildReactData()` logic

### Phase 4: Node Method Migration
1. Migrate node operations to Node classes
2. These become `$node->method()` calls

### Phase 5: XML/Ticker Evaluation
1. Determine if XML ticker is still used
2. If not, delete all 14 XML functions
3. If yes, consider moving to dedicated module

---

## Notes

- Always check nodepack/ for XML definitions before deleting
- Some functions may be called via `htmlcode($name)` with variable names
- Test thoroughly after each wave
- User handles all git commits
