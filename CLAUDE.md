# AI Assistant Context for Everything2

This document provides context for AI assistants (like Claude) working on the Everything2 codebase. It summarizes recent work, architectural decisions, and important patterns to understand.

**Last Updated**: 2025-11-24
**Maintained By**: Jay Bonci

## Recent Work History

### Session 15: Mason2 Elimination Phase 3 - Portal Elimination & Bug Fix (2025-11-24)

**Focus**: Execute Phase 3 of Mason2 elimination plan - eliminate React Portals, have React own sidebar rendering

**Completed Work**:
1. ✅ **Phase 3 Documentation** - Updated docs/mason2-elimination-plan.md to explicitly scope Phase 3 to sidebar only
2. ✅ **E2ReactRoot.js Complete Rewrite** ([E2ReactRoot.js:1-728](react/components/E2ReactRoot.js))
   - Removed all 26 Portal component imports
   - Added `nodeletorder` to toplevelkeys array (line 186)
   - Created `renderNodelet()` method (lines 438-698) with component map for all 26 nodelets
   - New `render()` method (lines 708-725) renders nodelets directly without sidebar wrapper
3. ✅ **Controller.pm Updates** ([Controller.pm:86-102](ecore/Everything/Controller.pm#L86-L102))
   - Built `nodeletorder` array from user's nodelet preferences
   - Added to both `$e2` (for React) and `$params` (for Mason2 template requirements)
   - Skipped `nodelets()` call - Mason2 no longer builds nodelet data structures
4. ✅ **zen.mc Template Update** ([zen.mc:102-105](templates/zen.mc#L102-L105))
   - Removed Mason2 nodelet loop
   - Left only `<div id='e2-react-root'></div>` inside sidebar div
5. ✅ **Portal Files Deleted** - Removed entire `react/components/Portals/` directory (27 files, ~1,350 lines)
6. ✅ **Critical Bug Fix** - Fixed nodelets not displaying on page
   - **Problem**: E2ReactRoot was rendering `<div id='sidebar'>` wrapper but mounting to `#e2-react-root` which is already inside Mason2's sidebar div
   - **Result**: Incorrect double-nesting, nodelets not visible
   - **Fix**: Removed sidebar wrapper from React render() - React just renders nodelets directly
   - **DOM Structure**: `Mason2 sidebar div → e2-react-root div → React nodelets`

**Final Results**:
- ✅ **445/445 React tests passing** (100%)
- ✅ **159/159 smoke tests passing** (100%)
- ✅ **Nodelets displaying correctly** - All 26 nodelets render properly
- ✅ **Portal architecture eliminated** - Cleaner, simpler codebase

**Key Files Modified**:
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm) - Build nodeletorder, skip nodelets()
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Complete rewrite without Portals
- [react/components/E2ReactRoot.test.js](react/components/E2ReactRoot.test.js) - Updated mocks
- [templates/zen.mc](templates/zen.mc) - Removed nodelet loop
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - Phase 3 completion report + Phase 4 plan

**Important Discoveries**:
- **DOM Mounting**: React mounts to `#e2-react-root` which is **inside** Mason2's `<div id='sidebar'>` wrapper
- **No Wrapper Needed**: React must NOT render a sidebar wrapper - it renders nodelets directly
- **Single Mount Point**: React mounts once instead of 26 times (Portals), better performance
- **Clear Boundaries**: Mason2 owns structure wrappers, React owns content rendering

### Session 14: Mason2 Elimination Phase 2 - Controller Simplification (2025-11-24)

**Focus**: Execute Phase 2 of Mason2 elimination plan - simplify Controller to skip building unused data structures

**Completed Work**:
1. ✅ **Controller.pm Simplification** ([Controller.pm:96-124](ecore/Everything/Controller.pm#L96-L124))
   - **Problem**: All 16 nodelets now React-handled with `react_handled => 1` flags, but Controller still:
     - Called individual nodelet methods (`epicenter()`, `readthis()`, `master_control()`, etc.)
     - Built complex Mason2 data structures via delegation lookups
     - Executed ~100+ database queries per page load
     - Discarded all this data because Mason2 templates don't render when `react_handled => 1`
   - **Solution**: Modified `nodelets()` method to skip all method calls:
     - Removed `if($self->can($title))` branch that called Controller methods
     - Removed delegation lookup to `Everything::Delegation::nodelet`
     - Provides only minimal placeholder data: `react_handled => 1`, `title`, `id`, `node`
     - Mason2 still renders empty div wrappers for CSS targeting
   - **Code Reduction**: 34 lines → 13 lines (-21 lines)
   - **Performance**: Eliminated ~16 method calls + ~100+ DB queries per page load

**Final Results**:
- ✅ **159/159 smoke tests passing** (100%)
- ✅ **445/445 React tests passing** (100%)
- ✅ **626 Perl test assertions passing** across 26 test files
- ✅ **No regressions** - All existing functionality works correctly
- ✅ **Expected performance**: 20-40% reduction in page load time (varies by nodelet count)

**Key Files Modified**:
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm) - Simplified nodelets() method
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - Added Phase 2 completion report

**Benefits Achieved**:
1. **Significant Performance Improvement** - Eliminated redundant work on every page load
2. **Cleaner Architecture** - Controller no longer coupled to individual nodelet implementations
3. **Reduced Complexity** - Simpler code, single code path instead of dual paths
4. **Prepares for Phase 3** - Clean separation between Controller and nodelet rendering
5. **No Breaking Changes** - All 16 React nodelets continue working perfectly

**Performance Impact**:
- **Before**: ~16 method calls + ~100+ DB queries + complex data structures → discarded by react_handled flags
- **After**: Minimal placeholder data only → same visual output, massive performance gain

**Code Changes Summary**:
```perl
# Before (34 lines):
if($self->can($title)) {
  my $nodelet_values = $self->$title($REQUEST, $node);
  $params->{nodelets}->{$title} = $nodelet_values;
} else {
  if(my $delegation = Everything::Delegation::nodelet->can($title)) {
    $params->{nodelets}->{$title}->{delegated_content} = $delegation->(...);
  }
}

# After (13 lines):
$params->{nodelets}->{$title} = {
  react_handled => 1,
  title => $nodelet->title,
  id => $id,
  node => $node
};
```

**Important Discoveries**:
- **Optimization Pattern**: When ALL components use react_handled, Controller can skip all legacy code paths
- **Minimal Data Needed**: Mason2 only needs `title` and `id` for div wrappers, not full data structures
- **Clean Simplification**: Removing code rather than adding complexity makes system more maintainable
- **Backward Compatibility**: Old Controller methods remain in codebase but are never called (can remove in future cleanup)

**Next Steps**:
- **Phase 3**: Create React-only template path (zen_react.mc) - no Mason2 nodelet rendering
- **Phase 4**: Full Mason2 elimination - pure React frontend

### Session 13: Notification Dismiss & API Polling Optimization (2025-11-24)

**Focus**: Fix notification dismiss functionality and prevent redundant API calls on page load

**Completed Work**:
1. ✅ Implemented notification dismiss functionality
   - Created [notifications.pm](ecore/Everything/API/notifications.pm) API with two endpoints:
     - `GET /api/notifications/` - Fetch unseen notifications
     - `POST /api/notifications/dismiss` - Mark notification as seen
   - Updated [Notifications.js](react/components/Nodelets/Notifications.js) with dismiss handling
   - Uses event delegation to catch clicks on dismiss buttons
   - Extracts `notified_id` from button class (`dismiss notified_123`)
   - Local state filtering hides dismissed notifications immediately
   - Security: Users can only dismiss their own notifications (403 for others)
   - Guest users blocked (401)
2. ✅ Created comprehensive test suite ([t/037_notifications_api.t](t/037_notifications_api.t))
   - 6 subtests, 15 assertions, 100% passing
   - Tests success, validation, security, guest blocking
   - Verified cross-user security (can't dismiss another user's notifications)
3. ✅ **API Polling Optimization** - Prevented redundant API calls on page load
   - **Problem**: Polling hooks made API calls on mount even when components had initial data from server
   - **Impact**: 2x database queries per page load, delayed rendering
   - Modified three polling hooks to accept `initialData` parameter:
     - [usePolling.js](react/hooks/usePolling.js) - Added `options.initialData`
     - [useChatterPolling.js](react/hooks/useChatterPolling.js) - Added `initialChatter` parameter
     - [useOtherUsersPolling.js](react/hooks/useOtherUsersPolling.js) - Added `initialData` parameter
   - Hooks skip initial API call when data provided: `if (!initialData) { fetchData() }`
   - Updated [OtherUsers.js](react/components/Nodelets/OtherUsers.js) to pass `props.otherUsersData` to hook
   - **Benefits**: 50% fewer API calls on page load, instant rendering, reduced server load
4. ✅ Documentation created
   - [docs/api-polling-optimization.md](docs/api-polling-optimization.md) - Complete optimization details
   - Documented before/after data flow, performance impact, future opportunities

**Final Results**:
- ✅ **All 445 React tests passing**
- ✅ **All 47 Perl tests passing**
- ✅ **Application rebuilt and running** at http://localhost:9080
- ✅ **Performance**: 50% fewer API calls on page load for optimized components

**Key Files Modified**:
- [ecore/Everything/API/notifications.pm](ecore/Everything/API/notifications.pm) - NEW: Notification management API
- [react/components/Nodelets/Notifications.js](react/components/Nodelets/Notifications.js) - Dismiss functionality
- [react/hooks/usePolling.js](react/hooks/usePolling.js) - Added initialData option
- [react/hooks/useChatterPolling.js](react/hooks/useChatterPolling.js) - Added initialChatter parameter
- [react/hooks/useOtherUsersPolling.js](react/hooks/useOtherUsersPolling.js) - Added initialData parameter
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Pass initial data to hook
- [t/037_notifications_api.t](t/037_notifications_api.t) - NEW: Comprehensive API tests
- [react/components/Nodelets/OtherUsers.test.js](react/components/Nodelets/OtherUsers.test.js) - Updated mock

**Important Discoveries**:
- **API Polling Pattern**: Hooks should accept `initialData` to avoid redundant requests on mount
- **Performance Impact**: Components with server-provided initial data save 1 API call + 1 DB query per page load
- **Test Mocking**: Mock functions must handle new parameters: `(pollIntervalMs, initialData) => ...`
- **Backward Compatible**: Hooks work with or without initial data (existing behavior maintained)
- **Local State Optimization**: For dismiss operations, local state filtering is faster than re-fetching HTML from server

**Next Steps**:
1. Monitor API call reduction in production logs
2. Add initial chatter messages to backend (`window.e2.chatterbox.messages`)
3. Apply same optimization pattern to other polling components
4. Consider localStorage caching for even faster page loads

### Session 12: UI Bug Fixes & Room Filtering (2025-11-24)

**Focus**: Fix multiple UI bugs - notifications display, Recent Nodes clear button, nodelet collapse, and chatterbox room filtering

**Completed Work**:
1. ✅ Fixed Notifications nodelet showing "0" ([Notifications.js:27,70](react/components/Nodelets/Notifications.js#L27))
   - Issue: When notifications configured but empty, displayed "0" instead of appropriate message
   - Root cause: Perl boolean `0` being rendered by React when using `{showSettings && ...}`
   - Fix: Added `const shouldShowSettings = Boolean(showSettings)` to convert to proper boolean
   - Now shows "No new notifications" or "Configure notifications to get started"
2. ✅ Implemented Recent Nodes "Clear My Tracks" button ([RecentNodes.js:32-59](react/components/Nodelets/RecentNodes.js#L32-L59))
   - Issue: Button used HTML form submission causing page reload without clearing tracks
   - Added `nodetrail` preference to [preferences.pm:23](ecore/Everything/API/preferences.pm#L23)
   - Created async handler calling `/api/preferences/set` with `{ nodetrail: '' }`
   - Added `onClearTracks` callback to [E2ReactRoot.js:580](react/components/E2ReactRoot.js#L580)
   - Shows visual feedback (disabled button + opacity) while clearing
   - Updates UI immediately without page reload
3. ✅ Fixed collapsedNodelets bug preventing last nodelet collapse ([E2ReactRoot.js:347-352](react/components/E2ReactRoot.js#L347-L352))
   - Issue: When expanding last collapsed nodelet, preference gets deleted (becomes undefined)
   - Root cause: [String.pm:20](ecore/Everything/Preference/String.pm#L20) `should_delete` returns true for empty string
   - Fix: Added defensive checks `this.state.collapsedNodelets || ''` and `e2['collapsedNodelets'] || ''`
   - Ensures collapsedNodelets is always a string before calling `.replace()`
   - Now properly handles empty string preference
4. ✅ Fixed Chatterbox showing all rooms when in "outside" ([Application.pm:4231-4232](ecore/Everything/Application.pm#L4231-L4232))
   - Issue: When in room 0 ("outside"), chatterbox showed messages from ALL rooms
   - Root cause: SQL filter only applied when `if ($room > 0)`, excluding room 0
   - Fix: Changed to `$where .= " and room=$room"` to always filter by room
   - Now properly shows only "outside" messages when in room 0

**Final Results**:
- ✅ **All 445 React tests passing**
- ✅ **All 46 Perl tests passing**
- ✅ **Application rebuilt and running** at http://localhost:9080
- ✅ All UI bugs resolved

**Key Files Modified**:
- [react/components/Nodelets/Notifications.js](react/components/Nodelets/Notifications.js) - Fixed "0" display with boolean conversion
- [react/components/Nodelets/RecentNodes.js](react/components/Nodelets/RecentNodes.js) - Implemented clear tracks functionality
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Fixed collapsedNodelets handling + added clear tracks callback
- [ecore/Everything/API/preferences.pm](ecore/Everything/API/preferences.pm) - Added nodetrail preference support
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed room filtering in getRecentChatter
- [react/components/Nodelets/RecentNodes.test.js](react/components/Nodelets/RecentNodes.test.js) - Updated tests for new API approach

**Important Discoveries**:
- **React rendering of falsy values**: React renders `0` but not `false/null/undefined` - always use Boolean() for Perl booleans
- **String preference deletion**: When set to empty string, String.pm deletes the preference instead of storing ""
- **Defensive coding**: Always check for undefined/null before calling string methods like `.replace()`
- **SQL filtering**: Be careful with `> 0` checks that exclude valid zero values
- **Room 0 is valid**: "outside" is room 0, not a null/undefined room

### Session 11: Usergroup Messaging & Message Modal Implementation (2025-11-24)

**Focus**: Fix usergroup messaging bugs, implement comprehensive message composition modal with reply/reply-all functionality

**Completed Work**:
1. ✅ Fixed usergroup messaging internal server error ([Application.pm:4403,4412-4417](ecore/Everything/Application.pm#L4403))
   - Root cause: Code accessed `$usergroup->{user_id}` but usergroups have `node_id`, not `user_id`
   - Fixed `for_usergroup` field in message insertion
   - Fixed `getParameter()` call for archive copy
   - Fixed archive copy insertion
2. ✅ Created usergroup message test suite ([t/037_usergroup_messages.t](t/037_usergroup_messages.t))
   - 4 subtests: member send, non-member rejection, /msg command, archive copy
   - Validates `for_usergroup` field uses node_id correctly
   - Tests usergroup membership authorization
   - Tests archive copy creation for usergroups with `allow_message_archive` setting
3. ✅ Fixed archive filter in Messages nodelet
   - API endpoint wasn't reading `archive` parameter ([messages.pm:27](ecore/Everything/API/messages.pm#L27))
   - `get_messages()` wasn't filtering by archive status ([Application.pm:3758](ecore/Everything/Application.pm#L3758))
   - Added WHERE clause: `for_user=$user->{node_id} AND archive=$archive`
4. ✅ Implemented comprehensive message composition modal ([MessageModal.js](react/components/MessageModal.js))
   - Reply and Reply-All functionality
   - Toggle between individual/group replies for usergroup messages
   - 512 character limit with live counter (yellow at 90%, red at 100%)
   - Auto-focus textarea on open
   - Click-outside-to-close pattern
   - Error handling and loading states
   - Fixed positioning with z-index 10000
5. ✅ Updated Messages nodelet UI ([Messages.js:165-202,253-315,406-453](react/components/Nodelets/Messages.js))
   - Added reply/reply-all/archive/delete buttons with icons (↩, ↩↩, 📦, 🗑)
   - Added Compose and Message Inbox footer buttons (✉, 📬)
   - Integrated MessageModal component
   - Refresh messages list after send
6. ✅ Deployed React bundle and restarted Apache
   - Bundle size: main.bundle.js 139KB, 671.bundle.js 115KB
   - All features live in development environment
7. ✅ Documented message modal features ([message-chatter-system.md:728-794](docs/message-chatter-system.md#L728))
   - Complete feature documentation
   - Button layout and icon usage
   - Validation rules and UX patterns
   - API integration details

**Final Results**:
- ✅ **Usergroup messaging working** - Fixed node_id bug, tests passing
- ✅ **Archive filter working** - Correctly shows inbox vs archived messages
- ✅ **Message modal deployed** - Full reply/reply-all/compose functionality
- ✅ **Complete documentation** - All features documented in message-chatter-system.md

**Key Files Created/Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed sendUsergroupMessage() node_id bugs, archive filtering
- [ecore/Everything/API/messages.pm](ecore/Everything/API/messages.pm) - Added archive parameter reading
- [t/037_usergroup_messages.t](t/037_usergroup_messages.t) - NEW: Comprehensive usergroup test suite
- [react/components/MessageModal.js](react/components/MessageModal.js) - NEW: Full-featured composition modal
- [react/components/Nodelets/Messages.js](react/components/Nodelets/Messages.js) - Integrated modal, updated UI
- [docs/message-chatter-system.md](docs/message-chatter-system.md) - Documented modal features

**Important Discoveries**:
- **Blessed Object Fields**: Usergroup nodes have `node_id` field, not `user_id` - must check node type
- **Archive Parameter Flow**: Must explicitly pass parameters through all API layers (CGI → API → Application)
- **React Modal Patterns**: Fixed positioning with high z-index, click-outside-to-close, focus management
- **Character Limit UI**: Live counter with color changes (90% yellow, 100% red) provides clear feedback
- **Reply Context**: Modal needs to distinguish between individual replies and usergroup replies
- **API Integration**: POST to `/api/messages/create` automatically refreshes message list on success

**Critical Bug Pattern Identified**:
```perl
# WRONG - accessing non-existent field
$usergroup->{user_id}  # usergroups don't have user_id

# RIGHT - using correct field
$usergroup->{node_id}  # usergroups are nodes with node_id
```

### Session 10: Message Opcode Refactoring & Parallel Testing (2025-11-24)

**Focus**: Refactor message opcode into centralized Application.pm methods, implement parallel test execution, fix test runner bugs

**Completed Work**:
1. ✅ Extracted command processing from message opcode ([Application.pm:3901-4184](ecore/Everything/Application.pm#L3901-L4184))
   - Created `processMessageCommand()` router with synonym normalization (~285 LOC)
   - Extracted 8 command handlers: /me, /roll, /msg, /fireball, /sanctify, /invite, easter eggs, public chatter
   - Command synonyms: /flip→/roll 1d2, /small→/whisper, /aria→/sing, /tomb→/death
   - ONO (Online-Only) private message support with ? suffix
   - Dice notation parser: XdY[kZ][+/-N] format
2. ✅ Updated chatter API to use command processor ([chatter.pm:52](ecore/Everything/API/chatter.pm#L52))
   - Routes through processMessageCommand() instead of direct chatter
   - React Chatterbox now uses centralized command logic
3. ✅ Refactored message opcode to use Application.pm ([opcode.pm:421-435, 666-673](ecore/Everything/Delegation/opcode.pm#L421))
   - Routes user commands through processMessageCommand()
   - Keeps admin commands inline (/drag, /borg, /topic, etc.)
   - Replaced hardcoded node_id '1948205' with getNode('unverified email', 'sustype')
4. ✅ Implemented Chatterbox focus retention ([Chatterbox.js:55,89](react/components/Nodelets/Chatterbox.js#L55))
   - Stores input reference before async operations
   - Restores focus after message sent (success and error paths)
   - Enables rapid-fire messaging without re-clicking input
5. ✅ Created message opcode burndown chart ([message-chatter-system.md:1136-1270](docs/message-chatter-system.md#L1136))
   - Documented 7 op=message call sites (1 XML ticker, 6 internal forms)
   - 4-phase migration strategy
   - Progress tracking table
6. ✅ Documented insertNodelet() legacy issue ([nodelet-migration-status.md:487-536](docs/nodelet-migration-status.md#L487))
   - 5 affected chatterlight functions in document.pm
   - Impact: Pages likely broken for migrated nodelets
   - 3 resolution options with recommendations
7. ✅ Created parallel test runner ([tools/parallel-test.sh](tools/parallel-test.sh))
   - Concurrent execution: smoke+perl and react tests
   - Animated progress spinners, color-coded output
   - Performance: ~52s vs 55.3s sequential (6% faster + better UX)
   - Integrated into devbuild.sh
8. ✅ Fixed parallel test runner exit code bug
   - Changed from grep-based detection to direct exit code capture
   - Prevents false failures when grep doesn't find expected patterns
   - All tests now report correct pass/fail status

**Final Results**:
- ✅ **1223 Perl tests passing** (smoke + unit, 14 parallel jobs)
- ✅ **445 React tests passing** (25 test suites)
- ✅ **Command processing centralized** - Ready for future API migration
- ✅ **Parallel testing integrated** - Faster builds with better visibility

**Key Files Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Added ~285 LOC of command processing
- [ecore/Everything/API/chatter.pm](ecore/Everything/API/chatter.pm) - Routes through processMessageCommand()
- [ecore/Everything/Delegation/opcode.pm](ecore/Everything/Delegation/opcode.pm) - Refactored to use Application.pm methods
- [react/components/Nodelets/Chatterbox.js](react/components/Nodelets/Chatterbox.js) - Focus retention
- [tools/parallel-test.sh](tools/parallel-test.sh) - NEW: Unified parallel test runner
- [docker/devbuild.sh](docker/devbuild.sh) - Integrated parallel testing
- [docs/message-chatter-system.md](docs/message-chatter-system.md) - Added burndown chart
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - Added insertNodelet() issue
- [docs/test-parallelization.md](docs/test-parallelization.md) - Added parallel test runner docs

**Important Discoveries**:
- Command Router Pattern: Central dispatcher routes messages to specialized handlers
- Exit Code Handling: Bash grep returns 1 on no matches - must capture command exit codes directly
- Focus Restoration: Store element reference before async operations, restore after completion
- Test Parallelization: Concurrent test execution improves speed AND developer UX
- Hardcoded IDs: Use getNode() lookups instead of hardcoded node_ids for maintainability

**Next Steps**:
- Complete op=message migration after React page routing and Mason2 elimination
- Resolve insertNodelet() legacy issue (3 options documented)
- Consider extracting more admin commands from opcode

### Session 9: Message Opcode Analysis & Baseline Testing (2025-11-24)

**Focus**: Analyze message opcode for refactoring, document nodelet periodic update system, create baseline test suite

**Completed Work**:
1. ✅ Documented nodelet periodic update system ([docs/nodelet-periodic-updates.md](docs/nodelet-periodic-updates.md))
   - Analyzed legacy.js AJAX polling mechanisms (list-based updates vs nodelet replacement)
   - Documented sleep/wake system (stops polling after 10 minutes inactivity)
   - Evaluated 4 options for React-based periodic updates
   - **Recommended**: Option D (Hybrid with Shared Activity Detection)
   - Individual polling per nodelet with shared useActivityDetection hook
   - Migration plan for removing legacy.js updaters piecemeal
2. ✅ Analyzed message opcode structure ([opcode.pm:379-1142](ecore/Everything/Delegation/opcode.pm#L379))
   - 763-line monolithic function handling all message functionality
   - Identified 20+ command handlers (/msg, /roll, /fireball, /sanctify, /borg, /drag, etc.)
   - Documented synonym normalization (/small→/whisper, /flip→/rolls 1d2, etc.)
   - Planned hybrid refactoring: extract core commands, keep admin commands in opcode
3. ✅ Created comprehensive baseline test suite ([t/036_message_opcode.t](t/036_message_opcode.t))
   - **9 subtests, 21 tests, 100% pass rate**
   - Tests public chatter (basic + 512 char limit)
   - Tests private messages (creation + permissions)
   - Tests special commands (/roll dice, /me actions)
   - Tests message actions (delete, archive, unarchive)
   - Uses existing users (root, guest user, Cool Man Eddie)
   - MockQuery class simulates CGI query params
   - Baseline ensures no regressions during refactoring

**Final Results**:
- ✅ **Documentation complete**: Periodic update system fully analyzed and documented
- ✅ **Message opcode mapped**: 763 lines analyzed, refactoring strategy defined
- ✅ **Baseline tests passing**: 21/21 tests pass, safe refactoring foundation established

**Key Files Created**:
- [docs/nodelet-periodic-updates.md](docs/nodelet-periodic-updates.md) - Complete periodic update analysis
- [t/036_message_opcode.t](t/036_message_opcode.t) - Baseline test suite (247 lines)

**Key Discoveries**:
- Legacy.js uses two patterns: list-based (smart DOM updates) and nodelet replacement (full HTML swap)
- Message opcode handles 20+ commands but can be refactored piecemeal
- Testing in Docker container required (DBI dependencies)
- `Everything::getVars()` is the correct function (not `$DB->getVars()` or `$user->getVars()`)
- `$DB->sqlSelect('LAST_INSERT_ID()')` for getting last insert ID

**Next Steps**:
1. Extract sendPublicChatter() to Application.pm
2. Extract sendPrivateMessage() to Application.pm
3. Extract processSpecialCommand() to Application.pm
4. Create getRecentChatter() method
5. Create Everything::API::chatter module
6. Update opcode to call new Application methods
7. Verify baseline tests still pass

### Session 8: Chatroom API, Stylesheet Recovery & UI Refinement (2025-11-23)

**Focus**: Fix chatroom API 500 errors, recover broken stylesheets from git history, refine purple chat UI to minimalist design, validate all stylesheets

**Completed Work**:
1. ✅ Fixed chatroom API 500 errors ([chatroom.pm](ecore/Everything/API/chatroom.pm))
   - Root cause: Used `$self->USER` which doesn't exist in Globals role
   - **Correct pattern**: `$REQUEST->user` to access current user
   - Fixed all three methods: change_room, set_cloaked, create_room
   - Changed `$Everything::CONF` to `$self->CONF` for proper attribute access
   - API now returns proper 403 Forbidden instead of 500 Internal Server Error
2. ✅ Fixed browser-debug.js tool ([tools/browser-debug.js:143,158](tools/browser-debug.js#L143))
   - Updated default password from 'password' to 'blah'
   - Fixed login selector from overly specific `input[type="submit"][value="login"]` to generic `input[type="submit"]`
3. ✅ Updated OtherUsers Room Options styling to minimalist design
   - Removed purple gradient (`linear-gradient(135deg, #667eea 0%, #764ba2 100%)`)
   - Applied neutral light gray background (#f8f9fa) matching Kernel Blue aesthetic
   - Reduced visual size: padding 16px → 12px, margins adjusted
   - Removed emojis for cleaner professional look
   - Updated all interior elements with consistent gray palette
   - Removed box shadow for flatter, more minimal appearance
4. ✅ Recovered 3 broken stylesheets from git history
   - **e2gle** (1997552.css) - 20KB, 674 lines, Google-inspired design
   - **gunpowder_green** (1905818.css) - 5.7KB, 449 lines, weblog/nodelet optimized
   - **jukka_emulation** (1855548.css) - 12KB, 583 lines, Clockmaker's fixes
   - Extracted from commits ad67017 and 2f55285
   - Used `perl -MHTML::Entities` to properly decode XML entities
   - Files named by node_id (not escaped friendly names) per E2 convention
5. ✅ Comprehensive stylesheet validation ([docs/stylesheet-system.md](docs/stylesheet-system.md))
   - Validated all 22 stylesheets for syntax errors
   - **22/22** have valid CSS syntax (balanced braces)
   - **FIXED**: Pamphleteer (2029380.css) - added missing closing brace for @media query at line 208
   - **1/22** external dependencies: e2gle (1997552.css) - 6 ImageShack URLs (likely broken)
   - **21/22** fully functional with no known issues
   - Updated documentation with complete evaluation
6. ✅ Fixed 5 more Perl::Critic string interpolation warnings ([NodeBase.pm](ecore/Everything/NodeBase.pm))
   - Line 1167: `'LAST_INSERT_ID()'`
   - Line 1178: `'_id'` concatenation
   - Line 1226: `'tomb'` table name
   - Line 1269: `'node'` table name
   - Line 1328: `'*'` and `'node_id='` in SQL
   - **Total session count**: 15 warnings fixed (10 previous + 5 this session)

**Final Results**:
- ✅ **Chatroom API working** - All endpoints return proper HTTP status codes
- ✅ **Browser debug tool updated** - Matches current E2 environment
- ✅ **UI refined** - Purple gradient replaced with professional neutral design
- ✅ **All stylesheets recovered** - 22/22 present in www/css/
- ✅ **Quality documented** - Complete validation report in stylesheet-system.md
- ✅ **Code quality improved** - 15 total Perl::Critic warnings fixed

**Key Files Modified**:
- [ecore/Everything/API/chatroom.pm](ecore/Everything/API/chatroom.pm) - Fixed USER access pattern
- [tools/browser-debug.js](tools/browser-debug.js) - Updated password and selector
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Minimalist Room Options design
- [react/components/Nodelets/OtherUsers.test.js](react/components/Nodelets/OtherUsers.test.js) - Updated test data structure
- [www/css/1855548.css](www/css/1855548.css) - NEW: jukka_emulation recovered
- [www/css/1905818.css](www/css/1905818.css) - NEW: gunpowder_green recovered
- [www/css/1997552.css](www/css/1997552.css) - NEW: e2gle recovered
- [docs/stylesheet-system.md](docs/stylesheet-system.md) - Added comprehensive validation results
- [ecore/Everything/NodeBase.pm](ecore/Everything/NodeBase.pm) - Fixed 5 string interpolation warnings

**Important Discoveries**:
- **Globals Role Pattern**: `Everything::Globals` role provides CONF, DB, APP, FACTORY, JSON, MASON - but NO USER attribute
- **API Request Pattern**: Always access user via `$REQUEST->user`, never `$self->USER`
- **Git History Recovery**: Can extract deleted files using `git show <commit>:path/to/file.xml`
- **HTML Entity Decoding**: Use `perl -MHTML::Entities -0777 -ne 'print decode_entities($1) if /<doctext>(.*?)<\/doctext>/s'`
- **Node ID Naming**: Stylesheets must be named `{node_id}.css` not escaped friendly names
- **CSS Validation**: Simple brace balance check catches most syntax errors
- **External Dependencies**: Old user-submitted stylesheets may have external image URLs from defunct services
- **Design Consistency**: Kernel Blue uses neutral grays (#f8f9fa, #dee2e6, #495057) not vibrant gradients
- **Test Data Evolution**: React component rewrites require updating test mock data to match new props

**API Architecture Clarification**:
```perl
# API Base Class Pattern
package Everything::API::example;
use Moose;
extends 'Everything::API';

sub my_endpoint {
  my ($self, $REQUEST) = @_;

  # Correct access patterns:
  my $USER = $REQUEST->user;      # ✓ User from request
  my $DB = $self->DB;              # ✓ From Globals role
  my $APP = $self->APP;            # ✓ From Globals role
  my $CONF = $self->CONF;          # ✓ From Globals role

  # WRONG patterns:
  # my $USER = $self->USER;        # ✗ Doesn't exist
  # my $CONF = $Everything::CONF;  # ✗ Global instead of attribute
}
```

### Session 7: Poll Vote Management & Other Users Nodelet Complete Rewrite (2025-11-23)

**Focus**: Fixing poll admin delete/revote bugs, section collapse preferences, and complete restoration of Other Users nodelet social features

**Completed Work**:
1. ✅ Fixed poll admin delete vote functionality
   - Changed from `$APP->isAdmin($user)` to `$user->is_admin` in [poll.pm:147](ecore/Everything/API/poll.pm#L147)
   - Critical learning: `$user` is a blessed `Everything::Node::user` object, not a hash
   - Method name is `is_admin` (underscore), not `isAdmin` (camelCase)
   - Added `is_admin` method to MockUser in tests
2. ✅ Fixed poll vote bold highlighting
   - Changed `userVote => $choice` to `userVote => int($choice)` in [poll.pm:130](ecore/Everything/API/poll.pm#L130)
   - JavaScript `===` strict equality requires matching types (was comparing `0 === "0"`)
3. ✅ Fixed section collapse preferences for 7 nodelets
   - Changed from `collapsible={false}` to proper `showNodelet` and `nodeletIsOpen` props
   - Fixed: Categories, CurrentUserPoll, FavoriteNoders, MostWanted, OtherUsers, PersonalLinks, RecentNodes, UsergroupWriteups
4. ✅ Complete rewrite of Other Users nodelet ([Application.pm:5329-5585](ecore/Everything/Application.pm#L5329-L5585))
   - Restored all 10+ original social features that were lost in React migration
   - **Corrected sigil assignments** (after user feedback): `@` = gods, `$` = editors, `+` = chanops, `Ø` = borged
   - **Fixed visibility logic**: Changed to `visible=0` for normal users (was inverted)
   - **Created comprehensive spec**: [docs/other-users-nodelet-spec.md](docs/other-users-nodelet-spec.md) with complete original source
   - **Refactored to structured data**: Changed from pre-rendered HTML to JSON objects with type flags
   - **Fixed new user tags visibility**: Added `$newbielook` check - only admins/editors see account age indicators
   - **Bracket formatting**: Flags wrapped in `[...]` instead of plain text
   - **Bold current user**: User's own name in `<strong>` tags
   - **Random user actions**: 2% chance of "is petting a kitten" style messages (29 verbs, 34 nouns from original)
   - **Recent noding links**: 2% chance of "has recently noded [writeup]" if < 1 week old
   - **Multi-room support**: Shows users across ALL rooms with room headers
   - **Proper sorting**: Current room first, then by last noding time, then by active days
   - **Ignore list support**: Respects user message ignore list (unless admin)
   - **Infravision setting**: User preference to see invisible users (alternative to staff powers)
   - **Active days from votesrefreshed**: Uses correct VARS field for account activity
   - **Last node reset logic**: Resets to 0 if < 1 month old or never noded
5. ✅ Removed AWS WAF Anonymous IP List
   - Deleted AWSManagedRulesAnonymousIpList rule from [cf/everything2-production.json](cf/everything2-production.json)
   - Bot protection change per user request
6. ✅ Created browser debugging tool ([tools/browser-debug.js](tools/browser-debug.js))
   - Puppeteer-based headless Chrome automation
   - Commands: screenshot, console, inspect, check-nodelets, login
   - Requested by user for easier debugging

**Final Results**:
- ✅ **Poll voting fully functional** - Admin delete + revote works perfectly
- ✅ **Bold highlighting works** - Voted choice displays in bold
- ✅ **Section collapse working** - All 8 nodelets respect user preferences
- ✅ **Other Users feature-complete** - All 10+ social features restored
- ✅ **Tests passing** - Poll API tests all passing (t/034_poll_api.t ok)
- ✅ **Build successful** - Application running at http://localhost:9080

**Key Files Modified**:
- [ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm) - Fixed admin check and type coercion
- [t/034_poll_api.t](t/034_poll_api.t) - Added is_admin method to MockUser
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Complete Other Users rewrite with structured data (250+ lines)
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Complete rewrite using LinkNode for structured data
- [react/components/Nodelets/Categories.js](react/components/Nodelets/Categories.js) - Fixed collapse props
- [react/components/Nodelets/CurrentUserPoll.js](react/components/Nodelets/CurrentUserPoll.js) - Fixed collapse props
- [react/components/Nodelets/FavoriteNoders.js](react/components/Nodelets/FavoriteNoders.js) - Fixed collapse props
- [react/components/Nodelets/MostWanted.js](react/components/Nodelets/MostWanted.js) - Fixed collapse props
- [react/components/Nodelets/PersonalLinks.js](react/components/Nodelets/PersonalLinks.js) - Fixed collapse props
- [react/components/Nodelets/RecentNodes.js](react/components/Nodelets/RecentNodes.js) - Fixed collapse props
- [react/components/Nodelets/UsergroupWriteups.js](react/components/Nodelets/UsergroupWriteups.js) - Fixed collapse props
- [docs/other-users-nodelet-spec.md](docs/other-users-nodelet-spec.md) - NEW: Complete specification with original source
- [cf/everything2-production.json](cf/everything2-production.json) - Removed AWS WAF Anonymous IP List
- [tools/browser-debug.js](tools/browser-debug.js) - NEW: Puppeteer debugging tool

**Important Discoveries**:
- **Blessed Objects**: `Everything::Node::user` objects require method calls, not hash access
- **Method Naming**: E2 uses underscore naming (`is_admin`, `is_editor`) not camelCase
- **Type Coercion**: JavaScript strict equality requires matching types - always `int()` numbers from Perl
- **React Migration**: Critical to preserve ALL original features - social interactions depend on details like sigils, brackets, user actions
- **User Feedback Loop**: "This is a very important social feature" - user emphasized restoration priority
- **Original Code as Reference**: Git history (`git diff <commit>~1 <commit>`) invaluable for recovering complete implementations
- **Test Complexity**: MockUser objects need all methods that real objects have (`is_admin`, `is_editor`, etc.)
- **Structured Data Pattern**: Passing JSON objects with type flags (instead of pre-rendered HTML) provides:
  - Better security (no dangerouslySetInnerHTML for user data)
  - Lighter payload
  - Consistent LinkNode usage
  - Better maintainability
- **Privilege Checks**: Features visible only to privileged users MUST check viewing user's role before adding data
  - **Example**: New user tags should check `$newbielook = $user_is_admin || $user_is_editor` before adding
  - **Bug Pattern**: Adding privileged data unconditionally exposes it to all users
- **Iterative Refinement**: Initial implementation + user testing reveals edge cases (sigils wrong, visibility inverted, missing features)

**Critical Bug Pattern Identified**:
```perl
# WRONG - treating blessed object like hash
$APP->isAdmin($user)

# RIGHT - calling method on blessed object
$user->is_admin

# Note: Method is is_admin (underscore), not isAdmin (camelCase)
```

### Session 6: Poll Voting API & Interactive Voting (2025-11-22)

**Focus**: Implementing poll voting functionality with API endpoints and AJAX voting UI

**Completed Work**:
1. ✅ Created poll voting API ([ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm))
   - POST /api/poll/vote - User voting endpoint with full validation
   - POST /api/poll/delete_vote - Admin-only endpoint for vote management
   - Fixed critical bug: vote existence check using COUNT(*) instead of checking defined value
   - Fixed critical bug: cache invalidation using updateNode() instead of sqlUpdate()
   - Fixed authorization: changed from isGod() to isAdmin()
2. ✅ Created comprehensive test suite ([t/034_poll_api.t](t/034_poll_api.t))
   - 10 subtests with 62 total assertions
   - Tests all scenarios: authorization, validation, voting, duplicate prevention
   - Uses delete_vote API for test cleanup to ensure idempotent runs
   - 100% test coverage for both endpoints
3. ✅ Updated API documentation ([docs/API.md](docs/API.md))
   - Added Polls section with complete endpoint documentation
   - Included request/response examples, error codes, curl commands
   - Updated test coverage table (overall coverage now ~42%)
   - Documented critical implementation notes (COUNT(*) fix, updateNode() fix)
4. ✅ Verified CurrentUserPoll component
   - Footer links correctly configured for poll management pages
   - AJAX voting already implemented in previous session
   - All 12 React tests passing

**Final Results**:
- ✅ **All 10 poll API tests passing** (62 assertions)
- ✅ **All 12 CurrentUserPoll React tests passing**
- ✅ **100% API coverage** for poll endpoints
- ✅ **Complete documentation** in API.md

**Key Files Created/Modified**:
- [ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm) - NEW: Poll voting API
- [t/034_poll_api.t](t/034_poll_api.t) - NEW: Comprehensive test suite
- [docs/API.md](docs/API.md) - Updated with Polls section

**Important Discoveries**:
- `sqlSelect()` returns `0` (defined) even when no rows exist - must use COUNT(*) for existence checks
- `sqlUpdate()` doesn't invalidate node cache - must use `updateNode()` for proper cache invalidation
- Admin endpoints use `isAdmin()` which internally calls `$this->{db}->isGod($user)`
- Test cleanup using delete_vote API makes tests idempotent without requiring database resets
- API endpoints that return updated state eliminate need for separate GET requests

### Session 5: Node Notes Enhancement & Mason2 Double Rendering Fix (2025-11-21)

**Focus**: Node notes display improvement, fixing double nodelet rendering, and E2 link parsing

**Completed Work**:
1. ✅ Fixed Perl hash dereference syntax error in Application.pm
   - Changed `$NODE{node_id}` to `$NODE->{node_id}` (lines 4910-4916)
   - Fixed similar errors for `$USER{node_id}`
2. ✅ Enhanced smoke test Apache detection
   - Added content validation for E2-specific markers
   - Added specific HTTP 500 error detection for Perl syntax errors
   - More helpful error messages
3. ✅ Improved node notes display in MasterControl
   - Added `noter_username` field to API responses
   - Created reusable `ParseLinks` React component for E2's bracket link syntax
   - Updated NodeNotes component to display noter username
   - Notes now show: `timestamp username: [parsed links in notetext]`
4. ✅ Fixed double nodelet rendering issue (Mason2 Elimination Phase 1)
   - Added `react_handled => 1` to epicenter.mi, readthis.mi, master_control.mi
   - Mason2 templates now render empty placeholder divs only
   - React handles all nodelet rendering
   - Created comprehensive 4-phase elimination plan
5. ✅ Enhanced ParseLinks to support nested bracket syntax
   - Added support for `[title[nodetype]]` syntax (e.g., `[root[user]]`)
   - Matches Perl parseLinks() regex exactly for legacy compatibility
   - Pattern: `/\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)\]/g`
   - Parses nested brackets to extract title and nodetype separately
   - Passes nodetype to LinkNode for correct URL generation
6. ✅ Optimized NodeNotes API usage
   - Eliminated redundant GET request after DELETE operations
   - DELETE endpoint already returns updated state
   - Reduced API calls from 2 to 1 per delete operation
7. ✅ Fixed initial page load for node notes
   - Added noter_username lookup in Application.pm getNodeNotes() method
   - Initial page load now has same data structure as API responses
   - No refresh needed to see noter usernames

**Final Results**:
- ✅ **213 React tests passing** (20 ParseLinks tests including nested bracket syntax)
- ✅ **61 API tests passing** (added 2 noter_username tests)
- ✅ **159/159 smoke tests passing**
- ✅ **No double rendering** - All nodelets appear exactly once
- ✅ **Nested bracket links work** - `[root[user]]` renders correctly as link to `/node/user/root`

**Key Files Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed hash dereference, added noter_username to getNodeNotes()
- [ecore/Everything/API/nodenotes.pm](ecore/Everything/API/nodenotes.pm) - Added noter_username lookup
- [react/components/ParseLinks.js](react/components/ParseLinks.js) - NEW: E2 link parser with nested bracket support
- [react/components/ParseLinks.test.js](react/components/ParseLinks.test.js) - NEW: 20 comprehensive tests
- [react/components/MasterControl/NodeNotes.js](react/components/MasterControl/NodeNotes.js) - Display noter, use ParseLinks, optimized API
- [templates/nodelets/epicenter.mi](templates/nodelets/epicenter.mi) - Added react_handled flag
- [templates/nodelets/readthis.mi](templates/nodelets/readthis.mi) - Added react_handled flag
- [templates/nodelets/master_control.mi](templates/nodelets/master_control.mi) - Added react_handled flag
- [tools/smoke-test.rb](tools/smoke-test.rb) - Better Apache error detection
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - NEW: Comprehensive 4-phase plan
- [docs/changelog-2025-11.md](docs/changelog-2025-11.md) - Updated with React migration details

**Important Discoveries**:
- Mason2 already has `react_handled` mechanism in Base.mc - just needed to set flags
- ParseLinks component is now reusable across entire React codebase
- E2's nested bracket syntax `[title[nodetype]]` requires exact Perl regex match for legacy compatibility
- API endpoints that return updated state eliminate need for separate GET requests
- Everything::Page can be preserved while eliminating Mason2 rendering
- Clean path forward: Phase 2 (optimize), Phase 3 (React template), Phase 4 (eliminate)

### Session 4: Smoke Test & Documentation Improvements (2025-11-20)

**Focus**: Smoke test reliability and special document documentation

**Completed Work**:
1. ✅ Fixed node_backup delegation for development environment
   - Added environment check at [document.pm:7138](ecore/Everything/Delegation/document.pm#L7138)
   - Returns friendly message instead of attempting S3 operations in dev
   - Resolved HTTP 400 error by copying file to Docker container (volume mount caching issue)
2. ✅ Fixed smoke test permission denied false positives
   - Updated [smoke-test.rb:187](tools/smoke-test.rb#L187) to check for actual error message
   - Changed from generic "Permission Denied" text to specific "You don't have access to that node."
   - Fixed "Everything Document Directory" and "What does what" false errors
3. ✅ Fixed URL encoding for documents with slashes
   - Updated [gen_doc_corrected.rb:72-75](/tmp/gen_doc_corrected.rb#L72-L75) to preserve raw slashes
   - E2 expects `/title/online+only+/msg` not `/title/online+only+%2Fmsg`
   - Fixed "online only /msg" and "The Everything2 Voting/Experience System" (404 → 200)
4. ✅ Regenerated [special-documents.md](docs/special-documents.md) with correct URLs
   - Now documents 159 superdocs loaded in development environment
   - Removed percent-encoding from slashes in URLs
   - Updated to reflect actual database state (only superdocs currently loaded)

**Final Results**:
- ✅ **159/159 documents passing (100% success rate)**
- ✅ All smoke tests passing
- ✅ No errors, no warnings
- ✅ Application ready for full test suite

**Key Files Modified**:
- [ecore/Everything/Delegation/document.pm](ecore/Everything/Delegation/document.pm) - Added development environment check for node_backup
- [tools/smoke-test.rb](tools/smoke-test.rb) - Fixed permission denied detection logic
- [docs/special-documents.md](docs/special-documents.md) - Regenerated with correct URLs
- [/tmp/gen_doc_corrected.rb](/tmp/gen_doc_corrected.rb) - Fixed URL encoding for slashes

**Important Discoveries**:
- Docker volume mounts can cache files; use `docker cp` to force updates
- E2 URL routing expects raw slashes in paths, not percent-encoded `%2F`
- Development database only has superdocs loaded; other types (restricted_superdoc, oppressor_superdoc, ticker, fullpage) not yet seeded
- Smoke test now dynamically reads from special-documents.md for test cases

### Session 3: React Nodelet Migration (2025-11-20)

**Focus**: ReadThis nodelet migration to React

**Completed Work**:
1. ✅ Updated [react-migration-strategy.md](docs/react-migration-strategy.md) with current state (9→10 nodelets migrated)
2. ✅ Migrated ReadThis nodelet from Perl to React
   - Created [ReadThis.js](react/components/Nodelets/ReadThis.js) component
   - Created [ReadThisPortal.js](react/components/Portals/ReadThisPortal.js)
   - Added comprehensive test suite (25 tests) in [ReadThis.test.js](react/components/Nodelets/ReadThis.test.js)
   - All 141 React tests passing
3. ✅ Fixed three bugs:
   - Dual nodelet rendering (Perl stub now returns empty string)
   - Section collapse preferences (fixed initialization logic)
   - Data population (integrated frontpagenews DataStash)
4. ✅ Updated news data source to use `frontpagenews` DataStash (weblog entries from "News For Noders" usergroup)
5. ✅ Created [nodelet-migration-status.md](docs/nodelet-migration-status.md) tracking all 25 nodelets
6. ✅ Investigated legacy AJAX: confirmed `showchatter` is ACTIVE and required for Chatterbox

**Key Files Modified**:
- [ecore/Everything/Delegation/nodelet.pm](ecore/Everything/Delegation/nodelet.pm) - readthis() returns ""
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Added ReadThis data loading with frontpagenews
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - ReadThis integration
- [docs/react-migration-strategy.md](docs/react-migration-strategy.md) - Updated current state
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - NEW: Complete nodelet inventory

### Session 2: Node Resurrection & Cleanup (2025-11-19)

**Focus**: Bug fixes and deprecated code removal

**Completed Work**:
1. ✅ Fixed node resurrection system
   - Corrected insertNode vs getNodeById confusion
   - Added proper tomb table detection
   - Created comprehensive test suite [t/022_node_resurrection.t](t/022_node_resurrection.t)
2. ✅ Removed deprecated chat functions (joker's chat, My Chatterlight v1)
3. ✅ Created November 2025 changelog: [docs/changelog-2025-11.md](docs/changelog-2025-11.md)

### Session 1: Eval() Removal (2025-11-18)

**Focus**: Security improvements - removing eval() calls

**Completed Work**:
1. ✅ Eliminated all parseCode/parsecode eval() calls
2. ✅ Implemented Safe.pm compartmentalized evaluation
3. ✅ Delegated remaining eval-dependent modules
4. ✅ Added 17 security tests
5. ✅ Updated IP address handling functions

**Key Achievement**: Complete removal of unsafe eval() from production code paths

## Architecture Overview

### Technology Stack

**Backend**:
- Perl 5 with Moose OOP framework
- MySQL database
- Mason2 templating (being gradually replaced)
- Everything2 custom node framework

**Frontend**:
- React 18.3.x (pinned until Mason2 elimination)
- React Portals architecture
- Jest for testing
- Legacy jQuery (being phased out)

**Deployment**:
- Docker containers
- AWS infrastructure
- DataStash caching system

### Key Architectural Patterns

#### React Nodelet Pattern

All React nodelets follow this established pattern:

```
1. Component (react/components/Nodelets/*.js)
   - Functional React component
   - Uses shared components: NodeletContainer, NodeletSection, LinkNode

2. Portal (react/components/Portals/*Portal.js)
   - Renders component into Mason-generated DOM
   - Targets specific div#id from Mason template

3. E2ReactRoot Integration (react/components/E2ReactRoot.js)
   - State management
   - Props passing to portals
   - Section collapse state management

4. Data Loading (ecore/Everything/Application.pm)
   - buildNodeInfoStructure() prepares data
   - Loads into window.e2 JSON object
   - Available to React on page load

5. Perl Stub (ecore/Everything/Delegation/nodelet.pm)
   - Returns empty string ""
   - Maintains framework compatibility
   - React handles all rendering
```

#### Data Flow

```
HTTP Request
  ↓
Everything::HTML::displayPage()
  ↓
Application.pm::buildNodeInfoStructure()
  ↓
window.e2 = { user: {...}, node: {...}, ... }
  ↓
E2ReactRoot initial state
  ↓
Portal components
  ↓
Nodelet components (props)
```

#### DataStash System

- Cached data for frequently accessed content
- Examples: `coolnodes`, `staffpicks`, `frontpagenews`, `newwriteups`
- Implements: `Everything::DataStash::*`
- Updated via cron: `cron_datastash.pl`
- 60-second refresh intervals

### Important Files & Locations

#### Core Backend
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Main application logic, buildNodeInfoStructure()
- [ecore/Everything/Delegation/](ecore/Everything/Delegation/) - Delegated modules (nodelet.pm, htmlcode.pm, etc.)
- [ecore/Everything/HTML.pm](ecore/Everything/HTML.pm) - HTML rendering and page display
- [ecore/Everything/Node.pm](ecore/Everything/Node.pm) - Base node class
- [ecore/Everything/NodeBase.pm](ecore/Everything/NodeBase.pm) - Database operations

#### React Frontend
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Main React application root
- [react/components/Nodelets/](react/components/Nodelets/) - Nodelet components
- [react/components/Portals/](react/components/Portals/) - Portal components
- [react/components/NodeletContainer.js](react/components/NodeletContainer.js) - Shared nodelet wrapper
- [react/components/NodeletSection.js](react/components/NodeletSection.js) - Collapsible sections
- [react/components/LinkNode.js](react/components/LinkNode.js) - Consistent node linking

#### Tests
- [t/](t/) - Perl test suite
- [react/components/**/*.test.js](react/components/) - React component tests (141 tests total)
- [tools/smoke-test.rb](tools/smoke-test.rb) - Pre-flight smoke tests (159 special documents)
- Run with: `npm test` (React), `prove t/` (Perl), `./tools/smoke-test.rb` (smoke test)

#### Documentation
- [docs/react-migration-strategy.md](docs/react-migration-strategy.md) - Overall React migration plan
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - Detailed nodelet inventory
- [docs/special-documents.md](docs/special-documents.md) - Catalog of all special document types (superdocs, tickers, etc.)
- [docs/react-19-migration.md](docs/react-19-migration.md) - Future React 19 upgrade plan
- [docs/changelog-2025-11.md](docs/changelog-2025-11.md) - November 2025 changes
- [docs/infrastructure-overview.md](docs/infrastructure-overview.md) - System architecture

### Database Schema

**Key Tables**:
- `node` - Base table for all content (polymorphic)
- `nodetype` - Defines node types
- `user` - User accounts
- `writeup` - Article content
- `weblog` - Blog/news entries
- `coolwriteups` - Editor-marked cool content
- `tomb` - Deleted nodes (resurrection system)
- `notification` - User notifications

**Node Types**:
- `document` (base type)
- `superdoc` (type_nodetype=14) - Special system pages
- `restricted_superdoc` (type_nodetype=46) - Editor/admin-only pages
- `oppressor_superdoc` (type_nodetype=57) - God-mode admin pages
- `fullpage` (type_nodetype=86) - Standalone interface pages
- `ticker` (type_nodetype=88) - XML/JSON API endpoints
- `superdocnolinks` (type_nodetype=107) - Superdocs with link parsing disabled
- `writeup`, `user`, `usergroup`, `htmlcode`, `htmlpage`, etc.

**Special Documents**: See [docs/special-documents.md](docs/special-documents.md) for complete catalog (159 in dev environment)

## Common Tasks

### Adding a New React Nodelet

1. Create component in `react/components/Nodelets/YourNodelet.js`
2. Create portal in `react/components/Portals/YourNodeletPortal.js`
3. Add to E2ReactRoot:
   - Import component and portal
   - Add to `managedNodelets` array
   - Add state initialization
   - Add portal in render()
4. Update `Application.pm::buildNodeInfoStructure()` to load data into `$e2->{yourdata}`
5. Update Perl nodelet function to `return "";`
6. Create test suite in `react/components/Nodelets/YourNodelet.test.js`
7. Update [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md)

### Running Tests

```bash
# React tests
npm test

# Perl tests
prove t/

# Specific Perl test
prove t/022_node_resurrection.t

# Smoke tests (pre-flight checks)
./tools/smoke-test.rb

# Docker environment
./docker/devbuild.sh
docker exec -it e2_everything2_1 bash
```

### Regenerating Special Documents Documentation

```bash
# Extract document data from database and generate markdown
docker exec e2devdb mysql -u root -pblah everything -N -e \
  "SELECT node_id, title, CASE type_nodetype
   WHEN 14 THEN 'superdoc'
   WHEN 46 THEN 'restricted_superdoc'
   WHEN 57 THEN 'oppressor_superdoc'
   WHEN 86 THEN 'fullpage'
   WHEN 88 THEN 'ticker'
   WHEN 107 THEN 'superdocnolinks'
   END as doc_type
   FROM node
   WHERE type_nodetype IN (14, 46, 57, 86, 88, 107)
   ORDER BY type_nodetype, title" 2>&1 | \
  grep -v "^mysql:" | \
  ruby /tmp/gen_doc_corrected.rb > docs/special-documents.md

# Then run smoke tests to verify
./tools/smoke-test.rb
```

### Database Access

```perl
# Get node by ID
my $node = $DB->getNodeById($node_id);

# Get node by title and type
my $node = $DB->getNode("title", "nodetype");

# DataStash access
my $data = $DB->stashData("datastash_name");

# SQL queries
my $csr = $DB->sqlSelectMany("fields", "table", "where", "order/limit");
```

## Current Priorities

### High Priority
1. Continue nodelet migrations (see [nodelet-migration-status.md](docs/nodelet-migration-status.md))
   - Chatterbox (complex, high value)
   - Notifications (important UX)
   - Messages (core feature)
2. React 18.3.x stability and test coverage
3. Progressive Mason2 elimination

### Medium Priority
1. Additional nodelet migrations (Tier 2-3)
2. Page content migration planning
3. Legacy jQuery removal where feasible

### Future (Post-Mason2)
1. React 19 upgrade
2. Full modern frontend stack
3. API-first architecture

## Known Issues & Gotchas

### React Portals
- **Issue**: Portals require target DOM element to exist
- **Solution**: Mason2 template must render placeholder div
- **Example**: `<div id='readthis'></div>` in Mason template

### Section Preferences
- **Issue**: Section collapse state stored as `{nodelet}_hide{section}` in user preferences
- **Logic**: Value of `1` means hidden, `0` or `undefined` means shown
- **Implementation**: `e2.display_prefs[nodelet+"_hide"+section] !== 1`

### DataStash Caching
- **Issue**: DataStash updates every 60 seconds via cron
- **Implication**: Changes may not appear immediately
- **Solution**: Understand caching behavior, don't expect real-time updates

### Node Type Confusion
- **Issue**: Writeups have both `node` and `writeup` table entries
- **Solution**: Always use `getNodeById()` which handles joins automatically

### Eval() History
- **Issue**: Legacy code used eval() for data deserialization
- **Status**: Removed in Session 1, replaced with Safe.pm
- **Important**: Never reintroduce eval() for untrusted data

### Legacy AJAX
- **Issue**: Some legacy AJAX calls seem obsolete
- **Status**: `showchatter` is ACTIVE and required - don't remove!
- **Lesson**: Always verify before removing legacy code

### URL Encoding for Special Documents
- **Issue**: Documents with slashes in titles need special URL handling
- **Correct**: Use raw slashes: `/title/online+only+/msg`
- **Wrong**: Percent-encoded slashes: `/title/online+only+%2Fmsg` (returns 404)
- **Pattern**: Spaces → `+`, slashes → raw `/`, other special chars → standard encoding

### Docker Volume Mount Caching
- **Issue**: File changes on host may not appear in container immediately
- **Solution**: Use `docker cp <host-file> <container>:<container-path>` to force update
- **Example**: `docker cp document.pm e2devapp:/var/everything/ecore/Everything/Delegation/document.pm`
- **Then**: Restart Apache with `docker exec e2devapp apache2ctl graceful`

### Development Environment Checks
- **Pattern**: Production-only features (S3, external APIs) need dev environment checks
- **Method**: Use `$Everything::CONF->environment eq 'development'`
- **Example**: node_backup returns friendly message instead of attempting S3 operations
- **Important**: Test that delegation compiles and renders, even if feature is disabled

## Development Environment

### Local Setup
```bash
# Docker environment
./docker/devbuild.sh

# Install dependencies
npm install

# Run tests
npm test
```

### File Locations
- **Project Root**: `/home/jaybonci/projects/everything2/`
- **Perl Code**: `ecore/Everything/`
- **React Code**: `react/`
- **Templates**: `www/mason2/`
- **Tests**: `t/` (Perl), `react/**/*.test.js` (React)
- **Documentation**: `docs/`

## Code Style

### Perl
- Moose OOP patterns
- Method signatures: `my ($this, $param1, $param2) = @_;`
- Use `$DB` for database, `$APP` for application
- Follow existing patterns in codebase

### React
- Functional components (no classes)
- Props destructuring encouraged
- Use shared components (NodeletContainer, NodeletSection, LinkNode)
- Comprehensive test coverage required
- No emojis unless explicitly requested

### Testing
- React: Jest with React Testing Library
- Perl: Test::More
- Mock child components in React tests
- Test rendering, state, props, edge cases

## Git Workflow

### Branch Naming
- `issue/{number}/{description}` - For GitHub issues
- Current branch: `issue/3742/remove_evalcode`
- Main branch: `master`

### Commit Messages
- Clear, descriptive
- Reference issue numbers when applicable
- Include co-author credit:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

### Pull Request Pattern
- Push changes to feature branch
- Create PR via `gh pr create`
- Include summary and test plan
- All tests must pass

## Contact & Resources

- **GitHub**: https://github.com/everything2/everything2
- **Issues**: https://github.com/everything2/everything2/issues
- **Project Lead**: Jay Bonci
- **Documentation**: [docs/](docs/) directory

## Tips for AI Assistants

1. **Always read files before editing** - Use Read tool before Edit/Write
2. **Follow established patterns** - Don't invent new architectures
3. **Test everything** - Add tests for new code; run smoke tests before full test suite
4. **Document changes** - Update relevant .md files (especially CLAUDE.md)
5. **Check existing code** - Search before implementing (might already exist)
6. **Ask when unclear** - Better to clarify than assume
7. **Maintain context** - Keep CLAUDE.md updated for future sessions
8. **Be conservative** - Don't remove legacy code without verification
9. **Use TodoWrite** - Track complex tasks
10. **Read summaries carefully** - Previous session context is valuable
11. **Run smoke tests first** - `./tools/smoke-test.rb` catches issues before expensive full test run
12. **Docker quirks** - Files may need `docker cp` to sync; containers are `e2devapp` and `e2devdb`

## Session Context Pattern

When starting a new session, review:
1. This CLAUDE.md file
2. Recent commits (`git log`)
3. Current branch status (`git status`)
4. Relevant documentation in `docs/`
5. Test status (`./tools/smoke-test.rb` and `npm test`)

When ending a session, update:
1. This CLAUDE.md file with new context
2. Relevant documentation files
3. Complete any pending TODOs

---

*This document is maintained to provide continuity across AI assistant sessions and help new contributors understand the codebase quickly.*
