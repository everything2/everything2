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
- Added 116 React component tests
- All tests pass cleanly with no warnings

---

## Quality Metrics

- **Security Critical eval() Count:** 0 (down from 22) ✅
- **Test Suite Size:** 30 Perl tests + 116 React tests
- **Code Quality:** All Perl::Critic checks pass (239 tests)
- **Modernization Progress:** 81% complete

---

## What's Next

The security improvements enable:
1. Performance profiling and optimization
2. Migration to modern web server architecture (PSGI/Plack)
3. Better debugging tools
4. Easier feature development

No immediate changes to user-facing features, but the foundation is now solid for future improvements!

---

*Last Updated: November 20, 2025*
*Maintained by: Jay Bonci*
