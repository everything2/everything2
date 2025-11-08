# Everything2 Modernization Priorities

**Date:** 2025-11-07
**Status:** Planning Phase

## Executive Summary

Everything2 (E2) is a user-submitted content website with a Perl/mod_perl backend dating to 1999. The codebase is undergoing systematic modernization to improve security, maintainability, performance, and mobile support.

## Strategic Goals

1. **API-Driven Architecture** - Decouple frontend from backend
2. **Mobile-First Frontend** - React-based responsive design
3. **Modern Object-Oriented Code** - Moose-based architecture
4. **Security & Maintainability** - Remove technical debt
5. **Scalability** - Move toward modern web frameworks (PSGI/Plack)

## Current Architecture

### Technology Stack
- **Backend:** Perl 5, mod_perl2, Apache2, MySQL 8.0+
- **Frontend:** React 18.2.0 + server-side Mason2 templates
- **Infrastructure:** Docker, AWS Fargate ECS, CloudFormation
- **OOP Framework:** Moose (100+ modules)
- **Build:** Webpack, Babel

### Deployment Pipeline
```
Local: ./docker/devbuild.sh → Docker Desktop (localhost:9080)
Production: GitHub push → AWS CodeBuild → Fargate ECS
Manual: ./ops/run-codebuild.rb (local AWS deployment)
```

### Architecture Evolution
```
1999-2015: Database Code
  ↓ All code stored in DB, eval'd at runtime

2015-2020: Delegation Pattern
  ↓ Code moved to filesystem (Everything::Delegation::*)
  ↓ Mason2 templates (interim MVC)

2020-Present: React Integration
  ↓ REST APIs + React components
  ↓ Hybrid server/client rendering

Future: Modern React SPA
  ↓ Full React frontend
  ↓ PSGI/Plack backend
  ↓ Mobile-first responsive design
```

## Priority 1: Remove Executable Code from Database 🔥

### Why This Matters

**Security**
- `eval()` of database strings = arbitrary code execution
- No code sandboxing, only access control
- Template injection vulnerabilities

**Performance Profiling**
- Devel::NYTProf cannot see inside `eval()` blocks
- Production performance issues are "black holes"
- Cannot identify optimization targets

**Maintainability**
- Code split between filesystem and database
- No git history for database code
- Hard to track changes and refactor

**Testing**
- Cannot unit test eval'd code
- Only integration tests possible
- No mocking or isolation

### Current Status

**Migrated to Delegation (100%):**
- ✅ htmlcode (222 nodes) → Everything::Delegation::htmlcode.pm
- ✅ htmlpage (99 nodes) → Everything::Delegation::htmlpage.pm
- ✅ opcode (47 nodes) → Everything::Delegation::opcode.pm

**Still in Database:**
- ❌ **achievement** (45 nodes) - Perl code in `{code}` field
- ❌ **room criteria** (unknown count) - Perl expressions in `roomdata.criteria`
- ❌ **superdoc templates** (129 nodes) - `[% perl code %]` blocks in content

### Template Language

E2 uses a custom template language in superdoc content:

```perl
[%
  # Full embedded Perl code
  my $user = getNode($query->param('user'));
  return linkNode($user);
%]

[{htmlcode_name:arg1:arg2:arg3}]  # Function call

[" $variable "]  # Expression evaluation (rarely used)
```

### Action Items

1. **Migrate achievements** - Move 45 nodes to Delegation pattern
2. **Migrate room criteria** - Extract logic to filesystem
3. **Audit all node types** - Find any hidden executable code
4. **Superdoc strategy** - Plan for 129 templates with Perl blocks

## Priority 2: Object-Oriented Refactoring 🎯

### Current State

**Moose Adoption:** 100+ modules using modern OOP
- Everything::Node (base class with attributes)
- Everything::Node::achievement extends Everything::Node
- Everything::API, Everything::Request, etc.

**Legacy Procedural Code:**
- Everything::Application (5,177 lines, 180 methods)
- Everything::NodeBase (2,849 lines, 70 methods)
- Everything::HTML (1,424 lines, 32 methods)
- Everything::Delegation::* (31,443 lines total)

### Best Practice: Moose

```perl
package Everything::Node;
use Moose;
with 'Everything::Globals';

has 'NODEDATA' => (isa => "HashRef", required => 1, is => "rw");
has 'author' => (is => "ro", lazy => 1, builder => "_build_author");

sub can_read_node {
    my ($self, $user) = @_;
    return $self->DB->canReadNode($user->NODEDATA, $self->NODEDATA);
}
```

