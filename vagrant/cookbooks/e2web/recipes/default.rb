#
# Cookbook Name:: e2web
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'base64'

to_install = [
    'apache2',
    'libapache2-mod-perl2',
    'build-essential'
]

to_install.each do |p|
  package p
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
  variables(node["e2web"])
end


template "#{confdir}/ssl.conf" do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'ssl.conf.erb'
  notifies :restart, "service[apache2]", :delayed
  variables(node["e2web"])
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

# Also in e2cron, e2web
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory "/var/run/apache2/ssl_mutex" do
  owner "www-data"
  group "root"
  mode 0755
  action :create
  notifies :restart, "service[apache2]", :delayed
end

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
  notifies :restart, "service[apache2]", :delayed
end

directory '/var/run/apache2/ssl_mutex' do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

cron 'log_deliver_to_s3.pl' do
  minute '5'
  command "/var/everything/tools/log_deliver_to_s3.pl 2>&1 >> #{logdir}/e2cron.log_deliver_to_s3.#{datelog}"
end

service 'apache2' do
  supports :status => true, :restart => true, :reload => true, :stop => true
end

if node['e2engine']['environment'].eql? 'production'
  Chef::Log.info('In production, doing instance registrations')
  bash "AWS: Register instance with application load balancer" do
    code "/var/everything/tools/aws_registration.rb --elb"
  end
else
  Chef::Log.info('Not in production, not doing instance registrations')
end
