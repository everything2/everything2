# Everything2 Health Check System

**Last verified:** 2026-11-16

## Overview

`/health` is a small PSGI app, `Everything::HealthCheck`, that `app.psgi` answers before any request setup. The ALB target group checks it. The ECS container health check requests `/` instead (see Health Check Configuration). Tests: `t/127`.

## Health Check Endpoint

**URL:** `/health` (`/health.pl` is an alias; both are matched in `app.psgi`, no redirect)

The basic check needs no database, so a DB hiccup does not fail the ALB check and recycle every task. `?db=1` is the readiness probe.

### Basic Health Check

```bash
curl http://localhost:9080/health      # dev
curl https://everything2.com/health    # prod
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1234567890,
  "version": "health-check-v2",
  "backend": "psgi"
}
```

**HTTP Status Codes:**
- `200 OK` - Application is healthy
- `503 Service Unavailable` - Only returned with `?db=1` when the DB probe fails

### Detailed Health Check

```bash
curl 'http://localhost:9080/health?detailed=1'
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1234567890,
  "version": "health-check-v2",
  "backend": "psgi",
  "checks": {
    "app": "ok"
  },
  "system": {
    "load_1min": 0.52,
    "load_5min": 0.48,
    "load_15min": 0.45,
    "running_processes": 2,
    "total_processes": 245
  },
  "memory": {
    "total_kb": 4096000,
    "available_kb": 2048000,
    "used_kb": 2048000,
    "used_percent": "50.0"
  },
  "response_ms": "12.4"
}
```

### Database Connectivity Check

```bash
curl 'http://localhost:9080/health?db=1'
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1234567890,
  "version": "health-check-v2",
  "backend": "psgi",
  "checks": {
    "app": "ok",
    "database": "ok"
  },
  "system": {
    "load_1min": 0.52,
    "load_5min": 0.48,
    "load_15min": 0.45,
    "running_processes": 2,
    "total_processes": 245
  },
  "memory": {
    "total_kb": 4096000,
    "available_kb": 2048000,
    "used_kb": 2048000,
    "used_percent": "50.0"
  },
  "response_ms": "156.2"
}
```

