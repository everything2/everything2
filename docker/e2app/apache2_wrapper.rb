#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'

STDERR.puts "Starting E2 Apache wrapper"

if ENV['E2_DOCKER'].nil? or !ENV['E2_DOCKER'].eql? "development"
  s3client = Aws::S3::Client.new(region: 'us-west-2');
  secretsbucket = "secrets.everything2.com"
  location = "/etc/everything"

  ['recaptcha_v3_secret','infected_ips_secret','banned_user_agents_secret','banned_ips_secret','banned_ipblocks_secret'].each do |value|
    STDERR.puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end
end

`rm -f /etc/apache2/logs/error_log`
`ln -s /dev/stderr /etc/apache2/logs/error_log` unless ENV['E2_DOCKER'].eql? "development"

exec("/usr/sbin/apachectl -D FOREGROUND")
