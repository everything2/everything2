#!/usr/bin/env ruby

require 'aws-sdk-cloudwatchlogs'

client = Aws::CloudWatchLogs::Client.new(region: 'us-west-2')

next_token = ''
log_group_name = '/aws/events/e2-app-errors'
streams = 0

while(!next_token.nil?)
  result = client.describe_log_streams(log_group_name: log_group_name, next_token: (next_token.eql? '')?(nil):(next_token))
  result.log_streams.each do |stream|
    puts "Stream: #{stream.log_stream_name}"
    client.delete_log_stream(log_group_name: log_group_name, log_stream_name: stream.log_stream_name)
    streams = streams + 1
    sleep 2
  end
  next_token = result.next_token
end
puts "#{streams} streams deleted"
