# PSGI/Plack Migration Plan - Move from mod_perl to FastCGI

**Status**: Planning - Ready for Review
**Last Updated**: 2025-11-26
**Author**: Claude Code (based on E2 architecture analysis)
**Goal**: Migrate from mod_perl to PSGI/Plack with Apache → FastCGI architecture

---

## Executive Summary

This document outlines the strategy for migrating Everything2 from mod_perl to PSGI/Plack, using Apache as an HTTP frontend serving FastCGI to the backend. This migration enables:

- **Modern Perl deployment** - PSGI standard used by all modern Perl frameworks
- **Better scalability** - FastCGI process management independent of Apache
- **Easier testing** - PSGI apps can run standalone without Apache
- **API-first architecture** - Clean separation between HTTP layer and application logic
- **Container-ready** - Simpler Docker deployment without mod_perl complexity

**Architecture Change**:
```
BEFORE: Browser → Apache (mod_perl) → Everything::HTML → Perl Application
AFTER:  Browser → Apache (mod_proxy_fcgi) → FastCGI → Plack → PSGI App → Everything::HTML
```

---

## Current Architecture Analysis

### mod_perl Integration Points

**1. Apache Configuration** ([docker/apache/everything2.conf](docker/apache/everything2.conf))
```apache
PerlModule Everything::HTML
PerlTransHandler Everything::HTML
```

**2. Request Handler** ([ecore/Everything/HTML.pm](ecore/Everything/HTML.pm))
- `sub handler` - mod_perl entry point
- Direct access to `Apache2::RequestRec` object
- Uses `Apache2::Const` for HTTP status codes
- Calls `displayPage()` to generate content

**3. Dependencies on mod_perl**
```perl
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::Const -compile => qw(OK DECLINED HTTP_NOT_FOUND);
use Apache2::Cookie;
```

**4. Request Flow**
```
Apache receives HTTP request
  ↓
mod_perl calls Everything::HTML->handler($r)
  ↓
Extract path, params, cookies from Apache2::RequestRec
  ↓
Build Everything::Request object
  ↓
Route to Controller (superdoc, htmlpage, etc.)
  ↓
Generate Mason2/React content
  ↓
Return Apache2::Const::OK
```

---

## Target Architecture

### PSGI/Plack Stack

```
┌─────────────────────────────────────────────────────┐
│ Apache (mod_proxy_fcgi)                             │
│ - Static assets: /react/*.js, /css/*.css, /images/ │
│ - Proxy to FastCGI: everything else                 │
└─────────────────────────────────────────────────────┘
                       ↓ (FastCGI protocol)
┌─────────────────────────────────────────────────────┐
│ Plack Server (Starman/Gazelle)                      │
│ - Process pool (20-50 workers)                      │
│ - Graceful restarts                                 │
│ - Hot code reload (dev mode)                        │
└─────────────────────────────────────────────────────┘
                       ↓ (PSGI env)
┌─────────────────────────────────────────────────────┐
│ PSGI Application (app.psgi)                         │
│ - Middleware stack                                  │
│   • Plack::Middleware::Session                      │
│   • Plack::Middleware::Static (fallback)            │
│   • Plack::Middleware::ReverseProxy                 │
│   • Plack::Middleware::AccessLog                    │
│ - Routes to Everything::HTML                        │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Everything::HTML (PSGI-compatible)                  │
│ - Receives PSGI env hash                            │
│ - Builds Everything::Request from env               │
│ - Returns PSGI response [status, headers, body]     │
└─────────────────────────────────────────────────────┘
```

---

## Migration Phases

### Phase 1: Create PSGI Adapter (2-3 days)

**Goal**: Make Everything::HTML work with both mod_perl AND PSGI

**Tasks**:

1. **Create app.psgi** - PSGI application file
   ```perl
   #!/usr/bin/env perl
   use strict;
   use warnings;
   use FindBin;
   use lib "$FindBin::Bin/ecore";

   use Everything::HTML;
   use Plack::Builder;

   my $app = sub {
       my $env = shift;
       return Everything::HTML->psgi_handler($env);
   };

   builder {
       enable 'ReverseProxy';
       enable 'AccessLog', format => 'combined';
       enable 'Static',
           path => qr{^/(react|css|images)/},
           root => './www';
       $app;
   };
   ```

