#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'

STDERR.puts "Starting E2 Apache wrapper"

['E2DOCKER','AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'].each do |var|
  if ENV[var].nil?
    STDERR.puts "#{var} is missing"
  else
    STDERR.puts "#{var} is: '#{ENV[var]}'"
  end
end

if !ENV['E2DOCKER'].nil? and !ENV['E2DOCKER'].eql? "development"
  s3client = Aws::S3::Client.new(region: 'us-west-2');
  secretsbucket = "secrets.everything2.com"
  location = "/etc/everything"

  ['recaptcha_v3_secret','infected_ips_secret','banned_user_agents_secret','banned_ips_secret','banned_ipblocks_secret'].each do |value|
    STDERR.puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end
end

`rm -f /etc/apache2/logs/error_log`
`ln -s /dev/stderr /etc/apache2/logs/error_log`

exec("/usr/sbin/apachectl -D FOREGROUND")
