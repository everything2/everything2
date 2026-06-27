#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'
require 'erb'
require 'json'

STDERR.puts "Starting E2 Apache wrapper"

bootstrap = '/var/bootstrap/etc'

unless Dir.exist? bootstrap
  puts "Could not find bootstrap directory: #{bootstrap}"
  exit
end

files = [{template: "#{bootstrap}/apache2.conf.erb", file: '/etc/apache2/apache2.conf'}]

if ENV['E2_DOCKER'].nil? or !ENV['E2_DOCKER'].eql? "development"
  s3client = Aws::S3::Client.new(region: 'us-west-2');
  secretsbucket = "secrets.everything2.com"
  location = "/etc/everything"

  # Download actual secrets and infected_ips (used by Everything::Configuration)
  # Apache blocks (banned_ips, banned_ipblocks, banned_user_agents) now in source control
  ['recaptcha_v3_secret', 'recaptcha_enterprise_api_key', 'infected_ips_secret'].each do |value|
    STDERR.puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end

  # Download database password from S3 (uses gateway endpoint, reliable at startup)
  STDERR.puts "Downloading database password from S3"
  s3client.get_object(response_target: "#{location}/database_password_secret", bucket: secretsbucket, key: 'database_password_secret')

  STDERR.puts "Apache access blocks loaded from source control: /var/everything/etc/apache_blocks.json"
end

files.each do |f|
  template = ERB.new(File.open(f[:template]).read)

  variables = {}

  if ENV['E2_DOCKER'].eql? 'development'
    variables['override_configuration'] = "development"
  end

  bind = binding
  bind.local_variable_set(:node, variables)

  File.write(f[:file], template.result(bind))
end

# Build the Starman supervisor command (the app backend, in both dev and prod).
# Tunable via env with sane, memory-aware defaults derived from how we already
# size Apache prefork:
#   STARMAN_WORKERS (default 16) -- worker process count. PSGI needs FEWER workers
#       than mod_perl's MaxRequestWorkers because the Apache proxy + disablereuse
#       decouple client connections from workers (keep-alive / slow clients no
#       longer pin a worker; a worker is busy only while actually processing).
#       Size to roughly (task RAM - headroom) / per-worker RSS; override per env.
#   STARMAN_MAX_REQUESTS (default 1000) -- recycle each worker after N requests.
#       Bounds any slow per-request leak -- the analog of mod_perl's
#       Apache::SizeLimit, which the persistent-worker model otherwise lacks.
#   --preload-app -- compile app.psgi in the master and fork, so workers share the
#       interpreter via copy-on-write instead of each loading ~the full app RSS
#       independently (the dominant memory lever, exactly like mod_perl prefork's
#       shared parent). E2 opens its DB handle lazily per worker (NodeBase
#       connect_cached on first request), so nothing live crosses the fork.
def starman_supervisor(logdest)
  workers = ENV.fetch('STARMAN_WORKERS', '16')
  maxreq  = ENV.fetch('STARMAN_MAX_REQUESTS', '1000')
  "while true; do " \
    "PERL5LIB=/var/libraries/lib/perl5:/var/everything/ecore " \
    "/var/libraries/bin/starman --preload-app --workers #{workers} --max-requests #{maxreq} " \
    "--listen 127.0.0.1:5000 /var/everything/app.psgi >> #{logdest} 2>&1; " \
    "echo 'starman exited, restarting in 1s' >> #{logdest}; sleep 1; done"
end

# The in-webhead cron sidecar (docs/cron-sidecar-design.md). Supervised restart
# loop just like Starman's: if it dies it comes back and re-contends for the
# GET_LOCK leader lock. Every webhead runs one; exactly one wins the lock and runs
# due jobs, the rest idle. Defaults to --dry-run (SHADOW MODE: elect + heartbeat +
# log "would run X", but run nothing) so it is safe to ship before cutover; set
# E2_CRON_LIVE=1 to actually run jobs. This is how the EventBridge->Fargate cron
# rules get retired without a flag-day.
def cron_runner_supervisor(logdest)
  # Dev always runs LIVE (keeps the datastash/newwriteups objects fresh in dev,
  # which dev otherwise lacks any cron to do); prod is dry-run shadow unless
  # E2_CRON_LIVE=1. cron_runner.pl runs ONE pass (run_once) and exits, so we loop
  # it ~every minute -- the periodic model holds nothing between runs.
  live = ENV['E2_CRON_LIVE'].eql?('1') || ENV['E2_DOCKER'].eql?('development')
  mode = live ? '' : '--dry-run'
  "while true; do " \
    "PERL5LIB=/var/libraries/lib/perl5:/var/everything/ecore " \
    "/usr/bin/perl /var/everything/cron/cron_runner.pl #{mode} >> #{logdest} 2>&1; " \
    "sleep 60; done"
end

if ENV['E2_DOCKER'].eql? "development"
  # Dev DB password: mirror the dev DB wrapper's everyuser (caching_sha2 BY 'blah')
  # so the app exercises the full caching_sha2-with-password handshake (#4122).
  # No trailing newline -- _filesystem_default() reads the secret file verbatim.
  STDERR.puts "Writing development database_password_secret"
  File.write('/etc/everything/database_password_secret', 'blah')
  # Create development log file with world-writable permissions for tests
  STDERR.puts "Setting up development log file"
  `touch /tmp/development.log`
  `chmod 777 /tmp/development.log`
  # Link Apache error_log to development.log for easier debugging
  `rm -f /etc/apache2/logs/error_log`
  `ln -s /tmp/development.log /etc/apache2/logs/error_log`
  STDERR.puts "Starting Starman PSGI backend on 127.0.0.1:5000"
  # Keep Starman alive in the background, then start Apache (pure reverse proxy).
  spawn("/bin/bash", "-c", starman_supervisor("/tmp/development.log"))
  STDERR.puts "Starting cron runner sidecar (LIVE in dev -- keeps datastash fresh)"
  spawn("/bin/bash", "-c", cron_runner_supervisor("/tmp/development.log"))
  exec("/usr/sbin/apachectl -k start; sleep infinity & wait")
else
  `rm -f /etc/apache2/logs/error_log`
  `ln -s /dev/stderr /etc/apache2/logs/error_log`
  # Production: run the Starman supervisor (logging to stderr for CloudWatch)
  # before handing the foreground to Apache, which reverse-proxies to it.
  STDERR.puts "Starting Starman PSGI backend on 127.0.0.1:5000"
  spawn("/bin/bash", "-c", starman_supervisor("/dev/stderr"))
  # Cron sidecar ships DARK in prod: not spawned at all unless explicitly enabled,
  # so the code/tables can land while the EventBridge cron stays the source of
  # truth. Staged cutover: E2_CRON_ENABLED=1 spawns it in dry-run shadow (elects a
  # leader + heartbeats, runs nothing); then E2_CRON_LIVE=1 actually runs jobs.
  if ENV['E2_CRON_ENABLED'].eql?('1')
    STDERR.puts "Starting cron runner sidecar (#{ENV['E2_CRON_LIVE'].eql?('1') ? 'LIVE' : 'shadow/dry-run'})"
    spawn("/bin/bash", "-c", cron_runner_supervisor("/dev/stderr"))
  end
  exec("/usr/sbin/apachectl -D FOREGROUND")
end
