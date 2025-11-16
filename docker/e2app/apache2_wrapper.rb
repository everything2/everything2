#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'aws-sdk-secretsmanager'
require 'getoptlong'
require 'erb'
require 'json'

STDERR.puts "Starting E2 Apache wrapper"

bootstrap = '/var/bootstrap/etc'

unless Dir.exist? bootstrap
  puts "Could not find bootstrap directory: #{bootstrap}"
  exit
end

files = [{template: "#{bootstrap}/apache2.conf.erb", file: '/etc/apache2/apache2.conf'},
	 {template: "#{bootstrap}/everything.erb", file: '/etc/apache2/everything.conf'}]

if ENV['E2_DOCKER'].nil? or !ENV['E2_DOCKER'].eql? "development"
  s3client = Aws::S3::Client.new(region: 'us-west-2');
  secretsbucket = "secrets.everything2.com"
  location = "/etc/everything"

  # Download actual secrets and infected_ips (used by Everything::Configuration)
  # Apache blocks (banned_ips, banned_ipblocks, banned_user_agents) now in source control
  ['recaptcha_v3_secret', 'infected_ips_secret'].each do |value|
    STDERR.puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end

  # Download database password from AWS SecretsManager
  # This makes it available to standalone scripts (health.pl, container-health-check.pl)
  begin
    STDERR.puts "Fetching database password from SecretsManager"
    secrets_client = Aws::SecretsManager::Client.new(region: 'us-west-2')
    secret_value = secrets_client.get_secret_value(secret_id: 'E2DBMasterPassword')
    secret_data = JSON.parse(secret_value.secret_string)

    File.write("#{location}/database_password_secret", secret_data['password'])
    STDERR.puts "Database password written to filesystem"
  rescue => e
    STDERR.puts "Warning: Failed to fetch database password from SecretsManager: #{e.message}"
    STDERR.puts "Standalone health check scripts may fail in production"
  end

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

`rm -f /etc/apache2/logs/error_log`
`ln -s /dev/stderr /etc/apache2/logs/error_log` unless ENV['E2_DOCKER'].eql? "development"

if ENV['E2_DOCKER'].eql? "development"
  exec("/usr/sbin/apachectl -k start; sleep infinity & wait")
else
  exec("/usr/sbin/apachectl -D FOREGROUND")
end
