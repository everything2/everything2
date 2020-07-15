#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'

@s3client = Aws::S3::Client.new(region: 'us-west-2');

@secretsbucket = "secrets.everything2.com"
@location = "/etc/everything"

opts = GetoptLong.new(
  ['--secret', GetoptLong::REQUIRED_ARGUMENT]
)

opts.each do |key,value|
  case key
  when '--secret'
    puts "Downloading secret '#{value}' to disk"
    @s3client.get_object(response_target: "#{@location}/#{value}", bucket: @secretsbucket, key: value)
    puts "Done"
  end
end
