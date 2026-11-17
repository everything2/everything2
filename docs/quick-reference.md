# Everything2 Quick Reference

**Last verified:** 2026-11-16

## 🚀 Quick Start

```bash
# Local development
./docker/devbuild.sh                    # Build containers + run tests
./docker/devbuild.sh --skip-tests       # Apply local changes fast (files are not volume-mounted)
# Visit http://localhost:9080
docker exec e2devapp tail -f /tmp/development.log   # App log (Apache error.log stays empty)

# Deploy to production (no push-triggered deploy)
./ops/run-codebuild.rb                  # CodeBuild E2-Application-Builder-ARM, then ECS force-new-deployment

# Testing
./docker/run-tests.sh                   # Run all tests (Perl + React)
./docker/run-tests.sh 012               # Run specific Perl test
npm test                                # React (Jest) only
./tools/coverage.sh                     # Run tests with coverage

# Container shell access
./tools/shell.sh                        # Get bash shell in container

# Code quality
./tools/critic.pl ecore/File.pm         # Check single file (bugs theme)
CRITIC_FULL=1 ./tools/critic.pl .       # Full check (core theme)

# Dependency management
# Perl: edit cpanfile; tarballs are vendored in vendor/cache/ (image installs via cpanm --from)
npm install                             # Install JS deps (Node version: .nvmrc)
npx webpack --config etc/webpack.config.js   # Build React (devbuild does this for you)
```

## 📊 Modernization Status

See [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) and run `git log` for the current modernization plan and status.

## 🏗️ Architecture

```
Frontend:  React 18.3 (webpack; prod assets served from S3)
Backend:   Perl on Starman/PSGI (Apache mpm_event reverse proxy; mod_perl removed)
Database:  MySQL 8.4 (RDS)
Deploy:    ops/run-codebuild.rb → CodeBuild (docker/buildspec.yml, --target final) → ECR → Fargate ECS (ARM64)
Cron:      leader-elected sidecar in the webheads; sitemap is a nightly EventBridge Fargate task
```

## 📁 Key Directories

```
ecore/                          # Perl backend code
├── Everything/
│   ├── API/                   # REST API endpoints
│   ├── Application.pm         # Core application logic
│   ├── Controller.pm          # Base controller
│   ├── Cron/                  # Cron sidecar (Runner, Schedule, State, Health)
│   ├── Delegation/            # Legacy code being retired (htmlcode, etc.)
│   ├── Node/                  # Node type classes (Moose)
│   ├── NodeBase.pm            # Database/node storage layer
│   └── Page/                  # Page controllers
react/                          # React frontend
├── components/
│   ├── Documents/             # Page-level components
│   ├── Nodelets/              # Sidebar nodelet components
│   └── ...                    # Various feature components
www/                           # Web-accessible files
├── css/                       # Stylesheets
└── react/                     # Compiled React bundles
t/                             # Perl test suite (NNN_name.t, ~220 files; runner t/run.pl)
docs/                          # Documentation (index: docs/README.md)
cf/                            # CloudFormation template (everything2-production.json)
cron/                          # Cron job scripts + cron_runner.pl
docker/                        # Dockerfile, buildspec.yml, devbuild.sh
ops/                           # Deploy/ops scripts (run-codebuild.rb, cf.rb, ...)
tools/                         # Development and diagnostic utilities
nodepack/                      # Development seed data (XML)
```

## 🔧 Common Development Patterns

**Note:** The "Add Component" sections below represent rapidly evolving patterns. For the most current architectural patterns, see [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md).

### Add New Moose Class

```perl
package Everything::Node::mytype;
use Moose;
extends 'Everything::Node';

has 'my_field' => (is => 'ro', isa => 'Str');

sub my_method {
    my ($self) = @_;
    return $self->NODEDATA->{title};
}

__PACKAGE__->meta->make_immutable;
1;
```

### Add REST API Endpoint

```perl
# ecore/Everything/API/myresource.pm  ->  /api/myresource/...
package Everything::API::myresource;
use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes { return { "/" => "get" } }

sub get {
    my ($self, $REQUEST) = @_;
    # Always HTTP 200; report errors in the body (mod_perl-era rule, still the convention)
    return [$self->HTTP_OK, {success => 1, data => {}}];
}

__PACKAGE__->meta->make_immutable;
1;
```

### Add React Component

```javascript
// react/components/MyComponent.js
import React, { useState } from 'react';

const MyComponent = ({ prop1, prop2 }) => {
  const [state, setState] = useState(initialValue);

  return (
    <div className="my-component">
      {/* Component JSX */}
    </div>
  );
};

export default MyComponent;
```

### Write Tests

```perl
# t/NNN_my_test.t
use Test::More tests => 3;
use Everything::Application;

my $app = Everything::Application->new($DB, $CONF);
ok($app, "Application created");

my $result = $app->my_method();
is($result, 'expected', "Method returns expected value");
```

