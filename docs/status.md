# Everything2 Modernization Status

**Last Updated:** 2025-11-15

## Quick Overview

| Priority | Status | Progress | Risk |
|----------|--------|----------|------|
| SQL Injection Fixes | ✅ Complete | 100% (4/4 critical) | High |
| Database Code Removal | 🟡 In Progress | 82% (372/~542) | High |
| Object-Oriented Refactoring | 🟢 Active | 43% (100+/235) | Medium |
| Database Security | 🟡 In Progress | 25% | High |
| MySQL Modernization (8.0→8.4) | 🔴 Not Started | 0% | High |
| PSGI/Plack Migration | 🔴 Not Started | 0% | High |
| React Mobile Frontend | 🟡 Partial | 15% | Medium |
| Testing Infrastructure | ✅ Complete | 100% | Medium |
| Code Coverage Tracking | 🟡 Infrastructure Ready | 0%* | Low |

**Note:** *Code coverage at 0% for application code due to mod_perl architecture limitation. Infrastructure ready, blocked pending PSGI migration. See [Code Coverage Guide](code-coverage.md) for details.

## Database Code Removal (Priority 1)

### ✅ Completed (82%)
- **htmlcode** - 222 nodes migrated to Everything::Delegation::htmlcode.pm (14,499 lines)
- **htmlpage** - 99 nodes migrated to Everything::Delegation::htmlpage.pm (4,609 lines)
- **opcode** - 47 nodes migrated to Everything::Delegation::opcode.pm (2,637 lines)
  - *Note: Opcodes are action handlers (op=login, op=vote, etc.)*
  - *Future: Migrate to REST APIs once React migration is substantial*
  - *See: [Development Goals - Opcode Framework Migration](delegation-migration.md#development-goals---opcode-framework-migration-to-rest-apis)*
- **superdoc/document** - 5 nodes migrated to Everything::Delegation::document.pm (267 lines)
  - Permission Denied
  - super mailbox
  - Nothing Found
  - Findings:
  - My Recent Writeups
- **Total:** 373 nodes, 22,012 lines of delegated code

### ❌ Remaining (18%)
- **achievement** - 45 nodes with Perl code in `{code}` field
- **room criteria** - Unknown count with Perl expressions in `roomdata.criteria`
- **superdoc templates** - 125 nodes with `[% perl %]` blocks (5 completed this week)
- **Total:** 170+ code-containing nodes

### Why This Matters
1. **Security:** eval() of database strings = arbitrary code execution
2. **Profiling:** Devel::NYTProf can't see inside eval blocks (performance blind spots)
3. **Testing:** Can't unit test eval'd code
4. **Maintainability:** No git history for database code

### Next Steps
1. Audit and migrate achievement nodes
2. Audit and migrate room criteria
3. Develop strategy for superdoc templates
4. Complete audit for any other executable code

## Object-Oriented Refactoring (Priority 2)

### ✅ Moose Adoption (43%)
- **100+ modules** using Moose
- Clean inheritance (extends)
- Roles (with)
- Lazy attributes
- Type checking

### Examples
```perl
package Everything::Node;
use Moose;
with 'Everything::Globals';

package Everything::Node::achievement;
use Moose;
extends 'Everything::Node';
```

### ❌ Legacy Procedural Code (57%)
- Everything::Application (5,177 lines)
- Everything::NodeBase (2,849 lines)
- Everything::HTML (1,424 lines)
- Everything::Delegation::* (31,443 lines)
- **Total:** 135 non-Moose modules

### Next Steps
1. Refactor Application.pm to Moose classes
2. Extract business logic into services
3. Create proper class hierarchy
4. Use roles for cross-cutting concerns

## Database Security (Priority 3)

### Current Issues
- **433 queries** using string concatenation + `quote()`
- **~15 queries** with direct interpolation (HIGH RISK)
- **5-10 queries** using prepared statements (GOOD)
- Inconsistent sanitization patterns

### Vulnerability Count
- **Critical:** 5-7 (SQL injection possible)
- **High:** 10-15 (depends on input validation)
- **Medium:** 20-30 (table/field names from variables)
- **Low:** 100+ (assumes node_ids are integers)

### Next Steps
1. Audit all `getDatabaseHandle()->do()` calls
2. Fix direct interpolation vulnerabilities
3. Add integer validation for node_ids
4. Whitelist table names
5. Migrate to prepared statements

## MySQL Modernization (Priority 4)

### Current State: MySQL 8.0
- **Amazon RDS**: Running MySQL 8.0, which is approaching end of standard support
- **Extended Support Charges**: Will be required after standard support ends
- **sql_mode=ALLOW_INVALID_DATES**: Current dependency on deprecated mode
- **Authentication**: Using legacy mysql_native_password (being phased out)

### Critical Issues

1. **Invalid Date Defaults**:
   - DATE/DATETIME columns with '0000-00-00' defaults
   - Code assumes invalid dates are valid sentinel values
   - MySQL 8.4 enforces stricter date validation
   - ALLOW_INVALID_DATES mode deprecated

2. **Authentication Methods**:
   - mysql_native_password deprecated in MySQL 8.4
   - Need to migrate to caching_sha2_password
   - DBD::mysql version compatibility required
   - Apache::DBI connection pooling must be tested

3. **Schema Compatibility**:
   - Unknown number of date columns with invalid defaults
   - Need full audit of all tables
   - Existing data may contain '0000-00-00' values
   - Must decide NULL vs. valid default strategy

### Migration Phases

**Phase 1: Audit (Week 1)**
- Run INFORMATION_SCHEMA queries to find date columns with invalid defaults
- Grep codebase for '0000-00-00' literals and comparisons
- Test application against MySQL 8.4 in development
- Document all breaking changes and affected code
- Categorize fixes by risk and impact

**Phase 2: Schema Changes (Weeks 2-3)**
- ALTER TABLE statements to fix column defaults
- UPDATE statements to fix existing invalid date data
- Test schema changes in development environment
- Create rollback procedures
- Document migration scripts

**Phase 3: Code Updates (Weeks 3-4)**
- Replace '0000-00-00' comparisons with IS NULL checks
- Fix code that inserts invalid dates
- Update date validation and handling logic
- Add tests for date edge cases
- Run full test suite

**Phase 4: Authentication (Week 5)**
- Update MySQL users to caching_sha2_password
- Verify DBD::mysql version (minimum 4.050)
- Test all database connections
- Update deployment documentation

**Phase 5: Upgrade (Week 6)**
- Final testing in staging environment
- Deploy schema changes to production
- Upgrade RDS instance to MySQL 8.4
- Monitor for errors and performance regressions

### Estimated Effort
- **Total:** 4-6 weeks
- **Risk:** High (schema changes, potential data corruption)
- **Dependencies:** Testing infrastructure, staging environment
- **Rollback:** Complex (requires database restore for schema changes)

### Blockers
1. Need to identify all date columns (schema audit)
2. Need to understand business logic for "invalid" dates
3. Must ensure DBD::mysql compatibility
4. Must coordinate downtime for schema changes

### Next Steps
1. Run SQL audit to find all date columns with invalid defaults
2. Grep codebase for '0000-00-00' usage patterns
3. Set up MySQL 8.4 in Docker development environment
4. Test current application against MySQL 8.4
5. Document breaking changes and create migration plan

**See**: [Development Goals - MySQL Modernization](delegation-migration.md#development-goals---mysql-modernization-80--84) for detailed migration strategy

## PSGI/Plack Migration (Priority 5)

### Current State: Apache mod_perl2 + Prefork MPM
- Package-level globals
- Per-process NodeCache
- CGI.pm for request/response
- Apache::DBI connection pooling
- **NOT thread-safe**

### Blockers
1. **NodeCache** - Per-process memory cache needs Redis/Memcached replacement
2. **Package Globals** - Unsafe in threaded/async workers
3. **CGI.pm** - 68+ calls in HTML.pm need Plack::Request
4. **Apache::DBI** - Need alternative connection pooling

### Estimated Effort
- Phase 1: Preparation (2-3 weeks)
- Phase 2: Core Refactoring (4-6 weeks)
- Phase 3: Cache Migration (3-4 weeks)
- Phase 4: Deployment (2-3 weeks)
- **Total: 11-16 weeks**

### Next Steps
1. Create request context object
2. Add comprehensive tests
3. Implement Plack::Request wrapper
4. Design Redis cache architecture

## React Mobile Frontend (Priority 6)

### Current State
- **29 React components** (1,094 lines)
- **15+ REST APIs** working
- Webpack build pipeline
- Focus on sidebar nodelets

### Critical Gap: Mobile
- ❌ No responsive CSS
- ❌ No media queries
- ❌ Fixed 240px sidebars
- ❌ No mobile navigation
- ❌ No touch interactions

### Long-term Goal: Replace Template Systems with React

**Two Distinct Template Systems in Everything2**:
1. **Legacy E2 Templates** (Everything::HTML::parseCode):
   - `[% perl %]` blocks in database nodes
   - **Current migration**: Moving to delegation functions (Phase 1)
   - 125 superdocs remaining to migrate
2. **Mason2 Templates** (Everything::Page, Everything::Mason):
   - Modern Mason2 framework in `templates/` directory
   - Already version-controlled and testable
   - Separate from current delegation migration

**Current Focus**: Legacy E2 template migration (Phase 1)
- **Interim step**: Delegation functions are temporary, server-side rendering solution
- **End goal**: Replace both delegation functions AND Mason2 templates with React components + REST APIs
- **Benefits**:
  - Dynamic UI without page reloads
  - Component reusability and testing
  - Separation of concerns (API backend + React frontend)
  - Modern, responsive, mobile-first design
- **Migration path**:
  - Legacy E2: Database templates → Delegation functions → REST APIs + React
  - Mason2: Mason2 templates → REST APIs + React (future consideration)
- **See**: [Development Goals - Template System Migration to React](delegation-migration.md#development-goals---template-system-migration-to-react) for full migration strategy

### Next Steps
1. Add CSS media queries
2. Responsive navigation
3. Touch-friendly interactions
4. Convert class components to hooks
5. Add Context API for state
6. Identify high-value delegations for React conversion pilots
7. **Future (post-React migration)**: Convert opcode framework (`op=login`, `op=vote`, etc.) to REST APIs
   - Opcodes are action handlers currently using query parameters
   - Requires React forms to replace legacy HTML forms
   - See: [Opcode Framework Migration](delegation-migration.md#development-goals---opcode-framework-migration-to-rest-apis)

## Testing Infrastructure (Priority 7)

### ✅ Test Status
- **11/13 test files passing** (572/576 tests)
- **235/235 modules** pass Perl::Critic checks
- **Automated in build:** Tests run during `./docker/devbuild.sh`
- **Test runner:** `./docker/run-tests.sh` with pattern matching

### Current Test Coverage
- **13 active tests** (643+ LOC) - API integration, unit tests
- **16 legacy tests** (795 LOC) - excluded, unmaintained
- **0 React tests** - No Jest configured
- **CI/CD:** Tests automated in Docker build

### Test Failures (Deferred)
- **006_usergroups.t** - Multi-add operations (3 failed tests)
- **007_systemutilities.t** - Purge count mismatch (1 failed test)

### Next Steps
1. Add GitHub Actions CI/CD test gate
2. Install Jest + React Testing Library
3. Fix deferred test failures
4. Create test fixtures
5. Enable full coverage after PSGI migration

## Code Coverage Tracking (Priority 8)

### ✅ Infrastructure Status
- **Devel::Cover** added to cpanfile
- **Coverage script:** `./tools/coverage.sh` ready
- **Documentation:** [Code Coverage Guide](code-coverage.md)
- **Reports:** HTML and text output configured

### ⚠️ Current Limitation
**Application coverage blocked by mod_perl architecture:**
- Tests make HTTP requests to separate Apache process
- Devel::Cover cannot instrument web server process
- Currently only tracks test runner code (t/run.pl)
- **Effective coverage: 0%** for application modules

### Blocker: PSGI Migration Required
**To enable full coverage:**
1. Migrate from mod_perl to PSGI/Plack (Priority 8)
2. Convert tests to use Plack::Test for in-process testing
3. Application code will load directly in test process
4. Devel::Cover will instrument all executed code

**See:** [Priority 5: PSGI/Plack Migration](modernization-priorities.md#priority-5-psgiplack-migration-) for migration plan

### Coverage Goals (Post-PSGI)
- **High Priority (>80%):** Security, API, Application modules
- **Medium Priority (>60%):** Node, NodeBase, HTML, Request
- **Lower Priority (>40%):** Delegation (legacy code)

## Development Environment

### Build System
- **Local:** `./docker/devbuild.sh` → Docker Desktop
- **Containers:** e2devdb (MySQL) + e2devapp (Apache/mod_perl)
- **Access:** http://localhost:9080
- **Deployment:** `./ops/run-codebuild.rb` → AWS CodeBuild → Fargate ECS

### Dependency Management
- **Perl:** Carton (cpanfile + cpanfile.snapshot)
- **Dependencies embedded** in codebase for deployment
- **JavaScript:** npm (package.json + package-lock.json)
- **Build:** Webpack + Babel for React

### Code Quality
- **Perl::Critic:** `CRITIC_FULL=1 ./tools/critic.pl` ✅ All modules passing
- **.perlcriticrc:** Configured overrides
- **Code Coverage:** Devel::Cover installed, blocked by architecture (see Priority 8)

## Recent Milestones

### Week of November 15, 2025
- ✅ Superdoc delegation progress (5 nodes completed)
  - Permission Denied - Simple access denied message
  - super mailbox - Bot mailbox management with usergroup permissions
  - Nothing Found - 404-style search results with external link detection
  - Findings: - Search results display with nodeshell detection
  - My Recent Writeups - User's writeup count from the past year
- ✅ Documentation updates
  - Added usergroup permission details to delegation-migration.md
  - Documented 'gods' administrative usergroup
  - Added development goal for permission simplification (gods → Content_Editors)
  - Added development goal for template system migration to React
  - Clarified distinction between Legacy E2 templates (parseCode) and Mason2 templates
  - Added development goal for opcode framework migration to REST APIs
  - Added development goal for MySQL modernization (8.0 → 8.4)
  - Enhanced module import checklist (use statements at top of file)
- ✅ Code quality improvements
  - Fixed expression form of map/grep violations
  - Fixed mixed high/low precedence boolean issues
  - Moved Time::HiRes import to top of document.pm (findings_ function)
  - All new delegations pass Perl::Critic severity 1 + theme bugs

### Completed
- ✅ SQL injection fixes (4 critical vulnerabilities)
- ✅ Perl::Critic compliance (235/235 modules)
- ✅ Test infrastructure automation
- ✅ Code coverage tooling (infrastructure ready)
- ✅ Moose adoption in 100+ modules
- ✅ htmlcode/htmlpage/opcode delegation (368 nodes)
- ✅ React integration (29 components)
- ✅ REST API infrastructure (15+ endpoints)
- ✅ Docker development environment
- ✅ AWS deployment pipeline

### In Progress
- 🟡 Database code removal (82% complete, 5 nodes added this week)
- 🟡 Superdoc template migration (125 remaining, down from 129)
- 🟡 React frontend expansion
- 🟡 Documentation in docs/ directory

## Immediate Priorities

### This Week
1. ✅ Continue superdoc delegation (5 completed)
2. ✅ Update delegation documentation with usergroup details
3. Complete achievement node audit
4. Complete room criteria audit

### Next Week
1. Continue superdoc template migration
2. Document current test infrastructure
3. Create modernization roadmap for team

### This Month
1. Migrate more superdoc templates to Delegation (target: 20+ nodes)
2. Begin achievement node audit and migration planning
3. Begin room criteria audit
4. Fix test dependencies
5. Add CI/CD test gate

### This Quarter
1. Complete database code removal (Phase 1: delegation functions)
2. Fix critical SQL injection vulnerabilities
3. Begin MySQL 8.4 audit (schema + code analysis)
4. Set up React testing infrastructure
5. Begin PSGI preparation work
6. Mobile responsiveness Phase 1
7. Document React migration strategy and identify Phase 2 pilot candidates

## Team Communication

### For Users
- Gradual improvements, no disruption
- Focus on mobile support and performance
- Transparent testing process

### For Staff
- Technical docs in docs/ directory
- Regular status updates
- Code review standards
- Modernization guidelines

### For Contributors
- Moose required for new code
- Testing required for PRs
- API-first design
- Security awareness

## Questions & Decisions Needed

1. Which to migrate first: achievements or room criteria?
2. What's the strategy for remaining 125 superdoc templates?
3. Timeline for implementing permission simplification (gods → Content_Editors)?
4. Timeline for PSGI migration start?
5. Redis vs Memcached for cache layer?
6. Testing coverage targets by milestone?
7. **React migration strategy**:
   - **Legacy E2 templates**: Which delegated superdocs should be prioritized for React conversion?
   - When to start Phase 2 (delegation functions → React + REST APIs)?
   - Should we build REST APIs alongside delegations now, or later?
   - Which features provide the most value for React conversion (high user interaction)?
   - **Mason2 templates**: Should Mason2 templates also be converted to React, or maintained separately?
   - What is the long-term vision for Mason2 vs React rendering?
8. **MySQL modernization (8.0 → 8.4)**:
   - When to schedule the MySQL 8.0 → 8.4 upgrade (timeline relative to RDS support end)?
   - What is the business logic meaning of '0000-00-00' dates (unknown? not set? legacy data?)?
   - Should invalid dates become NULL or valid sentinel values (e.g., '1970-01-01')?
   - How many date columns are affected (need schema audit results)?
   - What is acceptable downtime window for schema ALTER TABLE operations?
   - Should we batch schema changes or apply incrementally?
   - Which tables are highest priority (most critical business data)?
   - Test strategy: Full staging test or incremental table-by-table validation?
   - Rollback plan: Database restore vs. reverse migrations?
9. **Opcode framework migration**:
   - At what point in React migration should we begin converting opcodes to REST APIs?
   - Which opcodes should be prioritized (authentication, voting, messaging, content creation)?
   - Should we maintain `op=` query parameter backward compatibility during transition?
   - What authentication strategy for APIs (JWT tokens, session cookies, both)?
   - How to handle CSRF protection in React + API architecture?

---

**Next Review:** Weekly
**Documentation:** docs/ directory under version control
**Contact:** See team roster for modernization working group
