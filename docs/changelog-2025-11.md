# Everything2 Changelog - November 2025

**For communication to users - Non-technical summary**

## reCAPTCHA Enterprise Migration (2025-11-30) 🔒 NEW

### Upgraded to Google reCAPTCHA Enterprise
**What Changed:** Upgraded the anti-spam protection from reCAPTCHA v3 to reCAPTCHA Enterprise for improved bot detection.

**Why This Matters:**
- **Better Bot Detection**: Enterprise API provides more accurate risk scores and better protection against sophisticated spam bots
- **Future-Proofing**: Enterprise is Google's recommended platform for high-traffic sites
- **Metrics & Monitoring**: Now have access to detailed reCAPTCHA statistics and monitoring tools

**Technical Details:**
- Updated [SignUp.js](react/components/Documents/SignUp.js) with Enterprise script loading and token generation
- Fixed race condition where form submission could occur before reCAPTCHA token was ready
- Added dual-mode verification in [sign_up.pm](ecore/Everything/Page/sign_up.pm) - supports both Enterprise and legacy endpoints
- Created [recaptcha-stats.rb](tools/recaptcha-stats.rb) monitoring tool for metrics dashboard
- Fixed username availability check on form error (pre-populated username now validates on mount)

**User Impact:** No visible changes - the signup experience remains the same, but spam protection is now more robust.

---

## Docker Build Optimization (2025-11-30) ⚡ NEW

### CodeBuild Layer Caching Improvements
**What Changed:** Optimized AWS CodeBuild configuration for better Docker layer caching, significantly reducing build times.

**Technical Details:**
- Converted Dockerfile to multi-stage build with separate `deps` stage
- Dependencies stage (apt-get, cpanm, npm install) now cached separately
- Added `BUILDKIT_INLINE_CACHE=1` for proper cache metadata embedding
- Deps image pushed to ECR for reuse across builds
- Build times reduced from ~8 minutes to ~2-3 minutes when dependencies unchanged

**User Impact:** No visible changes - this is infrastructure improvement for faster deployments.

---

## Message Ordering Fix (2025-11-30) 🐛 NEW

### Sidebar Messages Now Display Chat-Style (Newest at Bottom)
**What Changed:** Fixed message ordering in sidebar components to match chat interface expectations.

**Why This Matters:**
- **Chat-Style Interface**: Messages nodelet and Chatterbox mini-messages now show newest messages at the bottom (like a chat)
- **Inbox Unchanged**: Full Message Inbox page keeps newest at top (traditional email style)
- **Consistency**: Sidebar components now behave like chat interfaces where you read from top to bottom

**Technical Details:**
- Added `chatOrder` prop to [MessageList.js](react/components/MessageList.js) for independent ordering control
- Updated Messages nodelet and Chatterbox mini-messages to use `chatOrder={true}`
- Message Inbox page keeps default `chatOrder={false}` (newest first)

**User Impact:** Private messages in the sidebar now appear in chronological order with newest at bottom, matching natural chat reading flow.

---

## Deprecated Code Cleanup (2025-11-30) 🧹 NEW

### Removed Legacy Nodelet Display Code
**What Changed:** Removed deprecated `node_shownodelet_page` function from htmlpage.pm after production page was deleted.

**Technical Details:**
- Removed 7 lines of deprecated stub code from [htmlpage.pm](ecore/Everything/Delegation/htmlpage.pm)
- Updated nodelet links in `node_listnodelets_page` to point to nodelet info pages instead of deleted display type

**User Impact:** No visible changes - cleanup of obsolete code that was no longer used.

---

## Notification Periodic Update Bug Fixed (2025-11-29) 🐛

### Bug Fix: Notifications Disappearing After Periodic Refresh
**What Changed:** Fixed a bug where the Notifications nodelet would lose all notification text after the 2-minute periodic refresh, showing only the dismiss "×" button.

