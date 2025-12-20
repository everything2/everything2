# Everything2 Modernization Priorities

**Date:** 2025-11-09
**Last Updated:** 2025-12-17
**Status:** Planning Phase

> **Note**: See [Developer Roadmap](DEVELOPER-ROADMAP.md) for comprehensive technical roadmap (Dec 2025)

## Executive Summary

Everything2 (E2) is a user-submitted content website with a Perl/mod_perl backend dating to 1999. The codebase is undergoing systematic modernization to improve security, maintainability, performance, and mobile support.

## Strategic Goals

1. **API-Driven Architecture** - Decouple frontend from backend
2. **Mobile-First Frontend** - React-based responsive design
3. **Modern Object-Oriented Code** - Moose-based architecture
4. **Security & Maintainability** - Remove technical debt
5. **Scalability** - Move toward modern web frameworks (PSGI/Plack)
6. **User Acquisition** - Alternative login methods to reduce friction

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

## Priority 1: Remove Executable Code from Database ✅ COMPLETE

### Why This Mattered

**Security**
- `eval()` of database strings = arbitrary code execution risk
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

### Status: COMPLETE ✅

**Completed November 2025** - All executable code has been removed from the database.

**Migrated to Delegation (100%):**
- ✅ htmlcode (222 nodes) → Everything::Delegation::htmlcode.pm
- ✅ htmlpage (99 nodes) → Everything::Delegation::htmlpage.pm
- ✅ opcode (47 nodes) → Everything::Delegation::opcode.pm
- ✅ achievement (45 nodes) → Everything::Delegation::achievement.pm
- ✅ room criteria → Everything::Delegation::room.pm (delegation pattern in canEnterRoom)
- ✅ superdoc template execution → parseCode/eval() system completely eliminated (Session 1)

**Key Achievement:** Complete removal of unsafe eval() from production code paths. All code now resides in the filesystem under version control.

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

## Priority 5.5: Guest User Static Page Caching (S3) 💰

**Priority Level:** High (Cost Reduction / Scalability)

### Why This Matters

**Financial Sustainability**
- Majority of E2 traffic is anonymous/guest users viewing read-only content
- Every guest page view hits the database and executes Perl code
- Static HTML caching for guest users could reduce infrastructure costs by 60-80%
- Massive reduction in database load and compute costs
- Long-term financial stability measure for the site

**Scalability**
- S3 can handle millions of requests with minimal cost
- CloudFront CDN distribution for global performance
- Eliminates database as bottleneck for read traffic
- Web Application Firewall (WAF) costs reduced proportionally
- Infrastructure can scale down during off-peak hours

**Performance**
- Static S3 pages served in milliseconds vs. hundreds of milliseconds for dynamic generation
- Reduced latency for international users via CloudFront edge locations
- No database queries, no Perl execution for cached content
- Better user experience for guest visitors

**Reliability**
- Static content survives database outages
- Reduced load on application servers
- Better fault isolation
- Easier disaster recovery

### Current State

**Architecture:**
- All page requests (logged-in and guest) hit Apache/mod_perl
- Every request executes Perl code and queries MySQL
- No differentiation between authenticated and anonymous traffic
- Full application stack overhead for read-only guest views

**Traffic Patterns:**
- ~70-80% of traffic is anonymous/guest users
- Most guest traffic is to static content (writeups, nodes, help pages)
- Authenticated users see personalized content (nodelets, user-specific data)
- Search engines and bots generate significant guest traffic

### Target Architecture

```
Guest Request → CloudFront CDN
  ↓
  ├─ Cache Hit → Serve from S3 (fast path)
  └─ Cache Miss → Origin Request
       ↓
     React App renders static HTML
       ↓
     Upload to S3 + serve response
       ↓
     Future requests served from S3

Logged-in Request → Normal dynamic path
  ↓
  React App (personalized content)
  ↓
  Database queries
  ↓
  Dynamic response
```

### Implementation Plan

**Phase 1: Static Page Generator (Week 1-2)**
1. 📋 Create static HTML generator for guest-viewable pages
2. 📋 Identify cacheable routes (writeups, nodes, superdocs, help pages)
3. 📋 Build React components that can render to static HTML
4. 📋 Generate initial static snapshot of top 10,000 pages
5. 📋 Configure S3 bucket for static hosting
6. 📋 Set appropriate cache headers and TTLs

**Phase 2: Routing Logic (Week 3-4)**
1. 📋 Implement guest detection at CloudFront/ALB level
2. 📋 Route guest traffic to S3 bucket
3. 📋 Route authenticated traffic to application servers
4. 📋 Handle cache misses (fall through to origin)
5. 📋 Implement cache invalidation webhooks
6. 📋 Add monitoring for cache hit rates

**Phase 3: Dynamic Cache Population (Week 5-6)**
1. 📋 On-demand static page generation for cache misses
2. 📋 Background worker to pre-generate popular pages
3. 📋 Incremental updates when content changes
4. 📋 Cache warming for trending content
5. 📋 Intelligent TTL based on page type and update frequency

**Phase 4: Cache Invalidation (Week 7-8)**
1. 📋 Invalidate S3 pages when writeups are edited
2. 📋 Invalidate related pages (parent nodes, category pages)
3. 📋 Batch invalidation for efficiency
4. 📋 Fallback to origin for recently invalidated pages
5. 📋 Monitor invalidation patterns and costs

**Phase 5: Optimization & Rollout (Week 9-12)**
1. 📋 A/B test with 10% of guest traffic to S3
2. 📋 Monitor performance, errors, and cost savings
3. 📋 Gradually increase guest traffic to S3 (25%, 50%, 75%, 100%)
4. 📋 Optimize cache hit rates and generation patterns
5. 📋 Document cost savings and performance improvements
6. 📋 Scale down application infrastructure proportionally

### Technical Details

**Cacheable Page Types:**
- Writeups (core content, rarely changes)
- E2nodes (collections of writeups)
- Superdocs (help pages, FAQs, documentation)
- User pages (for guest view, without personalized nodelets)
- Category pages
- Search engine landing pages

**Non-Cacheable (Always Dynamic):**
- Logged-in user pages (personalized nodelets)
- Write operations (posting, voting, messaging)
- User-specific API endpoints
- Admin tools and operations
- Real-time features (chatterbox, notifications)

**S3 Bucket Structure:**
```
s3://e2-guest-static/
├── node/
│   ├── writeup/
│   │   ├── 12345.html
│   │   └── 67890.html
│   ├── e2node/
│   │   ├── Everything.html
│   │   └── Perl.html
│   └── user/
│       └── root.html
├── title/
│   ├── Everything.html
│   └── help/
│       └── FAQ.html
└── manifest.json  # Cache metadata
```

**CloudFront Configuration:**
```
Origin Request Policy:
- Forward query strings: No (for guest requests)
- Forward headers: None (for guest requests)
- Forward cookies: None (for guest requests)

Cache Policy:
- TTL: 1 hour (default)
- TTL: 24 hours (writeups, stable content)
- TTL: 5 minutes (frequently updated pages)

Behaviors:
- /node/* → S3 bucket (guest only)
- /title/* → S3 bucket (guest only)
- /api/* → ALB (always dynamic)
- /* (with auth cookie) → ALB (authenticated users)
```

**Cache Invalidation Strategy:**
```perl
# When a writeup is edited
sub invalidate_writeup_cache {
    my ($writeup_id, $node_id) = @_;

    # Invalidate writeup page
    $s3->delete_object("node/writeup/$writeup_id.html");

    # Invalidate parent e2node
    $s3->delete_object("node/e2node/$node_id.html");

    # Invalidate related indexes
    # (category pages, user pages, etc.)
}
```

### Cost Savings Projection

