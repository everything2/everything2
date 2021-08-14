#
# Cookbook Name:: e2engine
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'json'
require 'net/http'
require 'uri'

Chef::Resource::Git.send(:include, E2)
Chef::Resource::Bash.send(:include, E2)
Chef::Resource::File.send(:include, E2)

everythingdir = "/var/everything"
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

to_install = [
    'perl',
    'libalgorithm-diff-perl',
    'libarchive-zip-perl',
    'libcgi-pm-perl',
    'libcache-perl',
    'libdbi-perl',
    'libdate-calc-perl',
    'libdatetime-perl',
    'libdatetime-format-strptime-perl',
    'libhtml-tiny-perl',
    'libheap-perl',
    'libio-string-perl',
    'perlmagick',
    'libjson-perl',
    'libxml-generator-perl',
    'libxml-simple-perl',
    'libyaml-perl',
    'libapache-dbi-perl',
    'libclone-perl',
    'libtest-deep-perl',
    'libdevel-caller-perl',
    'libdbd-mysql-perl',
    'git',
    'libnet-smtp-ssl-perl',
    'libauthen-sasl-perl',
    'libxml-rss-perl',
    'libmoose-perl',
    'libnamespace-autoclean-perl',
    'libwww-perl',
    'libperl-critic-perl',
    'libmason-perl',
    'libmason-plugin-htmlfilters-perl',
    'libtry-tiny-perl',
    'yui-compressor',
    'libapache-db-perl',
    'libdevel-nytprof-perl',
    'libdevel-cycle-perl',
# Practical helper utils
    'strace',
    'vim',
    'locate',
    'screen',
    'mysql-client',
    'xz-utils',
    'xdelta3',
# Needed for Amazon provisioning
    'ruby',
    'ruby-dev',
    'ruby-bundler',
    'build-essential',
# Needed for serverless build testing
    'libssl1.0-dev'
]

to_install.each do |p|
  package p
end

Chef::Log.info("Primary runlist: #{node.primary_runlist}")

git everythingdir do
  repository 'git://github.com/everything2/everything2.git'
  action :sync
  if is_webhead?
    notifies :restart, "service[apache2]", :delayed
  end
end

directory '/etc/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
end

directory '/var/mason' do
  owner "www-data"
  group "www-data"
  mode 0755
  action "create"
end

bash "Clear Mason2 cache" do
  code "rm -rf /var/mason/obj"

  if is_webhead?
    notifies :restart, "service[apache2]", :delayed
  end
end

['libraries','dlcache','buildcache'].each do |dir|
  directory "/var/#{dir}" do
    owner "www-data"
    group "www-data"
    mode 0755
    action "create"
  end
end

bash "Install non-system dependencies" do
  code "perl /var/everything/tools/createdeps.pl --depfile=/var/everything/serverless/deplists/app.json --installdir=/var/libraries --skipverify=Alien::Libxml --builddir=/var/buildcache --dldir=/var/dlcache --skipverify=Alien::Libxml2"

  if is_webhead?
    notifies :restart, "service[apache2]", :delayed
  end
end

['rds','elasticloadbalancingv2','s3','iam','secretsmanager','ses','opsworks','ec2','lambda'].each do |pkg|
  gem_package "aws-sdk-#{pkg}" do
    timeout 240
    retries 3
  end
end

unless node['override_configuration'].eql? 'development'
  ['recaptcha_v3_secret','infected_ips_secret'].each do |secret|
    Chef::Log.info("Seeding secret: #{secret}")
    bash "Seeding secret: #{secret}" do
      code "/var/everything/tools/fetch_secret.rb --secret=#{secret}"

      if is_webhead?
        notifies :restart, "service[apache2]", :delayed
      end
    end 
  end
else
  Chef::Log.info('Not in production, not doing secret seeding')
end

override_config_file = '/etc/everything/override_configuration'
if !node['override_configuration'].nil?
  Chef::Log.info("Using override configuration: #{node['override_configuration']}")
  file override_config_file do
    owner 'www-data'
    group 'www-data'
    content node['override_configuration']
    mode '0755'
    if is_webhead?
      notifies :restart, "service[apache2]", :delayed
    end
  end
