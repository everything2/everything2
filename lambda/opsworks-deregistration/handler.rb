#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'json'
require 'aws-sdk-ec2'
require 'aws-sdk-opsworks'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  event = args[:event]

  if(event['Records'].nil? or event['Records'][0].nil? or event['Records'][0]['Sns'].nil? or event['Records'][0]['Sns']['Message'].nil?)
    return http_response(400, "No event to parse")
  end

  pp event['Records'][0]

  message = JSON.parse(event['Records'][0]['Sns']['Message'])
  pp message

  if message['Event'].eql? 'autoscaling:EC2_INSTANCE_TERMINATE'
    ec2client = Aws::EC2::Client.new(region: ENV['AWS_DEFAULT_REGION'])
    
    instance_id = message['EC2InstanceId']
    puts "Removing instance from OpsWorks: #{instance_id}"

    ec2client.describe_instances(instance_ids: [instance_id]).reservations[0].instances[0].tags.each do |tag|
      if tag.key.eql? 'opsworks_stack_id'
        stack_id = tag.value
        puts "Checking OpsWorks Stack: #{stack_id}"
        opsworks_client = Aws::OpsWorks::Client.new(region: ENV['AWS_DEFAULT_REGION'])
        opsworks_client.describe_instances(stack_ids: [stack_id]).instances.each do |instance|
          if instance.ec2_instance_id.eql? instance_id
            puts "Instance #{instance_id} found in stack: #{stack_id}, deregistering"
            opsworks_client.deregister_instance(instance_id: instance_id)
          end
        end
      end
    end 
  end
  return http_response(200, "OK")
end
