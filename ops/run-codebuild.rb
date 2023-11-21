#!/usr/bin/env ruby

require 'aws-sdk-codebuild'
require 'aws-sdk-ecs'

client = Aws::CodeBuild::Client.new(region: 'us-west-2')
ecs = Aws::ECS::Client.new(region: 'us-west-2')

result = client.start_build(project_name: 'E2-Application-Builder-ARM')
build_id = result.build.id
 
done = nil
status = nil
while(done.nil?)
  status = client.batch_get_builds(ids: [build_id]).builds[0].build_status
  puts "#{build_id}: #{status}"

  if(status.eql? "IN_PROGRESS")
    sleep 2
  else
    done = 1
  end
end

if status.eql? "SUCCEEDED"
  pp ecs.update_service(cluster: 'E2-App-ECS-Cluster', service: 'E2-App-Fargate-Service', task_definition: 'e2app-family', desired_count: 2, force_new_deployment: true)
else
  puts "Failed, could not deploy cluster"
end
