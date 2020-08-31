#!/usr/bin/env ruby
#frozen_string_literal: true

require 'getoptlong'
require 'aws-sdk-lambda'
require 'base64'
require 'json'

@lambdaclient = Aws::Lambda::Client.new(region: 'us-west-2')

opts = GetoptLong.new(
  ['--zipfile', GetoptLong::REQUIRED_ARGUMENT],
  ['--bucket', GetoptLong::REQUIRED_ARGUMENT],
  ['--function', GetoptLong::REQUIRED_ARGUMENT]
)

function = nil
bucket = 'githubzips.everything2.com'
zipfile = nil

opts.each do |opt,arg|
  case opt
  when '--zipfile'
    zipfile = arg
  when '--bucket'
    bucket = arg
  when '--function'
    function = arg
  end
end

if function.nil? or zipfile.nil?
  puts "Need --function and --zipfile"
  exit
end

puts "Calling function: #{function}"
resp = @lambdaclient.invoke(function_name: function, payload: {'bucket': bucket, zipfile: zipfile}.to_json, log_type: "Tail")
puts "Log result:"
puts Base64.decode64(resp.log_result)

puts "Done"
