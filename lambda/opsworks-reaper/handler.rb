#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'

require 'json'
require 'aws-sdk-ec2'
require 'aws-sdk-opsworks'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  # Opsworks is global
  puts "In reaper\n"
  opsworks_client = Aws::OpsWorks::Client.new(region: 'us-east-1')
  ec2_client = Aws::EC2::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  opsworks_client.describe_stacks.stacks.each do |stack|
    puts "Investigating stack_id: #{stack.stack_id}\n"
    opsworks_client.describe_instances(stack_id: stack.stack_id).instances.each do |instance|
      if instance.status.eql? 'start_failed'
        puts "Instance #{instance.ec2_instance_id} failed\n"
        begin
          ec2_client.describe_instances(instance_ids: [instance.ec2_instance_id]).reservations[0].instances.each do |ec2_instance|
            puts "Terminating instance: #{instance.ec2_instance_id}"
            ec2_client.terminate_instance(instance_ids: [instance.ec2_instance_id])
          end
        rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
          puts "Instance #{instance.ec2_instance_id} not found"
        end
        puts "Deregistering instance: #{instance.instance_id}"
        opsworks_client.deregister_instance(instance_id: instance.instance_id)
      end

      resp = ec2_client.describe_instances(instance_ids: [instance.ec2_instance_id])
      if resp.reservations.empty?
        puts "Instance doesn't exist, deregistering: #{instance.ec2_instance_id}"
        opsworks_client.deregister_instance(instance_id: instance.instance_id)
      else
        puts "Instance does exist: #{instance.ec2_instance_id} (#{resp.reservations[0].instances[0].state})"
        if(resp.reservations[0].instances[0].state.name.eql? 'terminated')
          puts "Reaping terminated instance: #{instance.ec2_instance_id}"
          opsworks_client.deregister_instance(instance_id: instance.instance_id)
        end
      end
    end
  end
  return http_response(200, "OK")
end