**Note:** `?db=1` opens a fresh DBI connection as the app DB user (SSL, 2 s connect timeout) and runs `SELECT 1`, independent of the app framework (#4215). `checks.database` is `ok`, `query_failed`, `connection_failed`, or `error`. Use it for diagnostics, not frequent polling.

## Query Parameters

| Parameter | Description | Impact |
|-----------|-------------|--------|
| `detailed=1` | Include detailed health status with system metrics | Slight performance impact |
| `db=1` | Test database connectivity (implies detailed) | Moderate performance impact (~100-200ms) |

## System Metrics

When using `?detailed=1` or `?db=1`, the health check endpoint returns detailed system metrics to help diagnose performance issues.

### System Load

Reports Linux system load averages from `/proc/loadavg`:

```json
"system": {
  "load_1min": 0.52,      // 1-minute load average
  "load_5min": 0.48,      // 5-minute load average
  "load_15min": 0.45,     // 15-minute load average
  "running_processes": 2, // Currently running processes
  "total_processes": 245  // Total processes
}
```

**What it means:**
- Load average shows average number of processes waiting for CPU
- Rule of thumb: Load should be below number of CPU cores
- Rising load (1min > 5min > 15min) indicates increasing pressure
- Falling load (1min < 5min < 15min) indicates decreasing pressure

### Memory Usage

Reports memory statistics from `/proc/meminfo`:

```json
"memory": {
  "total_kb": 4096000,      // Total system memory
  "available_kb": 2048000,  // Available for new applications
  "used_kb": 2048000,       // Used memory (total - available)
  "used_percent": "50.0"    // Percentage used
}
```

**What it means:**
- `available_kb` includes free memory + reclaimable cache
- `used_percent` > 90% may indicate memory pressure
- High memory usage with good performance is normal (Linux caches aggressively)
- Memory issues typically show as swap usage or OOM kills

### Worker / Concurrency Model

The app runs under **Starman/PSGI** (`app.psgi`; `/health` is answered by `Everything::HealthCheck` inside it); **Apache (mpm_event)** sits in front as a pure reverse proxy and runs no app code. The health response carries no `apache` object. Concurrency is bounded at the backend by `STARMAN_WORKERS` (10 per task in prod; set in the task definition, read by `docker/e2app/apache2_wrapper.rb`), not by Apache's `MaxRequestWorkers`.

The detailed health response instead reports `system` (load average) and `memory` (meminfo), plus `database` when `?db=1` is passed — see the examples above. To inspect live worker/request state, look at Starman's own process list and the CloudWatch request/latency metrics rather than an Apache mod_status scrape.

### Interpreting Metrics for Diagnostics

| Symptom | Likely Cause | What to Check |
|---------|--------------|---------------|
| High load (> CPU cores) | CPU saturation | Review slow queries, check Starman worker saturation |
| High memory usage (> 90%) | Memory pressure | Check for memory leaks, review Starman worker sizes |
| All Starman workers busy | Request backlog | Raise `STARMAN_WORKERS`, check slow endpoints |
| Low workers, high load | Database or I/O bottleneck | Check database connectivity and query performance |
| Rising 1min load | Current spike | Monitor to see if temporary or sustained |
| High 15min load | Sustained problem | Investigate application performance |
| Backend 503 / proxy errors | Starman backend down or saturated | Check Starman process on :5000, review CloudWatch |

## Health Check Configuration

### ECS Container Health Check

Configured on the `e2app` container in `E2AppFargateTaskDefinition` ([cf/everything2-production.json](../cf/everything2-production.json)):

```json
"HealthCheck": {
  "Interval": 10,
  "Retries": 5,
  "StartPeriod": 60,
  "Timeout": 5,
  "Command": ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
}
```

**Settings:**
- **Command:** requests the front page (`/`), not `/health`, so it exercises the full app stack
- **Interval:** 10 seconds between checks
- **Retries:** 5 consecutive failures before marking unhealthy
- **StartPeriod:** 60 second grace period during container startup
- **Timeout:** 5 second timeout per check

### ALB Target Group Health Check

`FargateTargetGroupHTTP` (`E2-App-Fargate-HTTP-TG`): HTTP on port 80, path `/health`, expects `200`, 20 s timeout, healthy after 2 / unhealthy after 5 checks. The ECS service adds a 45 s health-check grace period. Deployments use the circuit breaker with rollback, so a build whose tasks never pass these checks is rolled back automatically (see [infrastructure-overview.md](infrastructure-overview.md)).

### Apache (Reverse Proxy) Configuration

The proxy-side bits are in [etc/templates/apache2.conf.erb](../etc/templates/apache2.conf.erb). Under PSGI, `/health` and `/health.pl` are reverse-proxied to the Starman backend like any other dynamic path and answered by `Everything::HealthCheck` (in `app.psgi`). Apache only marks `/health.pl` as `dontlog`:

```apache
# Health check endpoint - no access logging
<Location /health.pl>
    SetEnv dontlog 1
</Location>

# Apache server-status for monitoring the *proxy* layer (localhost only)
<Location /server-status>
    SetHandler server-status
    Require local
    SetEnv dontlog 1
</Location>
```

**Key features:**
- `dontlog` on `/health.pl` and `/server-status` (Apache writes an access log only in dev anyway)
- Both `/health` and `/health.pl` are proxied to Starman and answered by the PSGI health app
- `/server-status` (Apache mod_status) reports on the **proxy** layer only — it no longer feeds app metrics into the health response
- The health JSON's worker/concurrency model is Starman, not Apache prefork (see the Worker / Concurrency Model section above)

### CloudWatch Log Group `/aws/fargate/e2-health-check`

`Everything::HealthCheck` does **no logging**; it only returns JSON. The `HealthCheckLogGroup` (`/aws/fargate/e2-health-check`, 3-day retention, write access via `HealthCheckLogWritePolicy` on the task role) is written by `tools/container-health-check.pl`, an older script that checks Apache processes, `/health.pl`, `/server-status`, and the DB, and posts the result to that group when run in prod. The admin Server Telemetry page (`Everything::Page::server_telemetry`) runs it on demand. It is not part of the ECS or ALB health checks.

```bash
./tools/tail-health-check-logs.sh --since 1h       # helper (reads /aws/fargate/e2-health-check)
aws logs tail /aws/fargate/e2-health-check --since 1h --region us-west-2
```

For actual app errors, use `/aws/events/e2-app-errors` and `/aws/events/e2-uninitialized-errors` (see [infrastructure-overview.md](infrastructure-overview.md#monitoring--logging)).

## Testing Health Checks

### Local Testing Script

Use [tools/test-health-check.sh](../tools/test-health-check.sh) for comprehensive health check testing:

```bash
# Basic health check
./tools/test-health-check.sh

# Detailed health check
./tools/test-health-check.sh --detailed

# Test database connectivity
./tools/test-health-check.sh --db

# Continuous monitoring (1 second intervals)
./tools/test-health-check.sh --watch

# Test production (without DB check)
./tools/test-health-check.sh https://everything2.com/health
```

### Manual Testing

```bash
H=http://localhost:9080/health   # dev; inside a container use http://localhost/health

curl -s $H | jq .                                  # basic
curl -s -o /dev/null -w '%{http_code}\n' $H        # status code only
time curl -s "$H?detailed=1" | jq .                # detailed with timing
curl -s "$H?db=1" | jq .                           # database probe
```

## Troubleshooting Health Check Failures

### Step 1: Check Container Status

```bash
# Use the diagnostic tool
./tools/diagnose-health-checks.rb

# Or manually check ECS tasks
aws ecs describe-tasks \
  --cluster E2-App-ECS-Cluster \
  --tasks <task-arn>
```

### Step 2: Check Logs

```bash
# Container stdout/stderr (Starman lifecycle, startup errors)
aws logs tail /aws/fargate/fargate-app-awslogs --since 30m --region us-west-2

# App errors (caught dies, warnings)
./tools/app-errors.rb --hours 1

# Dev
docker exec e2devapp tail -100 /tmp/development.log
```

### Step 3: Test Health Endpoint Manually

```bash
# From within the container (ECS exec is enabled on the service)
curl -v http://localhost/health
curl -v 'http://localhost/health?db=1'
curl -v http://127.0.0.1:5000/health     # Starman directly, bypassing Apache

# Check Apache and Starman are running
ps aux | grep -E 'apache2|starman'
```

### Step 4: Check Target Group Health

```bash
# Use the diagnostic tool
./tools/diagnose-health-checks.rb

# Or manually check target health
aws elbv2 describe-target-health \
  --target-group-arn <arn>
```

## Common Issues and Solutions

### Issue: Health checks timing out

**Symptoms:** Container check (5 s) or target group check (20 s) times out

**Possible causes:**
- All Starman workers busy (the container check requests `/`, which needs a free worker)
- Database slow or unreachable (affects `/`, and `/health?db=1`)
- Starman not running (Apache returns 502/503)

**Solutions:**
1. Compare `/health` (no DB) with `/` from inside the container
2. Check container logs in `/aws/fargate/fargate-app-awslogs` (in prod, Apache's error log goes to stderr)
3. Check RDS CPU/connections alarms
4. Consider the timeouts in CloudFormation

### Issue: Health checks fail during deployments

**Symptoms:** Brief health check failures during new task deployments

**Expected behavior:** This is normal during rolling deployments

**Mitigation:**
- 60-second StartPeriod and 45-second service grace period allow containers to initialize
- 5 retries prevent false positives
- ECS keeps 100% minimum healthy during deployments; the circuit breaker rolls back deployments whose tasks never get healthy

### Issue: Database health checks always fail

**Symptoms:** `?db=1` returns `"database":"connection_failed"`

**Possible causes:**
- Database credentials incorrect
- Database server unreachable
- Security group rules blocking connection
- Wrong database hostname in `E2_DBSERV`

**Solutions:**
1. Verify database endpoint: `echo $E2_DBSERV`
2. Check that `/etc/everything/database_password_secret` exists (written at startup by `apache2_wrapper.rb`)
3. Check security group rules allow MySQL traffic
4. Review CloudFormation database configuration

### Issue: Health checks succeed but application returns errors

**Symptoms:** `/health` returns 200 OK, but application pages fail

**Explanation:** The basic check only proves Starman is answering; it does not load the app or touch the DB

**Solutions:**
1. Use the DB probe: `curl 'http://localhost/health?db=1'`
2. Check `/aws/events/e2-app-errors` (`./tools/app-errors.rb`); in dev, `/tmp/development.log`
3. Test specific application endpoints
4. Check the `e2-app-5xx-errors` alarm and ALB access logs in `elblogs.everything2.com`

## Performance Considerations

### Health Check Impact

| Mode | Response Time | Impact | Use Case |
|------|---------------|--------|----------|
| Basic | ~10-50ms | Minimal | ECS/ELB health checks, frequent monitoring |
| Detailed | ~50-150ms | Low | Periodic diagnostics, includes system metrics |
| Database | ~150-250ms | Moderate | Troubleshooting, includes all metrics + DB test |

**Note:** Detailed and database modes read `/proc/loadavg` and `/proc/meminfo`; database mode adds a fresh DB connection.

### Recommendations

1. **ECS Container Health Checks:** Currently `/` (full page)
2. **ELB Target Health Checks:** Basic `/health`
3. **Monitoring Dashboards:** Use basic mode with 30-60s intervals
4. **Troubleshooting:** Use detailed or database mode as needed
5. **Automated Testing:** Use basic mode for CI/CD pipelines

## Integration with Monitoring

### CloudWatch Integration

Health check failures are visible through:
- ECS container health status
- Target group unhealthy target count
- The `e2-ecs-deployment-failed` EventBridge rule (failed/rolled-back deploys)

### Alerting

Live alarms that cover health (SNS `e2-alerts`, email):
1. `e2-app-unhealthy-hosts` — target group unhealthy hosts
2. `e2-app-5xx-errors` — target 5xx
3. `e2-app-high-p95-latency`
4. `e2-ecs-deployment-failed` (EventBridge rule, not an alarm)

See [tools/diagnose-health-checks.rb](../tools/diagnose-health-checks.rb) for automated diagnostics.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ECS Task (Fargate)                                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Docker Container                                     │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  Apache (mpm_event) reverse proxy            │    │  │
│  │  │     │  proxies /health -> Starman :5000      │    │  │
│  │  │     ▼                                         │    │  │
│  │  │  Starman / PSGI  (app.psgi)                  │    │  │
│  │  │                                               │    │  │
│  │  │  ┌────────────────────────────────────┐      │    │  │
│  │  │  │  /health endpoint                  │      │    │  │
│  │  │  │  (Everything::HealthCheck)         │      │    │  │
│  │  │  │                                     │      │    │  │
│  │  │  │  • Basic check: app OK             │      │    │  │
│  │  │  │  • Detailed: + load + memory       │      │    │  │
│  │  │  │  • DB check (?db=1): + database    │      │    │  │
│  │  │  └────────────────────────────────────┘      │    │  │
│  │  │                                               │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                    ▲                                  │  │
│  └────────────────────┼──────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────┼──────────────────────────────────┐ │
│  │  ECS Container Health Check                          │ │
│  │  Every 10s: curl -f http://localhost/                │ │
│  │  5 retries, 60s start period                         │ │
│  └──────────────────────────────────────────────────────┘ │
│                       │                                     │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  Target Group Health Check     │
        │  Protocol: HTTP                │
        │  Port: 80                      │
        │  Path: /health                 │
        └───────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| [ecore/Everything/HealthCheck.pm](../ecore/Everything/HealthCheck.pm) | Health check endpoint implementation (PSGI app, wired in `app.psgi`) |
| [etc/templates/apache2.conf.erb](../etc/templates/apache2.conf.erb) | Apache reverse-proxy config for `/health` |
| [cf/everything2-production.json](../cf/everything2-production.json) | ECS health check configuration |
| [app.psgi](../app.psgi) | Routes `/health` and `/health.pl` to the health app |
| [t/127_health_check.t](../t/127_health_check.t) | Unit tests |
| [tools/test-health-check.sh](../tools/test-health-check.sh) | Health check testing script |
| [tools/diagnose-health-checks.rb](../tools/diagnose-health-checks.rb) | ECS health check diagnostics |
| [tools/container-health-check.pl](../tools/container-health-check.pl) | Legacy combined check used by the Server Telemetry page; writes `/aws/fargate/e2-health-check` |
| [tools/tail-health-check-logs.sh](../tools/tail-health-check-logs.sh) | Tails `/aws/fargate/e2-health-check` |

## See Also

- [Infrastructure Overview](infrastructure-overview.md) - Overall system architecture
- [Apache configuration](spec/apache-configuration.md) - Reverse-proxy config