### Benefits
- Better encapsulation
- Lazy attribute loading
- Method modifiers (around, before, after)
- Roles for mixins
- Type checking
- Immutability for performance

### Action Items

1. Refactor legacy modules to Moose
2. Create proper class hierarchy
3. Extract business logic from Application.pm
4. Use roles for cross-cutting concerns

## Priority 3: Database Security ⚠️

### Current Issues

**Query Construction:**
- String concatenation with `quote()`
- ~15 direct variable interpolation vulnerabilities
- Inconsistent sanitization
- Dynamic table names without whitelist

**Risk Examples:**

```perl
# VULNERABLE: Direct interpolation
$DB->getDatabaseHandle()->do(
    "update weblog set removedby_user=$$USER{user_id}
     where weblog_id=$src"
);

# VULNERABLE: IN clause without validation
my $inclause = join(",", keys %$nodeidhash);
$dbh->prepare("... IN($inclause) ...");

# GOOD: Using quote()
$this->sqlUpdate('user', {
    passwd => $pwhash,
    salt => $salt
}, "user_id=$$USER{node_id}");
```

### Statistics
- **433 queries** using wrapper functions with `quote()`
- **~15 queries** with direct interpolation (HIGH RISK)
- **5-10 queries** using proper prepared statements
- **37 direct calls** to `quote()`

### Action Items

1. Audit all `getDatabaseHandle()->do()` calls
2. Add integer validation for node_ids
3. Whitelist table names in `sqlXXX()` functions
4. Replace IN clause joins with prepared statements
5. Migrate to DBIx::Class or prepared statements

## Priority 4: Web Framework Migration (PSGI/Plack) 🔄

### Current: Apache mod_perl2 + Prefork MPM

**Architecture:**
- Package-level globals persist between requests
- NodeCache in process memory (LRU, version-checked)
- CGI.pm for request/response
- Apache::DBI connection pooling
- Apache2::SizeLimit (kills process > 800MB)

**Problems:**
- Not thread-safe (package globals, no mutexes)
- Memory inefficient (per-process cache)
- Hard to scale horizontally
- Tied to Apache lifecycle
- Legacy CGI.pm API

### Target: PSGI/Plack

**Benefits:**
- Deployment flexibility (Starman, Gazelle, etc.)
- Standard interface (any PSGI server)
- Middleware ecosystem
- Better performance potential
- Modern request/response handling

**Challenges:**

1. **NodeCache Replacement**
   - Need external shared cache (Redis/Memcached)
   - Current: per-process, version-checked
   - Complex coherency requirements

2. **Global Variable Elimination**
   - Package globals unsafe in threaded/async workers
   - Must convert to request-scoped context
   - Affects 100+ files, 500+ functions

3. **CGI.pm → Plack::Request**
   - 68+ CGI.pm calls in HTML.pm alone
   - Change from `$query->print()` to return values
   - Cookie/header API changes

4. **Connection Pooling**
   - Apache::DBI not available
   - Need DBIx::Connector or manual pool

### Migration Estimate

- **Phase 1:** Preparation (2-3 weeks)
- **Phase 2:** Core Refactoring (4-6 weeks)
- **Phase 3:** Cache Migration (3-4 weeks)
- **Phase 4:** Deployment (2-3 weeks)

**Total: 11-16 weeks (2.5-4 months)**

### Action Items

1. Create request context object
2. Add tests for critical paths
3. Implement Plack::Request wrapper alongside CGI.pm
4. Design Redis cache architecture
5. Gradual migration with parallel deployment

## Priority 5: Mobile-First React Frontend 📱

### Current State

**React Integration:**
- 29 React components (1,094 lines)
- Focus on right-sidebar nodelets (widgets)
- REST APIs in place (15+ endpoints)
- Webpack build pipeline
- **CRITICAL GAP: Zero mobile responsiveness**

**Problems:**
- No media queries for responsive design
- Fixed 240px sidebar widths
- Desktop-only CSS
- No mobile navigation patterns
- No touch-friendly interactions

**Mason2 Templates:**
- Interim MVC system (want to move away from)
- 30+ .mc template files
- Parallel with legacy parseCode system
- Server-side rendering

### Target Architecture