```javascript
// react/components/__tests__/MyComponent.test.js
import { render, screen } from '@testing-library/react';
import MyComponent from '../MyComponent';

test('renders component', () => {
  render(<MyComponent />);
  expect(screen.getByText('Hello')).toBeInTheDocument();
});
```

## 🐛 Known Issues

See [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) and run `git log` for current open issues and status. (The earlier list here — SQL injection, no CI/CD, zero React coverage, Apache thread-safety — is stale/resolved as of 2026-06.)

## 📞 Emergency Procedures

### Site Down
1. Check CloudWatch logs in AWS Console
2. Check ECS service status
3. Check RDS database status
4. Rollback: a deploy whose tasks never get healthy is rolled back automatically (circuit breaker, emails e2-alerts). Otherwise point `:latest` back at the previous good image digest and force a new deployment; see "Rollback Strategy" in [infrastructure-overview.md](infrastructure-overview.md)

### Database Issues
1. Check RDS status in AWS Console
2. Review slow query log (`/aws/rds/instance/everything2vpc/slowquery`)
3. Check connection count (alarm `e2-rds-high-connections`)
4. Point-in-time recovery if needed

### Deployment Failed
1. Check CodeBuild logs (`/aws/codebuild/dockerbuild`, stream = build id)
2. Review `docker/buildspec.yml` / `docker/e2app/Dockerfile` for errors
3. Check ECR (`everything2/e2app-arm`) for image push success
4. Re-run `./ops/run-codebuild.rb`. A failed build leaves prod on the last good image.

## 🔐 Security Checklist

- [ ] Never commit secrets to repository
- [ ] Use prepared statements for SQL queries
- [ ] Validate all user input
- [ ] Quote all variables in SQL (use `$this->quote()`)
- [ ] No `eval()` of user-supplied data
- [ ] Check permissions before sensitive operations
- [ ] Use HTTPS for all connections
- [ ] Set secure cookie flags

## 📈 Performance Tips

### Backend
- Use NodeCache for frequently accessed nodes
- Batch database queries where possible
- Profile with Devel::NYTProf: `NYTPROF=start=no perl -d:NYTProf script.pl`
- Check slow query log

### Frontend
- Minimize bundle size (check with webpack-bundle-analyzer)
- Use React.memo for expensive components
- Lazy load routes and large components
- Optimize images (compression, WebP)
- Static assets are served from S3 (no CDN; CloudFront was evaluated and rejected)

### Database
- Add indexes for frequently queried fields
- Avoid N+1 queries (use JOINs or batch fetches)
- Use EXPLAIN to analyze query plans
- Monitor cache hit rate

## 🧪 Testing Strategy

### Perl Tests
```bash
./docker/run-tests.sh               # Run all tests in container
./docker/run-tests.sh 012           # Run specific test by number
./docker/run-tests.sh sql           # Run tests matching pattern
```

### Code Quality
```bash
# Perl::Critic - Check for bugs and code quality issues
./tools/critic.pl ecore/Everything/Application.pm  # Single file (bugs theme, severity 1)
CRITIC_FULL=1 ./tools/critic.pl ecore/Path.pm      # Single file (core theme, all policies)

# Default mode (bugs theme):
#   - Severity 1 (brutal) violations only
#   - Theme: "bugs" (logic errors, unsafe patterns)
#   - Mimics application health test in t/000_application_health.t
#
# CRITIC_FULL mode (core theme):
#   - Severity 1 violations only
#   - Theme: "core" (all Perl::Critic policies)
#   - More comprehensive style and best practice checks
```

### Code Coverage

```bash
./tools/coverage.sh                      # Run tests with coverage
./tools/coverage.sh report               # Generate report only
./tools/coverage.sh clean                # Clean coverage data
./tools/generate-coverage-badges.sh      # Update coverage badges

# Inside container (manual)
perl -MDevel::Cover=-db,coverage/cover_db t/run.pl
cover -report html -outputdir coverage/html
```

Current numbers: see `coverage/COVERAGE-SUMMARY.md` (regenerated by `./docker/devbuild.sh --coverage`).

**View Reports:**
- Summary: `coverage/COVERAGE-SUMMARY.md`
- Badges: ![Perl](../coverage/badges/perl-coverage.svg)
- HTML: `coverage/html/coverage.html`
- Text: `cover -report text`

**See:** [Code Coverage Guide](code-coverage.md) and [COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) for details

### React Tests
```bash
npm test                            # Run Jest
npm run test:watch                  # Watch mode
npm run test:coverage               # Coverage report
npm run test:e2e                    # Playwright end-to-end
```

## 🚢 Deployment Checklist

- [ ] Run tests locally
- [ ] Check Perl::Critic
- [ ] Build and test in Docker locally
- [ ] Update documentation if needed
- [ ] Commit with descriptive message
- [ ] Merge to master, then run `./ops/run-codebuild.rb`
- [ ] Monitor CodeBuild progress
- [ ] Check `/aws/events/e2-app-errors` after deployment
- [ ] Verify site functionality
- [ ] Monitor error rates for 15 minutes

