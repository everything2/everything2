#!/usr/bin/env ruby

$LOAD_PATH.unshift('lib')
require 'aws-sdk'
require 'e2/utils'
require 'getoptlong'


e2util = E2::Utils.new


puts "Updating OpsWorks JSON"
e2util.update_opsworks_json

["update_cookbooks", "deploy"].each do |sym|
  puts "Runnng #{sym}"

  deployment = e2util.send(sym)

  completed = []

  while(completed.count != deployment.count)

    deployment.each do |dep|
      deployment_status = e2util.deployment_status(dep['deployment_id'])

      if(deployment_status['status'].eql? 'running')
        puts "Deployment '#{deployment_status['deployment_id']}' running"
      else
        unless(completed.include?(deployment_status['deployment_id']))
          completed.push(deployment_status['deployment_id'])
          puts "Deployment '#{deployment_status['deployment_id']}' complete"
        end
      end
    end
    puts
    sleep(5)
  end
end
