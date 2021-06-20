require 'e2/awsclient'
require 'e2/appstate'
require 'json'

class E2
  class Utils

    def initialize
      @aws = E2::Awsclient.new
      @e2 = E2::Appstate.new
      @app = JSON.parse(File.open('app.json','r').read)
    end

    def deploy
      deployment_ids = []
      @e2.opsworks_instances('E2 webhead').each do |instance|
        deployment_ids.push @aws.opsworks.create_deployment(stack_id: @e2.opsworks_stack['stack_id'], instance_ids: [instance['instance_id']],
          command: {name: 'execute_recipes', args: {recipes: @app['webhead_recipes']}})
      end

      deployment_ids
    end

    def update_cookbooks
      deployment_ids = []
      @e2.opsworks_instances('E2 webhead').each do |instance|
        deployment_ids.push @aws.opsworks.create_deployment(stack_id: @e2.opsworks_stack['stack_id'], instance_ids: [instance['instance_id']],
          command: {name: 'update_custom_cookbooks'})
      end

      deployment_ids
    end

    def deployment_status(deployment_id)
      @aws.opsworks.describe_deployments(deployment_ids: [deployment_id]).deployments[0]
    end

  end
end
