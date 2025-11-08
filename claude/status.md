# Everything2 Modernization Status

**Last Updated:** 2025-11-07

## Quick Overview

| Priority | Status | Progress | Risk |
|----------|--------|----------|------|
| Database Code Removal | 🟡 In Progress | 81% (368/413) | High |
| Object-Oriented Refactoring | 🟢 Active | 43% (100+/235) | Medium |
| Database Security | 🔴 Not Started | 0% | High |
| PSGI/Plack Migration | 🔴 Not Started | 0% | High |
| React Mobile Frontend | 🟡 Partial | 15% | Medium |
| Testing Infrastructure | 🔴 Minimal | 5% | Medium |

## Database Code Removal (Priority 1)

### ✅ Completed (81%)
- **htmlcode** - 222 nodes migrated to Everything::Delegation::htmlcode.pm (14,499 lines)
- **htmlpage** - 99 nodes migrated to Everything::Delegation::htmlpage.pm (4,609 lines)
- **opcode** - 47 nodes migrated to Everything::Delegation::opcode.pm (2,637 lines)
- **Total:** 368 nodes, 21,745 lines of delegated code

### ❌ Remaining (19%)
- **achievement** - 45 nodes with Perl code in `{code}` field
- **room criteria** - Unknown count with Perl expressions in `roomdata.criteria`
- **superdoc templates** - 129 nodes with `[% perl %]` blocks
- **Total:** 174+ code-containing nodes

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

## PSGI/Plack Migration (Priority 4)

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

## React Mobile Frontend (Priority 5)

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

### Next Steps
1. Add CSS media queries
2. Responsive navigation
3. Touch-friendly interactions
4. Convert class components to hooks
5. Add Context API for state

## Testing Infrastructure (Priority 6)

### Current Coverage
- **12 active tests** (643 LOC) - API integration only
- **16 legacy tests** (795 LOC) - excluded, unmaintained
- **0 React tests** - No Jest configured
- **No CI/CD test gate** - Tests don't block deployment

### Gaps
- Core business logic untested
- 235 Perl modules untested
- All 29 React components untested
- No coverage measurement
- No test fixtures

### Next Steps
1. Fix test dependencies (LWP::UserAgent)
2. Add GitHub Actions CI/CD
3. Install Jest + React Testing Library
4. Create test fixtures
5. Target 70%+ coverage

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
- **Perl::Critic:** `CRITIC_FULL=1 ./tools/critic.pl`
- **.perlcriticrc:** Configured overrides
- **No coverage tools** installed yet

## Recent Milestones

### Completed
- ✅ Moose adoption in 100+ modules
- ✅ htmlcode/htmlpage/opcode delegation (368 nodes)
- ✅ React integration (29 components)
- ✅ REST API infrastructure (15+ endpoints)
- ✅ Docker development environment
- ✅ AWS deployment pipeline

### In Progress
- 🟡 Database code removal (81% complete)
- 🟡 React frontend expansion
- 🟡 Documentation in claude/ directory

## Immediate Priorities

### This Week
1. Complete achievement node audit
2. Complete room criteria audit
3. Document current test infrastructure
4. Create modernization roadmap for team

### This Month
1. Migrate achievement nodes to Delegation
2. Migrate room criteria to Delegation
3. Fix test dependencies
4. Add CI/CD test gate
5. Begin SQL injection fixes

### This Quarter
1. Complete database code removal
2. Fix critical SQL injection vulnerabilities
3. Set up React testing infrastructure
4. Begin PSGI preparation work
5. Mobile responsiveness Phase 1

## Team Communication

### For Users
- Gradual improvements, no disruption
- Focus on mobile support and performance
- Transparent testing process

### For Staff
- Technical docs in claude/ directory
- Regular status updates
- Code review standards
- Modernization guidelines

### For Contributors
- Moose required for new code
- Testing required for PRs
- API-first design
- Security awareness

## Resource Utilization

**Claude Usage Today:**
- Token usage: ~62,000 / 200,000 (31%)
- Remaining: ~138,000 tokens
- Plenty of capacity remaining for continued work

## Questions & Decisions Needed

1. Which to migrate first: achievements or room criteria?
2. What's the strategy for 129 superdoc templates?
3. Timeline for PSGI migration start?
4. Redis vs Memcached for cache layer?
5. Testing coverage targets by milestone?

---

**Next Review:** Weekly
**Documentation:** claude/ directory under version control
**Contact:** See team roster for modernization working group
