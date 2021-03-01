#!/usr/bin/ruby

require 'aws-sdk'
require 'net/http'
require 'json'
require 'uri'

@instance_server='http://169.254.169.254/latest'

def query_metadata(value)
  Net::HTTP.get(URI("#{@instance_server}/#{value}"))
end

def instance_identity
  JSON.parse(query_metadata('dynamic/instance-identity/document'))
end

def instance_region
  instance_identity['region']
end

@rds = Aws::RDS::Client.new(region: instance_region)
@elb = Aws::ElasticLoadBalancingV2::Client.new(region: instance_region)

def instance_id
  instance_identity['instanceId']
end

def mac_address
  query_metadata('meta-data/network/interfaces/macs/').split("\n")[0].gsub!(%r{/$},'')
end

def public_address
  query_metadata("meta-data/network/interfaces/macs/#{mac_address}/public-ipv4s").split("\n")[0]
end

def frontend_elb
  @elb.describe_load_balancers.load_balancers.each do |elb|
    @elb.describe_tags(resource_arns: [elb['load_balancer_arn']]).tag_descriptions[0]['tags'].each do |tag|
      return elb if tag['key'].eql? 'app' and tag['value'].eql? 'e2'
    end
  end
  nil
end

def web_cluster_target_group
  @elb.describe_target_groups.target_groups.each do |tg|
    return tg if tg['protocol'].eql? 'HTTPS' and tg['load_balancer_arns'].include?(frontend_elb['load_balancer_arn'])
  end
  nil
end

begin
  @rds.authorize_db_security_group_ingress(db_security_group_name: 'default', cidrip: "#{public_address}/32")
rescue Aws::RDS::Errors::AuthorizationAlreadyExists
end

@elb.register_targets(target_group_arn: web_cluster_target_group['target_group_arn'], targets: [{id: instance_id}]) 

