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

  # PSGI/Starman mode toggle (PSGI migration). When E2_PSGI is set, render the
  # proxy-to-Starman Apache config (Define E2_PSGI) instead of the mod_perl path.
  variables['psgi'] = !ENV['E2_PSGI'].nil?

  bind = binding
  bind.local_variable_set(:node, variables)

  File.write(f[:file], template.result(bind))
end

# Build the Starman supervisor command (used in BOTH dev and prod under E2_PSGI).
# Tunable via env with sane, memory-aware defaults derived from how we already
# size Apache prefork:
#   STARMAN_WORKERS (default 10) -- worker process count. PSGI needs FEWER workers
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
  workers = ENV.fetch('STARMAN_WORKERS', '10')
  maxreq  = ENV.fetch('STARMAN_MAX_REQUESTS', '1000')
  "while true; do " \
    "PERL5LIB=/var/libraries/lib/perl5:/var/everything/ecore " \
    "/var/libraries/bin/starman --preload-app --workers #{workers} --max-requests #{maxreq} " \
    "--listen 127.0.0.1:5000 /var/everything/app.psgi >> #{logdest} 2>&1; " \
    "echo 'starman exited, restarting in 1s' >> #{logdest}; sleep 1; done"
end

# Under E2_PSGI, Apache is a pure reverse proxy to Starman and runs no app code,
# so don't load mod_perl at all. Drop its module symlink before Apache starts.
# Every Perl* directive in the rendered config is guarded behind <IfDefine
# !E2_PSGI>, so Apache parses cleanly without the module. This removes both the
# redundant mod_perl interpreter AND the second in-memory copy of the whole app
# that the PerlModule Everything... preloads would load into every Apache worker.
unless ENV['E2_PSGI'].nil?
  %w[perl.load perl.conf].each do |m|
    f = "/etc/apache2/mods-enabled/#{m}"
    File.delete(f) if File.exist?(f)
  end
  STDERR.puts "E2_PSGI: mod_perl not loaded (Apache is a pure proxy)"
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
  unless ENV['E2_PSGI'].nil?
    STDERR.puts "Starting Starman PSGI backend on 127.0.0.1:5000 (E2_PSGI mode)"
    # Keep Starman alive in the background, then start Apache.
    spawn("/bin/bash", "-c", starman_supervisor("/tmp/development.log"))
  end
  exec("/usr/sbin/apachectl -k start; sleep infinity & wait")
else
  `rm -f /etc/apache2/logs/error_log`
  `ln -s /dev/stderr /etc/apache2/logs/error_log`
  # Production: under E2_PSGI, run the same Starman supervisor (logging to stderr
  # for CloudWatch) before handing the foreground to Apache. Without this the prod
  # path would render the proxy config but have no backend to proxy to.
  unless ENV['E2_PSGI'].nil?
    STDERR.puts "Starting Starman PSGI backend on 127.0.0.1:5000 (E2_PSGI mode)"
    spawn("/bin/bash", "-c", starman_supervisor("/dev/stderr"))
  end
  exec("/usr/sbin/apachectl -D FOREGROUND")
end
