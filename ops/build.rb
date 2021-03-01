#!/usr/bin/env ruby

$LOAD_PATH.unshift('lib')
require 'aws-sdk'
require 'e2/appstate'
require 'getoptlong'

opts = GetoptLong.new(
  [ '--delete', '-d', GetoptLong::NO_ARGUMENT ],
  [ '--deep', GetoptLong::NO_ARGUMENT ],
  [ '--create', '-c', GetoptLong::NO_ARGUMENT ]
)

do_create = nil
do_delete = nil
do_deep = nil

opts.each do |opt|
  case opt
    when '--delete'
      do_delete = 1
    when '--create'
      do_create =1
    when '--deep'
      do_deep = 1
  end
end

if(do_create.nil? and do_delete.nil?)
  do_create = 1
end

if(do_create and do_delete)
  puts "Cannot do --create and --delete at the same time"
  exit
end

app = E2::Appstate.new

if do_create

  # CF - Complete
  if(app.vpc.nil?)
    puts "Creating E2 app VPC"
    app.create_vpc
  else
    puts "E2 app VPC already created"
  end

  # CF- Complete
  if app.vpc_internet_gateway.nil?  
    puts "Creating VPC internet gateway"
    app.create_vpc_internet_gateway
  else
    puts "VPC internet gateway already created"
  end

  # CF - Complete

  if(app.iam_app_role.nil?)
    puts "Creating IAM app role"
    app.create_iam_app_role
  else
    puts "E2 app IAM role already created"
  end

  # CF - Complete

  if(app.iam_service_role.nil?)
    puts "Creating IAM service role"
    app.create_iam_service_role
  else
    puts "E2 service IAM role already created"
  end

  # CF - Complete
  if(app.frontend_elb_security_group.nil?)
    puts "Creating frontend ELB security group"
    app.create_frontend_elb_security_group
  else
    puts "Frontend ELB security group already created"
  end

  # CF - Complete
  if(app.frontend_elb.nil?)
    puts "Creating frontend ELB"
    app.create_frontend_elb
  else
    puts "Frontend ELB already created"
  end

  # CF - Complete
  if(app.target_group.nil?)
    puts "Creating target group"
    app.create_target_group
  else
    puts "Target group already created"
  end

  # CF - Complete
  if(app.elb_certificate.nil?)
    puts "Creating ELB certificate"
    app.create_elb_certificate
  else
    puts "ELB certificate already created"
  end

  # CF - Complete
  if(app.elb_certificate_verified?)
    puts "ELB certificate already verified"
  else
    while(!app.elb_certificate_verified?)
      puts "Waiting on ELB certificate verification"
      sleep 5
    end
  end

  # CF - NOOP
  puts "Tagging hosted R53 zones"
  app.tag_hosted_zones

  # CF - Complete
  if(app.elb_https_listener.nil?)
    puts "Creating ELB HTTPS Listener"
    app.create_elb_https_listener
  else
    puts "ELB HTTPS Listener already created"
  end

  # CF - Complete
  if(app.elb_http_listener.nil?)
    puts "Creating ELB HTTP Listener"
    app.create_elb_http_listener
  else
    puts "ELB HTTP Listener already created"
  end

  # CF - NOOP
  puts "Create or Modify R53 testing alias"
  app.create_r53_testing_alias

  # CF - Complete
  if(app.e2app_elb_policy.nil?)
    puts "Creating E2 App ELB Policy"
    app.create_e2app_elb_policy
  else
    puts "E2 App ELB Policy already created"
  end

  # CF - Complete
  if(app.e2app_rds_policy.nil?)
    puts "Creating E2 App RDS Policy"
    app.create_e2app_rds_policy 
  else
    puts "E2 App RDS Policy already created"
  end

  # CF - Complete
  if(app.e2app_s3homenode_policy.nil?)
    puts "Creating S3 Homenode Image Policy"
    app.create_e2app_s3homenode_policy
  else
    puts "E2 S3 Homenode Image Policy already created"
  end

  # CF - Complete
  puts "Attaching E2 App Policies"
  app.attach_elb_policy
  app.attach_rds_policy
  app.attach_s3homenode_policy

  # CF - Complete
  if app.webhead_security_group.nil?
    puts "Creating E2 App Webhead security group"
    app.create_webhead_security_group
  else
    puts "E2 App Webhead security group already created"
  end

  # CF - Complete
  if app.bastion_security_group.nil?
    puts "Creating E2 Bastion security group"
    app.create_bastion_security_group
  else
    puts "E2 Bastion security group already created"
  end

  if(app.opsworks_stack.nil?)
    puts "Creating Opsworks stack"
    app.create_opsworks_stack
  else
    puts "E2 app OpsWorks stack already created"
  end

  [1,2].each do |subnet_num|
    if(app.rds_subnet(subnet_num).nil?)
      puts "Creating E2 app RDS subnet #{subnet_num}"
      app.create_rds_subnet(subnet_num)
    else
      puts "E2 app RDS subnet #{subnet_num} already created"
    end
  end

  if(app.rds_db_subnet_group.nil?)
    puts "Creating E2 app RDS db subnet group"
    app.create_rds_db_subnet_group 
  else
    pp app.rds_db_subnet_group
    puts "E2 app RDS subnet group already created"
  end