**Current Costs (estimated):**
- ECS Fargate tasks: $200-300/month
- RDS database: $150-200/month
- ALB: $50/month
- WAF: $100-150/month (based on request volume)
- **Total: $500-700/month**

**Projected Costs with S3 Caching:**
- ECS Fargate (reduced scale): $60-100/month (70% reduction)
- RDS database (reduced load): $150-200/month (unchanged, but better margin)
- ALB (reduced requests): $30/month (40% reduction)
- WAF (reduced requests): $30-50/month (70% reduction)
- S3 + CloudFront: $20-40/month (new cost)
- **Total: $290-420/month**

**Estimated Savings: $200-300/month (40-50% reduction)**

**Annual Savings: $2,400-3,600/year**

### Success Metrics

**Performance:**
- 📊 P50 latency for guest pages: <100ms (vs. current 300-500ms)
- 📊 P95 latency for guest pages: <200ms (vs. current 800-1200ms)
- 📊 Cache hit rate: >90% for popular content
- 📊 Time to first byte (TTFB): <50ms from CloudFront

**Cost:**
- 📊 40-50% reduction in total infrastructure costs
- 📊 60-80% reduction in database query volume
- 📊 70% reduction in WAF request charges
- 📊 Ability to scale down ECS tasks during off-peak

**Reliability:**
- 📊 99.9% availability for cached content (S3 SLA)
- 📊 Reduced database connection exhaustion
- 📊 Better handling of traffic spikes
- 📊 Improved disaster recovery posture

### Risk Assessment

**Medium Risk:**
- Cache invalidation complexity (stale content visible to guests)
- Increased complexity in deployment pipeline
- S3/CloudFront costs if caching is ineffective
- Need to maintain two rendering paths (static + dynamic)

**Low Risk:**
- S3/CloudFront are well-proven, reliable services
- Can roll back easily by routing traffic back to origin
- Incremental rollout allows validation at each step
- No changes to logged-in user experience

**Mitigation:**
- Comprehensive testing with traffic shadowing
- Start with long-lived, stable content (old writeups)
- Monitor cache hit rates and cost savings closely
- Maintain ability to bypass cache for debugging
- Gradual rollout with easy rollback mechanism

### Dependencies

**Requires:**
- Priority 5: Mobile-First React Frontend (React components must render static HTML)
- API-driven architecture for logged-in users
- Clear separation between guest and authenticated paths

**Enables:**
- Massive cost savings for site sustainability
- Better performance for guest users
- Ability to handle traffic spikes without infrastructure scaling
- Foundation for future optimizations (edge computing, etc.)

### Timeline

**Target Completion:** Q3 2025

**Q2 2025 (April-June):**
- ⏸️ Phase 1: Static page generator and initial snapshot
- ⏸️ Phase 2: Routing logic and S3 bucket configuration

**Q3 2025 (July-September):**
- ⏸️ Phase 3: Dynamic cache population and warming
- ⏸️ Phase 4: Cache invalidation strategy
- ⏸️ Phase 5: A/B testing and gradual rollout

**Q4 2025 (October-December):**
- ⏸️ 100% guest traffic to S3 cache
- ⏸️ Infrastructure cost optimization
- ⏸️ Monitoring and refinement

**Total Estimated Effort:** 8-12 weeks

**Expected ROI:** Break-even in 2-3 months, ongoing savings of $2,400-3,600/year

### Future Enhancements

**Edge Computing:**
- Lambda@Edge for dynamic personalization at the edge
- Real-time cache invalidation via edge functions
- A/B testing at CloudFront level

**Advanced Caching:**
- Incremental Static Regeneration (ISR) for popular pages
- Predictive pre-caching based on trending content
- Edge caching for API responses (public data)

**Global Performance:**
- Regional S3 buckets for faster cache population
- Multi-region failover for reliability
- Optimized CloudFront distribution configuration

## Priority 6: Message Opcode Cleanup 🧹

**Priority Level:** Medium (Technical Debt / API Modernization)

### Why This Matters

**API Modernization**
- Legacy `op=message` forms scattered across the codebase
- Mix of form submissions and AJAX calls using old opcode system
- Modern React components already using REST APIs
- Inconsistent patterns make maintenance harder

**Better User Experience**
- REST APIs can return structured error messages
- Enables better client-side error handling and user feedback
- Modern UX patterns (inline validation, toast notifications)
- Consistent error messaging across the application

**Code Maintainability**
- Centralized message handling in API endpoints
- Easier to add features (rate limiting, spam detection)
- Better separation of concerns
- Clearer code paths and fewer edge cases

### Current State

**Message System Architecture:**
- Core message commands extracted to Application.pm (✅ Complete)
- Chatter API using command processor (✅ Complete)
- React Chatterbox using `/api/chatter/create` (✅ Complete)
- Messages API for private messages (✅ Complete)

**Remaining op=message Usage:**
- 7 total call sites identified
- 1 XML ticker (user-facing, must preserve)
- 6 internal forms (can migrate to API)

**Call Sites to Migrate:**

1. **Archive/Delete Message Actions** (htmlcode.pm:11211, 11215)
   - Currently use op=message with action parameters
   - Should POST to `/api/messages/:id/action/{archive,delete}`
   - Estimated effort: 1-2 hours

2. **Message Inbox Forms** (document.pm:9928, 16184, 18362)
   - Legacy message composition forms
   - Should POST to `/api/messages/create`
   - Consider React component for composition
   - Estimated effort: 4-6 hours

3. **Universal Message XML Ticker** (legacy.js:2690)
   - **KEEP**: User-facing public API
   - Used by bookmarklets and external tools
   - Preserve for backward compatibility

### Implementation Plan

**Phase 1: Archive/Delete Actions (Week 1)**
1. 📋 Update htmlcode.pm message action links to use API endpoints
2. 📋 Convert GET links to POST forms for proper REST semantics
3. 📋 Test message archive and delete functionality
4. 📋 Update any error handling to use API responses

**Phase 2: Message Inbox Forms (Week 2-3)**
1. 📋 Audit all message composition forms in document.pm
2. 📋 Update forms to POST to `/api/messages/create`
3. 📋 Implement structured error responses (validation, rate limits)
4. 📋 Update client-side code to display API errors
5. 📋 Test message sending and error scenarios
6. 📋 Consider React component for unified message composition

**Phase 3: Documentation & Cleanup (Week 4)**
1. 📋 Document XML ticker as preserved public API
2. 📋 Update API documentation with error response formats
3. 📋 Create examples of error handling patterns
4. 📋 Remove unused opcode=message handling code
5. 📋 Update developer guidelines

### Error Response Pattern

**Structured API Error Responses:**

```json
// Success
{
  "success": true,
  "message_id": 12345,
  "message": "Message sent successfully"
}

// Validation Error
{
  "success": false,
  "error": "message_too_long",
  "message": "Message exceeds 512 character limit",
  "max_length": 512,
  "current_length": 650
}

// Rate Limit Error
{
  "success": false,
  "error": "rate_limit_exceeded",
  "message": "Too many messages sent. Please wait before sending another.",
  "retry_after": 30
}

// Permission Error
{
  "success": false,
  "error": "user_ignored",
  "message": "This user has ignored your messages"
}
```

**Client-Side Error Handling:**

```javascript
// React component error handling
try {
  const response = await fetch('/api/messages/create', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ recipient: 'username', text: message })
  })

  const data = await response.json()

  if (data.success) {
    showToast('Message sent!', 'success')
  } else {
    // Display specific error message from API
    showToast(data.message, 'error')

    // Handle specific error types
    if (data.error === 'rate_limit_exceeded') {
      disableSubmitButton(data.retry_after)
    }
  }
} catch (err) {
  showToast('Network error. Please try again.', 'error')
}
```

### Benefits

**User Experience:**
- Clear, actionable error messages
- Inline validation feedback
- Better rate limiting communication
- Consistent error presentation

