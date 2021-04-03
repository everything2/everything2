#!/usr/bin/env ruby

require 'aws-sdk-cloudwatchlogs'
require 'JSON'

client = Aws::CloudWatchLogs::Client.new(region: 'us-west-2')

next_token = ''
log_group_name = '/aws/events/e2-app-errors'

max_pull = 100;
pulled = 0
messages = {}

while(!next_token.nil?)
  break if pulled >= max_pull
  result = client.describe_log_streams(log_group_name: log_group_name, next_token: (next_token.eql? '')?(nil):(next_token))
  result.log_streams.each do |stream|
    resp = client.get_log_events(log_group_name: log_group_name, log_stream_name: stream.log_stream_name)
    resp.events.each do |event|
      info = JSON.parse(event.message)['detail']['message']
      messages[info] = 0 if messages[info].nil?
      messages[info] = messages[info]+1
      pulled = pulled + 1
    end
    sleep 2
    break if pulled >= max_pull
  end
  next_token = result.next_token
end

messages = messages.sort_by {|k,v| -v}
messages.each do |message|
  puts "#{message[1]}: #{message[0]}" 
end
