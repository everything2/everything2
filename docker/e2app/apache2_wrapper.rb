#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'


if !ENV['E2DOCKER'].nil? and !ENV['E2DOCKER'].eql? "development"
  s3client = Aws::S3::Client.new(region: 'us-west-2');
  secretsbucket = "secrets.everything2.com"
  location = "/etc/everything"

  ['recaptcha_v3_secret','infected_ips_secret','banned_user_agents_secret','banned_ips_secret','banned_ipblocks_secret'].each do |value|
    puts "Downloading secret '#{value}' to disk"
    s3client.get_object(response_target: "#{location}/#{value}", bucket: secretsbucket, key: value)
  end
end

exec("/usr/sbin/apachectl -D FOREGROUND")