```
React Frontend (SPA)
  ↓ REST API calls
Perl Backend (PSGI)
  ↓ Database queries
MySQL
```

### Action Items

1. **Phase 1: Mobile Responsiveness** (2-3 weeks)
   - Add CSS media queries
   - Responsive navigation
   - Touch interactions
   - Flexible layouts

2. **Phase 2: React Modernization** (3-4 weeks)
   - Convert class components to hooks
   - Add Context API for state
   - Eliminate prop drilling

3. **Phase 3: Component Expansion** (ongoing)
   - Convert more UI to React
   - Reduce Mason2 usage
   - API-driven data loading

4. **Phase 4: Testing** (3-4 weeks)
   - Jest + React Testing Library
   - Component tests
   - Integration tests

## Priority 6: Testing Infrastructure ✅

### Current State

**Perl Tests:**
- 12 active tests in `t/` (643 LOC)
- 16 legacy tests excluded (795 LOC)
- Focus on API integration tests
- Missing test dependencies (LWP::UserAgent)
- **No CI/CD test gate**

**React Tests:**
- **ZERO tests** for 29 components
- No Jest, React Testing Library
- No test runner configured

**Code Quality:**
- ✅ Perl::Critic via `CRITIC_FULL=1 ./tools/critic.pl`
- ✅ .perlcriticrc with pragmatic overrides
- No coverage measurement

### Coverage Gaps

**Not Tested:**
- Core business logic (Everything::Application, NodeBase)
- 235 Perl modules, ~609 functions
- All React components
- Database operations
- Security/permissions
- Search functionality
- Caching logic

### Action Items

1. **Immediate (Week 1-2)**
   - Fix test dependencies
   - Add GitHub Actions CI/CD
   - Test phase in buildspec.yml

2. **Backend Testing (Month 1-2)**
   - Unit tests for core modules
   - Test fixtures and seed data
   - Mocking strategy

3. **Frontend Testing (Month 2-3)**
   - Install Jest + React Testing Library
   - Component test coverage
   - 80% coverage goal

4. **Coverage & Quality (Month 3-4)**
   - Devel::Cover for Perl
   - Istanbul/nyc for JavaScript
   - Minimum 70% threshold

## Risk Assessment

### High Risk Areas

1. **NodeCache Migration** - Performance critical, complex coherency
2. **Global Variable Elimination** - Touches entire codebase
3. **Thread Safety** - Current code NOT thread-safe
4. **Eval'd Code** - Security and profiling blind spots

### Medium Risk Areas

1. **CGI.pm Migration** - Well-understood patterns
2. **SQL Injection** - Known vulnerabilities, fixable
3. **Testing Gaps** - Can be addressed incrementally

### Low Risk Areas

1. **Moose Adoption** - Already proven in 100+ modules
2. **React Integration** - Working pattern established
3. **Documentation** - Clear path forward

## Success Metrics

### Technical Metrics
- Zero executable code in database
- 70%+ test coverage
- Zero high-severity SQL injection vulnerabilities
- Mobile-friendly responsive design
- PSGI/Plack deployment option

### Performance Metrics
- Devel::NYTProf coverage of all code paths
- Improved page load times
- Better cache efficiency
- Horizontal scalability

### Maintainability Metrics
- All new code uses Moose
- All code in git (no database code)
- Comprehensive test suite
- API-driven architecture

## Timeline Overview

### Q1 2025
- Remove achievements from database
- Remove room criteria from database
- Fix SQL injection vulnerabilities
- Add basic test infrastructure

### Q2 2025
- Mobile responsiveness Phase 1
- React component testing
- Begin PSGI preparation
- Superdoc migration strategy

### Q3 2025
- PSGI migration Phase 1-2
- Redis cache implementation
- React modernization
- 50%+ test coverage

### Q4 2025
- PSGI production deployment
- Complete database code removal
- 70%+ test coverage
- Full mobile support

## Communication Strategy

### For Users
- Focus on benefits: mobile support, better performance, security
- Transparent about changes and testing
- Gradual rollout to minimize disruption

### For Staff
- Technical documentation in `claude/` directory
- Regular status updates
- Code review standards
- Testing requirements

### For Contributors
- Modernization guidelines
- Moose usage patterns
- Testing requirements
- API design standards

## Next Steps

See [next-steps.md](next-steps.md) for immediate action items.

---

**Document Status:** Initial draft
**Last Updated:** 2025-11-07
**Next Review:** 2025-12-07