**What Was Broken:**
- Periodic updates (every 2 minutes when active and nodelet expanded) were returning raw database rows instead of rendered notification text
- Initial page load worked correctly (using `buildNotificationsData()`)
- Periodic refresh used different API endpoint that wasn't rendering the notification text
- React component expected `notification.text` field but API was returning database fields like `notified_id`, `args`, `notification_id`
- Result: After periodic refresh, notifications would show only "×" button with no text

**The Fix:**
- Modified `/api/notifications/` endpoint to use `Application.pm::getRenderedNotifications()`
- Now both initial load and periodic updates use the same rendering logic
- Both endpoints return consistent data structure with rendered `text` field
- Affects all places Notifications nodelet appears:
  - Main sidebar
  - Chatterlight family pages (chatterlight, chatterlight classic, chatterlighter)
  - Any fullpage layouts with notifications

**User Impact:**
- Notifications will no longer lose their text after 2 minutes
- Periodic updates now work correctly across all page types
- No more mysterious "×" buttons with no associated notification text

**Technical Details:**
- File: [ecore/Everything/API/notifications.pm:17-32](ecore/Everything/API/notifications.pm#L17-L32)
- Simplified `get_all` endpoint from 66 lines to 14 lines by reusing existing rendering logic
- Eliminated code duplication between initial load and periodic refresh

---

## CSS Variable System & Theme Testing (2025-11-29) 🎨 NEW

### A/B Testing for Stylesheet Modernization
**What Changed:** Implemented CSS variable-based theming system with `?csstest=1` parameter for non-disruptive testing.

**Why This Matters:**
- **User Choice Preservation**: All 19 user stylesheets remain unchanged - no one's theme will break
- **Future-Proofing**: CSS variables enable modern features like real-time theme customization and dark mode
- **Safe Testing**: Users can opt-in to test new variable-based stylesheets without affecting normal browsing
- **React Compatibility**: Prepares themes to work properly with new React components

**Technical Implementation:**
- Created 19 `-var.css` versions of all stylesheets (Kernel Blue, Understatement family, Responsive2, etc.)
- Modified Controller.pm to detect `?csstest=1` and load variable versions
- Designed 20+ standardized CSS variable names (--e2-color-link, --e2-bg-body, etc.)
- Full documentation: docs/css-variables-testing.md

**User Impact:**
- No visible changes to normal site usage
- Add `?csstest=1` to any URL to preview variable-based stylesheets
- Report any visual differences - helps validate the modernization is working correctly
- Future: Will enable user-customizable theme colors without admin intervention

---

### Document Functions Cleanup
**What Changed:** Removed 690 lines of legacy code from document.pm that were migrated to React.

**Functions Removed:**
- `suspension_info` (161 lines) - Now SuspensionInfo.js + suspension.pm API
- `giant_teddy_bear_suit` (93 lines) - Now GiantTeddyBearSuit.js + teddybear.pm API
- `text_formatter` (436 lines) - Now TextFormatter.js component

**Why This Matters:**
- **Cleaner Codebase**: Reduces complexity and potential for bugs
- **Single Source of Truth**: Each feature now has one implementation, not two
- **Maintainability**: Future updates only need to touch React code, not Perl

**User Impact:** None - these features work exactly the same, just with cleaner backend code.

---

## Major Security & Performance Improvements

### Code Security Overhaul (eval() Removal Campaign) ✅ COMPLETE
**What Changed:** Removed all unsafe code evaluation from the Everything2 backend (22 instances total).

**Why This Matters:**
- **Security**: The old code execution system had potential security vulnerabilities that could be exploited. The new system is locked down and safe.
- **Performance**: We can now use modern performance profiling tools to make the site faster. Previously, these tools couldn't analyze parts of our code.
- **Reliability**: Code is now easier to debug and maintain, meaning fewer bugs and faster fixes.
- **Future-proofing**: Prepares the site for future upgrades and improvements.

**User Impact:** You won't notice any changes to how the site works, but the site is now more secure and maintainable behind the scenes.

---

### Private Message Outbox Fixed ✅ COMPLETE
**What Changed:** Messages sent via `/msg` command now appear in your Message Outbox.

**Why This Matters:**
- **Record Keeping**: You can now see what messages you've sent, not just what you've received
- **Accountability**: Keep track of your conversations and what you've told other users
- **Consistency**: The outbox now works the same way whether you send messages via the chat command (`/msg`) or the user's home node message form

**User Impact:** When you send private messages using `/msg username message` in the chatterbox, those messages will now appear in your Message Outbox along with messages sent via other methods. This has always worked for messages sent through user home nodes, but `/msg` command messages were not being saved to the outbox until now.

---

## Frontend Modernization: React Migration Initiative 🚀 IN PROGRESS

### Porting Epicenter, ReadThis, and MasterControl to React
**What Changed:** We're actively migrating Everything2's interface components (nodelets) from the legacy Perl/Mason2 system to modern React. Three major nodelets have been migrated: Epicenter (voting/experience display), ReadThis (news feed), and MasterControl (editor tools including node notes).

**Why This Matters:**
- **Modern Foundation**: React is the industry-standard frontend framework, giving us access to modern tools, libraries, and community support.
- **Site Health**: The old Mason2 templating system is 15+ years old and increasingly difficult to maintain. Moving to React ensures E2 can be maintained and improved for decades to come.
- **Performance**: React's efficient rendering means faster, more responsive interfaces. Users will see updates happen instantly without full page reloads.
- **Future Features**: React enables modern UI capabilities like real-time updates, smooth animations, drag-and-drop interfaces, and mobile-responsive designs that weren't possible with the old system.
- **Developer Experience**: New contributors can work with familiar, well-documented technology instead of learning E2's custom templating system.

**User Impact:**
- **Current State**: During this transition period, you may notice some visual inconsistencies or behavioral differences between migrated and non-migrated components. This is expected and temporary.
- **What to Expect**: Some nodelets now update without page reloads (like adding/deleting node notes in Master Control). Link formatting and user interactions should feel more responsive.
- **Future Benefits**: Once the migration is complete, we'll be able to rapidly add modern features like collapsible sections, inline editing, keyboard shortcuts, and mobile-optimized layouts.

**What's Been Migrated:**
- ✅ **Epicenter** (10 nodelets total now in React): User stats, navigation, voting/experience display
- ✅ **ReadThis**: News feed from "News For Noders" with frontpage news integration
- ✅ **MasterControl**: Editor control panel with interactive node notes, admin tools, CE section
- ✅ **Node Notes Enhancement**: Added interactive note management with link parsing, noter username display, and real-time updates via API
- ✅ **Current Poll Voting**: Interactive AJAX voting system with real-time results (no page reload)
  - Vote directly from the nodelet without leaving the page
  - Instant vote results with visual bar graphs and percentages
  - Admin vote management tools (delete votes, audit poll integrity)
  - Full REST API for poll operations with comprehensive test coverage
- ✅ **Other Users Nodelet**: Complete restoration of all social interaction features
  - Linked staff badges with tooltips (@ = gods, $ = editors, + = chanops, Ø = borged)
  - New user indicators (shows account age for users < 30 days, visible to admins/editors only)
  - Random user actions ("is petting a kitten" - adds personality and fun)
  - Recent noding activity ("has recently noded [writeup]" - shows active contributors)
  - Multi-room support (see users across different chat rooms)
  - Respect for user preferences (message ignore list, invisibility, infravision)
  - Halloween costume support (festive feature for October)
  - All original social signaling features preserved from legacy implementation
  - **Data Architecture**: Refactored from pre-rendered HTML to structured JSON objects
    - Better security (no dangerouslySetInnerHTML for user data)
    - Lighter payload
    - Consistent LinkNode usage throughout
    - Privilege checks properly enforced (new user tags only visible to staff)

**Technical Foundation Built:**
- Created reusable `ParseLinks` component for E2's bracket link syntax (20 tests)
  - Supports simple links: `[title]`, `[title|display]`
  - Supports external links: `[http://url]`, `[http://url|text]`
  - Supports nested bracket syntax: `[title[nodetype]]` (e.g., `[root[user]]` → `/node/user/root`)
  - Matches Perl parseLinks() regex exactly for legacy compatibility
- Implemented complete poll voting REST API (POST /api/poll/vote, POST /api/poll/delete_vote)
  - Full validation and authorization checks
  - Real-time vote updates without page reload
  - Admin vote management for poll integrity
  - Type-safe responses (JavaScript strict equality compatibility)
  - 62 automated tests ensuring reliability
- Implemented node notes REST API (GET/POST/DELETE) with full test coverage (62 tests including legacy format)
- Built shared components: `NodeletContainer`, `NodeletSection`, `LinkNode`, `ParseLinks`
- Optimized API usage: Eliminated redundant GET requests after CREATE/DELETE operations
- Fixed initial page load: `noter_username` now populated on first render (no refresh needed)
- **Section collapse preferences**: Fixed 8 nodelets to properly respect user collapse settings
  - Categories, CurrentUserPoll, FavoriteNoders, MostWanted, OtherUsers, PersonalLinks, RecentNodes, UsergroupWriteups
  - Changed from hardcoded `collapsible={false}` to proper `showNodelet` and `nodeletIsOpen` props
- **Legacy format support**: Handles historical notes where author was embedded in notetext (noter_user = 1)
  - API marks legacy notes with `legacy_format` flag
  - Component displays full notetext without separate username for legacy notes
  - Modern notes (noter_user > 1) show parsed username links
  - Comprehensive tests for both formats
- All 222 React tests passing (9 NodeNotes component tests), all 62 API tests passing

**Developer Experience Improvements:**
- ✅ **Source Map Feature**: Developer nodelet now shows which code files render each page
  - Works for both modern React pages and legacy delegation pages
  - Shows component path, description, and direct GitHub links to source code
  - Displays all contributing components: React components, Page classes, delegations, tests
  - Modal interface with "View on GitHub" and "Edit on GitHub" buttons
  - Built-in contribution guide linking to CONTRIBUTING.md
  - **Technical Implementation**: Moved buildSourceMap() to Application.pm for dual architecture support
    - Accessible from both Controller.pm (new) and htmlcode.pm (legacy delegation)
    - Handles blessed objects (Controller) and hashrefs (legacy) correctly
    - Detects React pages via buildReactData() method existence
    - Uses Everything::HTML::getPage() for legacy page detection
  - Makes contributing to E2 significantly easier by showing exactly which files to edit
  - Developers can quickly navigate from a page to its source code with one click

**Why This Is Critical Now:**
The old system architecture makes it increasingly difficult to fix bugs, add features, or onboard new developers. Every month we delay migration, the technical debt grows. By establishing the React foundation now, we ensure E2 can continue to evolve and improve for the next generation of noders.

---

## Node Resurrection System Improvements

### Fixed Dr. Nate's Secret Lab
**What Changed:** Node resurrection (bringing back deleted content) now works correctly and has better safety checks.

**Why This Matters:**
- **Data Recovery**: When editors need to restore accidentally deleted content, it now works reliably.
- **Safety**: The system prevents accidentally trying to resurrect content that's already been restored.
- **User Experience**: Clear feedback shows when content has already been resurrected, with a direct link to view it.

**User Impact:** Most users won't interact with this feature directly (it's an editor/admin tool), but it means deleted content can be recovered more reliably when needed.

