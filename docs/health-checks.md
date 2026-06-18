# Everything2 Health Check System

## Overview

The E2 health check system provides monitoring and diagnostics for the application running in ECS containers. It includes a lightweight health check endpoint, comprehensive logging, and testing tools.

## Health Check Endpoint

**URL:** `/health.pl` (or `/health` which redirects to `/health.pl`)

The health endpoint is designed for:
- ECS container health checks
- ELB target group health checks
- Manual diagnostics and monitoring
- Automated health monitoring scripts

**Note:** Both `/health` and `/health.pl` work. The actual endpoint is `/health.pl` but Apache has a rewrite rule that redirects `/health` to `/health.pl` for convenience.

### Basic Health Check

```bash
curl http://localhost/health.pl
# or
curl http://localhost/health
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
- `503 Service Unavailable` - Application is unhealthy

### Detailed Health Check

```bash
curl http://localhost/health.pl?detailed=1
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
curl http://localhost/health.pl?db=1
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

**Note:** Database checks are slower and should only be used for detailed diagnostics, not for frequent health monitoring.

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

### Worker / Concurrency Model (as of 2026-06)

The app runs under **Starman/PSGI** (`app.psgi`, served by `Everything::HealthCheck` as a standalone PSGI app); **Apache (mpm_event)** sits in front as a pure reverse proxy and runs no app code. mod_perl, the prefork MPM, and the old mod_status worker-metrics block are gone, so the health response no longer carries an `apache` object. Concurrency is bounded at the backend by `STARMAN_WORKERS` (see `etc/templates/apache2.conf.erb` and `docker/e2app/apache2_wrapper.rb`), not by `MaxRequestWorkers`.

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

Configured in [cf/everything2-production.json](../cf/everything2-production.json):

```json
"HealthCheck": {
  "Interval": 10,
  "Retries": 5,
  "StartPeriod": 60,
  "Timeout": 5,
  "Command": ["CMD-SHELL","curl -f -s http://localhost/health.pl || exit 1"]
}
```

**Settings:**
- **Interval:** 10 seconds between checks
- **Retries:** 5 consecutive failures before marking unhealthy
- **StartPeriod:** 60 second grace period during container startup
- **Timeout:** 5 second timeout per check

### Apache (Reverse Proxy) Configuration

The proxy-side bits are in [etc/templates/apache2.conf.erb](../etc/templates/apache2.conf.erb). Under PSGI, `/health` and `/health.pl` are reverse-proxied to the Starman backend and answered by `Everything::HealthCheck` (in `app.psgi`); Apache only suppresses logging for them:

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

**Key features (as of 2026-06):**
- No access logging for health check or server-status (reduces log noise)
- Both `/health` and `/health.pl` are proxied to Starman and answered by the PSGI health app
- `/server-status` (Apache mod_status) reports on the **proxy** layer only — it no longer feeds app metrics into the health response
- The health JSON's worker/concurrency model is Starman, not Apache prefork (see the Worker / Concurrency Model section above)

### CloudWatch Logs Configuration

CloudWatch Logs infrastructure is configured in [cf/everything2-production.json](../cf/everything2-production.json):

**Log Group:**
```json
"HealthCheckLogGroup": {
  "Type": "AWS::Logs::LogGroup",
  "Properties": {
    "LogGroupName": "/aws/fargate/health-check-awslogs",
    "RetentionInDays": 3
  }
}
```

**IAM Policy:**
```json
"HealthCheckLogWritePolicy": {
  "Type": "AWS::IAM::ManagedPolicy",
  "Properties": {
    "Description": "Allows the app containers to write health check logs to CloudWatch",
    "PolicyDocument": {
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "logs:PutLogEvents",
          "Resource": "arn:aws:logs:*:*:log-group:/aws/fargate/health-check-awslogs:*"
        },
        {
          "Effect": "Allow",
          "Action": "logs:CreateLogStream",
          "Resource": "arn:aws:logs:*:*:log-group:/aws/fargate/health-check-awslogs:*"
        }
      ]
    }
  }
}
```

