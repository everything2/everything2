# Everything2 Infrastructure Overview

**Last verified:** 2026-11-16 (against `cf/everything2-production.json`, `docker/`, and live us-west-2 state)

## Architecture Summary

Everything2 runs on AWS (us-west-2): one Docker image, run as ARM64 Fargate tasks on ECS behind an ALB, with RDS MySQL 8.4. Everything is defined in one CloudFormation template.

## Development Environment

### Local Setup

**Build Command:**
```bash
./docker/devbuild.sh               # full build + tests
./docker/devbuild.sh --skip-tests  # apply local changes quickly (files are NOT volume-mounted)
```

**Containers** (on the `e2-dev-net` Docker network):
- `e2devdb` - MySQL 8.4 database (host port 9306)
- `e2devapp` - Apache (mpm_event) reverse proxy → Starman/PSGI (`app.psgi`) on 127.0.0.1:5000, plus the cron sidecar (always live in dev)

**Access:**
- Local site: http://localhost:9080
- App log: `docker exec e2devapp tail -f /tmp/development.log` (Starman, app warnings, cron sidecar)

**Dependency Management:**
- **Perl:** `cpanfile` + `cpanfile.snapshot`; tarballs vendored in `vendor/cache/`. The image installs them with `cpanm --from vendor/cache` into `/var/libraries`.
- **JavaScript:** npm (`package.json` + `package-lock.json`); Node version pinned in `/.nvmrc` (currently 24.18.0) and passed to the image as `NODE_VERSION`.
  - Build: `npx webpack --config etc/webpack.config.js` (the dev image runs this itself)

### Development Workflow

1. Code locally
2. `./docker/devbuild.sh` and test at http://localhost:9080
3. Merge to master on GitHub
4. Deploy with `./ops/run-codebuild.rb` (there is no push-triggered deploy)

## Production Infrastructure

### Deployment Pipeline

```
./ops/run-codebuild.rb  (your AWS credentials; run after merging to master)
  ↓ starts CodeBuild project E2-Application-Builder-ARM
AWS CodeBuild (ARM, docker/buildspec.yml)
  ↓ Node from .nvmrc, npm install, webpack
  ↓ tools/asset_pipeline.rb uploads JS/CSS to S3 (deployed.everything2.com/<sha>/)
  ↓ docker buildx --target final (BuildKit registry cache in ECR)
  ↓ pushes everything2/e2app-arm:latest to ECR
run-codebuild.rb, on SUCCEEDED
  ↓ ecs update-service --force-new-deployment (E2-App-Fargate-Service)
ECS rolling deploy (circuit breaker + rollback on)
Production (everything2.com)
```

The CodeBuild project has no GitHub webhook, so nothing deploys on push. A FAILED build leaves prod on the last good image. GitHub Actions only runs CodeQL.

### Manual Deployment

```bash
./ops/run-codebuild.rb
# Starts the CodeBuild build, polls it, and forces a new ECS deployment if it succeeds
```

### Infrastructure-as-Code

**CloudFormation Template:**
- Location: `cf/everything2-production.json` (stack `everything2-production`)
- Defines: VPC/subnets, ALB, ECS cluster/service/task definitions, RDS, S3 buckets, Route53, alarms, EventBridge rules, CodeBuild project, read-only query Lambda
- Stack policy: `cf/stack-policy.json`
- Deploy: `tools/cf-deploy.rb` / `ops/cf.rb`

**CodeBuild Configuration:**
- Location: `docker/buildspec.yml`
- Phases: pre_build (ECR/Docker Hub login, Node, npm), build (webpack, asset pipeline, image build + push), post_build (log only)
- **No test phase.** Tests run locally via `./docker/devbuild.sh`.

### AWS Resources

**Compute:**
- ECS cluster `E2-App-ECS-Cluster`, service `E2-App-Fargate-Service`
- Task definitions (all ARM64, same image):
  - `e2app-family` — webhead, 1 vCPU / 2 GB, `STARMAN_WORKERS=10`; runs the cron sidecar (`E2_CRON_ENABLED=1`, `E2_CRON_LIVE=1`)
  - `e2cron-family` — 0.5 vCPU / 1 GB; the nightly sitemap task and on-demand `ops/cron-runner.rb` / `ops/nodepack-refresh.rb` runs
  - `e2heavyjob-family` — 1 vCPU / 4 GB; manual long jobs in `jobs/`
