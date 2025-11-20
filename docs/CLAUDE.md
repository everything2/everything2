# Claude Context Document

**Last Updated:** 2025-11-20
**Current Branch:** issue/3742/remove_evalcode
**Project:** Everything2 (E2) - Legacy Perl-based content management system modernization

## Current Session Context

### Active Task: eval() Removal Campaign (Issues #3742+)

**Objective:** Remove all string eval() calls from the E2 codebase to improve security, enable profiling, and enhance maintainability.

**Current Phase:** ✅ COMPLETE - ALL PHASES FINISHED
**Overall Status:** 🎉🎉 100% COMPLETE - ALL 22 Perl string eval() calls removed! 🎉🎉

**All Phases Completed:**
- ✅ Phase 1: parseCode/embedCode/evalCode removal (18 eval() calls)
- ✅ Phase 2: PluginFactory safe module loading (1 eval() call)
- ✅ Phase 2.5: API.pm routing + weblog closures (2 eval() calls)
- ✅ Phase 3: Data deserialization with Safe.pm (4 eval() calls - JUST COMPLETED!)

**Remaining:** 0 Perl string eval() calls - ZERO! ✅
  - All data deserialization now uses Safe.pm compartment
  - All dangerous operations blocked (system calls, file I/O, exec)
  - Only data structure deserialization allowed

### Key Findings

#### 1. evalCode() Function Status
- **Location (removed):** `ecore/Everything/HTML.pm:603-623` (in git HEAD, removed in working directory)
- **Purpose:** Core eval() function that evaluated arbitrary Perl code strings
- **Callers:** `parseCode()` and `embedCode()` (also removed in uncommitted changes)
- **Usage:** Had 4 historical call sites:
  1. `embedCode()` internal use (2 calls) - lines 702, 707
  2. jsonexport display
  3. Achievement checking
  4. Notification rendering

#### 2. Current Code State
- ✅ Function definition removed in uncommitted changes
- ✅ Zero active calls found in codebase
- ✅ No references in nodepack XML files
- ✅ Not exported in current working directory

#### 3. Dead Code References - CLEANED UP ✅

**Removed:**
1. ✅ **`ecore/Everything/Delegation/opcode.pm:35`** (was line 35, now removed)
   - Removed typeglob alias: `*evalCode = *Everything::HTML::evalCode;`
   - Would have caused runtime error if called

2. ✅ **`ecore/Everything/Application.pm:3448`** (was lines 3446-3452, now removed)
   - Removed entire if block checking for `"Everything::HTML::evalCode"` in stack trace
   - Simplified `getCallStack()` function by removing `$codeText` variable and conditional

3. ✅ **`ecore/Everything/Delegation/notification.pm:14-16`** (removed)
   - Removed historical comment mentioning evalCode()
   - Simplified header documentation

#### 4. Verification

- ✅ **ZERO evalCode references in code** (grep returns nothing)
- ✅ No evalCode in ecore/, react/, or www/ directories
- ✅ Perl syntax check passed for all modified files
- ✅ Modified files compile correctly
- ✅ Ready for testing and commit

### Completed Steps

1. ✅ Investigated evalCode() usage across entire codebase
2. ✅ Confirmed function already removed from Everything/HTML.pm (uncommitted)
3. ✅ Found and removed dead typeglob reference in opcode.pm
4. ✅ Found and removed dead stack trace check in Application.pm
5. ✅ Removed historical comment in notification.pm
6. ✅ Verified ZERO remaining evalCode references in code
7. ✅ Fixed critical bug: Added missing `use Everything::Delegation::notification;` in htmlcode.pm
   - Bug caused all notifications to be skipped (delegation lookup always failed)
   - Module was used but never loaded
8. ✅ Replaced PluginFactory eval() with Module::Runtime (Phase 2 complete)
   - Replaced `eval("use $evalclass")` with `use_module($evalclass)`
   - Renamed `$evalclass` to `$plugin_class` (cleaner grep results)
   - Affects 150+ dynamically loaded plugins (API, Controller, DataStash, Node, Page)
   - All 28 Perl tests pass (948 assertions)
   - Safer dynamic module loading without eval()
9. ✅ Replaced API.pm routing compiler eval() with closure-based routing (Phase 2.5 complete)
   - Replaced `eval ("\$subroutineref = $perlcode")` with proper closure
   - Compiles route patterns to regex at build time, matches at runtime
   - No more Perl code generation via string concatenation
   - Fixed Perl::Critic violation: Don't modify $_ in map (line 74)
   - All 5 API routing tests pass
   - Application health test passes
   - More maintainable and debuggable