**Key features:**
- 3-day retention period (shorter retention since only failures/slow responses are logged)
- Automatic log stream creation per container instance
- JSON-formatted structured logs for easy querying
- Attached to AppFargateTaskRole via HealthCheckLogWritePolicy
- Only logs failures and slow responses (minimal CloudWatch Logs costs)

## Health Check Logging

### Log Destinations

Health check events are logged to two destinations:

1. **Local file**: `/var/log/everything/health-check.log`
2. **CloudWatch Logs**: `/aws/fargate/health-check-awslogs`

### What Gets Logged

The health check endpoint only logs:
- **Failed health checks** (status 503)
- **Slow health checks** (> 1 second response time)

This prevents log spam from frequent health checks while capturing important diagnostic information.

### Log Format

**Local file format:**
```
[Timestamp] REASON status=CODE time=TIMEms details
```

**CloudWatch Logs format (JSON):**
```json
{
  "reason": "FAILED",
  "status_code": 503,
  "response_time_ms": 156.23,
  "timestamp": 1702476225,
  "checks": {"apache": "ok", "database": "connection_failed"},
  "system": {...},
  "memory": {...},
  "apache": {...}
}
```

**Examples:**

Local file:
```
[Fri Dec 13 14:23:45 2024] FAILED status=503 time=156.23ms checks={"apache":"ok","database":"connection_failed"}
[Fri Dec 13 14:30:12 2024] SLOW status=200 time=1234.56ms checks={"apache":"ok","database":"ok"}
```

### Viewing Health Check Logs

**Local file:**
```bash
# View recent health check failures/slowness
tail -f /var/log/everything/health-check.log

# Count failures in the last hour
grep FAILED /var/log/everything/health-check.log | tail -100

# Analyze slow health checks
grep SLOW /var/log/everything/health-check.log
```

**CloudWatch Logs:**

Using the helper script (recommended):
```bash
# Follow all health check logs in real-time
./tools/tail-health-check-logs.sh

# Show only failed health checks
./tools/tail-health-check-logs.sh --failed

# Show only slow health checks
./tools/tail-health-check-logs.sh --slow

# Show logs from the last hour
./tools/tail-health-check-logs.sh --since 1h

# Show failed checks from last 30 minutes
./tools/tail-health-check-logs.sh --since 30m --failed
```

Using AWS CLI directly:
```bash
# View recent health check events
aws logs tail /aws/fargate/e2-health-check --follow --region us-west-2

# Query failed health checks from the last hour
aws logs filter-log-events \
  --log-group-name /aws/fargate/e2-health-check \
  --region us-west-2 \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '"FAILED"'

# Query slow health checks
aws logs filter-log-events \
  --log-group-name /aws/fargate/e2-health-check \
  --region us-west-2 \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '"SLOW"'
```

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
# Basic check
curl http://localhost/health.pl

# Check with pretty JSON (requires jq)
curl -s http://localhost/health.pl | jq .

# Check HTTP status code only
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/health.pl

# Detailed check with timing
time curl -s http://localhost/health.pl?detailed=1 | jq .

# Database connectivity check
curl -s http://localhost/health.pl?db=1 | jq .
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

### Step 2: Check Health Check Logs

```bash
# In the container or via ECS exec
tail -100 /var/log/everything/health-check.log

# Via CloudWatch Logs - Health Check specific logs (use helper script)
./tools/tail-health-check-logs.sh --failed

# Via CloudWatch Logs - General application logs
aws logs tail /aws/fargate/fargate-app-awslogs --follow --region us-west-2
```

### Step 3: Test Health Endpoint Manually

