#!/usr/bin/env ruby
# frozen_string_literal: true

require 'aws-sdk'
require 'net/http'
require 'json'
require 'uri'
require 'getoptlong'

@instance_server = 'http://169.254.169.254/latest'

def query_metadata(value)
  uri = URI("#{@instance_server}/#{value}")
  req = Net::HTTP::Get.new(uri)

  begin 
    res = Net::HTTP.start(uri.hostname, uri.port){ |http|
      http.request(req)
    }

    res.body.chomp

  rescue Net::ReadTimeout, Net::OpenTimeout => e
    puts "Can't get instance metadata: #{e.message}" 
    exit
  end
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

def private_address
  query_metadata("meta-data/local-ipv4")
end

def frontend_elb
  @elb.describe_load_balancers.load_balancers.each do |elb|
    @elb.describe_tags(resource_arns: [elb['load_balancer_arn']]).tag_descriptions[0]['tags'].each do |tag|
      return elb if(tag['key'].eql? 'app' and tag['value'].eql? 'e2')
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

def db_security_group_registration
  begin
    @rds.authorize_db_security_group_ingress(db_security_group_name: 'default', cidrip: "#{private_address}/32")
  rescue Aws::RDS::Errors::AuthorizationAlreadyExists
  end
end

def elb_target_group_registration
  @elb.register_targets(target_group_arn: web_cluster_target_group['target_group_arn'], targets: [{id: instance_id}])
end


opts = GetoptLong.new(
  [ '--db', GetoptLong::NO_ARGUMENT ],
  [ '--elb', GetoptLong::NO_ARGUMENT ],
)

opts.each do |opt|
  case opt
    when '--db'
      db_security_group_registration
    when '--elb'
      elb_target_group_registration
  end
end


