# Everything2 Changelog - November 2025

**For communication to users - Non-technical summary**

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

**Technical Foundation Built:**
- Created reusable `ParseLinks` component for E2's bracket link syntax (20 tests)
  - Supports simple links: `[title]`, `[title|display]`
  - Supports external links: `[http://url]`, `[http://url|text]`
  - Supports nested bracket syntax: `[title[nodetype]]` (e.g., `[root[user]]` → `/node/user/root`)
  - Matches Perl parseLinks() regex exactly for legacy compatibility
- Implemented node notes REST API (GET/POST/DELETE) with full test coverage (62 tests including legacy format)
- Built shared components: `NodeletContainer`, `NodeletSection`, `LinkNode`, `ParseLinks`
- Optimized API usage: Eliminated redundant GET requests after CREATE/DELETE operations
- Fixed initial page load: `noter_username` now populated on first render (no refresh needed)
- **Legacy format support**: Handles historical notes where author was embedded in notetext (noter_user = 1)
  - API marks legacy notes with `legacy_format` flag
  - Component displays full notetext without separate username for legacy notes
  - Modern notes (noter_user > 1) show parsed username links
  - Comprehensive tests for both formats
- All 222 React tests passing (9 NodeNotes component tests), all 62 API tests passing

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

## Quality Metrics

- **Security Critical eval() Count:** 0 (down from 22) ✅
- **Test Suite Size:** 30 Perl tests + 209 React tests + 61 API tests
- **React Nodelets Migrated:** 10 of 25 (40% complete)
- **Code Quality:** All Perl::Critic checks pass (239 tests)
- **Modernization Progress:** 85% complete

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

*Last Updated: November 21, 2025*
*Maintained by: Jay Bonci*