10. ✅ Replaced weblog specials eval() with direct closure (Phase 2.5 complete)
   - Removed unnecessary eval() for closure creation
   - Perl closures naturally capture variables from enclosing scope
   - Consistent with other closures in same function
   - All tests pass
11. ✅ Replaced ALL data deserialization eval() calls with Safe.pm (Phase 3 COMPLETE!)
   - Created Everything::Serialization module with safe_deserialize_dumper()
   - Uses Safe.pm compartment with restricted operations
   - Blocks all dangerous operations: system, exec, backticks, file I/O, require
   - Allows only data structure operations
   - Replaced 4 eval() calls:
     * htmlcode.pm:13653 (retrieveCorpse)
     * document.pm:18947 (resurrect)
     * document.pm:21229 (opencoffin)
     * document.pm:24781 (nodeheaven)
   - Created comprehensive test suite (t/021_safe_deserialization.t, 17 tests)
   - All 239 Perl::Critic tests pass
   - All React tests pass (116 tests)
   - **ZERO Perl string eval() calls remain in codebase!**

### Next Steps

1. ✅ Updated eval-removal-plan.md with 100% completion status
2. ✅ Updated CLAUDE.md with Phase 3 completion
3. ✅ Abstracted resurrection logic to Everything::NodeBase::resurrectNode()
4. ✅ Created comprehensive resurrection test suite (t/022_node_resurrection.t, 28 tests)
5. ✅ Renumbered tests to be sequential (000-029)
6. ✅ Enhanced resurrection UX (prevent double-resurrection, clean UI)
7. ✅ Verified ZERO Perl string eval() remaining (only safe block eval{} for exception handling)
8. Test changes in Docker container (run full test suite)
9. Review git diff for all changes
10. Commit changes with appropriate message
11. Update issue #3742 - mark as COMPLETE!

### Additional Work Completed

- ✅ Updated docs/eval-removal-plan.md with:
  - **Phase 1 & 2 complete:** parseCode/embedCode/evalCode + PluginFactory
  - **Current status:** 4 Perl eval() calls remaining (down from 20)
  - **Progress:** 80% of string eval() calls removed
  - **Security-critical eval() count:** 0 (all eliminated!)
  - Remaining eval() calls are data deserialization only (low risk)
  - None of the remaining eval() process user input
  - PluginFactory now uses Module::Runtime for safe dynamic loading

- ✅ Created comprehensive notification rendering tests (t/020_notification_rendering.t):
  - Tests all 24 notification types
  - 611 lines of comprehensive test coverage
  - Tests edge cases (missing arguments, missing node_ids)
  - Tests singular/plural text formatting
  - Tests all notification types migrated from evalCode()
  - Verifies graceful handling of missing/invalid data
  - Ensures no regressions in notification system after eval() removal
  - Perl::Critic pragmas added for test-appropriate style
  - Run with: ./docker/run-tests.sh 020

- ✅ Updated Apache thread configuration for development:
  - Reduced thread count to optimize for Devel::NYTProf profiling
  - Now that evalCode() is removed, all code paths are profilable
  - Prepares for PSGI/Plack migration (Priority 7 in modernization plan)
  - Simpler thread model = easier debugging and performance analysis

- ✅ Abstracted node resurrection logic (Everything::NodeBase::resurrectNode):
  - Moved resurrection logic from Dr. Nate's Secret Lab to reusable method
  - Simplified Dr. Nate's Secret Lab from 60 lines to 27 lines (55% reduction)
  - Uses safe_deserialize_dumper() for Data::Dumper format deserialization
  - Handles multi-table node reconstruction correctly
  - Bypasses cache with 'nocache' parameter for getNodeById
  - Cleans up tombstone after successful resurrection (enables re-nuking)
  - Prevents resurrection of already-living nodes (checks existence first)
  - Dr. Nate's Secret Lab shows friendly message if node already exists
  - The Node Crypt hides resurrection button and shows green success message for resurrected nodes
  - Signature: resurrectNode($node_id, $burialground) where $burialground defaults to 'tomb'

- ✅ Created comprehensive resurrection test suite (t/022_node_resurrection.t):
  - 28 tests covering all resurrection scenarios
  - Tests document and writeup node types
  - Tests successful resurrection with data verification
  - Tests error cases (non-existent nodes, already-living nodes, missing tombstones)
  - Tests multiple nuke/resurrect cycles
  - All tests pass with safe deserialization (no eval() needed)
  - Validates that resurrected nodes have correct fields (title, doctext, etc.)
  - Suppresses expected "uninitialized value" warnings from legacy code paths
  - Runs cleanly with no test output noise

- ✅ Fixed test numbering conflicts:
  - Renumbered t/020_test_cloaking.t → t/027_test_cloaking.t
  - Renumbered t/021_test_room_cleaning.t → t/028_test_room_cleaning.t
  - Renumbered t/022_chatterbox_cleanup.t → t/029_chatterbox_cleanup.t
  - Now have sequential test numbers from 000-029 (30 tests total)