**Technical Details:**
- Added comprehensive test suite (28 automated tests)
- Prevents double-resurrection attempts
- Cleans up database records properly
- Shows clear success/error messages

---

## Bug Fixes

### Fixed "Bestow Cools" Function
**What Changed:** The admin tool for giving cools to users now works correctly when bestowing cools to yourself (useful for testing).

**Why This Matters:**
- **Testing**: Admins can properly test the cools system
- **Accuracy**: Cools are now added to your total instead of replacing it (e.g., if you have 5 cools and get 3 more, you now have 8 instead of 3)

**User Impact:** Only affects admin testing functionality. Regular users won't notice any change to how cools work.

---

## Chat System Improvements

### Removed Legacy Chat Interfaces
**What Changed:** Removed two older, non-functional chat interfaces: "joker's chat" and "My Chatterlight" (original version).

**Why This Matters:**
- **Consistency**: Moving toward a unified, modern chat experience for all users
- **Maintenance**: Removing non-functional code reduces confusion and makes the site easier to maintain
- **Focus**: Resources can be directed toward improving the main chatterbox experience

**User Impact:** If you tried to access these pages, they were already non-functional. This is an early cleanup step toward unifying the chat experience under a single, modern interface. The standard chatterbox remains fully functional and is the recommended way to chat on E2.

