#!/usr/bin/env ruby

require 'aws-sdk-lambda'

['e2-perl-layer','e2-library-layer'].each do |layer_name|

  lambda_client = Aws::Lambda::Client.new(region: 'us-west-2')
  layer_versions = lambda_client.list_layer_versions(layer_name: layer_name).layer_versions

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

    expected_layer = nil
    new_layers = []
    (0..func.layers.count-1).each do |layernum|
      if func.layers[layernum].arn.match("#{layer_name}")
        puts "#{layer_name} found in #{func.function_name}"
        expected_layer = layernum

        if matches = func.layers[layernum].arn.match(/:(\d+)$/)
          this_version = matches[1]

          if this_version.to_i < highest_version.to_i
            puts "Function #{func.function_name} has #{layer_name} version: #{this_version}, current best: #{highest_version}, updating"
            new_layers.push(highest_version_arn)
          else
            puts "Function has equal or higher layer version '#{this_version.to_i}'"
            new_layers.push(func.layers[layernum].arn)
          end
        end
      else
        new_layers.push(func.layers[layernum].arn)
      end
    end

    if expected_layer.nil?
      puts "Function #{func.function_name} does not appear to contain the layer '#{layer_name}', skipping"
      next
    end

    lambda_client.update_function_configuration(function_name: func.function_name, layers: new_layers)

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
end