### Session 2: Resurrection Enhancement & Final Verification (2025-11-20)

**Objective:** Fix resurrection bug report, enhance UX, and verify eval() removal completion

**Work Completed:**

1. ✅ **Fixed Resurrection Functionality**
   - Investigated "Not unique table/alias: 'node'" SQL error in Dr. Nate's Secret Lab
   - Root cause: Test was calling insertNode() incorrectly (passing hashref instead of separate args)
   - Fixed test helper to use correct insertNode signature
   - Fixed multiple cache and field assignment issues during implementation

2. ✅ **Cleaned Up Test Warnings**
   - Added global warning handler in t/022_node_resurrection.t
   - Suppresses expected "Use of uninitialized value" warnings from legacy code paths
   - Test now runs cleanly with no noise (28 tests, all pass)

3. ✅ **Enhanced Resurrection UX - Prevent Double Resurrection**
   - Added existence check in resurrectNode() method (NodeBase.pm:1323-1325)
   - Added existence check in dr__nate_s_secret_lab (document.pm:1945-1947)
   - Added existence check in the_node_crypt (document.pm:21203-21211)
   - Dr. Nate's Secret Lab shows: "That node (id: $nid) is already alive! No resurrection needed."
   - The Node Crypt hides RESURRECT button, shows green success message with link to live node
   - Added test case for resurrection of already-living nodes (test 20-21)
   - Increased test count from 26 to 28 tests

4. ✅ **Verified eval() Removal Completion**
   - Comprehensive grep search of entire ecore/ directory
   - Found ZERO Perl string eval() calls remaining
   - Only safe usage remains:
     * Block eval { } for exception handling (8 instances)
     * JavaScript eval() in embedded HTML/JS (3 instances)
     * Comments/documentation (3 instances)
   - **Campaign 100% COMPLETE!**

**Test Results:**
- ✅ 28 resurrection tests pass
- ✅ 116 React tests pass
- ✅ All tests run cleanly with no warnings

5. ✅ **Fixed bestow_cools Bug**
   - Fixed self-bestowing: now modifies in-scope $VARS instead of fetching user node
   - Prevents changes from being overwritten when page saves $USER and $VARS
   - Changed from setting to incrementing: `$$V{cools} += $cools`
   - Added self-detection: checks if target user is the current user
   - Shows current total after bestowing: "now have X cools" or "now has X cools"
   - Location: document.pm:18899-18918

6. ✅ **Created Monthly Changelog System**
   - Created docs/changelog-2025-11.md for user-friendly monthly communication
   - Documented eval() removal campaign, resurrection improvements, bug fixes
   - Added "Monthly User Communication" section to CLAUDE.md with guidelines
   - Non-technical language focusing on "what" and "why" for site users

7. ✅ **Removed Deprecated Chat Functions**
   - Removed `joker_s_chat` function (lines 23690-23764, 75 lines)
   - Removed `my_chatterlight` function (lines 23766-23986, 221 lines)
   - Both nodes deleted from production database
   - Total reduction: 297 lines from Everything::Delegation::document
   - Location: ecore/Everything/Delegation/document.pm

## Everything2 Architecture Context

### Core Technology Stack
- **Backend:** Perl 5 + mod_perl2 + Apache2 + MySQL 8.0+
- **Frontend:** React 18.2 (29 components) + Mason2 templates
- **ORM/Framework:** Moose (100+ modules)
- **Infrastructure:** Docker → AWS Fargate ECS
- **Deployment:** Git push to master triggers AWS CodeBuild

### Key Directories
- `ecore/` - Perl backend code
- `ecore/Everything/Delegation/` - Migrated database code (htmlcode, htmlpage, opcode, document, notification)
- `react/components/` - React components
- `nodepack/` - Development seed data (XML format)
- `docs/` - Comprehensive technical documentation

### Modernization Status (81% Complete)
**Completed:**
- ✅ 222 htmlcode nodes → Delegation
- ✅ 99 htmlpage nodes → Delegation
- ✅ 47 opcode nodes → Delegation
- ✅ Moose OOP adoption (100+ modules)
- ✅ React 18.2 integration
- ✅ Docker containerization

