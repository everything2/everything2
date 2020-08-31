#!/usr/bin/env ruby
# frozen_string_literal: true

require 'aws-sdk-lambda'
require 'getoptlong'
require 'json'

GetoptLong.new(['--repo', GetoptLong::REQUIRED_ARGUMENT]).each do |arg,val|
  case arg
  when '--repo'
    url = "https://github.com/everything2/#{val}"
    puts "Pulling #{url}"

    lambda_client = Aws::Lambda::Client.new(region: 'us-west-2')
    lambda_client.invoke(function_name: 'cicd-zips-puller', payload: {"repo": url}.to_json)
    puts "Done"
  end
end