2. **Add PSGI handler to Everything::HTML**
   ```perl
   sub psgi_handler {
       my ($class, $env) = @_;

       # Convert PSGI env to Everything::Request
       my $request = $class->build_request_from_psgi($env);

       # Generate page (existing logic)
       my ($status, $headers, $body) = $class->displayPage($request);

       # Return PSGI response
       return [$status, $headers, [$body]];
   }

   sub build_request_from_psgi {
       my ($class, $env) = @_;

       # Extract request info from PSGI env
       my $uri = $env->{REQUEST_URI};
       my $method = $env->{REQUEST_METHOD};
       my $params = $class->parse_query_string($env->{QUERY_STRING});
       my $cookies = $class->parse_cookies($env->{HTTP_COOKIE});

       # Build Everything::Request object
       return Everything::Request->new(
           uri => $uri,
           method => $method,
           params => $params,
           cookies => $cookies,
           env => $env
       );
   }
   ```

3. **Update Everything::HTML to be dual-mode**
   - Keep existing `handler()` for mod_perl
   - Add new `psgi_handler()` for PSGI
   - Share common logic in `displayPage()`

4. **Cookie handling migration**
   - Replace `Apache2::Cookie` with `Plack::Request->cookies`
   - Or use `CGI::Simple::Cookie` for compatibility

5. **Session handling**
   - Current: Custom session in database
   - Future: Keep database sessions, use `Plack::Middleware::Session`
   - Store session ID in cookie

**Deliverables**:
- ✅ `app.psgi` file
- ✅ `Everything::HTML->psgi_handler()`
- ✅ Tests for PSGI handler
- ✅ Documentation

**Success Criteria**:
- Can run `plackup app.psgi` in development
- Basic page rendering works via PSGI
- Sessions/cookies work
- Static assets served correctly

---

### Phase 2: Apache FastCGI Configuration (1-2 days)

**Goal**: Configure Apache to proxy to PSGI backend via FastCGI

**Tasks**:

1. **Update Apache configuration**
   ```apache
   # Disable mod_perl
   # PerlModule Everything::HTML
   # PerlTransHandler Everything::HTML

   # Enable FastCGI proxy
   LoadModule proxy_module modules/mod_proxy.so
   LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so

   # Serve static assets directly
   <LocationMatch "^/(react|css|images|favicon.ico)">
       # Apache serves these directly (fast!)
   </LocationMatch>

   # Proxy everything else to FastCGI backend
   <LocationMatch "^/(?!(react|css|images|favicon.ico))">
       ProxyPass unix:/var/run/e2-fcgi.sock|fcgi://localhost/
       ProxyPassReverse unix:/var/run/e2-fcgi.sock|fcgi://localhost/
   </LocationMatch>

   # Or use TCP socket
   ProxyPass / fcgi://127.0.0.1:9000/
   ProxyPassReverse / fcgi://127.0.0.1:9000/
   ```

2. **Choose Plack server** (Recommendation: **Starman**)

   **Option A: Starman** (Recommended)
   - Mature, battle-tested
   - Preforking server (like Apache)
   - Graceful restarts
   - Good performance
   ```bash
   starman --listen /var/run/e2-fcgi.sock --workers 20 app.psgi
   # or TCP: starman --listen :9000 --workers 20 app.psgi
   ```

   **Option B: Gazelle**
   - Faster (uses XS)
   - Fewer features
   - Good for high-traffic
   ```bash
   plackup -s Gazelle --listen /var/run/e2-fcgi.sock app.psgi
   ```

   **Option C: uWSGI**
   - Not pure Perl (Python/C core)
   - Complex configuration
   - Overkill for E2

   **Recommendation**: Start with **Starman** - proven, stable, easy to debug

