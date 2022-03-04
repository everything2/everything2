#!/usr/bin/env ruby

require 'aws-sdk-opsworks'

opsworks_client = Aws::OpsWorks::Client.new(region: 'us-east-1')

commands = [{description: "update_cookbooks",command: {name: 'update_custom_cookbooks'}},
            {description: "execute_recipes", command: {name: 'execute_recipes', args: {recipes: ['e2engine']}}}]

commands.each do |cmd|
  pp cmd
  opsworks_client.describe_stacks.stacks.each do |stack|
    deployments = []
    opsworks_client.describe_instances(stack_id: stack.stack_id).instances.each do |i|
      deployments.push opsworks_client.create_deployment(stack_id: stack.stack_id, instance_ids: [i.instance_id], command: cmd[:command]).deployment_id
    end

    deployments.each_with_index do |val, index|
      while opsworks_client.describe_deployments(deployment_ids: [val]).deployments[0].status.eql? "running"
        puts "Deployment #{val} running for #{cmd[:description]}"
        sleep 2
      end
    end
  end
end
