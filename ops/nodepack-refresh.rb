#!/usr/bin/env ruby

require 'aws-sdk-ec2'
require 'aws-sdk-s3'
require 'aws-sdk-ecs'

@s3client = Aws::S3::Client.new(region: 'us-west-2')
@ecsclient = Aws::ECS::Client.new(region: 'us-west-2')
@ec2client = Aws::EC2::Client.new(region: 'us-west-2')

e2_cluster = "E2-App-ECS-Cluster"
subnet_placement=nil
security_group=nil
cluster=nil

@ec2client.describe_subnets.subnets.each do |subnet|
  subnet.tags.each do |tag|
    if tag.key.eql? 'aws:cloudformation:logical-id' and tag.value.eql? 'AppVPCSubnet1'
      subnet_placement = subnet.subnet_id
    end
  end
end

@ec2client.describe_security_groups.security_groups.each do |sg|
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

@bucket = 'nodepack.everything2.com'

# Find nodepack directory - works from main dir or ops/
nodepack_dir = nil
if Dir.exist?('nodepack')
  # Running from main directory
  nodepack_dir = 'nodepack'
elsif Dir.exist?('../nodepack')
  # Running from ops/ directory
  nodepack_dir = '../nodepack'
else
  puts "ERROR: Could not find nodepack directory"
  puts "Tried: ./nodepack and ../nodepack"
  puts "Please run this script from either the project root or the ops/ directory"
  exit 1
end

puts "Using nodepack directory: #{nodepack_dir}"

done = nil

results = @s3client.list_objects_v2(bucket: @bucket)

while(done.nil?)
  to_delete = []
  results.contents.each do |content|
    puts "Queueing: #{content.key}"
    to_delete.push({key: content.key})
  end

  if(!to_delete.empty?)
    puts "Sending delete API call"
    @s3client.delete_objects(bucket: @bucket, delete: {objects: to_delete})
  else
    puts "Nothing to delete"
    done = 1
  end

  if !results.next_continuation_token.nil?
    results = @s3client.list_objects_v2(bucket: @bucket, continuation_token: results.next_continuation_token)
  else
    done = 1
  end
end

puts "Calling remote nodepack update"
ecsresult = @ecsclient.run_task(cluster: e2_cluster, task_definition: "e2cron-family", overrides: {container_overrides: [{name: "e2app", command: ["/usr/bin/perl","/var/everything/jobs/job_nodepack_builder.pl",]}]}, network_configuration: {awsvpc_configuration: {subnets: [subnet_placement], security_groups: [security_group], assign_public_ip: "ENABLED"}}, capacity_provider_strategy: [{capacity_provider: "FARGATE", weight: 1}])
task_arn = ecsresult.tasks[0].task_arn
puts "Watching task_arn: #{task_arn}"

done = nil
retries = 0
while(done.nil?)
  begin
    sleep 2
    current_status = @ecsclient.describe_tasks(cluster: e2_cluster, tasks: [task_arn]).tasks[0].last_status
    puts "Current nodepack job status: #{current_status}"
    if current_status.eql? "STOPPED"
      done = 1
    end
  rescue SocketError => e
    if retries.eql? 6
      puts "Failing to monitor nodepack job"
    else
      puts "Retrying connection: #{e.message}"
      retries = restries + 1
    end
  end
end

puts "Downloading results"
results = @s3client.list_objects_v2(bucket: @bucket)

done = nil
while(done.nil?)
  results.contents.each do |content|
    puts "Downloading #{content.key}"
    @s3client.get_object(bucket: @bucket, key: content.key, response_target: "#{nodepack_dir}/#{content.key}")
  end

  if !results.next_continuation_token.nil?
    results = @s3client.list_objects_v2(bucket: @bucket, continuation_token: results.next_continuation_token)
  else
    done = 1
  end
end

puts "Done"