3. **Create systemd service** (`/etc/systemd/system/everything2-psgi.service`)
   ```ini
   [Unit]
   Description=Everything2 PSGI Application
   After=network.target mysql.service

   [Service]
   Type=simple
   User=www-data
   Group=www-data
   WorkingDirectory=/var/everything
   Environment="PERL5LIB=/var/everything/ecore:/var/libraries/lib/perl5"
   ExecStart=/usr/local/bin/starman \
       --listen /var/run/e2-fcgi.sock \
       --workers 20 \
       --max-requests 1000 \
       --access-log /var/log/everything2/access.log \
       --error-log /var/log/everything2/error.log \
       /var/everything/app.psgi
   ExecReload=/bin/kill -HUP $MAINPID
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

4. **Docker integration**
   - Update `docker/devbuild.sh` to start Starman
   - Separate Apache container from app container (optional)
   - Use docker-compose multi-container setup

**Deliverables**:
- ✅ Apache configuration for FastCGI proxy
- ✅ Systemd service file
- ✅ Docker configuration updates
- ✅ Startup/shutdown scripts

**Success Criteria**:
- Apache proxies to Starman successfully
- Static assets served by Apache (fast)
- Dynamic content served by Starman (PSGI)
- Graceful restart works (`systemctl reload everything2-psgi`)

---

### Phase 3: Testing & Validation (3-5 days)

**Goal**: Ensure feature parity between mod_perl and PSGI

**Testing Strategy**:

1. **Automated Testing**
   - ✅ All Perl tests pass: `prove t/*.t`
   - ✅ All React tests pass: `npm test`
   - ✅ Smoke tests pass: `./tools/smoke-test.rb`
   - ✅ E2E tests pass (if available)

2. **Manual Testing Checklist**
   - [ ] Login/logout
   - [ ] Cookie persistence
   - [ ] Session management
   - [ ] User voting
   - [ ] Chatterbox (AJAX polling)
   - [ ] Message sending
   - [ ] Node editing
   - [ ] Admin tools
   - [ ] File uploads (if any)
   - [ ] Search functionality
   - [ ] Cached pages (DataStash)

3. **Performance Testing**
   - Benchmark mod_perl vs PSGI response times
   - Load testing with `ab` or `wrk`
   - Monitor memory usage (PSGI should use less)
   - Check CPU utilization

4. **Error Handling**
   - 404 pages work correctly
   - 500 errors logged properly
   - Stack traces captured
   - No information leakage

**Deliverables**:
- ✅ Test results document
- ✅ Performance comparison report
- ✅ Bug fixes for any issues found

**Success Criteria**:
- Zero regressions in functionality
- Performance equal or better than mod_perl
- All error cases handled correctly

---

### Phase 4: Production Deployment (1-2 days)

**Goal**: Deploy PSGI to production with zero downtime

**Deployment Strategy**:

1. **Blue-Green Deployment**
   ```
   BEFORE:
   Load Balancer → [Apache (mod_perl) x2]

   TRANSITION:
   Load Balancer → [Apache (mod_perl) x1] + [Apache+Starman x1]

   AFTER:
   Load Balancer → [Apache+Starman x2]
   ```

2. **Rollback Plan**
   - Keep mod_perl configuration available
   - Symlink switch for Apache config
   - Database sessions work with both
   - Can roll back in < 5 minutes

3. **Monitoring**
   - Set up alerts for error rates
   - Monitor response times
   - Watch memory/CPU usage
   - Track FastCGI socket errors

4. **Gradual Rollout**
   - Week 1: 10% traffic to PSGI
   - Week 2: 50% traffic to PSGI
   - Week 3: 100% traffic to PSGI
   - Week 4: Remove mod_perl

**Deliverables**:
- ✅ Deployment runbook
- ✅ Rollback procedure
- ✅ Monitoring dashboards
- ✅ Post-deployment report

**Success Criteria**:
- Zero downtime during deployment
- No increase in error rate
- Performance maintained or improved
- Successful rollback test

---

## Benefits of PSGI/Plack

### For Development

1. **Faster iteration** - No Apache restart needed
   ```bash
   plackup -r app.psgi  # Auto-reloads on file changes
   ```

2. **Easier debugging** - Run app directly
   ```bash
   plackup app.psgi
   perl -d:NYTProf app.psgi  # Profile easily
   ```

3. **Standalone testing** - No Apache required
   ```perl
   use Plack::Test;
   use HTTP::Request::Common;

   test_psgi $app, sub {
       my $cb = shift;
       my $res = $cb->(GET '/');
       is $res->code, 200;
   };
   ```

4. **Middleware ecosystem** - 200+ CPAN modules
   - Authentication: `Plack::Middleware::Auth::*`
   - Caching: `Plack::Middleware::Cache`
   - Compression: `Plack::Middleware::Deflater`
   - CORS: `Plack::Middleware::CrossOrigin`

### For Operations

1. **Better resource management**
   - Workers independent of Apache
   - Can restart app without Apache
   - Memory leaks isolated to workers

2. **Easier scaling**
   - Add workers without changing Apache
   - Can run multiple PSGI servers
   - Load balance across servers

3. **Simpler deployment**
   - No mod_perl compilation
   - No Apache module dependencies
   - Faster Docker builds

4. **Modern monitoring**
   - Standard PSGI middleware for metrics
   - Easy integration with Prometheus/Grafana
   - Better error tracking (Sentry, etc.)

### For API Development

1. **Clean separation** - HTTP layer vs application logic
2. **Easy API routes** - Use `Plack::App::URLMap`
3. **Versioned APIs** - Mount different apps at `/api/v1`, `/api/v2`
4. **Middleware for APIs** - Rate limiting, auth, CORS

---

## Implementation Details

### Cookie Migration

**Current (mod_perl)**:
```perl
use Apache2::Cookie;

my $cookies = Apache2::Cookie->fetch($r);
my $userpass = $cookies->{userpass}->value if $cookies->{userpass};
```

**Future (PSGI)**:
```perl
use Plack::Request;

my $req = Plack::Request->new($env);
my $userpass = $req->cookies->{userpass};
```

**Or use CGI::Simple::Cookie** (no dependencies):
```perl
use CGI::Simple::Cookie;

my %cookies = CGI::Simple::Cookie->parse($env->{HTTP_COOKIE});
my $userpass = $cookies{userpass}->value if $cookies{userpass};
```

### Session Handling

**Current**: Database-backed sessions (custom implementation)

**Future**: Same database sessions, accessed via PSGI env
```perl
use Plack::Middleware::Session;
use Plack::Session::Store::DBI;

builder {
    enable 'Session',
        store => Plack::Session::Store::DBI->new(
            dbh => $dbh,
            table => 'session'
        );
    $app;
};
```

**Or keep existing session code** - just adapt to PSGI env

### Request Object Migration

**Create Everything::Request::PSGI**:
```perl
package Everything::Request::PSGI;
use Moose;

has 'env' => (is => 'ro', required => 1);
has 'plack_request' => (is => 'ro', lazy => 1, builder => '_build_plack_request');

sub _build_plack_request {
    my $self = shift;
    return Plack::Request->new($self->env);
}

sub param {
    my ($self, $name) = @_;
    return $self->plack_request->param($name);
}

sub cookies {
    my $self = shift;
    return $self->plack_request->cookies;
}

sub method {
    my $self = shift;
    return $self->env->{REQUEST_METHOD};
}

sub uri {
    my $self = shift;
    return $self->env->{REQUEST_URI};
}

sub user_agent {
    my $self = shift;
    return $self->env->{HTTP_USER_AGENT};
}
```

---

## Testing Strategy

### Unit Tests

**Test PSGI handler directly**:
```perl
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Everything::HTML;

my $app = Everything::HTML->to_app;  # Convert to PSGI app

test_psgi $app, sub {
    my $cb = shift;

    # Test homepage
    my $res = $cb->(GET '/');
    is $res->code, 200, 'Homepage returns 200';
    like $res->content, qr/Everything2/, 'Contains site name';

    # Test login
    my $login_res = $cb->(POST '/login', [
        user => 'testuser',
        passwd => 'testpass'
    ]);
    is $login_res->code, 302, 'Login redirects';

    # Test API endpoint
    my $api_res = $cb->(GET '/api/messages/');
    is $api_res->code, 200, 'API returns 200';
    is $api_res->header('Content-Type'), 'application/json';
};
```

### Integration Tests

**Test with real Starman server**:
```perl
use Test::TCP;
use LWP::UserAgent;

test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://localhost:$port/");
        is $res->code, 200;
    },
    server => sub {
        my $port = shift;
        exec 'starman', '--port', $port, 'app.psgi';
    }
);
```

### Load Testing

**Apache Bench**:
```bash
ab -n 1000 -c 10 http://localhost:9080/
```

**wrk (better)**:
```bash
wrk -t4 -c100 -d30s http://localhost:9080/
```

**Compare mod_perl vs PSGI** - expect similar or better performance

---

## Risks & Mitigation

### Risk 1: Breaking Changes

**Risk**: PSGI env different from Apache2::RequestRec
**Impact**: High - could break core functionality
**Mitigation**:
- Comprehensive testing before deploy
- Keep mod_perl code path during transition
- Gradual rollout with traffic splitting

### Risk 2: Performance Regression

**Risk**: PSGI slower than mod_perl
**Impact**: Medium - user experience degrades
**Mitigation**:
- Benchmark early and often
- Profile with NYTProf
- Optimize hot paths
- Use faster PSGI server (Gazelle) if needed

### Risk 3: Session Compatibility

**Risk**: Session handling breaks
**Impact**: High - users logged out
**Mitigation**:
- Keep same session storage (database)
- Test session persistence thoroughly
- Monitor session errors in production

### Risk 4: Memory Leaks

**Risk**: Workers grow over time
**Impact**: Medium - requires worker restarts
**Mitigation**:
- Set `--max-requests` to recycle workers
- Monitor worker memory usage
- Use Devel::Cycle to find leaks

### Risk 5: Deployment Complexity

**Risk**: New deployment process unfamiliar
**Impact**: Low - can be learned
**Mitigation**:
- Document thoroughly
- Practice in staging
- Have rollback plan ready

---

## Timeline Estimate

| Phase | Duration | Effort | Dependencies |
|-------|----------|--------|--------------|
| Phase 1: PSGI Adapter | 2-3 days | 16-24 hours | None |
| Phase 2: Apache Config | 1-2 days | 8-16 hours | Phase 1 complete |
| Phase 3: Testing | 3-5 days | 24-40 hours | Phase 2 complete |
| Phase 4: Deployment | 1-2 days | 8-16 hours | Phase 3 complete |
| **Total** | **7-12 days** | **56-96 hours** | Sequential |

**Recommended Approach**: 2-week sprint with 1 developer full-time

---

## Dependencies

### Perl Modules (add to cpanfile)

```perl
# PSGI/Plack core
requires 'Plack', '>= 1.0049';
requires 'PSGI', '>= 1.102';

# PSGI server
requires 'Starman', '>= 0.4016';  # Recommended
# OR
requires 'Gazelle', '>= 0.48';    # Alternative (faster)

# Middleware
requires 'Plack::Middleware::ReverseProxy';
requires 'Plack::Middleware::Static';
requires 'Plack::Middleware::AccessLog';
requires 'Plack::Middleware::Session';

# Testing
requires 'Plack::Test', '0';
requires 'Test::TCP', '0';

# Optional but useful
requires 'Plack::Middleware::Debug', '0';  # Dev toolbar
requires 'Starman::Server', '0';  # For systemd integration
```

### System Dependencies

```bash
# Already have these (no new dependencies!)
- Perl 5.x
- Apache 2.4+
- mod_proxy
- mod_proxy_fcgi
```

---

## Success Metrics

### Performance

- Response time ≤ mod_perl baseline
- Memory usage ≤ mod_perl baseline
- Throughput ≥ mod_perl baseline

### Reliability

- Error rate < 0.1%
- Uptime > 99.9%
- Zero data loss
- Zero session loss

### Developer Experience

- Hot reload works in development
- Tests run 2x faster (no Apache needed)
- Deployment time reduced by 50%

---

## Future Opportunities (Post-Migration)

### 1. API Versioning

```perl
use Plack::App::URLMap;

my $map = Plack::App::URLMap->new;
$map->map('/api/v1' => $api_v1_app);
$map->map('/api/v2' => $api_v2_app);
$map->map('/' => $main_app);
$map->to_app;
```

### 2. Microservices

- Extract APIs into separate PSGI apps
- Run on different servers/ports
- Scale independently

### 3. GraphQL

```perl
use Plack::App::GraphQL;

builder {
    mount '/graphql' => Plack::App::GraphQL->new(
        schema => $schema
    )->to_app;
    mount '/' => $main_app;
};
```

### 4. WebSocket Support

```perl
use Plack::App::WebSocket;

# Real-time chatterbox updates via WebSocket
```

### 5. Better Caching

```perl
enable 'Plack::Middleware::Cache',
    store => Cache::Memcached::Fast->new(...);
```

---

## Conclusion

Migrating from mod_perl to PSGI/Plack is a **low-risk, high-reward** modernization that:

✅ Enables API-first architecture
✅ Simplifies development workflow
✅ Improves deployment flexibility
✅ Reduces operational complexity
✅ Opens path to modern Perl ecosystem

**Recommendation**: Proceed with migration. Start with Phase 1 (PSGI adapter) to validate approach with minimal risk.

---

## References

- [PSGI Specification](https://metacpan.org/pod/PSGI)
- [Plack Documentation](https://metacpan.org/pod/Plack)
- [Starman Server](https://metacpan.org/pod/Starman)
- [Plack::Middleware](https://metacpan.org/pod/Plack::Middleware)
- [Migrating from mod_perl to PSGI](https://perl.apache.org/docs/2.0/user/porting/compat.html)

---

**Next Steps**:
1. Review this plan with team
2. Set up development environment for testing
3. Create Phase 1 PSGI adapter
4. Validate with smoke tests
5. Proceed to Phase 2 if successful
