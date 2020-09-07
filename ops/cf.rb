#!/usr/bin/env ruby
# frozen_string_literal: true

require 'aws-sdk-cloudformation'
require 'aws-sdk-s3'
require 'aws-sdk-iam'
require 'aws-sdk-route53'
require 'aws-sdk-ec2'
require 'aws-sdk-elasticloadbalancingv2'
require 'aws-sdk-acm'
require 'aws-sdk-rds'
require 'aws-sdk-sns'
require 'aws-sdk-secretsmanager'
require 'getoptlong'
require 'json'

@stack_name = 'everything2-production'
@cfclient = Aws::CloudFormation::Client.new(region: 'us-west-2')
@s3client = Aws::S3::Client.new(region: 'us-west-2')
@r53client = Aws::Route53::Client.new(region: 'us-west-2')
@elbclient = Aws::ElasticLoadBalancingV2::Client.new(region: 'us-west-2')
@ec2client = Aws::EC2::Client.new(region: 'us-west-2')
@acmclient = Aws::ACM::Client.new(region: 'us-west-2')
@rdsclient = Aws::RDS::Client.new(region: 'us-west-2')
@snsclient = Aws::SNS::Client.new(region: 'us-west-2')
@secclient = Aws::SecretsManager::Client.new(region: 'us-west-2')


@cfbucket = 'cloudformation.everything2.com'
@first_changeset = 'InitialImport'

def iam_policy_arn(policyname)
  iam_client = Aws::IAM::Client.new(region: 'us-west-2')

  iam_client.list_policies(scope: 'Local').policies.each do |policy|
    if policy.policy_name.eql? policyname
      return policy.arn
    end
  end
  nil
end

def global_tags
  [
    {
      "key": "app",
      "value": "e2"
    }
  ]
end

def stack_exists?
  @cfclient.list_stacks.stack_summaries.each do |stack|
    return true if stack.stack_name.eql? @stack_name and not stack.stack_status.eql? 'DELETE_COMPLETE'
  end
  nil
end

def exists_in_template(resource)
  if stack_exists?
    @cfclient.list_stack_resources(stack_name: @stack_name).stack_resource_summaries.each do |res|
      if resource.eql? res.logical_resource_id
        return true
      end
    end
  end
  nil
end

def stack_status(client, stack_name)
  client.describe_stacks(stack_name: stack_name).stacks.each do |stack|
    next if stack.stack_status.eql? 'DELETE_COMPLETE'
    return stack.stack_status
  end
end

def wait_on_in_progress(client, stack_name)
  num_stacks = 0
  client.list_stacks.each do |stack|
    unless stack.stack_summaries[0].stack_name.eql? stack_name
      puts "Stack name #{stack.stack_summaries[0].stack_name} does not match target stack #{stack_name}"
      next
    end

    next if stack.stack_summaries[0].stack_status.eql? 'DELETE_COMPLETE'
    num_stacks = num_stacks + 1
  end

  puts "Number of stacks: #{num_stacks}"

  return unless num_stacks == 1
  complete = nil
  while(complete.nil?)
    client.describe_stacks(stack_name: stack_name).stacks.each do |stack|
      next if stack.stack_status.eql? 'DELETE_COMPLETE'
      puts "Stack is in: #{stack.stack_status}"
      if stack.stack_status.match(/_IN_PROGRESS$/)
        sleep 2
      else
        complete = 1
      end
    end
  end
end

def cf_dir
  "#{File.expand_path(File.dirname(__FILE__))}/../cf"
end

def stack_filename
  "#{@stack_name}.json"
end

def template_file
  "#{cf_dir}/#{stack_filename}"
end

def template_body
  File.open(template_file).read
end

def template_items
  JSON.parse(template_body)
end

def importable_template
  template_copy = template_items
  template_copy['Resources'].keys.each do |key|
    to_delete = nil
    case template_items['Resources'][key]['Type']
    when 'AWS::S3::BucketPolicy'
      to_delete = true
    when 'AWS::Route53::RecordSet'
      to_delete = true
    when 'AWS::EC2::VPCGatewayAttachment'
      to_delete = true
    when 'AWS::ElasticLoadBalancingV2::TargetGroup'
      to_delete = true
    when 'AWS::ElasticLoadBalancingV2::LoadBalancer'
      to_delete = true
    when 'AWS::CertificateManager::Certificate'
      to_delete = true
    when 'AWS::ElasticLoadBalancingV2::Listener'
      to_delete = true
    when 'AWS::RDS::DBSubnetGroup'
      to_delete = true
    end
    template_copy['Resources'].delete(key) if to_delete
  end
  template_copy
end

def importable_template_body
  JSON.generate(importable_template)
end

def r53_hosted_zone_id(name)
  @r53client.list_hosted_zones.hosted_zones.each do |zone|
    next unless zone.name.eql? "#{name}."
    return zone.id.gsub!("/hostedzone/","")
  end