**Developer Experience:**
- Structured error responses
- Type-safe error codes
- Easier to add new validations
- Better debugging information

**Maintainability:**
- Centralized error handling
- Easier to update messaging
- Simpler code paths
- Better testability

### Dependencies

**Blocks:** None

**Enables:**
- Modern UX patterns in React components
- Better error reporting infrastructure
- Preparation for future API expansions
- Foundation for PSGI/Plack error middleware (Priority 9)

**Requires:**
- Priority 5: Mason2 template elimination must be complete first
- Messages API already complete (✅)
- Chatter API already complete (✅)
- React components for client-side handling

**Sequencing Note:**
This work follows Mason2 elimination in the React migration. Once Mason2 templates are removed, API endpoints become the primary interface, making structured error responses even more critical.

**Related Work:**
- Priority 5: Mobile-First React Frontend (React components, Mason2 elimination)
- Priority 9: PSGI/Plack Migration (error middleware foundation)

### Timeline

**Q1 2025:**
- ⏸️ Phase 1: Archive/delete actions (Week 1)
- ⏸️ Phase 2: Message inbox forms (Week 2-3)

**Q2 2025:**
- ⏸️ Phase 3: Documentation and cleanup (Week 4)
- ⏸️ Monitor usage and refine error messages

**Estimated Effort:** 3-4 weeks

**Progress:** Phase 1 preparation complete (command processor extracted, APIs created)

## Priority 7: Testing Infrastructure ✅

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

## Priority 9: Code Coverage Tracking 📊

### Why This Matters

**Visibility**
- Identify untested code paths
- Track test improvement over time
- Ensure critical paths are covered
- Guide testing priorities

**Quality Assurance**
- Catch regression gaps
- Validate refactoring safety
- Enforce coverage minimums
- CI/CD quality gates

### Current Blocker: mod_perl Architecture

**Issue:** Devel::Cover cannot effectively track coverage in the current setup because:
- Most tests make HTTP requests to the Apache/mod_perl server
- Application code runs in a separate Apache process
- Devel::Cover only instruments the test process, not the web server

**Solution:** Migrate to PSGI/Plack architecture first (see Priority 8 above)
- PSGI apps can be loaded directly in test processes
- Enables in-process testing without HTTP overhead
- Full coverage tracking of application code
- Faster test execution

**Current Status:** Infrastructure ready, blocked by architecture

### Implementation Plan

**Phase 1: Infrastructure Setup** ✅ COMPLETE
1. ✅ Add Devel::Cover to cpanfile dependencies
2. ✅ Create coverage script: `./tools/coverage.sh`
3. ✅ Add coverage/ to .gitignore
4. ✅ Create documentation: [Code Coverage Guide](code-coverage.md)
5. 🔄 Run `carton install && carton bundle` to vendor dependencies
6. 🔄 Rebuild Docker container with new dependencies

**Phase 2: PSGI Migration Required** ⏸️ BLOCKED
1. ⏸️ Migrate from mod_perl to PSGI/Plack (Priority 8)
2. ⏸️ Convert tests to use Plack::Test for in-process testing
3. ⏸️ Generate baseline coverage report
4. ⏸️ HTML report generation

**Phase 3: CI/CD Integration** ⏸️ BLOCKED
1. ⏸️ Coverage threshold enforcement
2. ⏸️ Fail build if coverage drops
3. ⏸️ Coverage badge in README
4. ⏸️ Trend tracking over time

### Tool Configuration

**Devel::Cover Options:**
```bash
# Run tests with coverage
./docker/run-tests.sh coverage

# Generate HTML report
cover -report html -outputdir coverage/html

# Check coverage thresholds
cover -report text -coverage_threshold 70
```

**Exclusions:**
- Generated code (Moose attributes)
- Legacy database eval code
- Vendor libraries
- Test files themselves

### Coverage Goals

**Current State:**
- ❌ No coverage tracking
- ❌ Unknown coverage percentage
- ❌ No coverage baseline

**Short-term (Month 1):**
- ✅ Coverage infrastructure setup
- ✅ Baseline measurement
- 🎯 Target: 40% overall coverage

**Medium-term (Month 2-3):**
- 🎯 Target: 60% core modules
- 🎯 Target: 80% new code
- 🎯 CI/CD enforcement

**Long-term (Month 4-6):**
- 🎯 Target: 70% overall coverage
- 🎯 Target: 90% critical paths
- 🎯 Per-module coverage reports

### Priority Modules for Coverage

**High Priority (>80% target):**
- Everything::Application (security, permissions)
- Everything::Security::* (authentication, authorization)
- Everything::API::* (public interfaces)
- SQL injection fixes (dataproviders)

**Medium Priority (>60% target):**
- Everything::Node::* (business logic)
- Everything::NodeBase (database layer)
- Everything::HTML (rendering)
- Everything::Request (routing)

**Lower Priority (>40% target):**
- Everything::Delegation::* (legacy code being replaced)
- Utility modules
- Helper classes

## Priority 8: PSGI/Plack Migration 🔄

### Why This Matters

**Modern Perl Web Standards**
- PSGI is the standard interface for Perl web applications (like WSGI for Python, Rack for Ruby)
- Decouples application from web server (run on Apache, nginx, Starman, etc.)
- Enables middleware ecosystem (logging, authentication, compression, etc.)
- Better testability with in-process testing

**Enables Better API Error Handling**
- PSGI middleware for consistent error responses across all endpoints
- Structured error logging and monitoring
- Better exception handling and recovery
- Foundation for improved user-facing error messages (relates to Priority 6)
- Standardized error response format across application
- Easier to implement API versioning and deprecation warnings

**Enables Code Coverage**
- Applications can be loaded directly in test processes
- No separate Apache server needed for tests
- Full Devel::Cover instrumentation of application code
- Faster test execution (no HTTP overhead)