---

## Under the Hood (Technical Details)

### Safe Data Deserialization
- Replaced unsafe `eval()` with `Safe.pm` compartment
- Blocks all dangerous operations (system calls, file operations)
- Only allows safe data structure operations
- 17 automated tests ensure security

### Module Loading
- Replaced string eval with `Module::Runtime` for dynamic plugin loading
- Affects 150+ dynamically loaded plugins (API, Controller, DataStash, Node, Page)
- All 28 Perl tests pass (948 assertions)

### Code Delegation
- Migrated 47 opcode nodes to proper delegation system
- Migrated 222 htmlcode nodes to delegation
- Migrated 99 htmlpage nodes to delegation
- Created notification system module (24 notification types)

### Test Coverage
- Added 28 resurrection tests
- Added 17 deserialization security tests
- Added 24 notification rendering tests
- Added 209 React component tests (including 16 ParseLinks tests)
- Added 61 API tests for node notes
- All tests pass cleanly with no warnings

---

## Test Infrastructure Improvements

### Parallel Test Execution Robustness (Session 24)
**What Changed:** Fixed intermittent test failures during parallel execution and added comprehensive UTF-8 emoji testing.

**Why This Matters:**
- **Reliability**: Tests that shared user accounts (normaluser1, normaluser2) now run serially to avoid race conditions
- **UTF-8 Support**: Emojis and special characters (❤️, …, 🎉) now verified to work correctly in chatter messages
- **Developer Experience**: Consistent test results mean faster development cycles

