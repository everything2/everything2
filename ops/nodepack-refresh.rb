#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'aws-sdk-lambda'

@s3client = Aws::S3::Client.new(region: 'us-west-2')
@lambdaclient = Aws::Lambda::Client.new(region: 'us-west-2', http_read_timeout: 180)
@bucket = 'nodepack.everything2.com'

#@lambdaclient.invoke(function_name: 'nodepack-builder')

done = nil

results = @s3client.list_objects_v2(bucket: @bucket)

while(done.nil?)
  to_delete = []
  results.contents.each do |content|
    puts "Queueing: #{content.key}"
    to_delete.push({key: content.key})
  end

  if(!to_delete.empty?)
    puts "Sending delete API call"
    @s3client.delete_objects(bucket: @bucket, delete: {objects: to_delete})
  else
    puts "Nothing to delete"
    done = 1
  end

  if !results.next_continuation_token.nil?
    results = @s3client.list_objects_v2(bucket: @bucket, continuation_token: results.next_continuation_token)
  else
    done = 1
  end
end

puts "Calling remote nodepack update"
@lambdaclient.invoke(function_name: 'nodepack-builder')

puts "Downloading results"
results = @s3client.list_objects_v2(bucket: @bucket)

done = nil
while(done.nil?)
  results.contents.each do |content|
    puts "Downloading #{content.key}"
    @s3client.get_object(bucket: @bucket, key: content.key, response_target: "../nodepack/#{content.key}")
  end

  if !results.next_continuation_token.nil?
    results = @s3client.list_objects_v2(bucket: @bucket, continuation_token: results.next_continuation_token)
  else
    done = 1
  end
end

puts "Done"
