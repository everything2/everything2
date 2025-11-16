# Apache2 Production Configuration

## Overview

This document describes the Apache2 configuration for Everything2, focusing on production settings optimized for performance, security, and reliability in AWS ECS Fargate environments.

## Configuration Files

### Main Configuration Template

**Location:** `etc/templates/apache2.conf.erb`

This ERB template is processed by `docker/e2app/apache2_wrapper.rb` during container startup to generate the final Apache configuration.

### Virtual Host Configuration

**Location:** `etc/templates/everything.erb`

Contains the main virtual host configuration, including mod_perl handlers and access control rules.

## Production Settings

### Connection Handling

#### ListenBacklog

```apache
Listen 80
ListenBacklog 511

Listen 443
ListenBacklog 511
```

**Purpose:** Controls the TCP listen queue depth for incoming connections.

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

### MPM Prefork Settings (Production)

```apache
<IfDefine E2_PRODUCTION>
Define E2StartServers 15
Define E2MinSpareServers 15
Define E2MaxSpareServers 20
Define E2MaxRequestWorkers 40
Define E2MaxConnections 10000
</IfDefine>

<IfModule mpm_prefork_module>
  StartServers         ${E2StartServers}
  MinSpareServers      ${E2MinSpareServers}
  MaxSpareServers      ${E2MaxSpareServers}
  MaxRequestWorkers    ${E2MaxRequestWorkers}
  MaxConnectionsPerChild ${E2MaxConnections}
</IfModule>
```

**Why MPM Prefork?**
- Required for mod_perl compatibility
- Each worker is isolated (safer for legacy code)
- Simpler memory management for Perl

**StartServers (15):**
- Number of child processes to spawn at startup
- Ensures immediate capacity without warmup delay
- Sized for typical baseline traffic

**MinSpareServers (15) / MaxSpareServers (20):**
- Apache maintains pool of idle workers
- Ensures workers available for traffic bursts
- Narrow range (15-20) keeps resource usage predictable

**MaxRequestWorkers (40):**
- Maximum concurrent Apache processes
- **CRITICAL LIMIT:** Constrained by container memory
- Fargate task definition must allocate sufficient memory
- Each mod_perl worker can use 100-200MB of RAM
- 40 workers × 150MB ≈ 6GB + overhead = ~8GB container

**MaxConnectionsPerChild (10000):**
- Number of requests each worker handles before recycling
- Prevents memory leaks from accumulating
- 10,000 balances worker longevity with memory hygiene
- With 40 workers: 400,000 total requests between full recycling

### Development Settings

```apache
<IfDefine E2_DEVELOPMENT>
Define E2StartServers 2
Define E2MinSpareServers 2
Define E2MaxSpareServers 2
Define E2MaxRequestWorkers 2
Define E2MaxConnections 0
</IfDefine>
```

**Purpose:** Lightweight configuration for local development

**MaxRequestWorkers (2):** Minimal workers for profiling with NYTProf
**MaxConnections (0):** Workers never recycle (preserves profiling data)

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

### SSL/TLS Configuration

```apache
<IfModule mod_ssl.c>
  SSLRandomSeed startup builtin
  SSLRandomSeed startup file:/dev/urandom 512
  SSLRandomSeed connect builtin
  SSLRandomSeed connect file:/dev/urandom 512

  SSLSessionCache        shmcb:${APACHE_RUN_DIR}/ssl_scache(512000)
  SSLSessionCacheTimeout  300

  SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5:!RC4

  # enable only TLSv1
  SSLProtocol all -SSLv2 -SSLv3
</IfModule>
```

**SSLRandomSeed:**
- Uses `/dev/urandom` for cryptographically secure random numbers
- 512 bytes at startup and per connection
- Essential for session keys and encryption

**SSLSessionCache:**
- Shared memory cache for SSL session resumption
- 512KB cache size
- Reduces CPU overhead of TLS handshakes
- Improves connection performance

**SSLSessionCacheTimeout (300):**
- 5 minutes session cache lifetime
- Balances security (shorter = more handshakes) with performance

**SSLCipherSuite:**
- HIGH: Strong encryption (256-bit AES)
- MEDIUM: Acceptable encryption (128-bit)
- !aNULL: Reject anonymous ciphers (no authentication)
- !MD5: Reject weak MD5-based ciphers
- !RC4: Reject vulnerable RC4 stream cipher