**Deployment Flexibility**
- Run with any PSGI-compatible server
- Easier local development (Plack's built-in server)
- Better process management options
- Simplified Docker containers

### Current State

**Architecture:**
- mod_perl 2 with Apache 2.4
- Application tied to Apache::Request
- Global variables ($APP, $DB, $USER, etc.)
- Request handling in Everything::Application

### Implementation Plan

**Phase 1: Research and Planning (Week 1-2)**
1. 📋 Audit Apache-specific dependencies
2. 📋 Identify mod_perl-specific features in use
3. 📋 Document request lifecycle
4. 📋 Design PSGI app structure
5. 📋 Plan gradual migration strategy

**Phase 2: PSGI Compatibility Layer (Week 3-4)**
1. 📋 Create PSGI app wrapper (app.psgi)
2. 📋 Add Plack dependencies to cpanfile
3. 📋 Wrap Everything::Application in PSGI handler
4. 📋 Create request/response adapters
5. 📋 Test basic request handling

**Phase 3: Parallel Deployment (Week 5-8)**
1. 📋 Run PSGI app alongside mod_perl
2. 📋 Route subset of traffic to PSGI
3. 📋 Monitor performance and errors
4. 📋 Gradually increase PSGI traffic
5. 📋 Fix compatibility issues

**Phase 4: Test Migration (Week 9-10)**
1. 📋 Convert HTTP tests to Plack::Test
2. 📋 Enable in-process testing
3. 📋 Validate coverage tracking works
4. 📋 Update test documentation

**Phase 5: Full Cutover (Week 11-12)**
1. 📋 Deploy PSGI as primary
2. 📋 Remove mod_perl configuration
3. 📋 Update deployment scripts
4. 📋 Update documentation

### Required Dependencies

```perl
# Add to cpanfile
requires 'Plack';
requires 'Plack::Middleware::Session';
requires 'Plack::Middleware::Static';
requires 'Plack::Test';  # For testing
requires 'Starman';      # Production PSGI server
```

### Example app.psgi Structure

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'ecore';
use Everything::Application;
use Plack::Builder;

my $app = sub {
    my $env = shift;

    # Create Everything application instance
    my $e2app = Everything::Application->new(env => $env);

    # Handle request
    my $response = $e2app->handle_request();

    return $response->finalize();
};

builder {
    enable 'Static',
        path => qr{^/images/},
        root => './www';

    enable 'Session',
        store => 'File';

    $app;
};
```

### Testing Benefits

**Before (mod_perl):**
```perl
# Must start Apache server, make HTTP requests
my $ua = LWP::UserAgent->new;
my $response = $ua->get("http://localhost/api/users");
# No coverage of application code
```

**After (PSGI):**
```perl
# In-process testing with full coverage
use Plack::Test;
my $app = require 'app.psgi';
test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/api/users");
    # Full Devel::Cover instrumentation
};
```

### Risk Assessment

**Low Risk:**
- PSGI is well-established (since 2009)
- Large community support
- Minimal code changes required
- Can run in parallel with mod_perl

**Medium Risk:**
- Request object differences (Apache::Request vs Plack::Request)
- Session handling changes
- Upload handling differences

**Mitigation:**
- Gradual rollout with parallel deployment
- Comprehensive testing before cutover
- Keep mod_perl config as fallback

### Dependencies

- **Blocks:** Priority 9 (Code Coverage Tracking)
- **Enables:** Better testing, code coverage, deployment flexibility, improved error handling (Priority 6)
- **Requires:** Refactoring of request handling in Everything::Application

## Priority 10: Alternative Login Methods 🔐

### Why This Matters

**User Acquisition**
- Reduce account creation friction
- Lower barrier to entry for new users
- Improve conversion rates
- Modern user expectations (OAuth login is standard)

**Security Benefits**
- OAuth providers handle password security
- Multi-factor authentication via providers
- Reduced password management burden
- Better account recovery options

**User Experience**
- Faster registration process
- No password to remember
- Seamless cross-device experience
- Trusted third-party authentication

### Current State

**Authentication System:**
- Custom username/password authentication
- Manual account creation flow
- Password storage with salt/hash
- Email verification required
- No alternative login methods

**Barriers to Entry:**
- Users must create new credentials
- Email verification step
- Password requirements
- Additional friction vs. modern sites

### Target Implementation

**OAuth 2.0 Providers:**
1. **Google Sign-In** (OAuth 2.0)
   - Widest adoption
   - Google Account integration
   - Well-documented API

2. **Facebook Login** (OAuth 2.0)
   - Large user base
   - Social graph integration
   - Profile data access

3. **Apple Sign In** (OAuth 2.0)
   - Required for iOS apps
   - Privacy-focused
   - Email relay option

### Technical Architecture

**OAuth Flow:**
```
1. User clicks "Login with Google"
2. Redirect to provider authorization URL
3. User authorizes on provider site
4. Provider redirects back with auth code
5. Exchange auth code for access token
6. Fetch user profile from provider
7. Link to existing account or create new
8. Set E2 session cookie
```

**Database Schema Changes:**
```sql
CREATE TABLE oauth_accounts (
    oauth_account_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    provider_email VARCHAR(255),
    access_token TEXT,
    refresh_token TEXT,
    token_expires DATETIME,
    created_on DATETIME NOT NULL,
    last_login DATETIME,
    UNIQUE KEY unique_provider_user (provider, provider_user_id),
    FOREIGN KEY (user_id) REFERENCES user(user_id)
);
```

**Account Linking:**
- Match by email address (with confirmation)
- Allow multiple OAuth providers per account
- Support both OAuth and password login
- Handle edge cases (email changes, account merges)

### Implementation Plan

**Phase 1: Infrastructure (Week 1-2)**
1. 📋 Add OAuth2 client library to cpanfile (Net::OAuth2, Mojolicious::Plugin::OAuth2, or similar)
2. 📋 Create oauth_accounts database table
3. 📋 Store OAuth credentials in environment variables
4. 📋 Create OAuth configuration module

**Phase 2: Google Sign-In (Week 3-4)**
1. 📋 Register application with Google Cloud Console
2. 📋 Implement authorization flow
3. 📋 Add "Login with Google" button to login page
4. 📋 Handle callback and token exchange
5. 📋 Create or link user account
6. 📋 Set session and redirect

**Phase 3: Facebook Login (Week 5-6)**
1. 📋 Register application with Facebook Developers
2. 📋 Implement Facebook-specific flow
3. 📋 Add "Login with Facebook" button
4. 📋 Handle permissions and profile data
5. 📋 Test account linking

**Phase 4: Apple Sign In (Week 7-8)**
1. 📋 Register with Apple Developer Program
2. 📋 Implement Apple-specific flow (different from standard OAuth2)
3. 📋 Add "Sign in with Apple" button
4. 📋 Handle email relay privacy feature
5. 📋 Test iOS integration

**Phase 5: Security & Testing (Week 9-10)**
1. 📋 CSRF protection on OAuth flows
2. 📋 State parameter validation
3. 📋 Token refresh logic
4. 📋 Account unlinking functionality
5. 📋 Comprehensive testing
6. 📋 Security audit

**Phase 6: User Experience (Week 11-12)**
1. 📋 Account settings page for linked accounts
2. 📋 Help documentation
3. 📋 Error handling and user messaging
4. 📋 Mobile responsive design
5. 📋 Analytics tracking

### Required Dependencies

```perl
# Add to cpanfile
requires 'LWP::Protocol::https';  # HTTPS support
requires 'JSON::XS';              # JSON handling
requires 'URI';                   # URL manipulation
requires 'Crypt::JWT';            # JWT for Apple Sign In

# OAuth2 client (choose one)
requires 'Net::OAuth2::Client';
# OR
requires 'Mojolicious::Plugin::OAuth2';
# OR
requires 'LWP::Authen::OAuth2';
```

### Configuration

**Environment Variables:**
```bash
# Google OAuth
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_secret

# Facebook OAuth
FACEBOOK_APP_ID=your_app_id
FACEBOOK_APP_SECRET=your_secret

