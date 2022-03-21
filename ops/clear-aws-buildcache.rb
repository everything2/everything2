#!/usr/bin/env ruby

require 'aws-sdk-s3'

s3client = Aws::S3::Client.new(region: 'us-west-2')
s3client.delete_object(bucket: 'buildcache.everything2.com', key: 'last_build.json')
puts "Buildcache cleared"
