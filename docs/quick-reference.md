# Everything2 Quick Reference

**Date:** 2025-12-17

## 🚀 Quick Start

```bash
# Local development
./docker/devbuild.sh                    # Build containers
# Visit http://localhost:9080

# Deploy to production
git push origin master                  # Automatic deploy
./ops/run-codebuild.rb                 # Manual deploy

# Testing
./docker/run-tests.sh                   # Run all tests
./docker/run-tests.sh 012               # Run specific test
./tools/coverage.sh                     # Run tests with coverage

# Container shell access
./tools/shell.sh                        # Get bash shell in container

# Code quality
./tools/critic.pl ecore/File.pm         # Check single file (bugs theme)
CRITIC_FULL=1 ./tools/critic.pl .       # Full check (core theme)

# Dependency management
carton install && carton bundle         # Install and vendor Perl deps
npm install                            # Install JS deps
npm run build                          # Build React
```

## 📊 Modernization Status

See [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) for the comprehensive modernization plan and current status.

**Quick Summary (Dec 2025)**:
- ✅ **Phase 4a Complete**: All 26 nodelets + 21 content pages migrated to React
- 🔄 **Phase 1**: API modernization in progress (50+ endpoints)
- 🔄 **Phase 5**: jQuery elimination in progress
- ⏳ **Phase 6-10**: Planned (guest user optimization, PSGI/Plack, ORM, etc.)

**Key Achievements**:
- Mason2 reduced to 3 base templates only
- All user-facing content pages React-rendered
- Full-Text Search, Sign Up, and Maintenance Display migrated

## 🎯 Current Priorities

1. **API Modernization** (Phase 1) - RESTful endpoints with comprehensive testing
2. **Guest User Optimization** (Phase 6) - S3 caching for anonymous users
3. **PSGI/Plack Migration** (Phase 7) - Eliminate mod_perl dependency

## 🏗️ Architecture

```
Frontend:  React 18.2 + Mason2 templates
Backend:   Perl + mod_perl2 + Apache2
Database:  MySQL 8.0+
Deploy:    Docker → AWS CodeBuild → Fargate ECS
```

## 📁 Key Directories

```
ecore/                          # Perl backend code
├── Everything/
│   ├── API/                   # REST API endpoints
│   ├── Application.pm         # Core application logic
│   ├── Controller.pm          # Request routing
│   ├── Delegation/            # Legacy migrated code (htmlcode, etc.)
│   ├── Node/                  # Node type classes (Moose)
│   ├── NodeBase/              # Node type database methods
│   └── Page/                  # Page controllers
react/                          # React frontend
├── components/
│   ├── Documents/             # Page-level components
│   ├── Nodelets/              # Sidebar nodelet components
│   └── ...                    # Various feature components
templates/                      # Mason2 templates (only 3 base templates)
├── pages/
│   ├── Base.mc                # Base template class
│   ├── react_page.mc          # React page wrapper
│   └── react_fullpage.mc      # Full-page React wrapper
www/                           # Web-accessible files
├── index.pl                   # mod_perl entry point
├── css/                       # Stylesheets
└── react/                     # Compiled React bundles
t/                             # Perl test suite
├── 0*.t                       # Core tests
├── 05*.t                      # API tests
└── 06*.t                      # Feature tests
docs/                          # Documentation
├── DEVELOPER-ROADMAP.md       # Master modernization plan
├── mason2-migration-status.md # React migration status
└── ...                        # Technical guides
docker/                        # Docker build and development
ops/                           # AWS CloudFormation, deployment
tools/                         # Development utilities
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
# In Everything::API::myresource
package Everything::API::myresource;
use Moose;
extends 'Everything::API';

sub get_resource {
    my ($self) = @_;
    my $data = $self->DB->sqlSelectHashref('*', 'mytable', 'id=?', [$id]);
    return $self->json_response($data);
}

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
# t/012_my_test.t
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

### Critical
- **SQL Injection:** ~15 direct interpolations (Priority 2)
- **Database Code:** 45 achievements, room criteria, 129 superdocs (Priority 1)
- **No Mobile CSS:** Fixed widths, zero media queries (Priority 3)

### High
- **No CI/CD Tests:** Tests don't block deployment
- **No React Tests:** Zero test coverage for 29 components
- **Thread Safety:** Code not safe for Apache threaded MPM

### Medium
- **Legacy Patterns:** Class components instead of hooks
- **No Code Coverage:** Can't measure test coverage
- **Stored Procedures:** 2 stored procedures in database

## 📞 Emergency Procedures

### Site Down
1. Check CloudWatch logs in AWS Console
2. Check ECS service status
3. Check RDS database status
4. Rollback: Update ECS service to previous task definition

### Database Issues
1. Check RDS status in AWS Console
2. Review slow query log
3. Check connection pool exhaustion
4. Point-in-time recovery if needed

### Deployment Failed
1. Check CodeBuild logs in AWS Console
2. Review buildspec.yml for errors
3. Check ECR for image push success
4. Manually trigger build via `./ops/run-codebuild.rb`

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
- Use CDN for static assets

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
#   - Mimics application health test in t/001_application_health.t
#
# CRITIC_FULL mode (core theme):
#   - Severity 1 violations only
#   - Theme: "core" (all Perl::Critic policies)
#   - More comprehensive style and best practice checks
```

