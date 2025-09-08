#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'
require 'erb'

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

  ['recaptcha_v3_secret','infected_ips_secret','banned_user_agents_secret','banned_ips_secret','banned_ipblocks_secret'].each do |value|
    STDERR.puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end
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