#  puts "Adjusting ingress Security Groups for SSH"
#  app.vpc_add_ssh_ingress

end

if do_delete

  if(do_deep)
    puts "Deleting ELB certificate"
    # TODO
  end

  unless(app.opsworks_stack.nil?)
    puts "Deleting Opsworks stack"
    app.delete_opsworks_stack
  else
    puts "E2 app OpsWorks stack does not exist"
  end

  puts "Detaching E2 App Policies"
  app.detach_elb_policy
  app.detach_rds_policy

  unless(app.e2app_elb_policy.nil?)
    puts "Deleting E2 App ELB policy"
    app.delete_e2app_elb_policy
  else
    puts "E2 App ELB policy does not exist"
  end

  unless(app.elb_http_listener.nil?)
    puts "Deleting ELB HTTP Listener"
    app.delete_elb_http_listener
  else
    puts "ELB HTTP Listener does not exist"
  end

  unless(app.elb_https_listener.nil?)
    puts "Deleting ELB HTTPS Listener"
    app.delete_elb_https_listener
  else
    puts "ELB HTTPS Listener does not exist"
  end

  unless app.target_group.nil?
    puts "Deleting target group"
    app.delete_target_group
  else
    puts "Target group does not exist"
  end

  unless app.frontend_elb.nil?
    puts "Deleting frontend ELB"
    app.delete_frontend_elb
  else
    puts "Frontend ELB does not exist"
  end

  unless(app.frontend_elb_security_group.nil?)
    puts "Deleting Frontend ELB security group"
    app.delete_frontend_elb_security_group
  else
    puts "Frontend ELB Security group does not exist"
  end 


#  unless(app.bastion_vpc_elastic_ip.nil?)
#    puts "Deleting bastion elastic IP"
#    app.delete_bastion_vpc_elastic_ip   
#  else
#    puts 'Bastion elastic IP does not exist'
#  end

  unless(app.vpc_internet_gateway.nil?)
    puts 'Deleting VPC internet gateway'
    app.delete_vpc_internet_gateway
  else
    puts 'VPC internet gateway does not exist'
  end

  if(do_deep)
    unless(app.iam_app_role.nil?)
      puts 'Deleting IAM app role'
      app.delete_iam_app_role
    else
      puts 'E2 IAM role does not exist'
    end

    unless(app.iam_service_role.nil?)
      puts 'Deleting IAM service role'
      app.delete_iam_service_role
    else
      puts 'E2 Service role does not exist'
    end
  end

  unless app.vpc.nil?
    puts 'Deleting E2 app VPC'
    app.delete_vpc
  else
    puts 'E2 app VPC does not exist'
  end

end

