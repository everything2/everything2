# Apache Access Blocks Configuration

## Overview

This file documents the Apache access control configuration for Everything2, which is stored in `etc/apache_blocks.json` and loaded during Apache startup.

## Configuration File

**Location:** `etc/apache_blocks.json`

**Format:** JSON

## Structure

```json
{
  "comment": "Apache access control configuration for Everything2",
  "banned_user_agents": [
    "HTTrack 3.0x",
    "BLEXBot/1.0",
    "DataForSeoBot/1.0"
  ],
  "banned_ips": [
    "97.66.136.146",
    "37.0.121.104"
  ],
  "banned_ipblocks": [
    "221.204",
    "34.174"
  ]
}
```

## Fields

### `banned_user_agents`
Array of user agent strings to block. These are matched case-insensitively using Apache's `BrowserMatchNoCase` directive.

**Common examples:**
- Web scrapers: `HTTrack`, `wget`, `curl`
- Malicious bots: `BLEXBot`, `DataForSeoBot`

### `banned_ips`
Array of individual IP addresses to block. These are matched against the `X-FORWARDED-FOR` header (ELB passes client IP here).

**Format:** Full IP address (e.g., `"97.66.136.146"`)

### `banned_ipblocks`
Array of IP address prefixes to block entire subnets. These use regex pattern matching.

**Format:** First octets without trailing dot (e.g., `"221.204"` blocks all IPs starting with `221.204.*`)

## How It Works

1. **Build time:** The `apache_blocks.json` file is committed to source control in `etc/`
2. **Container startup:** The source code is deployed to `/var/everything/` in the Docker container
3. **Apache startup:** The `apache2_wrapper.rb` script processes ERB templates
4. **Template rendering:** `etc/templates/everything.erb` reads the JSON file from `/var/everything/etc/apache_blocks.json` and generates Apache directives:
   - `SetEnvIf X-FORWARDED-FOR "IP" denyip` for individual IPs
   - `SetEnvIf X-FORWARDED-FOR ^BLOCK denyip` for IP blocks (regex)
   - `BrowserMatchNoCase "UA" denyip` for user agents
5. **Request blocking:** Apache denies requests with `deny from env=denyip`

## Adding New Blocks

### To block a user agent:
```json
{
  "banned_user_agents": [
    "HTTrack 3.0x",
    "NewBadBot/1.0"  // Add here
  ]
}
```

### To block an IP address:
```json
{
  "banned_ips": [
    "97.66.136.146",
    "123.45.67.89"  // Add here
  ]
}
```

### To block an IP range:
```json
{
  "banned_ipblocks": [
    "221.204",
    "123.45"  // Blocks all 123.45.*.* IPs
  ]
}
```

## Deployment

Changes to this file require:
1. Commit the updated `etc/apache_blocks.json` to source control
2. Deploy the updated code (Docker image rebuild)
3. Restart Apache (container restart)

**Note:** This is now part of the application deployment, not a separate secrets update.

## Analyzing Bot Traffic

Use the bot spike analysis tool to identify candidates for blocking:

```bash
# Download logs from S3
./tools/download-elb-logs.sh ../e2-loganalysis

# Analyze logs
cd ../e2-loganalysis
../everything2/tools/bot-spike-analysis.rb --min-requests 1000

# Include Apache-blocked bots to verify blocks are working
../everything2/tools/bot-spike-analysis.rb --include-403

# Analyze only recent traffic (faster for large log collections)
../everything2/tools/bot-spike-analysis.rb --lookback 1h   # Last hour
../everything2/tools/bot-spike-analysis.rb --lookback 1d   # Last day
../everything2/tools/bot-spike-analysis.rb --lookback 1w   # Last week
```

See [tools/bot-spike-analysis.rb](../tools/bot-spike-analysis.rb) for more options.

## Validation

Before committing changes, validate the JSON file:

```bash
# Validate JSON structure and IP formats
./etc/validate_apache_blocks.rb

# Test Apache configuration generation
./etc/test_apache_config_generation.rb
```

## Relationship to infected_ips_secret

**Note:** There is a separate `infected_ips_secret` file downloaded from S3 that is used by `Everything::Configuration` for user-space IP bans. This is **not** part of the Apache configuration and remains in S3.

- **Apache blocks** (this file): Blocked at Apache level, never reach the application
- **infected_ips_secret**: Downloaded from S3, used by application code for additional filtering

## Related Files

- `etc/apache_blocks.json` - This configuration file
- `etc/templates/everything.erb` - ERB template that reads this file
- `docker/e2app/apache2_wrapper.rb` - Script that processes templates
- `etc/validate_apache_blocks.rb` - Validation script
- `etc/test_apache_config_generation.rb` - Configuration generation test
- `tools/bot-spike-analysis.rb` - Tool for analyzing bot traffic
- `tools/download-elb-logs.sh` - Tool for downloading ELB logs from S3

## Security Note

IP addresses and user agents that are blocked are **not secrets**. They are public information about traffic patterns. The actual secrets (like reCAPTCHA keys and infected_ips used by application code) remain in S3.