**In Progress:**
- 🔄 eval() removal (current task: evalCode)
- 🔄 parseCode/parsecode removal (PR #3741 merged, commit 145e43250)

**Remaining:**
- ❌ 45 achievement nodes with Perl code
- ❌ Room criteria with Perl expressions
- ❌ 129 superdoc templates with `[% perl %]` blocks
- ❌ ~15 SQL injection vulnerabilities
- ❌ Zero mobile responsiveness (no media queries)
- ❌ ~5% test coverage

### Recent Commits (Relevant)
- `145e43250` - "Remove parseCode/parsecode based evals()" (merged PR #3741)
- `b3af85f34` - "Delegates the last of the code modules on E2"
- `5990102cb` - "Delegates the last of the code modules on E2"

## Git Status (Current Working Directory)

```
Modified:
  docs/CLAUDE.md (this file - updated with resurrection work)
  docs/react-19-migration.md
  docs/react-migration-strategy.md
  docs/show_content_analysis.md
  ecore/Everything/Application.pm (removed evalCode stack trace check)
  ecore/Everything/Delegation/document.pm (simplified dr__nate_s_secret_lab, fixed bestow_cools, removed joker_s_chat & my_chatterlight)
  ecore/Everything/Delegation/htmlcode.pm (added notification module import + notificationsJSON delegation)
  ecore/Everything/Delegation/htmlpage.pm
  ecore/Everything/Delegation/opcode.pm (removed evalCode typeglob)
  ecore/Everything/HTML.pm (evalCode function removed)
  ecore/Everything/NodeBase.pm (added resurrectNode method)
  etc/templates/apache2.conf.erb (reduced threads for profiling)
  nodepack/jsonexport/universal_message_json_ticker.xml
  package.json

Deleted:
  docs/sql-fixes-applied.md
  nodepack/htmlcode/parsecode.xml

Renamed:
  t/020_test_cloaking.t → t/027_test_cloaking.t
  t/021_test_room_cleaning.t → t/028_test_room_cleaning.t
  t/022_chatterbox_cleanup.t → t/029_chatterbox_cleanup.t

Untracked:
  docs/changelog-2025-11.md (new file - user-friendly monthly changelog)
  docs/notification-system.md
  ecore/Everything/Delegation/notification.pm (new file - cleaned evalCode from header + fixed achievement guard clause)
  ecore/Everything/Serialization.pm (new file - Safe.pm deserialization module)
  t/020_notification_rendering.t (new comprehensive test suite for notifications)
  t/021_safe_deserialization.t (new comprehensive test suite for safe deserialization)
  t/022_node_resurrection.t (new comprehensive test suite for node resurrection)
  react/components/EditorHideWriteup.test.js
  react/components/ErrorBoundary.test.js
  react/components/NewWriteupsEntry.test.js
  react/components/NewWriteupsFilter.test.js
  react/components/NodeletSection.test.js
```

## Important Commands

```bash
# Local development
./docker/devbuild.sh                    # Build containers
# Visit http://localhost:9080

# Testing
./docker/run-tests.sh                   # Run all tests
./docker/run-tests.sh 012               # Run specific test
./tools/coverage.sh                     # Run tests with coverage

# Code quality
CRITIC_FULL=1 ./tools/critic.pl .      # Perl::Critic check

# Deployment (auto-triggers on git push to master)
git push origin master
```

## Quick Reference Documentation

For comprehensive details, see:
- **[docs/quick-reference.md](quick-reference.md)** - Commands, checklists, common tasks
- **[docs/analysis-summary.md](analysis-summary.md)** - Complete architectural overview
- **[docs/eval-removal-plan.md](eval-removal-plan.md)** - eval() removal strategy
- **[docs/GETTING_STARTED.md](GETTING_STARTED.md)** - Development setup

## Context for Future Sessions

When resuming work on E2:
1. Read this file first to understand current state
2. Check git status to see what's uncommitted
3. Check current branch (likely issue/XXXX/description format)
4. Review recent commits with `git log --oneline -10`
5. Check open files in IDE for hints about current task

## Notes

- E2 dates back to 1999 - legacy code patterns expected
- Active community site at https://everything2.com
- Jay Bonci (jaybonci) is primary maintainer
- Security and eval() removal are top priorities
- All new code must use Moose, prepared SQL statements
- No mobile CSS currently (major gap to address)

## Monthly User Communication

**IMPORTANT:** Maintain a running log of changes for monthly user communication.

- **File:** `docs/changelog-YYYY-MM.md` (e.g., changelog-2025-11.md)
- **Audience:** Non-technical Everything2 users
- **Format:**
  - High-level description of changes
  - Executive summary explaining "why" for each change
  - User-friendly language (avoid technical jargon)
  - Focus on user impact and benefits
- **Content Guidelines:**
  - What changed (user perspective)
  - Why it matters (benefits, improvements)
  - User impact (visible changes or "behind the scenes")
  - Include security, performance, and feature improvements
- **Update Frequency:** Add entries as significant changes are made
- **Monthly Rollup:** Jay uses this for once-a-month communication to site users