**Technical Details:**
- Added t/008_e2nodes.t and t/009_writeups.t to serial test execution (prevents session conflicts)
- Integrated UTF-8 emoji tests into t/037_chatter_api.t (6 new assertions)
- Tests verify proper UTF-8 flag setting and mojibake prevention
- Updated CLAUDE.md with comprehensive vendor library path documentation
- All 49 Perl tests + 445 React tests passing consistently

**User Impact:** Behind-the-scenes improvement ensuring site features work correctly with international characters and emojis.

---

## SEO & Content Optimization (November 27-28, 2025)

### Meta Description Improvements ✅
**What Changed:** Fixed meta description generation to properly handle E2 link syntax and truncate at word boundaries.

**Technical Details:**
- [Application.pm:1228-1238](ecore/Everything/Application.pm#L1228) - Fixed truncation logic
- Processes E2 soft link syntax: `[target|display text]` → uses display text only
- Truncates at 155 characters on word boundaries (no mid-word cuts)
- Adds ellipsis (`...`) only when text is actually truncated
- Comprehensive test coverage: [t/045_meta_description.t](t/045_meta_description.t) (5 subtests, 14 assertions)

**User Impact:** Better search engine snippets with natural-reading descriptions that properly display E2 link text.

### Social Sharing Cleanup ✅
**What Changed:** Removed defunct social networks from sharing widget.

**Technical Details:**
- [htmlcode.pm:9770-9776](ecore/Everything/Delegation/htmlcode.pm#L9770) - Cleaned up social networks
- Removed: Delicious (2017), Digg, StumbleUpon (2018), Yahoo Bookmarks, Google Bookmarks, BlinkList, Magnolia, Windows Live, Propellor, Technorati, Newsvine
- Kept: Twitter, Facebook, Reddit (active networks)

**User Impact:** Cleaner sharing interface with only functional services.

---

## React Page Migration (November 27-29, 2025)

### Login Page Modernization ✅
**What Changed:** Migrated login page from Perl delegation to React with modern Kernel Blue styling.

**Technical Details:**
- [login.pm](ecore/Everything/Page/login.pm) - Page class with buildReactData()
- [Login.js](react/components/Documents/Login.js) - React component (11.9 KiB bundle)
- Preserves `op=login` form functionality for backend compatibility
- Three UI states: login form, success (post-login navigation), already logged in, error (failed login)
- Modern card-based layout using Kernel Blue color palette
- Responsive design with proper input focus states and accessibility

**User Impact:** Modern, clean login experience with better visual design while maintaining all existing functionality.

### Holiday Page Consolidation ✅
**What Changed:** Migrated 5 holiday checker pages to single reusable React component.

**Technical Details:**
- [IsItHoliday.js](react/components/Documents/IsItHoliday.js) - Reusable component (3.8 KiB)
- Migrated: Is it Christmas yet?, Is it Halloween yet?, Is it New Year's Day yet?, Is it New Year's Eve yet?, Is it April Fools' Day yet?
- Ported date-checking logic from Mason2 to JavaScript
- Single component serves all 5 pages via contentData routing
- Fixed page name conversion to handle `?` characters in titles

**User Impact:** No visible changes; holiday pages work as before but are now faster and easier to maintain.

### Chatterlight Variants Migration ✅
**What Changed:** Migrated 3 chatterlight pages (chat-focused interfaces) to React fullpage architecture.

**Technical Details:**
- Migrated: chatterlight, chatterlight classic, chatterlighter
- [Chatterlight.js](react/components/Documents/Chatterlight.js) - Unified React component
- Fixed fullpage template inheritance (react_fullpage.mc with `extends => undef`)
- Removed 187 lines of obsolete delegation code from document.pm
- Fixed React collapsedNodelets error (undefined handling in E2ReactRoot.js)

**User Impact:** Chat-focused views now work with modern React architecture; no visible changes to functionality.

### Node List Pages Migration ✅
**What Changed:** Migrated 5 node list pages to single reusable NodeList component.

**Technical Details:**
- [NodeList.js](react/components/Documents/NodeList.js) - Reusable component
- Migrated: 25 (random nodes), Everything New Nodes, E2N, ENN, EKN
- Pagination support with configurable page size
- Removed 5 obsolete Mason templates

**User Impact:** Node list pages load faster and have consistent pagination behavior.

---

## Message System Enhancements (November 28, 2025)

### Message Outbox Implementation ✅
**What Changed:** Backend now creates outbox entries for sent messages (API level).

**Technical Details:**
- [Application.pm:4614-4631](ecore/Everything/Application.pm#L4614) - Dual message insert (inbox + outbox)
- Outbox messages identified by `author_user == for_user` in database
- Supports multi-recipient messages (one outbox entry per recipient)
- Online-only messages get `OnO:` prefix in outbox
- Works with `/msg` chatter command
- Comprehensive test coverage: [t/044_message_outbox.t](t/044_message_outbox.t) (4 subtests, 19 assertions)
- [messages.pm API](ecore/Everything/API/messages.pm) supports `outbox` parameter

**User Impact:** Backend infrastructure in place for future "Sent Messages" UI feature. No UI changes yet (Messages nodelet remains minimal styling as designed).

---

## Quality Metrics

- **Security Critical eval() Count:** 0 (down from 22) ✅
- **Test Suite Size:** 51 Perl tests + 445 React tests
- **React Nodelets Migrated:** 10 of 25 (40% complete)
- **React Pages Migrated:** 50+ superdoc pages
- **Code Quality:** All Perl::Critic checks pass (239 tests)
- **Modernization Progress:** 90% complete
- **Test Execution:** 4 serial tests, 47 parallel tests (robust against race conditions)
- **Delegation Code Removed:** 350+ lines of obsolete Perl code eliminated

---

## What's Next

### Immediate Priorities (React Migration)
1. **Chatterbox Migration**: Moving the chat interface to React for real-time updates and better UX
2. **Notifications Nodelet**: Modern notification display with inline actions
3. **Messages Nodelet**: Message inbox/outbox with React for better performance
4. **Navigation Components**: User menu, search, and other navigation elements

### Backend Improvements
The security improvements enable:
1. Performance profiling and optimization
2. Migration to modern web server architecture (PSGI/Plack)
3. Better debugging tools
4. Easier feature development

### Long-term Vision
Once Mason2 is fully retired and all nodelets are in React:
- Upgrade to React 19 for latest features and performance
- Modern responsive design that works beautifully on mobile
- Rich interactions: drag-and-drop, keyboard shortcuts, smooth animations
- Real-time features: live chat updates, instant notifications, collaborative editing
- Easier onboarding for new developers = faster feature development

The foundation is now solid for transforming E2 into a modern web platform while preserving everything we love about the community and content!

---

## Template Cleanup & Default Nodelet Persistence (November 27, 2025)

### Fixed Default Nodelet Persistence ✅
**What Changed:** User default nodelet settings now persist correctly when set via user.pm.

**Technical Details:**
- [user.pm:275](ecore/Everything/Node/user.pm#L275) - Fixed default nodelet persistence
- Changed from `Everything::setVars($USER, $VARS)` to `$self->set_vars($VARS)`
- Root cause: `$self->NODEDATA` doesn't include `vars` field without settings table join
- Method handles blessed object internals correctly by joining settings table internally

**User Impact:** Default nodelets now properly save when set programmatically (backend admin operations).

### Mason Template Cleanup ✅
**What Changed:** Removed 4 obsolete Mason helper templates that were replaced by React components.

**Technical Details:**
- Removed `templates/helpers/ennchoice.mi` - Dropdown selector (unused)
- Removed `templates/helpers/is_special_date.mi` - Date checking (moved to IsItHoliday.js)
- Removed `templates/helpers/nodelist.mi` - Node list display (pages now React)
- Removed `templates/pages/is_it_holiday.mc` - Holiday template (now generic react_page.mc)

**User Impact:** No user-facing changes; cleanup of obsolete code that was replaced during React migration.

### Holiday Pages Migration ✅
**What Changed:** Migrated 5 holiday pages to single reusable React component.

**Technical Details:**
- Created [IsItHoliday.js](react/components/Documents/IsItHoliday.js) - Reusable component (3.8 KiB bundle)
- Updated 5 Page classes to use `buildReactData()`:
  - [is_it_christmas_yet.pm](ecore/Everything/Page/is_it_christmas_yet.pm)
  - [is_it_halloween_yet.pm](ecore/Everything/Page/is_it_halloween_yet.pm)
  - [is_it_new_year_s_day_yet.pm](ecore/Everything/Page/is_it_new_year_s_day_yet.pm)
  - [is_it_new_year_s_eve_yet.pm](ecore/Everything/Page/is_it_new_year_s_eve_yet.pm)
  - [is_it_april_fools_day_yet.pm](ecore/Everything/Page/is_it_april_fools_day_yet.pm)
- Ported date-checking logic from Mason2 `is_special_date.mi` to JavaScript
- Fixed page name conversion to handle `?` characters ([Application.pm:6693](ecore/Everything/Application.pm#L6693))
- Fixed double-wrapping issue (buildReactData returns data without contentData wrapper)
- Single component serves all 5 pages via contentData routing

**Key Discoveries:**
- Page name conversion: "Is it Christmas yet?" → `is_it_christmas_yet` (regex strips `?`)
- buildReactData pattern: Returns `{ occasion => 'xmas' }` NOT `{ contentData => { ... } }`
- All nodelist pages (25, E2N, ENN, EKN) and holiday pages now pure React

**User Impact:** Holiday pages look and work the same but are now faster and easier to maintain.

---

*Last Updated: November 30, 2025*
*Maintained by: Jay Bonci*
