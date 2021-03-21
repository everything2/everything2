require 'e2/awsclient'
require 'json'
require 'net/http'
require 'uri'

class E2
  class Appstate

    def initialize
      @aws = E2::Awsclient.new
      @app = JSON.parse(File.open('app.json','r').read)
    end

    def current_ip
     uri = URI("http://v4.ifconfig.co/")
     req = Net::HTTP::Get.new(uri)
     req['User-Agent'] = 'curl/7.64.1'

     res = Net::HTTP.start(uri.hostname, uri.port){ |http|
       http.request(req)
     }

     res.body.chomp
    end

    def app_tag
      return {key: @app['app_tag']['key'], value: @app['app_tag']['value']}
    end

    def vpc
      @aws.ec2.describe_vpcs.vpcs.each do |thisvpc|
        return thisvpc if is_tagged_resource?(thisvpc)
      end
      nil
    end

    def vpc_get_security_group(group_name)
      @aws.ec2.describe_security_groups.security_groups.each do |group|
        return group if group['vpc_id'].eql? vpc['vpc_id'] and group['group_name'].eql? group_name
      end
      nil
    end

    def adjust_vpc_subnet_network_acl
      [1,2].each do |subnet_num|
        unless vpc_subnet_network_acl(subnet_num).nil?
          [true,false].each do |egress_state|
            @aws.ec2.create_network_acl_entry(
              egress: egress_state,
              cidr_block: "0.0.0.0/0",
              network_acl_id: vpc_subnet_network_acl(subnet_num)['network_acl_id'],
              protocol: '-1',
              rule_action: 'allow',
              rule_number: 50 )
          end
        end
      end
    end

    def vpc_subnet_network_acl(subnet_num)
      @aws.ec2.describe_network_acls.network_acls.each do |na|
        return na if na.associations[0]['subnet_id'].eql? app_subnet(subnet_num)['subnet_id']
      end
      nil
    end

    def vpc_opsworks_default_group
      vpc_get_security_group('AWS-OpsWorks-Default-Server')
    end

    def vpc_opsworks_webapp_group
       vpc_get_security_group('AWS-OpsWorks-WebApp')
    end

    def vpc_add_ssh_ingress
      [vpc_opsworks_default_group, vpc_opsworks_webapp_group].each do |grp|
        begin
          @aws.ec2.authorize_security_group_ingress(
            group_id: grp['group_id'],
            ip_permissions: [
              {
                from_port: 22,
                ip_protocol: 'tcp',
                ip_ranges: [
                  {
                    cidr_ip: "#{current_ip}/32",
                    description: 'SSH access from home'
                  },
                ],
                to_port: 22,
              }
            ]
          )
        end
      rescue Aws::EC2::Errors::InvalidPermissionDuplicate
      end
    end

    def create_vpc
      resp = @aws.ec2.create_vpc(cidr_block: @app['vpc_cidr_block'])
      @aws.ec2.create_tags(resources: [resp["vpc"].vpc_id, resp["vpc"].dhcp_options_id], tags: [app_tag])

      ['1','2'].each do |subnetnum|
        subnet_resp = @aws.ec2.create_subnet(
          availability_zone: @app["availability_zone_app#{subnetnum}"],
          cidr_block: @app["app_vpc_subnet#{subnetnum}"], 
          vpc_id: resp["vpc"].vpc_id)

        @aws.ec2.modify_subnet_attribute(map_public_ip_on_launch: {value: true}, subnet_id: subnet_resp['subnet']['subnet_id'])
      end

      # This appears unchangable
      @aws.ec2.create_security_group(
        description: "Default AWS OpsWorks Security Group",
        group_name: "AWS-OpsWorks-Default-Server",
        vpc_id: resp["vpc"].vpc_id
      )

      # Allow network access inside of the subnet
      adjust_vpc_subnet_network_acl
    end

    def find_subnet(vpc_id, subnet_cidr)
      @aws.ec2.describe_subnets.subnets.each do |subnet|
        return subnet if subnet['vpc_id'].eql? vpc_id and subnet['cidr_block'].eql? subnet_cidr
      end
      nil
    end

    def app_subnet(subnet_num)
      find_subnet(vpc['vpc_id'], @app["app_vpc_subnet#{subnet_num}"])
    end

    def rds_subnet(subnet_num)
      find_subnet(vpc['vpc_id'], @app["app_rds_subnet#{subnet_num}"])
    end

    def delete_vpc
      [vpc_opsworks_default_group,vpc_opsworks_webapp_group,bastion_security_group,webhead_security_group].each do |grp|
        @aws.ec2.delete_security_group(group_id: grp['group_id']) unless grp.nil?
      end

      [1,2].each do |num|
        @aws.ec2.delete_subnet(subnet_id: app_subnet(num)['subnet_id']) unless app_subnet(num).nil?
      end

      unless vpc.nil?
        @aws.ec2.delete_vpc(vpc_id: vpc["vpc_id"])
      end
    end

    def dhcp_options
      @aws.ec2.describe_vpcs.vpcs.each do |thisvpc|
        dhcp = is_tagged_resource?(thisvpc, 'dhcp_options_id')
        return dhcp unless dhcp.nil?
      end
      nil
    end

    def opsworks_stack
      @aws.opsworks.describe_stacks.stacks.each do |stack|
        return stack if stack['name'].eql? @app['opsworks_stack_name']
      end
      nil
    end

    def delete_opsworks_stack
      unless opsworks_stack.nil?
        @aws.opsworks.delete_stack(stack_id: opsworks_stack['stack_id'])
      end
    end

    def stack_config
      return {
        name: @app['opsworks_stack_name'],
        region: @app['region'],
        vpc_id: vpc['vpc_id'],
        default_subnet_id: app_subnet(1)['subnet_id'],
        default_os: @app['opsworks_default_os'],
        default_availability_zone: @app['availability_zone'],
        default_instance_profile_arn: app_instance_profile['arn'],
        service_role_arn: iam_service_role['arn'],
        configuration_manager: {name: "Chef", version: "12"},
        use_custom_cookbooks: true,
        custom_cookbooks_source: {
          type: "git",
          url: "https://github.com/everything2/cookbooks.git",
        }
      }
    end

    def create_opsworks_stack
      if opsworks_stack.nil?
        resp = @aws.opsworks.create_stack(stack_config)

        @aws.opsworks.create_layer(
          stack_id: opsworks_stack['stack_id'],
          type: 'custom',
          name: 'E2 webhead',
          shortname: 'e2web',
          auto_assign_public_ips: true,
          custom_security_group_ids: [webhead_security_group['group_id'], bastion_security_group['group_id']],
          custom_recipes: {
            deploy: @app['webhead_recipes']
          }
        )

        @aws.opsworks.create_layer(
          stack_id: opsworks_stack['stack_id'],
          type: 'custom',
          name: 'E2 bastion',
          shortname: 'e2bastion',
          auto_assign_public_ips: true,
          custom_security_group_ids: [bastion_security_group['group_id']],
          custom_recipes: {
            deploy: @app['bastion_recipes']
          }
        )
      end
    end

    def iam_app_role
      return role_search(@app['iam_app_role_name'])
    end

    def role_search(rolename)
      @aws.iam.list_roles.roles.each do |role|
        # Role tagging in the api seems buggy
        return role if role['role_name'].eql? rolename
      end
      nil
    end

    def iam_service_role
      return role_search(@app['iam_service_role_name'])
    end

    def is_tagged_resource?(resource,resource_key=nil)
      resource["tags"].each do |tag|
        if tag["key"].eql? @app['app_tag']['key'] and tag["value"].eql? @app['app_tag']['value']
          if resource_key.nil?
            return resource
          else
            return resource[resource_key]
          end
        end
      end
      nil
    end

    def create_iam_app_role
       policy_document = 
       {
         "Version": "2012-10-17",
         "Statement": {
           "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
         }
       }
      if iam_app_role.nil?
        resp = @aws.iam.create_role(assume_role_policy_document: policy_document.to_json, path: '/',
          role_name: @app['iam_app_role_name'], tags: [app_tag], description: @app['iam_app_role_description'])
      end
      create_app_instance_profile
    end

    def create_iam_service_role
      policy_document =
       {
         "Version": "2012-10-17",
         "Statement": {
           "Effect": "Allow",
            "Principal": {"Service": "opsworks.amazonaws.com"},
            "Action": "sts:AssumeRole"
         }
       }

      if iam_service_role.nil?
        @aws.iam.create_role(assume_role_policy_document: policy_document.to_json, path: '/',
          role_name: @app['iam_service_role_name'], tags: [app_tag], description: @app['iam_service_role_description'])
        @aws.iam.attach_role_policy(role_name: @app['iam_service_role_name'], policy_arn: 'arn:aws:iam::aws:policy/service-role/AWSOpsWorksRole')
        @aws.iam.attach_role_policy(role_name: @app['iam_service_role_name'], policy_arn: 'arn:aws:iam::aws:policy/AmazonEC2FullAccess')
      end
    end

    def app_instance_profile
      profile = nil
      begin
        profile = @aws.iam.get_instance_profile(instance_profile_name: @app["instance_profile_name"])[0]
      rescue Aws::IAM::Errors::NoSuchEntity
      end
      return profile
    end

    def create_app_instance_profile
      if app_instance_profile.nil?
        @aws.iam.create_instance_profile(instance_profile_name: @app["instance_profile_name"])
        @aws.iam.add_role_to_instance_profile(instance_profile_name: @app['instance_profile_name'], role_name: @app['iam_app_role_name'])
      end
    end

    def delete_app_instance_profile
      unless app_instance_profile.nil?
        @aws.iam.remove_role_from_instance_profile(instance_profile_name: @app['instance_profile_name'], role_name: @app['iam_app_role_name']) unless iam_app_role.nil?
        @aws.iam.delete_instance_profile(instance_profile_name: @app["instance_profile_name"])
      end
    end

    def delete_iam_app_role
      unless iam_app_role.nil?
        @aws.iam.delete_role(role_name: @app['iam_app_role_name'])
      end
    end

    def delete_iam_service_role
      unless iam_service_role.nil?
        ['service-role/AWSOpsWorksRole','AmazonEC2FullAccess'].each do |rolepolicy|
          begin
            @aws.iam.detach_role_policy(role_name: @app['iam_service_role_name'], policy_arn: "arn:aws:iam::aws:policy/#{rolepolicy}")
          rescue Aws::IAM::Errors::NoSuchEntity
          end
        end
        delete_app_instance_profile
        @aws.iam.delete_role(role_name: @app['iam_service_role_name'])
      end
    end

    def create_bastion_vpc_elastic_ip
      if bastion_vpc_elastic_ip.nil?
        resp = @aws.ec2.allocate_address(domain: "vpc")
        @aws.ec2.create_tags(resources: [resp['allocation_id']], tags: [app_tag])
      end
    end

    def delete_bastion_vpc_elastic_ip
      unless bastion_vpc_elastic_ip.nil?
        @aws.ec2.disassociate_address(association_id: bastion_vpc_elastic_ip['association_id']) unless bastion_vpc_elastic_ip['association_id'].nil?
        @aws.ec2.release_address(allocation_id: bastion_vpc_elastic_ip['allocation_id'])
      end
    end

    def bastion_vpc_elastic_ip
      @aws.ec2.describe_addresses.addresses.each do |addr|
        return addr if is_tagged_resource?(addr)
      end
      nil
    end

    def opsworks_register_bastion_vpc_elastic_ip
      if opsworks_registered_bastion_vpc_elastic_ip.nil?
        @aws.opsworks.register_elastic_ip(elastic_ip: bastion_vpc_elastic_ip['public_ip'],
          stack_id: opsworks_stack['stack_id'])
      end
    end

    def opsworks_registered_bastion_vpc_elastic_ip
      @aws.opsworks.describe_elastic_ips(stack_id: opsworks_stack['stack_id']).elastic_ips.each do |eip|
        return eip if eip['ip'].eql? bastion_vpc_elastic_ip['public_ip']
      end
      nil
    end

    def create_vpc_internet_gateway
      if(vpc_internet_gateway.nil?)
        resp = @aws.ec2.create_internet_gateway
        @aws.ec2.create_tags(resources: [resp['internet_gateway']['internet_gateway_id']], tags: [app_tag])
        @aws.ec2.attach_internet_gateway(internet_gateway_id: resp['internet_gateway']['internet_gateway_id'],
          vpc_id: vpc['vpc_id'])
        @aws.ec2.create_route(destination_cidr_block: '0.0.0.0/0', gateway_id: resp['internet_gateway']['internet_gateway_id'], route_table_id: vpc_route_table['route_table_id'])
      end
    end

    def vpc_internet_gateway
      @aws.ec2.describe_internet_gateways.internet_gateways.each do |ig|
        return ig if is_tagged_resource?(ig)
      end
      nil
    end

    def delete_vpc_internet_gateway
      unless(vpc_internet_gateway.nil?)
        @aws.ec2.detach_internet_gateway(internet_gateway_id: vpc_internet_gateway['internet_gateway_id'], vpc_id: vpc['vpc_id'])
        @aws.ec2.delete_internet_gateway(internet_gateway_id: vpc_internet_gateway['internet_gateway_id'])
      end
    end

    def vpc_route_table
      @aws.ec2.describe_route_tables.route_tables.each do |rt|
        if rt['vpc_id'].eql? vpc['vpc_id']
          return rt
        end
      end
      nil
    end

    def frontend_elb_security_group
      vpc_get_security_group(@app['frontend_elb_security_group']) 
    end

    def create_frontend_elb_security_group
      if frontend_elb_security_group.nil?
        resp = @aws.ec2.create_security_group(
          description: "E2 App Frontend Security Group",
          group_name: @app['frontend_elb_security_group'],
          vpc_id: vpc['vpc_id']
        )
        ['443','80'].each do |port|
          @aws.ec2.authorize_security_group_ingress(
            group_id: resp['group_id'],
            ip_permissions: [{
              from_port: port,
              to_port: port,
              ip_protocol: 'tcp',
              ip_ranges: [{cidr_ip: '0.0.0.0/0', description: 'Everywhere'}]
            }]
          )
        end
      end
    end

    def delete_frontend_elb_security_group
      unless frontend_elb_security_group.nil?
        @aws.ec2.delete_security_group(group_id: frontend_elb_security_group['group_id'])
      end
    end

    def frontend_elb
      @aws.elb.describe_load_balancers.load_balancers.each do |elb|
        return elb if elb['load_balancer_name'].eql? @app['frontend_load_balancer_name']
      end
      nil
    end

    def create_frontend_elb
      if frontend_elb.nil?
        @aws.elb.create_load_balancer(
          name: @app['frontend_load_balancer_name'],
          tags: [app_tag],
          subnets: [app_subnet(1)['subnet_id'], app_subnet(2)['subnet_id']],
          security_groups: [frontend_elb_security_group['group_id']]
        )

      end
    end

    def create_target_group
     if target_group.nil?
        @aws.elb.create_target_group(
          name: @app['frontend_elb_app_target_group'],
          vpc_id: vpc['vpc_id'],
          protocol: 'HTTPS',
          port: '443',
          health_check_enabled: true,
          health_check_port: '443',
          health_check_protocol: "HTTPS",
          matcher: {http_code: '200'},
        )
      end
    end

    def target_group
      @aws.elb.describe_target_groups.target_groups.each do |tg|
        return tg if tg['target_group_name'].eql? @app['frontend_elb_app_target_group']
      end
      nil
    end

    def delete_target_group
      unless target_group.nil?
        @aws.elb.delete_target_group(target_group_arn: target_group['target_group_arn']) 
      end
    end

    def elb_certificate
      @aws.acm.list_certificates.certificate_summary_list.each do |cert|
        @aws.acm.list_tags_for_certificate(certificate_arn: cert['certificate_arn']).tags.each do |tag|
          if tag['key'].eql? @app['app_tag']["key"] and tag['value'].eql? @app['app_tag']['value']
            return @aws.acm.describe_certificate(certificate_arn: cert['certificate_arn']).certificate
          end
        end
      end
      nil
    end

    def create_elb_certificate
      if elb_certificate.nil?
        resp = @aws.acm.request_certificate(
          domain_name: @app['certificate_domain_name'],
          validation_method: "DNS",
          subject_alternative_names: @app['certificate_sans'],
          idempotency_token: @app['certificate_idempotency_token'],
        )

        @aws.acm.add_tags_to_certificate(certificate_arn: resp['certificate_arn'], tags: [app_tag])
      end
    end

    def elb_certificate_verified?
      if elb_certificate['status'].eql? 'PENDING_VALIDATION'
        create_elb_certificate_dns_validation
      else
        true
      end
    end

    def tag_hosted_zones
      @app['hosted_zones'].each do |zone|
        hz = get_hosted_zone(zone)
        unless hz.nil?
          r_type , zone_id = hosted_zone_info(hz)
          @aws.r53.change_tags_for_resource(add_tags: [app_tag], resource_id: zone_id, resource_type: r_type)
        end
      end
    end

    def hosted_zone_info(hz)
      hz['id'].split('/')[1..2]
    end

    def get_hosted_zone(domain)
      @aws.r53.list_hosted_zones.hosted_zones.each do |zone|
        return zone if zone['name'].eql? "#{domain}."
      end
      nil
    end

    def create_elb_certificate_dns_validation
      elb_certificate.domain_validation_options.each do |dv|
        r_type , zone_id = hosted_zone_info(get_hosted_zone(get_base_domain(dv['domain_name'])))
        
        @aws.r53.change_resource_record_sets(change_batch: {
          changes: [{
            action: "UPSERT",
            resource_record_set: {
              name: dv['resource_record']['name'],
              resource_records: [ { value: dv['resource_record']['value'] } ],
              type: dv['resource_record']['type'],
              ttl: @app['dns_ttl_default'],
            },
          }]
        },
        hosted_zone_id: zone_id,
        )
      end
    end

    def get_base_domain(domain)
      domain.gsub(/.*?([^\.]+\.[^\.]+)$/, '\1')
    end

    def delete_frontend_elb
      eni = nil
      @aws.ec2.describe_network_interfaces.network_interfaces.each do |ni|
        eni = ni if ni.vpc_id.eql? vpc.vpc_id and %r{^ELB app/#{@app['frontend_load_balancer_name']}}.match(ni['description'])
      end

      unless frontend_elb.nil?
        @aws.elb.delete_load_balancer(
          load_balancer_arn: frontend_elb['load_balancer_arn']
        )
      end

      begin 
        while(@aws.ec2.describe_network_interfaces(network_interface_ids: [eni['network_interface_id']]).network_interfaces.any?)
          sleep 1
        end
      rescue Aws::EC2::Errors::InvalidNetworkInterfaceIDNotFound
      end

    end
 
    def db_instance
      @aws.rds.describe_db_instances.db_instances.each do |db|
        return db if db['db_instance_identifier'].eql? @app['db_instance_name']
      end
      nil
    end

    def default_db_security_group
      @aws.rds.describe_db_security_groups.db_security_groups.each do |dbsg|
        return dbsg if dbsg['db_security_group_name'].eql? 'default'
      end
    end

    def delete_vpc_network_interfaces
      pp @aws.ec2.describe_network_interfaces
    end

    def elb_https_listener
      get_elb_listener('HTTPS')
    end

    def elb_http_listener
      get_elb_listener('HTTP')
    end

    def get_elb_listener(proto)
      return nil if frontend_elb.nil?

      @aws.elb.describe_listeners(load_balancer_arn: frontend_elb['load_balancer_arn']).listeners.each do |listener|
        return listener if listener['load_balancer_arn'].eql? frontend_elb['load_balancer_arn'] and
          listener['protocol'].eql? proto
      end
      nil
    end

    def create_elb_https_listener
      if(elb_https_listener.nil?)
        @aws.elb.create_listener(default_actions: [{target_group_arn: target_group['target_group_arn'], type: 'forward'}],
          certificates: [{certificate_arn: elb_certificate['certificate_arn']}],
          load_balancer_arn: frontend_elb['load_balancer_arn'],
          port: 443,
          protocol: 'HTTPS',
          ssl_policy: @app['https_elb_security_policy'])
      end
    end

    def create_elb_http_listener
      if(elb_http_listener.nil?)
        @aws.elb.create_listener(default_actions: [{type: 'redirect',
          redirect_config: {
            protocol: "HTTPS",
            port: '443',
            host: '#{host}',
            path: '/#{path}',
            query: '#{query}',
            status_code: "HTTP_301"
          }}],
          load_balancer_arn: frontend_elb['load_balancer_arn'],
          port: 80,
          protocol: 'HTTP',
        )
      end
    end

    def delete_elb_http_listener
      if(!elb_http_listener.nil?)
        @aws.elb.delete_listener(listener_arn: elb_http_listener['listener_arn'])
      end
    end

    def delete_elb_https_listener
      if(!elb_https_listener.nil?)
        @aws.elb.delete_listener(listener_arn: elb_https_listener['listener_arn'])
      end
    end

    def create_r53_testing_alias
      r_type , zone_id = hosted_zone_info(get_hosted_zone(get_base_domain(@app['r53_testing_alias'])))
      @aws.r53.change_resource_record_sets(change_batch: { changes: [
        { action: 'UPSERT',
          resource_record_set: { 
            name: @app['r53_testing_alias'],
            resource_records: [{ value: frontend_elb['dns_name'] }],
            ttl: @app['dns_ttl_default'],
            type: 'CNAME',
          }
        }]},
        hosted_zone_id: zone_id,
      )
    end

    def r53_testing_alias
      r53_get_record(@app['r53_testing_alias'])
    end

    def r53_get_record(record)
       r_type , zone_id = hosted_zone_info(get_hosted_zone(get_base_domain(record)))
       @aws.r53.list_resource_record_sets(hosted_zone_id: zone_id).resource_record_sets.each do |rr|
         if rr.name.eql? "#{record}."
           return rr
         end
       end
       nil?
    end

    def e2app_elb_policy
      get_local_policy(@app['e2app_elb_policy_name'])
    end

    def get_local_policy(policy_name)
      @aws.iam.list_policies(scope: 'Local').policies.each do |policy|
        if policy['policy_name'].eql? policy_name
          return policy
        end
      end
      nil
    end

    def create_local_policy(policy_name, policy_document)
      if get_local_policy(policy_name).nil?
        @aws.iam.create_policy(policy_name: policy_name, path: '/', policy_document: policy_document.to_json)
      end
    end

    def e2app_elb_policy_document
      return {
        "Version": "2012-10-17",
        "Statement":[{
          "Effect": "Allow",
          "Action": "elasticloadbalancing:RegisterTargets",
          "Resource": target_group['target_group_arn'],
          },
          {
          "Effect": "Allow",
          "Action": "elasticloadbalancing:DescribeLoadBalancers",
          "Resource": '*',
          },
          {
          "Effect": "Allow",
          "Action": "elasticloadbalancing:DescribeTags",
          "Resource": '*',
          },
          {
          "Effect": "Allow",
          "Action": "elasticloadbalancing:DescribeTargetGroups",
          "Resource": '*',
          },
          {
          "Effect": "Allow",
          "Action": "elasticloadbalancing:DecribeListeners",
          "Resource": frontend_elb['load_balancer_arn'],
          },
        ]
      }
    end

    def create_e2app_elb_policy
      create_local_policy(@app['e2app_elb_policy_name'], e2app_elb_policy_document)
    end

    def db_instance_security_group
      @aws.rds.describe_db_security_groups.db_security_groups.each do |dbsg|
        if dbsg['db_security_group_name'].eql? db_instance['db_security_groups'][0]['db_security_group_name']
          return dbsg
        end
      end
      nil?
    end

    def create_e2app_rds_policy
      policy_document = {
        "Version": "2012-10-17",
        "Statement":[{
        "Effect": "Allow",
        "Action": "rds:AuthorizeDBSecurityGroupIngress",
        "Resource": db_instance_security_group['db_security_group_arn'],
        }]}
      create_local_policy(@app['e2app_rds_policy_name'], policy_document)
    end

    def create_e2app_s3homenode_policy
      policy_document = {
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::#{@app['homenodeimage_s3_bucket']}/*"
        }]}
      create_local_policy(@app['e2app_s3homenode_policy_name'], policy_document)
    end

    def delete_local_policy(policy_name)
      if !get_local_policy(policy_name).nil?
        @aws.iam.delete_policy(policy_arn: get_local_policy(policy_name)['arn'])
      end
    end

    def delete_e2app_elb_policy
      delete_local_policy(@app['e2app_elb_policy_name'])
    end

    def delete_e2app_rds_policy
      delete_local_policy(@app['e2app_rds_policy_name'])
    end

    def e2app_rds_policy
      get_local_policy(@app['e2app_rds_policy_name'])
    end

    def e2app_s3homenode_policy
      get_local_policy(@app['e2app_s3homenode_policy_name'])
    end

    def is_policy_attached?(policy_name, iam_role)
      return nil if get_local_policy(policy_name).nil?

      @aws.iam.list_entities_for_policy(policy_arn: get_local_policy(policy_name)['arn']).policy_roles.each do |role|
        if role['role_id'] == iam_app_role['role_id']
          return true
        end 
      end
      nil
    end

    def attach_policy_to_role(policy_name, iam_role)
      unless is_policy_attached?(policy_name, iam_role)
        @aws.iam.attach_role_policy(policy_arn: get_local_policy(policy_name)['arn'], role_name: iam_role['role_name'])
      end
    end

    def attach_elb_policy
      attach_policy_to_role(@app['e2app_elb_policy_name'], iam_app_role)
    end

    def attach_rds_policy
      attach_policy_to_role(@app['e2app_rds_policy_name'], iam_app_role)
    end

    def attach_s3homenode_policy
      attach_policy_to_role(@app['e2app_s3homenode_policy_name'], iam_app_role)
    end

    def detach_policy_from_role(policy_name, iam_role)
      if is_policy_attached?(policy_name, iam_role)
        @aws.iam.detach_role_policy(policy_arn: get_local_policy(policy_name)['arn'], role_name: iam_role['role_name'])
      end
    end

    def detach_elb_policy
      detach_policy_from_role(@app['e2app_elb_policy_name'], iam_app_role)
    end

    def detach_rds_policy
      detach_policy_from_role(@app['e2app_rds_policy_name'], iam_app_role)
    end

    def webhead_security_group
      vpc_get_security_group(@app['webhead_security_group'])
    end

    def create_webhead_security_group
      if webhead_security_group.nil?
        resp = @aws.ec2.create_security_group(description: "E2 Webhead Security Group", group_name: @app['webhead_security_group'], vpc_id: vpc['vpc_id'])
        @aws.ec2.authorize_security_group_ingress(
          group_id: resp['group_id'],
          ip_permissions: [{
            from_port: '443',
            to_port: '443',
            ip_protocol: 'tcp',
            user_id_group_pairs: [
            {
              group_id: frontend_elb_security_group['group_id'], 
            }], 
          }]
        )
      end
    end

    def bastion_security_group
      vpc_get_security_group(@app['bastion_security_group'])
    end

    def create_bastion_security_group
      if bastion_security_group.nil?
        resp = @aws.ec2.create_security_group(description: "E2 Bastion Security Group", group_name: @app['bastion_security_group'], vpc_id: vpc['vpc_id'])
        @aws.ec2.authorize_security_group_ingress(
          group_id: resp['group_id'],
          ip_permissions: [{
            from_port: '22',
            to_port: '22',
            ip_protocol: 'tcp',
            ip_ranges: [{cidr_ip: "#{current_ip}/32", description: 'Restricted'}]
          }]
        )
      end
    end

    def create_app_security_groups
      create_webhead_security_group
      create_bastion_security_group
    end

    def opsworks_layer(layer_name)
      @aws.opsworks.describe_layers(stack_id: opsworks_stack['stack_id']).layers.each do |layer|
        return layer if layer['name'].eql? layer_name
      end
    end

    def opsworks_instances(layer_name)
      @aws.opsworks.describe_instances(layer_id: opsworks_layer(layer_name)['layer_id']).instances
    end

    def create_rds_subnet(subnet_num)
      if rds_subnet(subnet_num).nil?
        subnet_resp = @aws.ec2.create_subnet(
          availability_zone: @app["availability_zone_rds#{subnet_num}"],
          cidr_block: @app["app_rds_subnet#{subnet_num}"], 
          vpc_id: vpc['vpc_id'])

        # No public addresses for the RDS instance, I believe
        # @aws.ec2.modify_subnet_attribute(map_public_ip_on_launch: {value: true}, subnet_id: subnet_resp['subnet']['subnet_id'])
      end
    end

    def rds_db_subnet_group
      @aws.rds.describe_db_subnet_groups.db_subnet_groups.each do |db_subnet_group|
        @aws.rds.list_tags_for_resource(resource_name: db_subnet_group['db_subnet_group_arn']).tag_list.each do |k,v|
          return db_subnet_group if(k.eql? 'app' and v.eql? 'e2')
        end
      end
      nil
    end

    def create_rds_db_subnet_group
      if rds_db_subnet_group.nil?
        @aws.rds.create_db_subnet_group(
          db_subnet_group_description: "E2 VPC RDS DB Subnet Group",
          db_subnet_group_name: @app['rds_db_subnet_group_name'],
          subnet_ids: [rds_subnet(1)['subnet_id'], rds_subnet(2)['subnet_id']],
          tags: [app_tag]
        )
      end
    end

  end
end
