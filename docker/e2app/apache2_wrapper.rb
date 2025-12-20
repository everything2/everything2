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

if ENV['E2_DOCKER'].eql? "development"
  # Create development log file with world-writable permissions for tests
  STDERR.puts "Setting up development log file"
  `touch /tmp/development.log`
  `chmod 777 /tmp/development.log`
  # Link Apache error_log to development.log for easier debugging
  `rm -f /etc/apache2/logs/error_log`
  `ln -s /tmp/development.log /etc/apache2/logs/error_log`
  exec("/usr/sbin/apachectl -k start; sleep infinity & wait")
else
  `rm -f /etc/apache2/logs/error_log`
  `ln -s /dev/stderr /etc/apache2/logs/error_log`
  exec("/usr/sbin/apachectl -D FOREGROUND")
end