```bash
# From within the container
curl -v http://localhost/health.pl

# With database check
curl -v http://localhost/health.pl?db=1

# Check Apache is running
ps aux | grep apache

# Check port 80 is listening
netstat -tlnp | grep :80
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

**Symptoms:** Health checks fail after 5 seconds

**Possible causes:**
- Database connectivity issues (if using `?db=1`)
- Apache overloaded or hanging
- Network latency

**Solutions:**
1. Check if issue persists with basic health check (no `?db=1`)
2. Review Apache error logs: `tail /var/log/apache2/error.log`
3. Check database connectivity separately
4. Consider increasing health check timeout in CloudFormation

### Issue: Health checks fail during deployments

**Symptoms:** Brief health check failures during new task deployments

**Expected behavior:** This is normal during rolling deployments

**Mitigation:**
- 60-second StartPeriod allows containers to initialize
- 5 retries prevent false positives
- ECS maintains minimum healthy percentage during deployments

### Issue: Database health checks always fail

**Symptoms:** `?db=1` returns `"database":"connection_failed"`

**Possible causes:**
- Database credentials incorrect
- Database server unreachable
- Security group rules blocking connection
- Wrong database hostname in `E2_DBSERV`

**Solutions:**
1. Verify database endpoint: `echo $E2_DBSERV`
2. Test connectivity: `mysql -h $E2_DBSERV -u e2readonly -e "SELECT 1"`
3. Check security group rules allow MySQL traffic
4. Review CloudFormation database configuration

### Issue: Health checks succeed but application returns errors

**Symptoms:** `/health.pl` returns 200 OK, but application pages fail

**Explanation:** Basic health check only verifies Apache is responding

**Solutions:**
1. Use detailed health check: `curl http://localhost/health.pl?db=1`
2. Check application logs: `tail -f /var/log/everything/e2.error.log`
3. Test specific application endpoints
4. Review Apache access logs for errors

## Performance Considerations

### Health Check Impact

| Mode | Response Time | Impact | Use Case |
|------|---------------|--------|----------|
| Basic | ~10-50ms | Minimal | ECS/ELB health checks, frequent monitoring |
| Detailed | ~50-150ms | Low | Periodic diagnostics, includes system metrics |
| Database | ~150-250ms | Moderate | Troubleshooting, includes all metrics + DB test |

**Note:** Response times for detailed and database modes include gathering system load, memory usage, and Apache worker statistics.

### Recommendations

1. **ECS Container Health Checks:** Use basic mode (default)
2. **ELB Target Health Checks:** Use basic mode
3. **Monitoring Dashboards:** Use basic mode with 30-60s intervals
4. **Troubleshooting:** Use detailed or database mode as needed
5. **Automated Testing:** Use basic mode for CI/CD pipelines

## Integration with Monitoring

### CloudWatch Integration

Health check failures are visible through:
- ECS container health status
- Target group unhealthy target count
- CloudWatch Logs (if health check logging enabled)

### Custom Metrics

To create custom CloudWatch metrics from health check logs:

```bash
# Parse health check log and publish metrics
grep FAILED /var/log/everything/health-check.log | \
  wc -l | \
  aws cloudwatch put-metric-data \
    --namespace Everything2/Health \
    --metric-name HealthCheckFailures \
    --value <count>
```

### Alerting

Recommended CloudWatch alarms:
1. **Unhealthy Target Count** > 0 for 2 minutes
2. **Task Failed Health Checks** > 5 in 5 minutes
3. **Running Task Count** < Desired Count

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
│  │  Every 10s: curl http://localhost/health.pl          │ │
│  │  5 retries, 60s grace period                         │ │
│  └──────────────────────────────────────────────────────┘ │
│                       │                                     │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  Target Group Health Check     │
        │  Protocol: HTTPS               │
        │  Port: 443                     │
        │  Path: /                       │
        └───────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| [ecore/Everything/HealthCheck.pm](../ecore/Everything/HealthCheck.pm) | Health check endpoint implementation (PSGI app, wired in `app.psgi`) |
| [etc/templates/apache2.conf.erb](../etc/templates/apache2.conf.erb) | Apache reverse-proxy config for `/health` |
| [cf/everything2-production.json](../cf/everything2-production.json) | ECS health check configuration |
| [tools/test-health-check.sh](../tools/test-health-check.sh) | Health check testing script |
| [tools/diagnose-health-checks.rb](../tools/diagnose-health-checks.rb) | ECS health check diagnostics |
| `/var/log/everything/health-check.log` | Health check failure/slowness log |

## See Also

- [Infrastructure Overview](infrastructure-overview.md) - Overall system architecture
- [Delegation Migration Guide](delegation-migration.md) - Application architecture patterns