end

def matches_global_tags(tags)
  matches = true
  global_tags.each do |g|
    tags.each do |tag|
      next unless g["key"].eql? tag.key
      unless g["value"].eql? tag.value
        matches = nil
      end
    end
  end
  matches
end

def find_vpc_id
  @ec2client.describe_vpcs.vpcs.each do |vpc|
    return vpc.vpc_id if matches_global_tags(vpc.tags)
  end
  nil
end

def find_hosted_zone_id(name)
  @r53client.describe_hosted_zones.zones.each do |zone|
    pp zone
  end
end

def find_resource_record_set_id(zone_name, name)
  @r53client.list_resource_record_sets(hosted_zone_id: r53_hosted_zone_id(zone_name)).resource_record_sets.each do |rr|
    return rr if rr.name.eql? name
  end
  nil
end

def find_internet_gateway_id
  @ec2client.describe_internet_gateways.internet_gateways.each do |igw|
    return igw.internet_gateway_id if matches_global_tags(igw.tags)
  end
  nil
end

def find_security_group_id(name)
  @ec2client.describe_security_groups.security_groups.each do |sg|
    return sg['group_id'] if sg['group_name'].eql? name
  end
  nil
end

def find_subnet_id_by_cidr(vpc_id, cidr)
  @ec2client.describe_subnets.subnets.each do |subnet|
    return subnet['subnet_id'] if subnet['vpc_id'].eql? vpc_id and subnet['cidr_block'].eql? cidr
  end
  nil
end

def find_elb_id_by_name(name)
  @elbclient.describe_load_balancers(names: [name]).load_balancers.each do |elb|
    if elb['load_balancer_name'].eql? name
      return elb['load_balancer_arn']
    end
  end
  nil
end

def find_target_group_id_by_name(name)
  @elbclient.describe_target_groups.target_groups.each do |tg|
    if tg['target_group_name'].eql? name
      return tg['target_group_arn']
    end
  end
  nil
end

def find_acm_cert_by_domain(domain)
  @acmclient.list_certificates.certificate_summary_list.each do |cert|
    if cert['domain_name'].eql? domain
      return cert['certificate_arn']
    end
  end
  nil
end

