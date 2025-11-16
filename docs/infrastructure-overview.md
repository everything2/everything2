# Everything2 Infrastructure Overview

**Date:** 2025-11-07

## Architecture Summary

Everything2 runs on a containerized AWS infrastructure with Docker containers managed by Fargate ECS, defined via CloudFormation templates.

## Development Environment

### Local Setup

**Build Command:**
```bash
./docker/devbuild.sh
```

**Containers:**
- `e2devdb` - MySQL 8.0+ database
- `e2devapp` - Apache2 + mod_perl2 + Node.js application

**Access:**
- Local site: http://localhost:9080
- Database: MySQL on standard port (internal)

**Dependency Management:**
- **Perl:** Carton (cpanfile + cpanfile.snapshot)
  - Dependencies **embedded in codebase** for deployment
  - Location: `vendor/` directory
  - Install: `carton install`
- **JavaScript:** npm (package.json + package-lock.json)
  - Dependencies in `node_modules/`
  - Build: `npm install && npm run build`

### Development Workflow

1. Code locally
2. Test at http://localhost:9080
3. Commit to GitHub
4. (Optional) Manual deploy via `./ops/run-codebuild.rb`
5. Or automatic deploy on push

## Production Infrastructure

### Deployment Pipeline

```
GitHub (everything2/everything2)
  ↓ Push to master
AWS CodeBuild
  ↓ docker/buildspec.yml
  ↓ Builds Docker image
  ↓ Runs Carton to bundle Perl deps
  ↓ Runs npm build for React
  ↓ Pushes to ECR
AWS Fargate ECS
  ↓ Pulls latest image
  ↓ Launches containers
Production (everything2.com)
```

### Manual Deployment

```bash
./ops/run-codebuild.rb
# Uses your AWS credentials
# Triggers CodeBuild manually
# Same process as automatic deploy
```

### Infrastructure-as-Code

**CloudFormation Template:**
- Location: `cf/everything2-production.json`
- Defines: ECS cluster, Fargate tasks, load balancer, networking
- Stack policy: `cf/stack-policy.json`

