#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'

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
    puts "Internal failure: could not find any layer versions\n"
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

    layers_list = []
    func.layers.each do |layer|
      if matches = layer.arn.match(/#{perl_layer}:(\d+)$/)
        puts "Function #{func.function_arn} contains the perl layer\n"
        layers_list.push highest_version_arn
      else
        layers_list.push layer.arn
      end
    end

    if !layers_list.empty?
      puts "Updating function with new layers\n"
      lambda_client.update_function_configuration(function_name: func.function_name, layers: layers_list)
    end
  end

  layer_versions.each do |layer|
    if layer.version.to_i < highest_version.to_i
      if matches = layer.layer_version_arn.match(/:([^\:]+):\d+$/)
        puts "Deleting layer: #{matches[1]}, version: #{layer.version}\n"
        lambda_client.delete_layer_version(layer_name: matches[1], version_number: layer.version)
      else
        puts "Could not determine layer name from arn\n"
        exit
      end
    end
  end
  return http_response(200, "OK")
end