def find_sns_topic_by_name(topicname)
  @snsclient.list_topics.topics.each do |topic|
    if topic.topic_arn.match(/#{topicname}$/)
      return topic.topic_arn
    end
  end
end

def find_secret_arn_by_name(name)
  @secclient.list_secrets.secret_list.each do |secret|
    if secret.name.eql? name
      return secret.arn
    end
  end
end

def importable_resources
  to_import = []
  importable_template['Resources'].keys.each do |key|
    if importable_template['Resources'][key]['DeletionPolicy'].eql? 'Retain'
      next if exists_in_template(key)
      importable = { resource_type: importable_template['Resources'][key]['Type'], logical_resource_id: key}

      property_key = nil
      external_value = nil

      case importable[:resource_type]

      when 'AWS::S3::Bucket'
        property_key = 'BucketName'
      when 'AWS::S3::BucketPolicy'
        # Not importable
        next
      when 'AWS::IAM::Role'
        property_key = 'RoleName'
      when 'AWS::IAM::User'
        property_key = 'UserName'
      when 'AWS::Route53::HostedZone'
        property_key = 'HostedZoneId'
        external_value = r53_hosted_zone_id(importable_template['Resources'][key]['Properties']['Name'])
      when 'AWS::IAM::ManagedPolicy'
        property_key = 'PolicyArn'
        external_value = iam_policy_arn(importable_template['Resources'][key]['Properties']['ManagedPolicyName'])
      when 'AWS::EC2::VPC'
        property_key = 'VpcId'
        external_value = find_vpc_id
      when 'AWS::EC2::InternetGateway'
        property_key = 'InternetGatewayId'
        external_value = find_internet_gateway_id
      when 'AWS::EC2::SecurityGroup'
        property_key = 'GroupId'
        external_value = find_security_group_id(importable_template['Resources'][key]['Properties']['GroupName'])
      when 'AWS::EC2::Subnet'
        property_key = 'SubnetId'
        external_value = find_subnet_id_by_cidr(find_vpc_id, importable_template['Resources'][key]['Properties']['CidrBlock'])
      when 'AWS::ElasticLoadBalancingV2::LoadBalancer'
        property_key = 'LoadBalancerArn'
        external_value = find_elb_id_by_name(importable_template['Resources'][key]['Properties']['Name'])
      when 'AWS::CertificateManager::Certificate'
        property_key = 'CertificateArn'
        external_value = find_acm_cert_by_domain(importable_template['Resources'][key]['Properties']['DomainName'])
      when 'AWS::SNS::Topic'
        property_key = 'TopicArn'
        external_value = find_sns_topic_by_name(importable_template['Resources'][key]['Properties']['TopicName'])
      when 'AWS::RDS::DBInstance'
        property_key = 'DBInstanceIdentifier'
      end

      if property_key.nil?
        puts "Internal error: Can't marshall property key for resource type #{importable[:resource_type]}"
      else
        if external_value.nil?
          importable[:resource_identifier] = {property_key => importable_template["Resources"][key]["Properties"][property_key]}
        else
          importable[:resource_identifier] = {property_key => external_value}
        end
      end

      to_import.push importable
    end
  end
  to_import
end

def wait_on_change_set_status(client, stack_name, change_set_name)

  complete = nil
  while complete.nil?
    resp = client.describe_change_set(change_set_name: change_set_name, stack_name: stack_name)
    puts "Changeset #{stack_name}/#{change_set_name} status: #{resp.status}"
    if resp.status.match(/_IN_PROGRESS$/) or resp.status.match(/_PENDING$/)
      sleep 2
    else
      complete = 1
    end
  end
end

def update_termination_protection(state)
  @cfclient.update_termination_protection(stack_name: @stack_name, enable_termination_protection: state)
  puts "Stack protection set to #{state}"
end

def upload_stack_to_s3
  puts "Uploading #{stack_filename} to #{@cfbucket}"
  File.open(template_file) do |f|
    @s3client.put_object(body: f, bucket: @cfbucket, key: stack_filename)
  end
end

def incremental_update
  change_set_name = "Update-#{Time.now.to_i}"
  puts 'Setting stack policy'
  @cfclient.set_stack_policy(stack_name: @stack_name, stack_policy_body: File.open("#{cf_dir}/stack-policy.json").read)

  puts 'Updating stack'

  upload_stack_to_s3

  pp @cfclient.create_change_set(
    stack_name: @stack_name,
    change_set_name: change_set_name,
    capabilities: ['CAPABILITY_NAMED_IAM'],
    change_set_type: 'UPDATE',
    template_url: "https://s3-us-west-2.amazonaws.com/#{@cfbucket}/#{stack_filename}",
    tags: global_tags
  )
  puts "Stack changeset created"

  wait_on_change_set_status(@cfclient, @stack_name, change_set_name)

  update_change_set = @cfclient.describe_change_set(change_set_name: change_set_name, stack_name: @stack_name)

  if update_change_set.status.eql? 'FAILED'
    puts "Proposed change failed: #{update_change_set.status_reason}"
    @cfclient.delete_change_set(stack_name: @stack_name, change_set_name: change_set_name)
    puts 'Rolled back'
  else
    @cfclient.execute_change_set(stack_name: @stack_name, change_set_name: change_set_name)
  end
end

def update_cf_template
  if stack_exists?
    incremental_update
  else
    puts 'Importing stack from scratch'
    to_import = importable_resources

    if to_import.empty?
      puts 'Nothing to import'
    else
      @cfclient.create_change_set(
        stack_name: @stack_name,
        change_set_name: @first_changeset,
        change_set_type: 'IMPORT',
        capabilities: ['CAPABILITY_NAMED_IAM'],
        template_body: importable_template_body,
        resources_to_import: to_import,
      )

      wait_on_change_set_status(@cfclient, @stack_name, @first_changeset)

      @cfclient.execute_change_set(stack_name: @stack_name, change_set_name: @first_changeset)
      update_termination_protection(true)

      wait_on_in_progress(@cfclient, @stack_name)

      if stack_status(@cfclient, @stack_name).eql? 'IMPORT_COMPLETE'
        puts 'Stack created'
      else
        puts 'Import failed, halting phase 2'
      end

      incremental_update
      wait_on_in_progress(@cfclient, @stack_name)
    end
  end
end

def delete_cf_template
  pp @cfclient.delete_stack(stack_name: @stack_name)
end

def detect_stack_drift
  template_items['Resources'].keys.each do |key|
    drift_info = @cfclient.detect_stack_resource_drift(stack_name: @stack_name, logical_resource_id: key)
    puts "#{key} - #{drift_info.stack_resource_drift.stack_resource_drift_status}"
  end
end

opts = GetoptLong.new(
  ['--update', GetoptLong::NO_ARGUMENT],
  ['--delete', GetoptLong::NO_ARGUMENT],
  ['--unprotect', GetoptLong::NO_ARGUMENT],
  ['--protect', GetoptLong::NO_ARGUMENT],
  ['--drift', GetoptLong::NO_ARGUMENT]
)

opts.each do |opt|
  case opt
  when '--update'
    update_cf_template
  when '--delete'
    delete_cf_template
  when '--unprotect'
    update_termination_protection(false)
  when '--protect'
    update_termination_protection(true)
  when '--drift'
    detect_stack_drift
  end
end