- Autoscaling: min 2 / max 8, target tracking on 2xx-per-target and on CPU (60%)

**Storage:**
- RDS MySQL 8.4.9, `db.t4g.medium`, single-AZ, gp3, 7-day automated backups, deletion protection
- S3 buckets (main ones): `deployed.everything2.com` (built JS/CSS), `hnimagew.everything2.com` (homenode images), `sitemap.everything2.com`, `nodebackup.everything2.com`, `elblogs.everything2.com` (ALB access logs), `secrets.everything2.com`, `e2-maintenance-jobs`, `nodepack.everything2.com`. See the template for the full list.

**Networking:**
- Application Load Balancer (ALB) — terminates client TLS (TLS 1.2+ policy) and forwards HTTP to port 80
- Route53 DNS for everything2.com/.org/.net

(No CloudFront and no AWS WAF: both were evaluated and rejected at this scale — the ALB terminates TLS and serves the origin directly, and bot traffic is absorbed rather than filtered by a WAF. See the CloudFront/WAF cost-vs-value decisions.)

**Monitoring:**
- CloudWatch logs (3-day retention on most groups), Container Insights
- 7 CloudWatch alarms + deploy-failed EventBridge rule → SNS topic `e2-alerts` (email). See Monitoring & Logging below.

## Cron Jobs / Scheduled Tasks

Scripts live in `cron/`. Since the #4246/#4252 cutover they run **inside the webhead tasks** via the leader-elected cron sidecar, not as per-job Fargate tasks. Full reference: [cron-sidecar.md](cron-sidecar.md).

### Cron Job Inventory

| Script | Where it runs | Cadence |
|---|---|---|
| `cron_datastash.pl` | webhead sidecar | every 2 min |
| `cron_datastash.pl --lengthy` | webhead sidecar | every 6 h |
| `cron_refresh_rooms.pl` | webhead sidecar | every 5 min |
| `cron_clean_cbox.pl` | webhead sidecar | hourly at :50 |
| `cron_clean_old_rooms.pl` | webhead sidecar | daily |
| `cron_iqm_recalculate.pl` | webhead sidecar | daily |
| `cron_generate_sitemap.pl` | dedicated `e2cron-family` Fargate task via EventBridge rule `cron-generate-sitemap` | daily 00:00 UTC |

Other scripts in `cron/`: `cron_runner.pl` (the sidecar entry point), `run_s3_job.pl` (one-off maintenance jobs, see [maintenance-jobs.md](maintenance-jobs.md)), `cron_extract_writeup_content.pl` (run on demand).

### Cron Job Architecture

```
Every webhead task (apache2_wrapper.rb)
  ↓ supervised loop: cron/cron_runner.pl; sleep 60
Everything::Cron::Runner->run_once
  ↓ GET_LOCK('e2cron_leader', 0) — one webhead wins per run
  ↓ fork+exec each due cron/*.pl (per-job timeout)
  ↓ records state in cron_state / cron_leader tables
  ↓ emits E2/Cron UnhealthyJobs → alarm e2-cron-wedged-jobs
Logs: [cron] lines in /aws/fargate/fargate-app-awslogs

Sitemap only:
EventBridge cron-generate-sitemap → RunTask e2cron-family
  → /aws/fargate/fargate-cron-awslogs
```

## Docker Configuration

### Docker Images

One Dockerfile, `docker/e2app/Dockerfile`, base `ubuntu:26.04`. Entrypoint is `docker/e2app/apache2_wrapper.rb`: it renders `etc/templates/apache2.conf.erb`, fetches secrets from S3 (prod only), starts the Starman supervisor and the cron sidecar, then runs Apache in the foreground.

**Development** (`dev` target, the default):
- Built by `docker/devbuild.sh`; clean with `docker/devclean.sh`; DB image in `docker/e2db/`
- Runs webpack inside the image; writes `last_commit` from git

**Production** (`final` target):
- Built by CodeBuild with `--target final`; JS/CSS are built on the CodeBuild host and served from S3, not from the image
- Pushed as `everything2/e2app-arm:latest`; each deploy is identified by its image digest. The commit SHA goes into `/etc/everything/last_commit`.

### Dockerfile Highlights

