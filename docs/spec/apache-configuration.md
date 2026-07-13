# Apache2 Production Configuration

## Overview

This document describes the Apache2 configuration for Everything2, focusing on production settings optimized for performance, security, and reliability in AWS ECS Fargate environments.

**Architecture (post-PSGI):** Apache is a **pure reverse proxy** in front of the application. All dynamic requests are proxied to a Starman/PSGI backend listening on `127.0.0.1:5000` (started by `apache2_wrapper.rb`); Apache itself runs **no application code and does not load mod_perl**. Apache uses **MPM Event** (the old mod_perl-mandated MPM Prefork is gone). The legacy mod_perl path and its `E2_PSGI` toggle were removed in the full PSGI cutover (#4234); this config is PSGI-only. See `etc/templates/apache2.conf.erb` for the live source of truth.

## Configuration Files

### Main Configuration Template

**Location:** `etc/templates/apache2.conf.erb`

This ERB template is processed by `docker/e2app/apache2_wrapper.rb` during container startup to generate the final Apache configuration.

### Virtual Host Configuration

**Location:** `etc/templates/everything.erb`

Contains the main virtual host configuration, including the reverse-proxy (`ProxyPass`/`ProxyPassReverse`) directives to the Starman backend and access control rules.

**Note:** As of the PSGI cutover, the virtual host configuration lives directly in `apache2.conf.erb` (the `<VirtualHost _default_:80>` block); the older standalone `everything.erb` mod_perl handler template is no longer the dispatcher.

## Production Settings

### Connection Handling

#### ListenBacklog

```apache
Listen 80
ListenBacklog 511
```

**Purpose:** Controls the TCP listen queue depth for incoming connections.

**Note:** The application listens only on port 80 (HTTP). TLS is terminated at the ALB, which forwards HTTP traffic to the containers.

**Value:** `511` - Maximum pending connections allowed to queue while Apache workers are busy.

**Rationale:**
- Handles traffic spikes without dropping connections
- Matches typical Linux kernel maximum (`net.core.somaxconn`)
- Provides adequate buffer for the configured `MaxRequestWorkers` (40)
- Prevents connection refused errors during bursts

**Production Impact:**
- During traffic spikes, connections wait in queue rather than being rejected
- Reduces likelihood of 503 errors from the load balancer
- Works in conjunction with ELB health checks to manage traffic flow

### Timeout Settings

```apache
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 15
```

**Timeout:** Maximum time in seconds for request/response cycle (5 minutes)
- Long enough for database-intensive operations
- Short enough to prevent resource exhaustion

**KeepAlive:** Enable persistent connections
- Reduces latency for subsequent requests from same client
- Decreases server load from TCP handshakes

**MaxKeepAliveRequests:** Maximum requests per persistent connection
- 100 requests balances connection reuse with memory management
- Prevents single connection from monopolizing worker

**KeepAliveTimeout:** Seconds to wait for next request on persistent connection
- 15 seconds balances responsiveness with worker availability
- Shorter than Timeout to free workers faster

### MPM Event Settings (Production)

```apache
<IfDefine E2_PRODUCTION>
Define E2StartServers 2
Define E2ServerLimit 4
Define E2ThreadsPerChild 25
Define E2MinSpareThreads 25
Define E2MaxSpareThreads 75
Define E2MaxRequestWorkers 100
Define E2MaxConnections 5000
</IfDefine>

<IfModule mpm_event_module>
  StartServers            ${E2StartServers}
  ServerLimit             ${E2ServerLimit}
  ThreadLimit             ${E2ThreadsPerChild}
  ThreadsPerChild         ${E2ThreadsPerChild}
  MinSpareThreads         ${E2MinSpareThreads}
  MaxSpareThreads         ${E2MaxSpareThreads}
  MaxRequestWorkers       ${E2MaxRequestWorkers}
  MaxConnectionsPerChild  ${E2MaxConnections}
</IfModule>
```

**Why MPM Event (not Prefork)?**
- mod_perl is gone, so the constraint that mandated Prefork is gone with it.
- Apache only proxies; threads handle client connections cheaply.
- **Effective request concurrency is bounded at the backend by `STARMAN_WORKERS`, not by Apache.** `MaxRequestWorkers` here is generous headroom for client connections, not a cap on parallel application work, and is *not* a per-worker-memory budget the way the old Prefork model was — Apache proxy threads are lightweight.

**StartServers (2) / ServerLimit (4) / ThreadsPerChild (25):**
- Apache spawns a small number of multi-threaded child processes.
- `ServerLimit × ThreadsPerChild` (4 × 25 = 100) is the hard ceiling, matching `MaxRequestWorkers`.

**MinSpareThreads (25) / MaxSpareThreads (75):**
- Apache maintains a pool of idle worker threads for bursts.

**MaxRequestWorkers (100):**
- Maximum concurrent connections Apache will service.
- Memory is no longer the binding constraint (no mod_perl interpreter per worker); the real application concurrency limit is the Starman worker count at `127.0.0.1:5000`.

**MaxConnectionsPerChild (5000):**
- Number of connections each child process handles before recycling, for general hygiene. Far less critical than under mod_perl, since Apache holds no application state or Perl memory.

### Development Settings

```apache
<IfDefine E2_DEVELOPMENT>
Define E2StartServers 1
Define E2ServerLimit 2
Define E2ThreadsPerChild 25
Define E2MinSpareThreads 10
Define E2MaxSpareThreads 50
Define E2MaxRequestWorkers 50
Define E2MaxConnections 0
</IfDefine>
```

**Purpose:** Lightweight configuration for local development

**MaxConnections (0):** Child processes never recycle on a connection count.

**Note:** E2_DEVELOPMENT vs E2_PRODUCTION set based on `node["override_configuration"]` in ERB template

### Security Headers

```apache
UseCanonicalName On
ServerTokens Prod
ServerSignature EMail
TraceEnable Off
```

**UseCanonicalName On:**
- Forces Apache to use ServerName for self-referential URLs
- Prevents Host header injection attacks

**ServerTokens Prod:**
- Minimal server version information in headers
- Only reveals "Apache" (not version, OS, modules)
- Reduces information leakage to attackers

**ServerSignature EMail:**
- Shows admin email in error pages
- Balances user support with security

**TraceEnable Off:**
- Disables HTTP TRACE method
- Prevents cross-site tracing (XST) attacks

### SSL/TLS Architecture

**Note:** TLS termination is handled at the ALB (no CloudFront):
- **ALB** terminates client TLS connections (TLS 1.2+ enforced)
- **Containers** receive HTTP traffic from the ALB on port 80

Apache no longer handles TLS directly. The SSL module configuration remains in the template for potential future use but is not active in the current architecture. This simplifies container configuration and reduces CPU overhead.

### Environment Variables

```apache
# AWS Fargate awareness
PassEnv AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
PassEnv AWS_DEFAULT_REGION

# Docker environment detection
PassEnv E2_DOCKER

# Application configuration
PassEnv E2_MAINTENANCE_MESSAGE
PassEnv E2_DBSERV
```

**Purpose:** Pass environment variables from the container into the proxied request environment so the application (running under Starman) can read them.

**AWS Variables:**
- Enable IAM role-based AWS API access
- Used by Everything::S3 module for S3 operations

**E2_DOCKER:**
- Signals application it's running in containerized environment
- Affects logging, paths, and resource discovery

**E2_MAINTENANCE_MESSAGE:**
- Allows dynamic maintenance page without code changes
- Set via ECS task definition environment variable

**E2_DBSERV:**
- Database server hostname/IP
- Allows different databases for dev/staging/production
- Overrides default 'localhost'

### Logging

#### Production (CloudWatch)

```apache
LogFormat "{\"time\":\"%{%Y-%m-%d}tT%{%T}t.%{msec_frac}tZ\",\"process\":\"%D\",\"filename\":\"%f\",\"remoteIP\":\"%{X-Forwarded-For}i\",\"host\":\"%V\",\"request\":\"%U\",\"query\":\"%q\",\"method\":\"%m\",\"status\":\"%>s\",\"userAgent\":\"%{User-agent}i\",\"referer\":\"%{Referer}i\"}" cloudwatch
```

**Format:** JSON for structured logging in CloudWatch Logs

**Fields:**
- `time`: ISO 8601 timestamp with milliseconds
- `process`: Request duration in microseconds
- `filename`: File that handled request (for static assets; dynamic requests are proxied to Starman)
- `remoteIP`: Client IP from X-Forwarded-For (ELB provides this)
- `host`: Virtual host name
- `request`: URI path (without query string)
- `query`: Query string parameters
- `method`: HTTP method (GET, POST, etc.)
- `status`: HTTP status code
- `userAgent`: Client user agent
- `referer`: Referring page

**Advantages:**
- CloudWatch Insights can query JSON fields
- Easy to filter, aggregate, and analyze
- No parsing required for log analysis

#### Health Check Logging

```apache
LogFormat "{\"time\":\"%{%Y-%m-%d}tT%{%T}t.%{msec_frac}tZ\",\"process\":\"%D\",\"filename\":\"%f\",\"remoteIP\":\"%a\",\"host\":\"%V\",\"request\":\"%U\",\"query\":\"%q\",\"method\":\"%m\",\"status\":\"%>s\",\"userAgent\":\"%{User-agent}i\",\"referer\":\"%{Referer}i\"}" healthlog

BrowserMatch "^ELB-HealthChecker" loghealthcheck
#CustomLog /etc/apache2/logs/healthcheck.log healthlog env=loghealthcheck
```

**Purpose:** Separate ELB health check traffic from application logs

**Note:** Currently commented out (health checks not logged)
- Reduces log volume
- Health check failures logged by application (see [health-checks.md](health-checks.md))

#### Development Logging

```apache
<IfDefine E2_DEVELOPMENT>
  ErrorLogFormat "{\"time\":\"%{%usec_frac}t\", \"function\" : \"[%-m:%l]\", \"process\" : \"[pid%P]\" ,\"message\" : \"%M\"}"
  ErrorLog "|/usr/bin/rotatelogs -f /var/log/apache2/e2.error.%Y%m%d%H.log 3600"

  SetEnvIf Remote_Addr "127\.0\.0\.1" dontlog
  SetEnvIf Request_URI "^/server_live\.html$" dontlog
  SetEnvIf Request_URI "favicon.ico$" dontlog
  SetEnvIf Request_URI "^/robots\.txt$" dontlog
</IfDefine>
```

**Development Features:**
- JSON error logs with microsecond timestamps
- Rotated hourly via rotatelogs
- Filters out noise (loopback, health checks, favicon, robots.txt)

### Access Control

```apache
HostnameLookups Off
AccessFileName .htaccess

<Files ~ "^\.ht">
  Order allow,deny
  Deny from all
  Satisfy all
</Files>
```

**HostnameLookups Off:**
- Disables reverse DNS lookups for client IPs
- **Critical for performance:** DNS lookups can add 100-500ms per request
- IP addresses logged instead of hostnames

**AccessFileName:**
- Defines `.htaccess` for directory-level overrides
- Used for legacy compatibility

**Files Protection:**
- Prevents access to `.htaccess` and `.htpasswd` files
- Blocks potential information disclosure
- Denies all access regardless of other rules

## Performance Tuning

### Capacity Planning

**Post-PSGI, Apache is not the concurrency constraint.** The old "MaxRequestWorkers = available memory / 150MB per mod_perl worker" formula no longer applies — Apache proxy threads are lightweight and hold no Perl interpreter or application memory. Real application concurrency is governed by the number of **Starman workers** (`STARMAN_WORKERS`) at the `127.0.0.1:5000` backend; size that against container CPU/RAM and database connection budget. Apache's `MaxRequestWorkers` (100 in prod) is generous connection headroom in front of that backend.

### Monitoring Recommendations

**Key metrics to monitor:**

1. **Apache Connection Utilization** (`mod_status` is enabled at `/server-status`, localhost only):
   ```bash
   curl http://localhost/server-status?auto
   ```
   - Watch `BusyWorkers` / `MaxRequestWorkers` ratio for proxy saturation.
   - Sustained saturation more often points to the **Starman backend** being the bottleneck (workers all busy) than to Apache itself — check backend worker count first.

2. **Memory Usage:**
   ```bash
   docker stats e2devapp
   ```
   - Monitor container memory limit
   - If near limit, reduce workers or increase container memory

3. **Connection Queue Depth:**
   - CloudWatch metrics: `SurgeQueueLength` on ALB
   - If frequently > 0, may need more workers or ListenBacklog adjustment

4. **Response Times:**
   - CloudWatch metrics: `TargetResponseTime` on ALB
   - Correlate with worker utilization and queue depth

### Scaling Considerations

**Vertical Scaling (increase container resources):**
- Increase Fargate task CPU/memory and raise the **Starman worker count** — that is the lever that adds application concurrency.
- Apache's `MaxRequestWorkers` rarely needs raising in lockstep, since proxy threads are cheap.

**Horizontal Scaling (add more containers):**
- Increase ECS service desired count
- Auto-scaling based on CPU or custom metrics
- More predictable than vertical scaling
- Better fault tolerance

**ListenBacklog Tuning:**
- If ALB `SurgeQueueLength` frequently > 0, may indicate backlog too small
- If containers have sustained high CPU but low memory, increase ListenBacklog
- Maximum effective value limited by kernel `net.core.somaxconn`

## Troubleshooting

### Container Won't Start

**Check Apache configuration syntax:**
```bash
./tools/shell.sh
apache2ctl configtest
```

**Common issues:**
- Invalid ERB template syntax in `etc/templates/*.erb`
- Missing required modules in `mods-enabled/`
- Port 80 already bound

### Connection Refused / 503 Errors

**Possible causes:**
1. **Starman backend saturated/down:** All Starman workers busy, or the backend on `127.0.0.1:5000` isn't responding — Apache returns 502/503 from the proxy. Check the backend first.
2. **All proxy workers busy:** Check `BusyWorkers` at `/server-status`
3. **ListenBacklog exceeded:** Increase backlog or add workers
4. **Container memory limit:** Check `docker stats`, may be OOM killing
5. **Health check failing:** See [health-checks.md](health-checks.md)

**Debug steps:**
```bash
# Check worker status
curl http://localhost/server-status?auto

# Check listen queue
ss -ltn | grep ':80'

# Check container resources
docker stats e2devapp

# Check error logs
tail -f /var/log/apache2/e2.error.*.log
```

### High Memory Usage

Under PSGI, application memory lives in the **Starman worker processes**, not in Apache. Investigate the `starman`/`perl` processes rather than `apache2`:

```bash
# Memory by process
ps aux --sort=-%mem | head -20

# Starman backend memory
ps aux | grep -E 'starman|perl' | awk '{s+=$6} END {print s/1024 "MB total"}'
```

**Solutions:**
- Tune the Starman worker count and per-worker request limit (workers recycle to bound memory).
- Profile application code with NYTProf to find leaks.
- Check for circular references in Perl objects.

## Related Documentation

- [Health Checks](health-checks.md) - Health check configuration and troubleshooting
- [Apache Access Blocks](apache_blocks.md) - IP and user agent blocking
- [Infrastructure Overview](infrastructure-overview.md) - AWS architecture
- [Getting Started](GETTING_STARTED.md) - Development environment setup

## Configuration Templates Reference

### apache2.conf.erb

Main Apache configuration template. Processes based on environment:
- `E2_DEVELOPMENT`: Lightweight, profiling-friendly
- `E2_PRODUCTION`: Optimized for production workloads

### Virtual Host (in apache2.conf.erb)

The `<VirtualHost _default_:80>` block in `apache2.conf.erb` provides:
- Reverse-proxy directives (`ProxyPass` / `ProxyPassReverse`) to the Starman backend on `127.0.0.1:5000`, with `nocanon` and `disablereuse=On`
- Static-asset `ProxyPass ... !` exclusions (css, react, images, static, js, sound, fonts, favicon, robots.txt, verification files, sitemap)
- Access control rules from `apache_blocks.json`
- Document root and directory settings
- Edge compression (brotli with gzip fallback)

### apache2_wrapper.rb

Ruby script that processes ERB templates at container startup:
1. Reads environment variables
2. Loads JSON configuration files
3. Processes ERB templates
4. Generates final Apache configuration
5. Starts Apache with generated config

**Location:** `docker/e2app/apache2_wrapper.rb`

## Security Best Practices

1. **Keep SSL/TLS Current:**
   - Update `SSLProtocol` to require TLS 1.2+ minimum
   - Review `SSLCipherSuite` quarterly against Mozilla SSL Config Generator

2. **Minimize Information Disclosure:**
   - Keep `ServerTokens Prod` (never Full)
   - Disable directory listings
   - Custom error pages without version info

3. **Regular Security Updates:**
   - Keep base Docker image updated
   - Update Apache and Perl/Starman packages
   - Monitor CVEs for Apache and OpenSSL

4. **Access Control:**
   - Application-level IP blacklist enforcement (no WAF — see [infrastructure-overview.md](infrastructure-overview.md))
   - Review `apache_blocks.json` regularly
   - Monitor failed requests in logs

5. **Resource Limits:**
   - Set `LimitRequestBody` for POST requests
   - Use `mod_reqtimeout` to prevent slowloris attacks
   - Rate limiting is handled at the app layer (no WAF tier)

## Future Improvements

**Potential optimizations:**

1. **HTTP/2 Support:**
   - Now unblocked: mod_perl is gone and Apache already runs MPM Event, so the historical "not compatible with mod_perl / requires Prefork→Event switch" obstacle no longer applies.
   - Enabling HTTP/2 origin-side (or at the ALB) is an optional follow-up.

2. **Request Coalescing:**
   - Implement request queue at application layer
   - Batch similar requests (e.g., multiple users loading same node)
   - Reduce database load

3. **Database Connection Pooling:**
   - Connection lifecycle is now owned by the Starman worker processes (each worker holds its own DB handle), not by Apache::DBI. Tune persistence at the application/Starman layer.

---

*Last updated: June 2026 (post-PSGI: Apache is a pure mpm_event reverse proxy to Starman; mod_perl removed)*