**SSLProtocol:**
- Enables TLS 1.0+ (modern browsers support TLS 1.2+)
- Disables SSLv2 (broken, 1995)
- Disables SSLv3 (POODLE vulnerability, 2014)

**Note:** Consider updating to `TLSv1.2` minimum for improved security

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

**Purpose:** Pass environment variables from container to mod_perl code

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
- `filename`: File that handled request (for mod_perl debugging)
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

**Formula for MaxRequestWorkers:**

```
MaxRequestWorkers = (Available_Memory - OS_Overhead) / Worker_Memory
```

**Example calculation:**
- Container memory: 8GB (8192MB)
- OS/Apache overhead: 1GB (1024MB)
- Available: 7GB (7168MB)
- Average worker size: 150MB
- Max workers: 7168 / 150 = **47 workers**

**Current setting:** 40 workers (conservative, allows headroom)

### Monitoring Recommendations

**Key metrics to monitor:**

1. **Apache Worker Utilization:**
   ```bash
   curl http://localhost/server-status?auto
   ```
   - Watch `BusyWorkers` / `MaxRequestWorkers` ratio
   - If consistently > 90%, increase workers or container size

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
- Increase Fargate task memory: 8GB → 16GB
- Increase MaxRequestWorkers: 40 → 80
- Monitor memory per worker to ensure headroom

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
- Port conflicts (80, 443 already bound)

### Workers Recycling Too Frequently

**Symptoms:**
- High CPU usage
- Increased latency
- Memory usage climbs then drops repeatedly

**Solutions:**
- Increase `MaxConnectionsPerChild` (10000 → 20000)
- Reduce worker memory footprint (profile with NYTProf)
- Check for memory leaks in mod_perl code

### Connection Refused / 503 Errors

**Possible causes:**
1. **All workers busy:** Check `BusyWorkers` at `/server-status`
2. **ListenBacklog exceeded:** Increase backlog or add workers
3. **Container memory limit:** Check `docker stats`, may be OOM killing
4. **Health check failing:** See [health-checks.md](health-checks.md)

**Debug steps:**
```bash
# Check worker status
curl http://localhost/server-status?auto

# Check listen queue
ss -ltn | grep ':80\|:443'

# Check container resources
docker stats e2devapp

# Check error logs
tail -f /var/log/apache2/e2.error.*.log
```

### High Memory Usage

**Investigation:**
```bash
# Memory by process
ps aux --sort=-%mem | head -20

# Apache worker memory
ps aux | grep apache2 | awk '{print $6}' | awk '{s+=$1} END {print s/1024 "MB total"}'

# Average per worker
ps aux | grep apache2 | awk '{s+=$6; c++} END {print s/c/1024 "MB average"}'
```

**Solutions:**
- Reduce `MaxRequestWorkers` if exceeding container memory
- Decrease `MaxConnectionsPerChild` to recycle workers sooner
- Profile code with NYTProf to find memory leaks
- Check for circular references in Perl objects

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

### everything.erb

Virtual host configuration template. Includes:
- mod_perl handlers
- Access control rules from `apache_blocks.json`
- Document root and directory settings
- Custom error pages

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
   - Update mod_perl and Apache packages
   - Monitor CVEs for Apache and OpenSSL

4. **Access Control:**
   - Use WAF rules (see [infrastructure-overview.md](infrastructure-overview.md))
   - Review `apache_blocks.json` regularly
   - Monitor failed requests in logs

5. **Resource Limits:**
   - Set `LimitRequestBody` for POST requests
   - Use `mod_reqtimeout` to prevent slowloris attacks
   - Configure rate limiting at WAF level

## Future Improvements

**Potential optimizations:**

1. **HTTP/2 Support:**
   - Requires switch from MPM Prefork to MPM Event
   - Not compatible with mod_perl
   - Would require significant refactoring

2. **TLS 1.3:**
   - Update OpenSSL version
   - Update `SSLProtocol` directive
   - Test compatibility with CloudFront

3. **Request Coalescing:**
   - Implement request queue at application layer
   - Batch similar requests (e.g., multiple users loading same node)
   - Reduce database load

4. **Connection Pooling:**
   - Currently using Apache::DBI
   - Consider persistent connection management improvements
   - Monitor connection lifecycle

5. **Graceful Worker Recycling:**
   - Implement signal handling for worker replacement
   - Avoid request interruption during recycling
   - Better memory management without user impact