**Stages:**
1. `deps` — apt packages (Apache, ImageMagick, mysql-client, Ruby, AWS CLI), bsdtar swap (#4544), Perl deps via `cpanm` from `vendor/cache`, Node from `NODE_VERSION`, `npm install`
2. `commit` — writes the commit id
3. `final` — unloads mod_perl, removes Ghostscript, copies the app (all `COPY --link`)
4. `dev` — `final` + webpack + git commit id

**Key Components:**
- Apache (mpm_event) reverse proxy in front of Starman/PSGI (`app.psgi`); mod_perl removed
- Apache modules: deflate, brotli, rewrite, proxy, proxy_http, status, evasive, remoteip, headers
- Webpack output: `www/react/[name].bundle.js` (dev); prod assets in S3 under `<sha>/`

## Database

### Development Database

**Container:** e2devdb
**Engine:** MySQL 8.4 (dev runs strict `sql_mode`; prod is non-strict)
**Data:**
- Seeded from `nodepack/` XML plus `tools/seeds.pl` (via `tools/qareload.pl`)
- Development data only
- Reset with `./docker/devclean.sh` then `./docker/devbuild.sh`

**Configuration:**
- Location: `etc/development-docker.json`
- Connection: `e2-dev-net` Docker network (`E2_DBSERV=e2devdb`)
- Credentials: Development defaults

### Production Database

**Service:** AWS RDS MySQL 8.4.9 (`everything2vpc`, `db.t4g.medium`)
**Configuration:**
- Location: `etc/production.json`; host comes from `E2_DBSERV` (set by CloudFormation)
- Credentials: not in the repo; fetched at container startup (see Secrets below)
- Backups: RDS automated backups, 7-day retention (point-in-time restore)
- High availability: **single-AZ** (`MultiAZ: false`)
- Ad-hoc read-only queries: the `e2-readonly-query` Lambda (`tools/aws/readonly-query-lambda/`)

### Database Schema

**Source:** `nodepack/dbtable/*.xml` (94 tables; CREATE TABLE statements incl. indexes)

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
- `etc/production.json` - Non-secret production settings
- Actual secrets: Not in repository; `apache2_wrapper.rb` downloads them from the private secrets bucket at container startup

### Environment Variables

**Key Variables (set in the task definition or by the wrapper):**
- `E2_DBSERV` - Database host
- `E2_DOCKER=development` - Dev mode (dev container only)
- `STARMAN_WORKERS` (prod 10, default 14), `STARMAN_MAX_REQUESTS` (1000) - Starman sizing
- `E2_CRON_ENABLED`, `E2_CRON_LIVE` - Start the cron sidecar and let it run jobs (both `1` in prod). The wrapper reads these, so don't remove them as unused.
- `PERL5LIB=/var/libraries/lib/perl5:/var/everything/ecore` - Set by the wrapper for Starman and cron
- Timezone is UTC (`TZ=Etc/UTC` in the image)

## Deployment Process Details

### CodeBuild Phases

**pre_build:**
- Log in to ECR and Docker Hub
- Install Node `$(cat .nvmrc)` with `n`, then `npm install`
- Install `aws-sdk-s3` for the asset pipeline

**build:**
- `npx webpack --config etc/webpack.config.js`
- `tools/asset_pipeline.rb --assets=$ASSETS_BUCKET` (compressed copies to S3 under the commit SHA)
- `docker buildx build --push --target final` with a BuildKit registry cache (`:buildcache`) in ECR; falls back to an inline-cache `docker build` if buildx or the cache fails

**post_build:**
- Log only. The ECS deploy is done by `ops/run-codebuild.rb` after the build succeeds.

**NOTE:** No test phase.

### Deployment Configuration

**Buildspec:** `docker/buildspec.yml`
**CodeBuild project:** `E2-Application-Builder-ARM` (ARM container, `amazonlinux-aarch64-standard:4.0`, 90-min timeout); build logs in `/aws/codebuild/dockerbuild`
**ECR repo:** `everything2/e2app-arm` (tag `latest`)
**ECS:** cluster `E2-App-ECS-Cluster`, service `E2-App-Fargate-Service`, task family `e2app-family`

### Rollback Strategy

Every deploy reuses the same task definition (`e2app-family`) with the image tag `:latest`;
what changes is the image digest. Each ECS deployment records the digest it resolved, so
"the previous version" means the previous digest, not a previous task definition.

- **Automatic (#4565):** the service has the ECS deployment circuit breaker on with rollback.
  If a new deployment's tasks never pass health checks (crash, failed `/health`), ECS marks it
  FAILED after a few failed tasks and rolls back to the last completed deployment's digest.
  The `e2-ecs-deployment-failed` EventBridge rule emails `e2-alerts` when that happens; until
  then, a rolled-back deploy just looks like "my change isn't live".
- The breaker only catches tasks that fail to come up healthy. A build that starts and passes
  `/health` but is broken in other ways rolls out normally; roll that back by hand.
- **Manual:** point `:latest` back at the previous good digest and redeploy:
  ```bash
  REPO=everything2/e2app-arm
  aws ecs list-service-deployments --cluster E2-App-ECS-Cluster --service E2-App-Fargate-Service  # find the good deployment
  aws ecs describe-service-revisions --service-revision-arns <its targetServiceRevisionArn> \
    --query 'serviceRevisions[0].containerImages[0].imageDigest'
  MANIFEST=$(aws ecr batch-get-image --repository-name $REPO --image-ids imageDigest=<digest> \
    --query 'images[0].imageManifest' --output text)
  aws ecr put-image --repository-name $REPO --image-tag latest --image-manifest "$MANIFEST"
  aws ecs update-service --cluster E2-App-ECS-Cluster --service E2-App-Fargate-Service --force-new-deployment
  ```
- The ECR lifecycle policy keeps the 10 most recent untagged images, so the last several
  deploys' digests are always available to roll back to.

## Monitoring & Logging

### Current Monitoring

**CloudWatch log groups (us-west-2):**

| Group | Contents |
|---|---|
| `/aws/fargate/fargate-app-awslogs` | Webhead container stdout/stderr: Starman lifecycle, uncaught output, `[cron]` sidecar lines |
| `/aws/events/e2-app-errors` | App warnings and caught `die`s (via `$SIG` handlers → EventBridge). **Check this first for 500s.** |
| `/aws/events/e2-uninitialized-errors` | "Use of uninitialized value" warnings |
| `/aws/fargate/fargate-cron-awslogs` | Sitemap task and on-demand `e2cron-family` runs |
| `/aws/fargate/fargate-heavyjob-awslogs` | `e2heavyjob-family` runs |
| `/aws/fargate/e2-health-check` | Written by `tools/container-health-check.pl` (Server Telemetry page) |
| `/aws/e2/client-errors`, `/aws/e2/rate-limit-blocks` | Browser-reported JS errors; mod_evasive blocks |
| `/aws/rds/instance/everything2vpc/{error,slowquery}` | RDS logs |
| `/aws/codebuild/dockerbuild` | Build logs |

Most groups keep 3 days (client-errors and rate-limit-blocks keep 7). 500s from malformed requests that fail before the app's handlers run show up only in the ALB access logs in S3 (`elblogs.everything2.com`).

**Alarms → SNS `e2-alerts` (email):** `e2-app-5xx-errors`, `e2-app-high-p99-latency`, `e2-app-unhealthy-hosts`, `e2-rds-high-cpu`, `e2-rds-high-connections`, `e2-rds-low-freeable-memory`, `e2-cron-wedged-jobs`, plus the `e2-ecs-deployment-failed` EventBridge rule. The two autoscaling `AlarmLow` alarms normally sit in ALARM; that is expected.

**Other:** Container Insights on the cluster; awslogs non-blocking mode with a 25 MB buffer; ECS managed tags and tag propagation. Memory: use Container Insights `MemoryUtilized`, not `MemoryUtilization` (the latter counts page cache and reads high).

**Error tooling:** `tools/app-errors.rb`, `tools/uninitialized-errors.rb`, `ops/top-app-errors.rb`.

### Gaps

- ❌ No APM or third-party error tracking
- ❌ No external uptime monitoring
- ⚠️  Alerts are email-only (no paging)

### Troubleshooting Tools

**Application Health Checks:**

The app serves `/health` (also `/health.pl`) from `Everything::HealthCheck` in `app.psgi`. The ALB target group checks `/health`; the ECS container check curls `/`. See [Health Check Documentation](health-checks.md) for details.

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
- Database in private subnets

**Secrets:**
- Not in the repository; app secrets are fetched from a private S3 bucket at container startup, and the RDS master password lives in Secrets Manager
- IAM task roles for AWS access

**Updates:**
- Ubuntu 26.04 base (rebuild picks up OS updates)
- Perl modules pinned in `cpanfile.snapshot` / `vendor/cache`
- npm packages pinned in `package-lock.json`

### Security Features

- No AWS WAF. It was evaluated and rejected on cost-vs-value at this scale (bot floods are datacenter traffic that AdSense already filters and the guest-chrome cache absorbs, so a WAF's per-request cost isn't justified — the decision was to "just eat it"). What remains at the app layer:
  - Application-level IP blacklist enforcement (see `t/190_ip_blacklist_enforcement`)
  - CloudWatch metrics/logging on the ALB and app

### Security Gaps

The previously-flagged SQL injection vulnerabilities and eval'd-in-database code have been cleaned up (the "~15 vulnerabilities" framing in older docs is stale). CodeQL runs on GitHub. Remaining hardening opportunity:

- ❌ No dependency vulnerability scanning

### Recommendations

1. Add Dependabot (or similar) for dependency updates and vulnerability alerts

(WAF geo-blocking and AWS Shield Advanced were considered and set aside — see the "just eat it" bot-traffic decision above; not worth the cost at this scale.)

## Scaling Considerations

### Current Architecture

**Starman/PSGI (as-built):** The PSGI/Plack migration is done and live in production (#4234). The app runs under Starman workers (`--preload-app`, 10 per task in prod, recycled every 1000 requests); Apache (mpm_event) is a pure reverse proxy on the front. RDS connections roughly halved compared with mod_perl.

- Per-worker memory cache (no shared cache tier; Redis/Memcached was evaluated and rejected as not cost-effective)
- Cache coherency via database `version` table

**Horizontal Scaling:**
- 2–8 Fargate tasks (target tracking on 2xx-per-target and on 60% CPU)
- Each task has isolated cache
- Cache coherency via database `version` table

**Bottlenecks:**
- RDS instance size (buffer pool RAM), not connection count
- Cache version checks (DB query per cache hit)
- No shared cache between workers (by design)

## Cost Optimization Opportunities

Done: webheads right-sized to 1 vCPU / 2 GB; scheduled cron moved onto the webheads (removed most cron Fargate tasks); JS/CSS served from S3. Rejected: CloudFront, WAF, Aurora, and a shared cache tier. Remaining ideas:

1. **Cache optimization** - Reduce database queries per render
2. **S3 lifecycle policies** - Archive old backups to Glacier

## Disaster Recovery

### Current Backup Strategy

- **Database:** RDS automated backups (7 days, point-in-time restore); S3 buckets exist for manual snapshot exports (`mysqlsnapshots.everything2.com`, `e2-snapshot-exports`)
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

The dated Q1-Q4 2025 roadmap that lived here (including "PSGI/Plack migration — long term", now done and live) is superseded. See [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) for the current roadmap and run `git log` for up-to-date status.

## Future Monitoring and Analysis Tasks

### AWS CloudWatch Log Analysis

Ongoing practice rather than a project: periodically pull the two app-error groups, fix what recurs, and skip one-offs. Logs keep only **3 days**, so look for patterns inside that window.

```bash
./tools/app-errors.rb --hours 24 --group-by file      # /aws/events/e2-app-errors
./tools/uninitialized-errors.rb --hours 24 --group-by file   # /aws/events/e2-uninitialized-errors

# Raw pull, if you want jq
aws logs filter-log-events --region us-west-2 \
  --log-group-name /aws/events/e2-app-errors \
  --start-time $(date -d '3 days ago' +%s)000 \
  --output json > app-errors-3days.json
jq -r '.events[].message' app-errors-3days.json | sort | uniq -c | sort -rn | head -20
```

Log group definitions: `AppErrorsLogGroup` / `AppUninitializedLogGroup` (and the `ApplicationErrorLoggingRule` / `ApplicationUninitializedValueLoggingRule` EventBridge rules) in `cf/everything2-production.json`.

## Related Documentation

- [Cron Sidecar](cron-sidecar.md) - How scheduled jobs run
- [Health Checks](health-checks.md) - `/health` and the ECS/ALB checks
- [Maintenance Jobs](maintenance-jobs.md) - One-off in-VPC Fargate jobs
- [Apache configuration](spec/apache-configuration.md) - Reverse-proxy config
- [Developer Roadmap](DEVELOPER-ROADMAP.md) - Current priorities