else
  Chef::Log.info("No override configuration, skipping")
  file override_config_file do
    action "delete"
  end
end

unless node['override_configuration'].eql? 'development'
  Chef::Log.info('In production, doing instance registrations')
  Chef::Log.info('Setting up ingress to production DB')

  bash "AWS: Register instance with db security group" do
    code "/var/everything/tools/aws_registration.rb --db"
  end
else
  Chef::Log.info('Not in production, not doing instance registrations')
end

to_install = [
    'apache2',
    'libapache2-mod-perl2',
    'build-essential'
]

to_install.each do |p|
  package p
end

unless node['override_configuration'].eql? 'development'
  ['banned_user_agents_secret','banned_ips_secret','banned_ipblocks_secret'].each do |secret|
    Chef::Log.info("Seeding web secret: #{secret}")
    bash "Seeding secret: #{secret}" do
      code "/var/everything/tools/fetch_secret.rb --secret=#{secret}"
      notifies :restart, "service[apache2]", :delayed
    end
  end
else
  Chef::Log.info('Not in production, not doing web secret seeding')
end


load_modules = ['rewrite','proxy','proxy_http','ssl','perl','mpm_prefork','socache_shmcb']

['mpm_event.conf','mpm_event.load'].each do |mod|
  file "/etc/apache2/mods-enabled/#{mod}" do
    action "delete"
    notifies :restart, "service[apache2]", :delayed
  end
end

load_modules.each do |apache_mod|
  link "/etc/apache2/mods-enabled/#{apache_mod}.load" do
    action "create"
    to "../mods-available/#{apache_mod}.load"
    link_type :symbolic
    owner "root"
    group "root"
    notifies :restart, "service[apache2]", :delayed
  end
end

directory "/etc/apache2/conf.d/" do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

confdir = '/etc/apache2/conf.d'

template "#{confdir}/everything" do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'everything.erb'
  notifies :restart, "service[apache2]", :delayed
end

template '/etc/apache2/mod_rewrite.conf' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source "mod_rewrite.conf.erb"
  notifies :restart, "service[apache2]", :delayed
end

template '/etc/apache2/apache2.conf' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'apache2.conf.erb'
  notifies :restart, "service[apache2]", :delayed
  variables(node["e2engine"])
end


template "#{confdir}/ssl.conf" do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'ssl.conf.erb'
  notifies :restart, "service[apache2]", :delayed
  variables(node["e2engine"])
end

bash "Generate self-signed certs" do
  cwd "/tmp"
  user "root"
  code "/var/everything/tools/generate-self-signed-cert.rb"
end

file '/etc/logrotate.d/apache2' do
  action "delete"
  notifies :restart, "service[apache2]", :delayed
end

logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
  notifies :restart, "service[apache2]", :delayed
end

bash 'Install Cloudwatch Agent' do
  user 'root'
  code '/var/everything/tools/cloudwatch-agent-installer.rb'
end

cron 'log_deliver_to_s3.pl' do
  minute '5'
  command "/var/everything/tools/log_deliver_to_s3.pl 2>&1 >> #{logdir}/e2cron.log_deliver_to_s3.#{datelog}"
end

unless node['override_configuration'].eql? 'development'
  template "/lib/systemd/system/apache2.service" do
    owner "root"
    group "root"
    mode "0755"
    action "create"
    source 'apache2.service.erb'
    notifies :restart, "service[apache2]", :delayed
  end

  bash "systemctl reload" do
    cwd "/tmp"
    user "root"
    code "systemctl daemon-reload"
  end
end

service 'apache2' do
  supports :status => true, :restart => true, :reload => true, :stop => true
end

unless node['override_configuration'].eql? 'development'
  Chef::Log.info('In production, doing instance registrations')
  bash "AWS: Register instance with application load balancer" do
    code "/var/everything/tools/aws_registration.rb --elb"
  end
else
  Chef::Log.info('Not in production, not doing instance registrations')
end
