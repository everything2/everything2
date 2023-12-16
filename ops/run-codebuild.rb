#!/usr/bin/env ruby

require 'aws-sdk-codebuild'
require 'aws-sdk-ecs'

client = Aws::CodeBuild::Client.new(region: 'us-west-2')
ecs = Aws::ECS::Client.new(region: 'us-west-2')

result = client.start_build(project_name: 'E2-Application-Builder-ARM')
build_id = result.build.id
 
done = nil
status = nil
retries = 0

while(done.nil?)
  begin
    status = client.batch_get_builds(ids: [build_id]).builds[0].build_status
    puts "#{build_id}: #{status}"

    if(status.eql? "IN_PROGRESS")
      sleep 2
    else
      done = 1
    end
  rescue Exception => e
    if retries.eql? 6
      puts "Bailing out due to connectivity issues"
      exit
    else
      retries = retries +1
      puts "Retrying after error: #{e.message}"
    end
  end
end

if status.eql? "SUCCEEDED"
  e2cluster = 'E2-App-ECS-Cluster'
  e2service = 'E2-App-Fargate-Service'
  build_count = ecs.describe_services(cluster: e2cluster,services: [e2service]).services[0].desired_count
  
  pp ecs.update_service(cluster: e2cluster, service: e2service, task_definition: 'e2app-family', desired_count: build_count, force_new_deployment: true)
else
  puts "Failed, could not deploy cluster"
end
