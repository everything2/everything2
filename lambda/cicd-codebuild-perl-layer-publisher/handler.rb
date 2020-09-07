#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'aws-sdk-lambda'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  event = args[:event]

  lambda_client = Aws::Lambda::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  perl_layer = 'e2-perl-layer'
  layer_versions = lambda_client.list_layer_versions(layer_name: perl_layer).layer_versions

  if layer_versions.empty?
    puts "Internal failure: could not find any layer versions"
  end

  highest_version = 0
  highest_version_arn = nil
  layer_versions.each do |layer|
    if layer.version.to_i > highest_version.to_i
      highest_version = layer.version
      highest_version_arn = layer.layer_version_arn
    end
  end

  lambda_client.list_functions.functions.each do |func|
    next if func.layers.nil?

    if func.layers.count > 1
      puts "Unexpected layer structure in function: '#{func.layer_name}'"
      exit
    end

    unless func.layers[0].arn.match("#{perl_layer}")
      puts "Function #{func.function_name} does not appear to contain the perl layer, skipping"
      next 
    end

    if matches = func.layers[0].arn.match(/:(\d+)$/)
      this_version = matches[1]

      if this_version.to_i < highest_version.to_i
        puts "Function #{func.function_name} has perl layer version: #{this_version}, current best: #{highest_version}, updating"
        lambda_client.update_function_configuration(function_name: func.function_name, layers: [highest_version_arn])
      end
    end
  end

  layer_versions.each do |layer|
    if layer.version.to_i < highest_version.to_i
      if matches = layer.layer_version_arn.match(/:([^\:]+):\d+$/)
        puts "Deleting layer: #{matches[1]}, version: #{layer.version}"
        lambda_client.delete_layer_version(layer_name: matches[1], version_number: layer.version)
      else
        puts "Could not determine layer name from arn"
        exit
      end
    end
  end
  return http_response(200, "OK")
end