## 💡 Best Practices

### Perl
- **Use Moose** for all new code
- **Prepared statements** for SQL (or at minimum `quote()`)
- **Avoid package globals** (use request context)
- **Test everything** (unit tests for business logic)

### React
- **Functional components** with hooks (not classes)
- **Context API** for shared state
- **fetch to `/api/...`**, with shared hooks in `react/hooks/`
- **Dates via `react/utils/dateFormat.js`** (UTC), not `toLocaleDateString`
- **Test with Jest** and React Testing Library

### Git
- **Descriptive commit messages** ("Add user authentication" not "Fix bug")
- **Small, focused commits** (one feature/fix per commit)
- **Test before committing**
- **Reference issues** in commit messages (#123)

## 📚 Learning Resources

### Perl
- [Moose Documentation](https://metacpan.org/pod/Moose)
- [Modern Perl](http://modernperlbooks.com/)
- [Perl::Critic Policy List](https://metacpan.org/pod/Perl::Critic)

### React
- [React Hooks Documentation](https://react.dev/reference/react)
- [React Testing Library](https://testing-library.com/react)

### AWS
- [ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)

## 🔗 Useful Links

- Production: https://everything2.com
- GitHub: https://github.com/everything2/everything2
- Local Dev: http://localhost:9080
- CloudWatch: AWS Console → CloudWatch
- ECS: AWS Console → ECS
- RDS: AWS Console → RDS

## 📊 Metrics to Track

### Performance
- Page load time (target: < 2s)
- API response time (target: < 200ms p95)
- Database query time (target: < 100ms p95)
- Cache hit rate (target: > 80%)

### Quality
- Test coverage (target: > 70%)
- Perl::Critic violations (target: 0 severity 1-3)
- ESLint warnings (target: 0)
- Lighthouse score (target: > 80)

### Reliability
- Error rate (target: < 0.1%)
- Uptime (target: 99.9%)
- Deployment success rate (target: > 95%)

## 🎓 Code Review Checklist

- [ ] Tests included and passing
- [ ] Moose used for new Perl code
- [ ] SQL queries use prepared statements or quote()
- [ ] No secrets in code
- [ ] Error handling present
- [ ] Performance considered
- [ ] Mobile responsive (if UI change)
- [ ] Documentation updated
- [ ] Commit message is clear

## 🐞 Debugging Tips

### Perl
```perl
use Data::Dumper;
warn Dumper($variable);                # Quick debug print

$DB->getDatabaseHandle()->{RaiseError} = 1;  # Enable DB errors
```

### React
```javascript
console.log('Debug:', variable);       // Browser console
debugger;                              // Breakpoint in DevTools
```

### MySQL
```sql
SHOW PROCESSLIST;                      -- Active queries
EXPLAIN SELECT ...;                    -- Query plan
SHOW PROFILE;                          -- Query profiling
```

## 🔍 AWS CloudWatch Log Analysis

**Note:** CloudWatch logs have a **3-day retention period**. These are typically transient errors - if they don't recur regularly within 3 days, they're not worth preserving.

Prod app errors are **not** in `/aws/fargate/fargate-app-awslogs`; they go through EventBridge to `/aws/events/e2-app-errors` and `/aws/events/e2-uninitialized-errors`.

### Pulling Logs for Analysis

```bash
./tools/app-errors.rb --hours 24            # Summary of /aws/events/e2-app-errors
./tools/uninitialized-errors.rb --hours 24  # Summary of /aws/events/e2-uninitialized-errors

# Raw pull
aws logs filter-log-events --region us-west-2 \
  --log-group-name /aws/events/e2-app-errors \
  --start-time $(date -d '3 days ago' +%s)000 \
  --output json > app-errors-3days.json

# Filter by pattern (e.g., specific error type)
aws logs filter-log-events --region us-west-2 \
  --log-group-name /aws/events/e2-app-errors \
  --filter-pattern "SQL" \
  --start-time $(date -d '24 hours ago' +%s)000
```

### Analyzing Error Patterns

```bash
# Count error frequency (most common errors)
jq -r '.events[].message' app-errors-3days.json | sort | uniq -c | sort -rn | head -20

# Extract specific error types
jq -r '.events[] | select(.message | contains("SQL")) | .message' app-errors-3days.json
```

### Creating CloudWatch Insights Queries

```sql
-- Top 10 most common errors
fields @timestamp, @message
| stats count() by @message
| sort count desc
| limit 10

-- Uninitialized errors by file
fields @timestamp, @message
| filter @message like /uninitialized/
| parse @message /at (?<file>[^ ]+) line/
| stats count() by file
| sort count desc
```

**See:** [infrastructure-overview.md](infrastructure-overview.md#monitoring--logging) for the full log group list

## 📞 Contact

- Modernization Documentation: `docs/` directory
- Report Issues: GitHub Issues

---

**Last verified:** 2026-11-16