**CodeBuild Configuration:**
- Location: `docker/buildspec.yml`
- Phases: pre_build, build, post_build
- Currently: **No test phase** (tests don't run in CI/CD)

### AWS Resources

**Compute:**
- Fargate ECS cluster
- Multiple task definitions:
  - Web application (e2devapp)
  - Cron jobs (scheduled tasks)

**Storage:**
- RDS MySQL (production database)
- S3 Buckets:
  - `hnimagew.everything2.com` - Home node images
  - `deployed.everything2.com` - Deployed assets
  - `nodebackup.everything2.com` - Backup/export data
  - `sitemap.everything2.com` - Sitemap data
  - `jscssw.everything2.com` - JavaScript/CSS assets

**Networking:**
- Application Load Balancer (ALB)
- AWS WAF (Web Application Firewall) protecting ALB
- CloudFront CDN (likely, for static assets)
- Route53 DNS

**Monitoring:**
- CloudWatch logs
- CloudWatch metrics
- (Manual monitoring via AWS Console)

## Cron Jobs / Scheduled Tasks

**Location:** `cron/` directory (7 scripts)

Each cron job:
- Runs as a scheduled Fargate task
- Has its own copy of the Everything2 codebase
- Defined in CloudFormation template
- Runs independently of web application

### Cron Job Inventory

1. **cron_clean_cbox.pl** (221 bytes)
   - Purpose: Chatterbox cleanup
   - Removes old messages, maintains chatterbox state

2. **cron_clean_old_rooms.pl** (252 bytes)
   - Purpose: Room cleanup
   - Archives or removes inactive rooms

3. **cron_datastash.pl** (925 bytes)
   - Purpose: DataStash updates
   - Refreshes cached data for various datastash displays
   - Examples: newwriteups, coolnodes, frontpagenews

4. **cron_generate_sitemap.pl** (1.2K)
   - Purpose: Sitemap generation
   - Creates XML sitemaps for search engines
   - Uploads to S3 bucket (sitemap.everything2.com)

5. **cron_iqm_recalculate.pl** (257 bytes)
   - Purpose: IQM (Image Quality Metric?) recalculation
   - Updates quality metrics

6. **cron_refresh_rooms.pl** (378 bytes)
   - Purpose: Room refresh
   - Updates room state, user lists

7. **cron_writeup_reaper.pl** (346 bytes)
   - Purpose: Writeup reaper
   - Removes or archives writeups marked for deletion

### Cron Job Architecture

```
CloudFormation Template
  ↓ Defines scheduled tasks
  ↓ Uses EventBridge (CloudWatch Events)
Fargate ECS
  ↓ Launches cron task container
  ↓ Contains full E2 codebase
Cron Script
  ↓ Initializes Everything (use Everything;)
  ↓ Connects to database
  ↓ Performs maintenance task
  ↓ Exits (container terminates)
CloudWatch Logs
  ↓ Captures output
```

**Key Points:**
- Each cron job runs in its own container
- Container starts, runs script, exits
- Uses same Docker image as web application
- Scheduled via EventBridge/CloudWatch Events
- Logs go to CloudWatch

## Docker Configuration

### Docker Images

**Development:**
- Location: `docker/` directory
- Base image: Ubuntu 24.04
- Includes: Apache2, mod_perl2, MySQL client, Node.js 20.19.2
- Build script: `docker/devbuild.sh`
- Clean script: `docker/devclean.sh`

**Production:**
- Built by CodeBuild
- Same base as development
- Includes compiled React bundles
- Perl dependencies from Carton
- Tagged with git commit SHA

### Dockerfile Highlights

**Multi-stage build:**
1. System dependencies (imagemagick, libmysqlclient, etc.)
2. Perl dependencies via Carton
3. Node.js and React build
4. Apache configuration
5. Everything2 codebase

**Key Components:**
- Apache2 with mod_perl2
- Perl modules from cpanfile (via Carton)
- Node.js for Webpack build
- React compiled to `www/react/main.bundle.js`
- Git commit recorded in image

## Database

### Development Database

**Container:** e2devdb
**Engine:** MySQL 8.0+
**Data:**
- Seeded from `nodepack/` XML files
- Development data only
- Reset with `./docker/devclean.sh`

**Configuration:**
- Location: `etc/development-docker.json`
- Connection: Internal Docker network
- Credentials: Development defaults

### Production Database

**Service:** AWS RDS MySQL
**Configuration:**
- Location: `etc/production.json` (secrets location reference)
- Actual credentials: AWS Secrets Manager (not in repo)
- Backups: Automated via RDS
- High availability: Multi-AZ (likely)

### Database Schema

**Source:** `nodepack/dbtable/*.xml`
- Node table definitions
- Index definitions
- Stored procedure definitions (2 procedures)

**Key Tables:**
- `node` - Core node table (all content)
- Type-specific tables (user, writeup, document, etc.)
- `links` - Node relationships
- `version` - Cache versioning
- `nodeparam` - Extensible node parameters

## Configuration Management

### Configuration Files

**Development:**
- `etc/development.json` - Local development config
- `etc/development-docker.json` - Docker-specific config
- `etc/docker-mysql-development.json` - Database config

**Production:**
- `etc/production.json` - References AWS Secrets Manager
- Actual secrets: Not in repository
- Retrieved at container startup

### Environment Variables

**Key Variables:**
- `TZ=+0000` - Timezone (UTC)
- `SCRIPT_NAME` - CGI script path
- `PERL5LIB` - Perl library path
- Database connection details (from config)

## Deployment Process Details

### CodeBuild Phases

**pre_build:**
- Login to ECR (Docker registry)
- Pull base images if needed

**build:**
- Run Carton to install Perl dependencies
- Bundle dependencies into `vendor/`
- Run npm install
- Build React with Webpack
- Build Docker image
- Tag with commit SHA

**post_build:**
- Push image to ECR
- Update ECS service to use new image
- Fargate pulls new image and deploys

**NOTE:** No test phase currently configured

### Deployment Configuration

**Buildspec:** `docker/buildspec.yml`
**ECR:** Elastic Container Registry
**ECS:** Elastic Container Service
**Fargate:** Serverless container runtime

### Rollback Strategy

- Keep previous image tags in ECR
- Can manually rollback via ECS console
- Update service to use previous task definition
- No automated rollback currently

## Monitoring & Logging

### Current Monitoring

**CloudWatch:**
- Application logs from containers
- Cron job output
- ECS task metrics (CPU, memory, network)
- **Container Insights** - Enhanced monitoring for ECS cluster
  - Task and container-level CPU and memory metrics
  - Network metrics (rx/tx bytes, packets)
  - Diagnostic metrics for performance troubleshooting
  - Pre-built CloudWatch dashboards

**Enhanced Observability Features:**
- **Tag Propagation** - Service tags automatically propagate to tasks for better resource tracking and cost allocation
- **Non-blocking Logging** - Logs use non-blocking mode with 25MB buffer to prevent logging backpressure from affecting application performance
- **ECS Managed Tags** - Automatic tagging of resources with cluster, service, and task metadata

**Manual:**
- AWS Console monitoring
- Log inspection
- Performance profiling (Devel::NYTProf locally)

### Gaps

- ❌ No application performance monitoring (APM)
- ❌ No error tracking (Sentry, Rollbar, etc.)
- ❌ No uptime monitoring
- ❌ No alerting on errors
- ⚠️  Basic metrics dashboards (Container Insights provides task-level metrics, but no application-level APM)

### Recommendations

1. ✅ Container Insights enabled - Use pre-built dashboards for task/container metrics
2. Set up CloudWatch alarms based on Container Insights metrics (CPU, memory, network)
3. Configure alerting for:
   - Task failure count
   - Unhealthy target count
   - High CPU/memory utilization
   - Network errors
4. Implement application-level APM (NewRelic, DataDog, or CloudWatch Application Insights)
5. Add error tracking service (Sentry, Rollbar)
6. Set up PagerDuty or similar for on-call

### Troubleshooting Tools

**Application Health Checks:**

The E2 application includes a dedicated health check endpoint at `/health` for monitoring and diagnostics. See [Health Check Documentation](health-checks.md) for complete details.

```bash
# Test health check locally
./tools/test-health-check.sh

# Detailed health status
./tools/test-health-check.sh --detailed

# Test database connectivity
./tools/test-health-check.sh --db

# Continuous monitoring
./tools/test-health-check.sh --watch
```

**ECS/AWS Health Check Diagnostics:**

```bash
# Quick health check status
./tools/diagnose-health-checks.rb

# Include recent CloudWatch logs
./tools/diagnose-health-checks.rb --logs

# Custom configuration
./tools/diagnose-health-checks.rb --region us-west-2 --cluster E2-App-ECS-Cluster
```

The health check diagnostic tool ([tools/diagnose-health-checks.rb](../tools/diagnose-health-checks.rb)) provides:
- ECS service status and task counts
- Running task details and container health
- Target group health status for all registered targets
- Task definition health check configuration
- Recent CloudWatch logs (with --logs flag)
- Automated diagnostics and recommendations

**Use Cases:**
- Debugging deployment issues
- Investigating unhealthy targets
- Understanding why tasks are failing
- Analyzing health check configuration
- Quick operational status check

**Requirements:**
- AWS CLI configured with appropriate credentials
- Ruby gems: aws-sdk-ecs, aws-sdk-elasticloadbalancingv2, aws-sdk-cloudwatchlogs

**Common Issues Detected:**
- No tasks running
- Tasks below desired count
- Unhealthy targets in load balancer
- Multiple deployments in progress
- Health check timeout issues
- Application not responding on health check port

## Security

### Current Security Measures

**Network:**
- ALB with HTTPS termination
- Security groups restricting access
- Private subnets for database

**Secrets:**
- AWS Secrets Manager for credentials
- No secrets in repository
- IAM roles for container access

**Updates:**
- Ubuntu 24.04 base (regular security updates needed)
- Perl module updates via Carton
- npm package updates via package-lock.json

### Security Features

- ✅ AWS WAF (Web Application Firewall) protecting ALB with:
  - IP reputation list blocking (known malicious IPs)
  - Anonymous IP list blocking (VPNs, proxies, Tor nodes)
  - Bot control (common bot detection)
  - Rate limiting (200 requests/minute per IP)
  - Custom bot blacklist (HTTrack blocker)
  - CloudWatch metrics and logging

### Security Gaps

- ❌ SQL injection vulnerabilities (see analysis-summary.md)
- ❌ Eval'd code in database (see analysis-summary.md)
- ❌ No automated security scanning
- ❌ No dependency vulnerability scanning

### Recommendations

1. Add Dependabot for dependency updates
2. Run Snyk or similar for vulnerability scanning
3. Fix SQL injection vulnerabilities (Priority 2)
4. Remove database code execution (Priority 1)
5. Consider WAF geo-blocking if needed
6. Consider enabling AWS Shield Advanced for DDoS protection

## Scaling Considerations

### Current Limitations

**mod_perl Architecture:**
- Per-process memory cache
- Package-level globals
- Not thread-safe
- Apache prefork MPM (one process per connection)
- Process size limit: 800MB (Apache2::SizeLimit)

**Horizontal Scaling:**
- Multiple Fargate tasks possible
- Each task has isolated cache
- Cache coherency via database `version` table
- Database queries for every cache hit

**Bottlenecks:**
- Database connection pool
- Cache version checks (DB query per cache hit)
- No shared cache between workers

### PSGI/Plack Benefits

**When migrated:**
- Shared cache (Redis/Memcached)
- Better horizontal scaling
- Thread-safe workers
- Lower memory per worker
- More efficient connection pooling

## Cost Optimization Opportunities

1. **Right-size Fargate tasks** - Monitor actual CPU/memory usage
2. **CDN for static assets** - Reduce origin requests
3. **Cache optimization** - Reduce database queries
4. **Spot instances** - For non-critical tasks (cron jobs)
5. **S3 lifecycle policies** - Archive old backups to Glacier

## Disaster Recovery

### Current Backup Strategy

- **Database:** RDS automated backups
- **Code:** GitHub repository
- **Node backups:** S3 bucket (nodebackup.everything2.com)

### Recovery Plan

1. Code: Clone from GitHub
2. Database: RDS point-in-time recovery
3. Assets: Restore from S3
4. Deploy: Run CodeBuild to create new container
5. Update: Point DNS to new ALB

### Gaps

- ❌ No documented disaster recovery procedure
- ❌ No tested recovery process
- ❌ No RTO/RPO defined
- ❌ No backup monitoring/alerting

### Recommendations

1. Document DR procedure
2. Test recovery quarterly
3. Define RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
4. Set up backup monitoring
5. Consider multi-region deployment for critical systems

## Future Infrastructure Improvements

### Short Term (Q1-Q2 2025)

1. **Add CI/CD test phase** - Run tests before deployment
2. **CloudWatch dashboards** - Better visibility
3. **Alerting** - Error rate, latency thresholds
4. **Backup monitoring** - Verify backups are working

### Medium Term (Q2-Q3 2025)

1. **APM integration** - Application performance monitoring
2. **Error tracking** - Sentry or similar
3. **WAF enhancements** - Geo-blocking, advanced rules, Shield Advanced
4. **Redis for caching** - Shared cache for PSGI

### Long Term (Q3-Q4 2025)

1. **PSGI/Plack migration** - Modern web framework
2. **Kubernetes** - Consider EKS for container orchestration
3. **Multi-region** - High availability
4. **Serverless components** - Lambda for cron jobs?

## Future Monitoring and Analysis Tasks

### AWS CloudWatch Log Analysis

**Priority:** Medium (Quality improvement)
**Estimated Effort:** 2-3 weeks

#### Log Groups to Review

1. **e2-app-errors** - Application-level errors
   - Parse and categorize error types
   - Identify most frequent error patterns
   - Create metrics and alarms for critical errors
   - Document error handling improvements needed

2. **e2-uninitialized-errors** - Uninitialized variable warnings
   - Catalog all uninitialized value warnings
   - Prioritize by frequency and severity
   - Similar to the base.pm fix we made (basedir defaulting)
   - Track down sources and add proper initialization
   - Add perlcritic rules to prevent new occurrences

#### Implementation Plan

**Note:** CloudWatch logs have a **3-day retention period**. Since these are transient errors, focus on recurring patterns within the 3-day window rather than historical archiving.

**Week 1: Data Collection & Pattern Identification**
```bash
# Pull recent logs from CloudWatch (3-day window sufficient)
aws logs filter-log-events \
  --log-group-name e2-app-errors \
  --start-time $(date -d '3 days ago' +%s)000 \
  --output json > app-errors-3days.json

aws logs filter-log-events \
  --log-group-name e2-uninitialized-errors \
  --start-time $(date -d '3 days ago' +%s)000 \
  --output json > uninit-errors-3days.json

# Identify frequently recurring errors (multiple occurrences = worth fixing)
jq '.events[].message' app-errors-3days.json | sort | uniq -c | sort -rn | head -20
```

**Week 2: Analysis & Prioritization**
- Parse log data to extract error patterns
- Create frequency distribution (focus on errors appearing 10+ times)
- Identify recurring issues that impact user experience
- Categorize by severity and fix priority
- **Skip one-off errors** - if it only happened once in 3 days, not worth fixing

**Week 3: Remediation**
- Fix top 5 most frequent errors
- Add test coverage for fixes
- Update code to prevent recurrence
- Document patterns in coding standards

#### Expected Outcomes

- **Reduced error noise** - Cleaner logs, easier debugging
- **Better code quality** - Proper initialization patterns
- **Improved monitoring** - CloudWatch dashboards with meaningful metrics
- **Proactive alerting** - Alarms for critical error spikes

#### Related Files

- [cf/everything2-production.json:653](../cf/everything2-production.json#L653) - CloudWatch log group definitions
- [ecore/Everything/dataprovider/base.pm:24-26](../ecore/Everything/dataprovider/base.pm#L24-L26) - Example fix for uninitialized basedir

#### Success Metrics

- 50% reduction in e2-uninitialized-errors log volume
- 80% of e2-app-errors categorized and documented
- CloudWatch dashboard created with key metrics
- All critical error patterns have test coverage

## Related Documentation

- [Modernization Priorities](modernization-priorities.md) - Strategic priorities
- [Analysis Summary](analysis-summary.md) - Complete technical analysis
- [Status](status.md) - Current project status
- [mod_perl/PSGI Analysis](modperl-psgi-analysis.md) - Detailed migration analysis

---

**Document Status:** Updated with CloudWatch log analysis task
**Last Updated:** 2025-11-07
**Next Review:** 2025-12-07