### Code Coverage

✅ **Coverage Now Working**: Mock-based API tests enable proper coverage tracking!

```bash
./tools/coverage.sh                      # Run tests with coverage
./tools/coverage.sh report               # Generate report only
./tools/coverage.sh clean                # Clean coverage data
./tools/generate-coverage-badges.sh      # Update coverage badges

# Inside container (manual)
perl -MDevel::Cover=-db,coverage/cover_db t/run.pl
cover -report html -outputdir coverage/html
```

**Current Coverage** (Dec 2025):
- Mock-based API tests: ✅ Working (23-26% coverage)
- Coverage tracked for: Everything::API::*, Application.pm, Node classes
- Badges update automatically during `./docker/devbuild.sh`

**Coverage Goals:**
- Short-term (Q1 2026): 40% (comprehensive API testing)
- Long-term (2026): 70% (post-PSGI migration)

**View Reports:**
- Summary: `coverage/COVERAGE-SUMMARY.md`
- Badges: ![Perl](../coverage/badges/perl-coverage.svg)
- HTML: `coverage/html/coverage.html`
- Text: `cover -report text`

**See:** [Code Coverage Guide](code-coverage.md) and [COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) for details

### React Tests
```bash
npm test                            # Run Jest (when configured)
npm run test:watch                  # Watch mode
npm run test:coverage               # Coverage report
```

## 🚢 Deployment Checklist

- [ ] Run tests locally
- [ ] Check Perl::Critic
- [ ] Build and test in Docker locally
- [ ] Update documentation if needed
- [ ] Commit with descriptive message
- [ ] Push to GitHub
- [ ] Monitor CodeBuild progress
- [ ] Check CloudWatch logs after deployment
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
- **React Query** for API calls
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
- [React Query](https://tanstack.com/query/latest)

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

### Pulling Logs for Analysis

```bash
# Pull e2-app-errors for analysis
aws logs filter-log-events \
  --log-group-name e2-app-errors \
  --start-time $(date -d '3 days ago' +%s)000 \
  --output json > app-errors-3days.json

# Filter by pattern (e.g., specific error type)
aws logs filter-log-events \
  --log-group-name e2-app-errors \
  --filter-pattern "SQL" \
  --start-time $(date -d '24 hours ago' +%s)000

# Pull last 24 hours for immediate triage
aws logs filter-log-events \
  --log-group-name e2-app-errors \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --output json > app-errors-recent.json

# For uninitialized value errors, use the dedicated tool
# (shows top 10 in production)
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

**See:** [infrastructure-overview.md](infrastructure-overview.md#future-monitoring-and-analysis-tasks) for detailed log analysis plan

## 📞 Contact

- Modernization Documentation: `docs/` directory
- Report Issues: GitHub Issues

---

**Quick Reference Version:** 1.2
**Last Updated:** 2025-12-17