# Apple Sign In
APPLE_CLIENT_ID=com.everything2.signin
APPLE_TEAM_ID=your_team_id
APPLE_KEY_ID=your_key_id
APPLE_PRIVATE_KEY=/path/to/private/key
```

### Security Considerations

**Token Storage:**
- Store access tokens encrypted in database
- Never log tokens
- Implement token rotation
- Automatic expiration handling

**Account Linking:**
- Require re-authentication before linking
- Email confirmation for account merges
- Prevent account hijacking via email takeover
- Rate limiting on OAuth attempts

**Privacy:**
- Request minimal OAuth scopes (profile, email only)
- Clear privacy policy about data usage
- Allow users to unlink accounts
- GDPR compliance for EU users

### User Stories

**New User:**
1. Visits E2, sees "Login with Google"
2. Clicks button, redirects to Google
3. Authorizes, redirects back to E2
4. Account automatically created
5. Immediately logged in and ready to contribute

**Existing User:**
1. Logs in with username/password
2. Goes to account settings
3. Clicks "Link Google Account"
4. Authorizes on Google
5. Now can use either login method

**Mobile User:**
1. Opens E2 on phone
2. Sees "Sign in with Apple"
3. Uses Face ID to authorize
4. Seamlessly logged in

### Success Metrics

**Adoption Metrics:**
- 30%+ of new signups use OAuth within 6 months
- 50%+ of new signups use OAuth within 12 months
- Reduced signup abandonment rate
- Faster time-to-first-contribution

**Technical Metrics:**
- <2s OAuth flow completion time
- >99.9% OAuth authentication success rate
- Zero security incidents related to OAuth
- Comprehensive error logging and monitoring

### Risks and Mitigation

**Provider Outages:**
- Keep traditional login as fallback
- Monitor provider status pages
- Graceful degradation

**Privacy Concerns:**
- Clear documentation of data usage
- Minimal scope requests
- Allow account unlinking
- Transparent privacy policy

**Technical Complexity:**
- Well-tested OAuth libraries
- Comprehensive testing
- Security review
- Staged rollout

### Future Enhancements

**Additional Providers:**
- GitHub Login (developer audience)
- Twitter/X Login
- Microsoft Account
- Discord Login

**Advanced Features:**
- Social profile importing
- Friend graph integration
- Cross-platform account sync
- OAuth for API access (developer tokens)

### Timeline

**Q1 2025:**
- ⏸️ Infrastructure and Google Sign-In
- ⏸️ Database schema and OAuth client setup

**Q2 2025:**
- ⏸️ Facebook and Apple Sign In
- ⏸️ Security audit and testing

**Q3 2025:**
- ⏸️ User experience refinement
- ⏸️ Documentation and analytics
- ⏸️ Production deployment

**Q4 2025:**
- ⏸️ Monitor adoption metrics
- ⏸️ Additional provider evaluation
- ⏸️ Feature enhancements

## Priority 11: CSS Asset Pipeline 🎨

**Priority Level:** Low (Developer Efficiency / Code Quality)

### Why This Matters

**Code Maintainability**
- CSS scattered across inline `<style>` blocks in delegation functions
- No single source of truth for styles
- Difficult to maintain consistency across pages
- Hard to identify and remove duplicate/unused CSS

**Performance**
- Inline CSS sent with every page request
- No browser caching for styles
- No minification or compression
- Larger HTML payloads

**Developer Experience**
- Cannot use CSS preprocessors (SASS, LESS)
- No CSS linting or validation
- Difficult to organize styles by component/page
- No hot-reloading during development

**Modern Standards**
- Industry standard is external stylesheets
- Better separation of concerns (content vs. presentation)
- Easier to apply site-wide theme changes
- Better tooling support

### Current State

**Inline CSS Locations:**
- Delegation functions (e.g., `site_trajectory_2`, settings, etc.)
- Legacy `<style>` blocks in superdoc content
- Scattered style definitions in htmlcode functions
- Some CSS in Mason2 templates

**Example Problem:**

```perl
sub site_trajectory_2
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;
    my $text = '';

    # CSS mixed with Perl code
    $text .= '<style>
<!--
th {
  text-align:left;
}
.graph td {
  border-bottom: 1px solid #ccc;
  border-right: 1px solid #ccc;
  padding: 3px;
}
-->
</style>';

    # Rest of function...
}
```

**Existing Asset Pipeline:**
- Webpack configured for JavaScript bundling
- React components use CSS modules
- Modern frontend has proper asset pipeline
- Legacy backend code lacks integration

### Target Implementation

**Asset Pipeline Structure:**

```
everything2/
├── assets/
│   ├── css/
│   │   ├── core/
│   │   │   ├── base.css          # Reset, typography, global
│   │   │   ├── layout.css        # Grid, containers, spacing
│   │   │   └── variables.css     # CSS custom properties
│   │   ├── components/
│   │   │   ├── forms.css         # Form elements
│   │   │   ├── buttons.css       # Button styles
│   │   │   ├── tables.css        # Table styles
│   │   │   └── graphs.css        # Graph/chart styles
│   │   ├── pages/
│   │   │   ├── settings.css      # Settings page
│   │   │   ├── trajectory.css    # Site trajectory graphs
│   │   │   ├── writeups.css      # Writeup display
│   │   │   └── users.css         # User pages
│   │   └── legacy/
│   │       └── compat.css        # Backward compatibility
│   └── js/
│       └── (existing webpack setup)
└── webpack.config.js              # Add CSS loaders
```

**Webpack Configuration:**

```javascript
// webpack.config.js additions
module: {
  rules: [
    {
      test: /\.css$/,
      use: [
        MiniCssExtractPlugin.loader,
        'css-loader',
        'postcss-loader'  // For autoprefixer, minification
      ]
    }
  ]
},
plugins: [
  new MiniCssExtractPlugin({
    filename: 'css/[name].[contenthash].css'
  })
]
```

**HTML Template Integration:**

```perl
# In htmlpage delegation or layout template
sub standard_header {
    my $css_url = $APP->getAssetUrl('main.css');
    return qq{
        <link rel="stylesheet" href="$css_url">
    };
}
```

### Implementation Plan

**Phase 1: Infrastructure Setup (Week 1-2)**
1. 📋 Configure Webpack for CSS processing
2. 📋 Add CSS loaders (css-loader, mini-css-extract-plugin, postcss-loader)
3. 📋 Create directory structure in `assets/css/`
4. 📋 Add CSS build to deployment pipeline
5. 📋 Create asset URL helper in Everything::Application
6. 📋 Add cache-busting with content hashes

**Phase 2: Extract Core Styles (Week 3-4)**
1. 📋 Audit existing inline `<style>` blocks across codebase
2. 📋 Create `core/base.css` with reset and typography
3. 📋 Create `core/layout.css` with grid and spacing
4. 📋 Extract common styles from delegation functions
5. 📋 Create CSS variables for colors, fonts, spacing
6. 📋 Update main layout template to include stylesheet

**Phase 3: Component Styles (Week 5-6)**
1. 📋 Extract form styles to `components/forms.css`
2. 📋 Extract table styles to `components/tables.css`
3. 📋 Extract graph styles to `components/graphs.css`
4. 📋 Create button style system
5. 📋 Document CSS component classes

**Phase 4: Page-Specific Styles (Week 7-8)**
1. 📋 Extract settings page CSS
2. 📋 Extract trajectory/statistics page CSS
3. 📋 Extract writeup display CSS
4. 📋 Extract user page CSS
5. 📋 Create page-specific CSS bundles if needed

**Phase 5: Legacy Cleanup (Week 9-10)**
1. 📋 Remove inline `<style>` blocks from delegation functions
2. 📋 Update delegation migration docs
3. 📋 Add CSS guidelines to developer documentation
4. 📋 Create CSS linting configuration
5. 📋 Run tests to ensure no visual regressions

**Phase 6: Optimization (Week 11-12)**
1. 📋 Enable CSS minification in production
2. 📋 Set up PostCSS for autoprefixing
3. 📋 Analyze and remove unused CSS
4. 📋 Implement critical CSS for above-fold content
5. 📋 Add CSS to build monitoring

### Technical Details

**Asset URL Helper:**

```perl
package Everything::Application;

sub getAssetUrl {
    my ($self, $asset_name) = @_;

    # In production: Use manifest.json from webpack
    # In development: Use dev server URL

    if ($ENV{E2_ENV} eq 'production') {
        my $manifest = $self->loadAssetManifest();
        return '/static/' . $manifest->{$asset_name};
    } else {
        return '/static/' . $asset_name;
    }
}

