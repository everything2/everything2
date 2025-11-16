# Everything2 Modernization Priorities

**Date:** 2025-11-09
**Status:** Planning Phase

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

## Priority 7: Code Coverage Tracking 📊

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

**Solution:** Migrate to PSGI/Plack architecture first (see Priority 8 below)
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

- **Blocks:** Priority 7 (Code Coverage Tracking)
- **Enables:** Better testing, code coverage, deployment flexibility
- **Requires:** Refactoring of request handling in Everything::Application

## Priority 9: Alternative Login Methods 🔐

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

## Priority 10: CSS Asset Pipeline 🎨

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
**Last Updated:** 2025-11-09
**Next Review:** 2025-12-09
