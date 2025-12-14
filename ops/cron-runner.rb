#!/usr/bin/env ruby

require 'aws-sdk-ecs'
require 'aws-sdk-ec2'
require 'getoptlong'


ec2client = Aws::EC2::Client.new(region: 'us-west-2')
ecsclient = Aws::ECS::Client.new(region: 'us-west-2')
job = nil
extra = ''
task_family = nil
opts = GetoptLong.new(['--job','-j',GetoptLong::REQUIRED_ARGUMENT],['--extra','-e',GetoptLong::REQUIRED_ARGUMENT],['--task-family','-t',GetoptLong::REQUIRED_ARGUMENT])
opts.each do |opt,arg|
  case opt
    when '--job'
      job = arg
    when '--extra'
      extra = arg
    when '--task-family'
      task_family = arg
  end
end

# Default to regular cron task family
task_family ||= 'e2cron-family'

subnet_placement=nil
security_group=nil
cluster=nil
ec2client.describe_subnets.subnets.each do |subnet|
  subnet.tags.each do |tag|
    if tag.key.eql? 'aws:cloudformation:logical-id' and tag.value.eql? 'AppVPCSubnet1'
      subnet_placement = subnet.subnet_id
    end
  end
end

ec2client.describe_security_groups.security_groups.each do |sg|
  if sg.group_name.eql? "E2-App-Webhead-Security-Group"
    security_group = sg.group_id
  end
end

if subnet_placement.nil?
  puts "Couldn't find subnet for placement of cron task"
  exit
end

if security_group.nil?
  puts "Couldn't find security group for placement of task"
  exit
end

if job.nil?
  puts "Need --job specified"
  exit
end

pp ecsclient.run_task(cluster: "E2-App-ECS-Cluster", task_definition: task_family, overrides: {container_overrides: [{name: "e2app", command: ["/usr/bin/perl","/var/everything/cron/#{job}.pl","#{extra}"]}]}, network_configuration: {awsvpc_configuration: {subnets: [subnet_placement], security_groups: [security_group], assign_public_ip: "ENABLED"}}, capacity_provider_strategy: [{capacity_provider: "FARGATE", weight: 1}])