sub loadAssetManifest {
    # Read webpack-generated manifest.json
    # Maps logical names to hashed filenames
    # Cached in memory for performance
}
```

**Migration Pattern:**

```perl
# BEFORE (inline CSS)
sub some_page {
    my $text = '<style>
    .special-table { border: 1px solid #ccc; }
    </style>';
    # ...
}

# AFTER (external CSS)
sub some_page {
    # CSS moved to assets/css/pages/some-page.css
    # Automatically included via main stylesheet
    # Or page-specific bundle loaded by layout
    my $text = '';
    # ...
}
```

**CSS Organization Guidelines:**

```css
/* assets/css/pages/trajectory.css */

/* Graph component styles */
.graph td {
    border-bottom: 1px solid var(--color-border);
    border-right: 1px solid var(--color-border);
    padding: var(--spacing-sm);
}

.graph .bar {
    background-color: var(--color-success);
    position: absolute;
    box-sizing: border-box;
}

/* Use CSS custom properties for theming */
:root {
    --color-border: #ccc;
    --color-success: #9e9;
    --spacing-sm: 3px;
}
```

### Benefits

**Performance Improvements:**
- Reduced HTML payload size (no inline CSS)
- Browser caching of stylesheets
- Minified and compressed CSS in production
- Fewer bytes transferred per request

**Developer Experience:**
- Modern CSS tooling (linting, formatting, validation)
- Hot-reloading during development
- Easier to find and modify styles
- Better IDE support and autocomplete

**Maintainability:**
- Single source of truth for styles
- Easier to enforce consistency
- Simpler to apply site-wide changes
- Clear organization and documentation

**Future Enhancements:**
- Easy to add CSS preprocessors (SASS/LESS)
- Support for CSS-in-JS if needed
- Easier to implement theming
- Better integration with design systems

### Dependencies

**Blocks:** None (can proceed independently)

**Enables:**
- Easier theming and design system implementation
- Better mobile-first responsive design
- Improved site performance
- Modern frontend development workflow

**Requires:**
- Webpack already configured (✅ present)
- Asset serving infrastructure (✅ present)
- Developer time for migration

### Timeline

**Q2 2025:**
- ⏸️ Infrastructure setup and tooling configuration
- ⏸️ Begin extracting core and component styles

**Q3 2025:**
- ⏸️ Continue page-specific style extraction
- ⏸️ Update delegation functions to remove inline CSS

**Q4 2025:**
- ⏸️ Complete migration and cleanup
- ⏸️ Optimize and document new system
- ⏸️ Update developer guidelines

**Note:** This is a **low priority** effort that can proceed in parallel with other work and doesn't block any critical functionality. It's primarily a code quality and developer experience improvement.

### Related Task: Migrate static.everything2.com Assets

**Background:**

Currently, various static assets (fonts, images) are hosted in an S3 bucket at `s3.amazonaws.com/static.everything2.com` and referenced directly in stylesheets and code. These assets should be migrated to the webpack asset deployment pipeline to:

- Centralize asset management in source control
- Enable versioning and cache-busting
- Improve asset loading performance
- Simplify deployment (no separate S3 bucket)
- Allow for asset optimization (compression, format conversion)

**Current Static Assets:**

1. **Fonts** (pamphleteer stylesheet):
   - essays1743-webfont.{eot,woff,ttf}
   - essays1743-italic-webfont.{eot,woff,ttf}
   - linlibertine_re-4.7.5-webfont.{eot,woff,ttf}
   - linlibertine_bd-4.1.5-webfont.{eot,woff,ttf}
   - linlibertine_it-4.2.6-webfont.{eot,woff,ttf}

2. **Images** (various stylesheets):
   - e2_tight.gif
   - external.png
   - triangles.png
   - socialcombined.gif
   - externalLinkGrayscale.png
   - topleft.png
   - e2_others_01.gif, e2_others_02.gif
   - search_button.gif
   - epicenter.gif, chatterbox.gif, otherusers.gif
   - vitals.gif, newwriteups.gif, readthis.gif
   - everything_developer.gif
   - magnifier.png
   - e2bg.jpg (bookwormier theme)

**Affected Files:**

17 files reference static.everything2.com:
- ecore/Everything/Delegation/document.pm
- ecore/Everything/Delegation/htmlcode.pm
- nodepack/superdocnolinks/e2_color_toy.xml
- 7 stylesheet files (nodepack/stylesheet/*.xml)
- 7 compiled CSS files (www/css/*.css)

**Implementation Plan:**

1. **Phase 1: Download and Organize Assets**
   - Download all assets from S3 bucket
   - Organize into appropriate directory structure:
     ```
     assets/
     ├── fonts/
     │   ├── essays1743/
     │   └── linlibertine/
     └── images/
         ├── themes/
         │   ├── pamphleteer/
         │   ├── simplicity/
         │   ├── kernel_blue/
         │   └── bookwormier/
         └── ui/
     ```

2. **Phase 2: Configure Webpack Asset Handling**
   - Add file-loader for fonts and images
   - Configure output paths and naming
   - Set up proper MIME types
   - Enable optimization (compression, format conversion)

3. **Phase 3: Update References**
   - Update stylesheet source files (nodepack/stylesheet/*.xml)
   - Update delegation code references
   - Use webpack asset helper functions
   - Generate new CSS with correct asset paths

4. **Phase 4: Testing and Validation**
   - Verify all themes render correctly
   - Check font loading in all supported browsers
   - Validate image references
   - Test cache-busting

5. **Phase 5: Deployment and Cleanup**
   - Deploy updated stylesheets
   - Verify assets load from new location
   - Monitor for any 404s or broken references
   - Document S3 bucket can be deprecated

**Benefits:**

- **Version Control:** All assets tracked in git
- **Cache-Busting:** Automatic content hashing
- **Optimization:** Webpack can compress/optimize assets
- **Simplification:** One less external dependency
- **Performance:** Assets served from same CDN as application
- **Developer Experience:** Easier to add/update assets

**Risks:**

- Low risk - primarily CSS reference updates
- No functionality changes, only asset location
- Easy to test visually
- Can be rolled back quickly if issues arise

**Priority:** Low (infrastructure improvement, no user-facing impact)

**Estimated Effort:** 1-2 days

**Dependencies:**
- Webpack configuration (already present)
- Asset pipeline infrastructure (already present)
- Access to static.everything2.com S3 bucket for downloading assets

## Priority 12: XML Generation Library Rationalization 📄

**Priority Level:** Low (Code Quality / Technical Debt)

### Why This Matters

**Code Maintainability**
- Multiple XML generation approaches scattered across codebase
- Inconsistent XML formatting and escaping
- Mix of string concatenation, custom functions, and library code
- Difficult to ensure consistent, valid XML output

**Security**
- Manual XML generation prone to injection vulnerabilities
- Inconsistent escaping of special characters
- No validation of XML structure
- Risk of malformed XML breaking parsers

**Library Redundancy**
- `Everything::XML` module (legacy custom implementation)
- `XML::Simple` used in some places
- Manual string concatenation in others
- No single standard approach

**Modern Standards**
- Industry standard is using well-tested XML libraries
- Better validation and error handling
- Standards-compliant output
- Easier to maintain and test

### Current State

**XML Generation Methods:**

1. **Everything::XML** (ecore/Everything/XML.pm)
   - Custom legacy module for XML generation
   - Used primarily for displaytype=xml (node export feature)
   - 460+ lines of custom XML generation code
   - Functions: `node2xml()`, `genTag()`, `xml_convert()`, etc.
   - Relies on global `$DB` variable
   - Limited to specific E2 node export use cases

2. **XML::Simple**
   - Perl CPAN module for simple XML tasks
   - Used in some parts of codebase
   - Better than string concatenation but has limitations
   - Not ideal for complex XML generation

3. **String Concatenation**
   - Manual XML building with string operations
   - Scattered across delegation functions
   - Prone to escaping errors
   - Hard to maintain and validate

**Example of Custom XML Module:**

```perl
# Everything/XML.pm - Custom implementation
sub genTag {
    my ($tag, $value, $PARAMS) = @_;
    my $str = "<$tag";

    foreach my $param (keys %$PARAMS) {
        $str .= qq| $param="$$PARAMS{$param}"|;
    }

    if (defined $value && $value ne "") {
        $str .= ">$value</$tag>";
    } else {
        $str .= " />";
    }

    return $str;
}
```

**Current Uses of Everything::XML:**
- displaytype=xml query parameter (legacy node export)
- XML representation of nodes for backup/import
- Nodepack XML generation (delegation migration tool)
- Limited usage outside of admin/debugging features

### Target Implementation

**Standardize on Modern XML Library:**

Use **XML::LibXML** (or similar robust library) for all XML generation:

**Benefits of XML::LibXML:**
- Industry-standard libxml2 bindings
- Comprehensive DOM API
- Automatic escaping and validation
- XPath support for querying
- Namespace handling
- Schema validation support
- Well-tested and maintained
- Fast C-based implementation

**Example Refactored Code:**

```perl
# BEFORE (Everything::XML custom code)
my $xml = genTag('user', $username, {
    id => $userid,
    level => $level
});

# AFTER (XML::LibXML)
use XML::LibXML;

my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
my $user_elem = $doc->createElement('user');
$user_elem->setAttribute('id', $userid);
$user_elem->setAttribute('level', $level);
$user_elem->appendText($username);
$doc->setDocumentElement($user_elem);
my $xml = $doc->toString();
```

### Implementation Plan

**Phase 1: Audit and Analysis (Week 1)**
1. 📋 Audit all XML generation code across codebase
2. 📋 Document current uses of Everything::XML
3. 📋 Identify all displaytype=xml usage in production
4. 📋 Catalog string concatenation XML building
5. 📋 Assess impact of removing Everything::XML

**Phase 2: Library Selection and Testing (Week 2)**
1. 📋 Evaluate XML::LibXML vs alternatives (XML::Writer, XML::Twig)
2. 📋 Add chosen library to cpanfile
3. 📋 Create wrapper/utility module for common E2 XML patterns
4. 📋 Write tests for XML generation functions
5. 📋 Document XML generation standards

**Phase 3: Migrate displaytype=xml (Week 3-4)**
1. 📋 Refactor Everything::XML to use modern library
2. 📋 Or create new implementation alongside old
3. 📋 Test node export functionality
4. 📋 Validate XML output matches expected format
5. 📋 Ensure backward compatibility for existing exports

**Phase 4: Migrate Other XML Generation (Week 5-6)**
1. 📋 Replace string concatenation with library calls
2. 📋 Update nodepack XML generation
3. 📋 Refactor any delegation functions using manual XML
4. 📋 Add XML validation to relevant code paths
5. 📋 Create helper functions for common patterns

**Phase 5: Deprecation and Cleanup (Week 7-8)**
1. 📋 Remove Everything::XML module (if fully replaced)
2. 📋 Update documentation and coding standards
3. 📋 Add XML generation guidelines to developer docs
4. 📋 Run comprehensive tests
5. 📋 Monitor production for any XML-related issues

### Technical Details

**Recommended Dependencies:**

```perl
# Add to cpanfile
requires 'XML::LibXML';
requires 'XML::LibXML::Simple';  # For backward compatibility if needed
```

**Utility Module Pattern:**

```perl
package Everything::XML::Generator;
use Moose;
use XML::LibXML;

has 'doc' => (
    is => 'ro',
    isa => 'XML::LibXML::Document',
    lazy => 1,
    default => sub { XML::LibXML::Document->new('1.0', 'UTF-8') }
);

sub node_to_xml {
    my ($self, $node) = @_;

    my $elem = $self->doc->createElement($node->{type}{title});
    $elem->setAttribute('node_id', $node->{node_id});
    $elem->setAttribute('title', $node->{title});

    # Add child elements with automatic escaping
    for my $field (keys %$node) {
        next if ref($node->{$field});
        my $field_elem = $self->doc->createElement($field);
        $field_elem->appendText($node->{$field});
        $elem->appendChild($field_elem);
    }

    return $elem;
}
```

**Migration Pattern for displaytype=xml:**

```perl
# In htmlpage delegation or similar
sub display_xml {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    # BEFORE: use Everything::XML
    # my $xml = Everything::XML::node2xml($NODE);

    # AFTER: use modern library
    use Everything::XML::Generator;
    my $generator = Everything::XML::Generator->new();
    my $xml = $generator->node_to_xml($NODE)->toString();

    $query->header(-type => 'text/xml');
    return $xml;
}
```

### Benefits

**Code Quality:**
- Single standard approach across codebase
- Well-tested library code vs custom implementation
- Proper escaping and validation
- Easier to maintain and understand

**Security:**
- Automatic escaping prevents XML injection
- Library handles edge cases properly
- Validation catches malformed XML
- Reduced attack surface

**Developer Experience:**
- Standard Perl XML library (well-documented)
- Better IDE support and examples
- Easier for new developers to understand
- Follows Perl best practices

**Future Capabilities:**
- XPath querying for XML parsing
- Schema validation support
- Namespace handling for complex formats
- XSLT transformation if needed

### Alternative Approaches

**Option A: Minimal Refactor**
- Keep Everything::XML but refactor internals to use XML::LibXML
- Maintain same API for backward compatibility
- Lower risk, easier migration
- Still reduces custom code

**Option B: Complete Removal**
- Replace Everything::XML entirely
- Deprecate displaytype=xml feature (low usage)
- Simplify codebase significantly
- Higher risk if feature is used

**Option C: Incremental Migration**
- Introduce new XML generation alongside old
- Gradually migrate code over time
- Eventually remove Everything::XML
- Safest approach, longer timeline

**Recommended:** Option A (refactor internals, keep API)

### Dependencies

**Blocks:** None (can proceed independently)

**Enables:**
- Better XML validation and security
- Easier to implement XML-based features
- Cleaner, more maintainable codebase

**Requires:**
- XML::LibXML or similar library added to dependencies
- Developer time for audit and migration
- Testing of XML output formats

**Related Work:**
- Priority 1: eval removal (XML generation in database code)
- Priority 2: Moose refactoring (could create XML::Generator as Moose class)

### Usage Assessment

**Current displaytype=xml Usage:**
- Admin/debugging feature
- Node export for backup/migration
- Used by delegation migration tooling
- Not heavily used in production
- Could be deprecated if low value

**Impact of Removal:**
- Low user impact (admin feature)
- May affect internal tooling
- Would simplify codebase
- Need to assess actual production usage

### Timeline

**Q2 2025:**
- ⏸️ Audit XML generation usage across codebase
- ⏸️ Evaluate and select modern XML library
- ⏸️ Add dependencies and create wrapper utilities

**Q3 2025:**
- ⏸️ Refactor Everything::XML internals
- ⏸️ Migrate string concatenation XML building
- ⏸️ Test XML output and validation

**Q4 2025:**
- ⏸️ Complete migration and cleanup
- ⏸️ Update developer documentation
- ⏸️ Consider deprecating legacy XML features

**Estimated Effort:** 2-3 weeks (low priority, can be done incrementally)

**Note:** This is a **low priority** technical debt cleanup that doesn't block any critical functionality. It primarily improves code quality, security, and maintainability. Can proceed in parallel with other work or be deferred to a future development cycle.

## Priority 13: MySQL 8.0 → 8.4 Upgrade ⚠️

**Priority Level:** High (Infrastructure / Cost Reduction)

### Why This Matters

**AWS RDS Deprecation Timeline**
- MySQL 8.0 reaches end of standard support April 30, 2026
- AWS will charge ~$150/month for extended support (50% of RDS instance cost)
- Upgrade required to avoid additional operational costs
- Proactive upgrade gives us time to identify and fix issues

**Technical Debt**
- Current database relies on `ALLOW_INVALID_DATES` SQL mode
- Significant number of date columns have invalid default values ('0000-00-00')
- MySQL 8.4 enforces stricter date validation
- Must audit and fix all date-related code before upgrade

**Security & Performance**
- MySQL 8.4 includes security improvements and bug fixes
- Better performance for certain query patterns
- Improved JSON handling
- Modern authentication methods

### Current State

**Environment:**
- MySQL 8.0.37 (development) / 8.0.39 (production)
- Running on AWS RDS
- Using `sql_mode=ALLOW_INVALID_DATES` to permit zero dates
- 240+ tables in schema

**Known Issues:**

1. **Invalid Date Defaults**
   - Multiple date/datetime columns default to '0000-00-00' or '0000-00-00 00:00:00'
   - MySQL 8.4 rejects these invalid dates by default
   - Will cause schema migrations and inserts to fail

2. **Date Column Usage**
   - Code may explicitly insert zero dates for "null" semantics
   - Some queries may filter on zero dates
   - Application logic may depend on zero date behavior
   - Potential display code that formats zero dates specially

3. **Authentication Changes**
   - MySQL 8.0 introduced caching_sha2_password as default
   - Older client libraries may have compatibility issues
   - May need to verify DBD::mysql version compatibility

### Implementation Plan

**Phase 1: Date Column Audit (Week 1)**

Identify all date columns with invalid defaults:

```sql
-- List all date/datetime/timestamp columns with defaults
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_TYPE,
    COLUMN_DEFAULT,
    IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
AND DATA_TYPE IN ('date', 'datetime', 'timestamp')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Check for zero date values in use
SELECT
    TABLE_NAME,
    COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
AND DATA_TYPE IN ('date', 'datetime', 'timestamp')
AND COLUMN_DEFAULT IN ('0000-00-00', '0000-00-00 00:00:00');
```

**Phase 2: Schema Migration (Week 2-3)**

Update all date columns to use NULL instead of zero dates:

```sql
-- Example migration for a table
ALTER TABLE mytable
MODIFY mydate DATE NULL DEFAULT NULL;

-- Update existing zero dates to NULL
UPDATE mytable
SET mydate = NULL
WHERE mydate = '0000-00-00';
```

Document all schema changes and create migration scripts.

**Phase 3: Code Audit (Week 3-4)**

Search codebase for date-related patterns:

```bash
# Find INSERT/UPDATE statements with date columns
grep -r "INSERT INTO\|UPDATE.*SET" ecore/ www/ | grep -i "date\|time"

# Find comparisons to zero dates
grep -r "'0000-00-00'" ecore/ www/
grep -r '"0000-00-00"' ecore/ www/

# Find date column references in queries
grep -r "DATE\|datetime\|timestamp" ecore/ www/ | grep -v "^Binary"

# Check for ALLOW_INVALID_DATES in code
grep -r "ALLOW_INVALID_DATES" ecore/ www/
```

Update all code to:
- Use NULL instead of '0000-00-00'
- Check for NULL instead of zero dates
- Handle NULL dates in display logic

**Phase 4: Authentication Verification (Week 4)**

```perl
# Verify DBD::mysql version supports caching_sha2_password
# Check cpanfile for DBD::mysql version
# Test connection with MySQL 8.4 test instance
# Update authentication if needed
```

**Phase 5: Testing and Migration (Week 5-6)**

1. 📋 Set up MySQL 8.4 test instance
2. 📋 Run schema migrations on test database
3. 📋 Deploy code changes to test environment
4. 📋 Run full test suite against MySQL 8.4
5. 📋 Perform manual QA of date-related features
6. 📋 Test backup/restore procedures
7. 📋 Create rollback plan
8. 📋 Schedule production migration window
9. 📋 Perform production upgrade with monitoring

**Phase 6: Production Migration**

1. 📋 Create RDS snapshot before upgrade
2. 📋 Enable enhanced monitoring
3. 📋 Upgrade RDS instance to MySQL 8.4
4. 📋 Monitor error logs for issues
5. 📋 Verify application functionality
6. 📋 Monitor performance metrics
7. 📋 Document any post-upgrade issues
8. 📋 Update infrastructure documentation

### SQL Mode Changes

**Current sql_mode:**
```
ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,
NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

**Note:** `ALLOW_INVALID_DATES` is explicitly enabled in current config

**Target sql_mode (MySQL 8.4):**
```
ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,
NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

**Key difference:** Remove `ALLOW_INVALID_DATES` reliance

### Risk Assessment

**High Risk:**
- Schema migrations could fail if zero dates are in use
- Application code may break if it inserts zero dates
- Display logic may not handle NULL dates properly
- Queries filtering on zero dates will need updates

**Medium Risk:**
- Authentication compatibility with client libraries
- Performance differences in query execution
- Backup/restore procedures may need updates

**Low Risk:**
- RDS upgrade process itself (well-documented by AWS)
- Rollback capability (RDS snapshot)

**Mitigation:**
- Comprehensive audit before migration
- Test environment validation
- Staged rollout approach
- RDS snapshot for quick rollback
- Detailed monitoring during migration

### Success Metrics

**Pre-Migration:**
- ✅ 100% of date columns audited
- ✅ All zero date defaults converted to NULL
- ✅ All zero date inserts updated to NULL
- ✅ All zero date comparisons updated
- ✅ Full test suite passes on MySQL 8.4

**Post-Migration:**
- ✅ Zero application errors related to dates
- ✅ No performance degradation
- ✅ All automated tests passing
- ✅ No increase in error logs
- ✅ Avoiding $150/month extended support costs

### Timeline

**Target Completion:** Q2 2025 (before April 2026 deadline)

**Q1 2025 (January-March):**
- ⏸️ Phase 1: Date column audit (Week 1)
- ⏸️ Phase 2: Schema migrations (Week 2-3)
- ⏸️ Phase 3: Code audit and updates (Week 3-4)
- ⏸️ Phase 4: Authentication verification (Week 4)

**Q2 2025 (April-June):**
- ⏸️ Phase 5: Testing on MySQL 8.4 instance (Week 5-6)
- ⏸️ Phase 6: Production migration (Week 7)
- ⏸️ Post-migration monitoring and optimization (Week 8+)

**Total Estimated Effort:** 4-6 weeks

**Buffer:** 10 months before AWS extended support charges begin

### Dependencies

**Blocks:** Avoiding extended support costs

**Requires:**
- Database schema audit
- Code audit for date handling
- Test environment with MySQL 8.4
- DBD::mysql compatibility verification

**Related Work:**
- Priority 6: Testing Infrastructure (need tests for validation)
- Priority 3: Database Security (opportunity to review all SQL)

### Communication Plan

**Internal Team:**
- Audit results and migration plan
- Timeline and resource allocation
- Testing requirements
- Production migration schedule

**Operations:**
- RDS upgrade process
- Monitoring requirements
- Rollback procedures
- Post-migration validation

**Documentation:**
- Schema changes
- Code changes
- Migration runbook
- Troubleshooting guide

### Resources

**AWS Documentation:**
- [MySQL on RDS Upgrade Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.MySQL.html)
- [MySQL 8.0 to 8.4 Upgrade Guide](https://dev.mysql.com/doc/refman/8.4/en/upgrading.html)

**Key Considerations:**
- Plan migration during low-traffic window
- Have rollback plan ready (RDS snapshot)
- Monitor application logs closely post-upgrade
- Extended support charges begin April 30, 2026

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
- OAuth infrastructure and Google Sign-In

### Q2 2025
- Mobile responsiveness Phase 1
- React component testing
- Begin PSGI preparation
- Superdoc migration strategy
- Facebook and Apple Sign-In implementation
- CSS asset pipeline infrastructure (low priority)

### Q3 2025
- PSGI migration Phase 1-2
- Redis cache implementation
- React modernization
- 50%+ test coverage
- OAuth production deployment
- CSS extraction from delegation functions (low priority)

### Q4 2025
- PSGI production deployment
- Complete database code removal
- 70%+ test coverage
- Full mobile support
- OAuth adoption monitoring
- CSS asset pipeline completion (low priority)

## Communication Strategy

### For Users
- Focus on benefits: mobile support, better performance, security
- Transparent about changes and testing
- Gradual rollout to minimize disruption

### For Staff
- Technical documentation in `docs/` directory
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
**Last Updated:** 2025-11-22
**Next Review:** 2025-12-22
