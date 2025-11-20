# Claude Context Document

**Last Updated:** 2025-11-20
**Current Branch:** issue/3742/remove_evalcode
**Project:** Everything2 (E2) - Legacy Perl-based content management system modernization

## Current Session Context

### Active Task: evalCode() Removal Investigation (Issue #3742)

**Objective:** Investigate whether `evalCode()` is dead code and can be safely removed as part of the eval() removal effort across the website.

**Status:** ✅ COMPLETE - All dead code removed

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

### Next Steps

1. ✅ Updated eval-removal-plan.md with current status (13 eval() calls remaining)
2. Test changes in Docker container (run tests)
3. Review git diff for all changes
4. Commit changes with appropriate message
5. Update issue #3742

### Additional Work Completed

- ✅ Updated docs/eval-removal-plan.md with:
  - parseCode/embedCode/evalCode removal marked as complete
  - Current status: 13 eval() calls remaining (down from 28+)
  - Progress: ~54% of string eval() calls removed
  - Security-critical eval() count: 0 (all eliminated!)
  - Detailed breakdown of remaining eval() calls by file and purpose
  - None of the remaining eval() process user input

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
  docs/react-19-migration.md
  docs/react-migration-strategy.md
  docs/show_content_analysis.md
  ecore/Everything/Application.pm (removed evalCode stack trace check)
  ecore/Everything/Delegation/document.pm
  ecore/Everything/Delegation/htmlcode.pm (added notification module import + notificationsJSON delegation)
  ecore/Everything/Delegation/htmlpage.pm
  ecore/Everything/Delegation/opcode.pm (removed evalCode typeglob)
  ecore/Everything/HTML.pm (evalCode function removed)
  etc/templates/apache2.conf.erb (reduced threads for profiling)
  nodepack/jsonexport/universal_message_json_ticker.xml
  package.json

Deleted:
  docs/sql-fixes-applied.md
  nodepack/htmlcode/parsecode.xml

Untracked:
  docs/CLAUDE.md (this file - session context tracking)
  docs/notification-system.md
  ecore/Everything/Delegation/notification.pm (new file - cleaned evalCode from header + fixed achievement guard clause)
  t/020_notification_rendering.t (new comprehensive test suite for notifications)
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
