#
# Cookbook Name:: e2web
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself


to_install = [
    'apache2-mpm-prefork',
    'libapache2-mod-perl2',
]

to_install.each do |p|
  package p
end

bash "install Linux::Pid" do
  cwd "/tmp"
  user "root"
  creates "/usr/local/lib/perl/5.14.2/auto/Linux/Pid/Pid.so"
  code <<-EOH
cd /tmp
wget "http://search.cpan.org/CPAN/authors/id/R/RG/RGARCIA/Linux-Pid-0.04.tar.gz";
tar xzvf Linux-Pid-0.04.tar.gz
cd Linux-Pid-0.04
perl Makefile.PL INSTALLDIRS=vendor
make install
cd ..
rm -rf Linux-Pid*
  EOH
end

template '/etc/apache2/conf.d/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'everything.erb'
  notifies :reload, "service[apache2]", :delayed
end

template '/etc/apache2/mod_rewrite.conf' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source "mod_rewrite.conf.erb"
  notifies :reload, "service[apache2]", :delayed
end

template '/etc/apache2/apache2.conf' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'apache2.conf.erb'
  notifies :reload, "service[apache2]", :delayed
  variables(node["e2web"])
end

link '/etc/apache2/mods-enabled/rewrite.load' do
  action "create"
  to "../mods-available/rewrite.load"
  link_type :symbolic
  owner "root"
  group "root"
end

link '/etc/apache2/mods-enabled/proxy.load' do
  action "create"
  to "../mods-available/proxy.load"
  link_type :symbolic
  owner "root"
  group "root"
end

link '/etc/apache2/mods-enabled/proxy_http.load' do
  action "create"
  to "../mods-available/proxy_http.load"
  link_type :symbolic
  owner "root"
  group "root"
end

file '/etc/logrotate.d/apache2' do
  action "delete"
  notifies :reload, "service[apache2]", :delayed
end

# Also in e2cron, e2web
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
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
  supports :status => true, :restart => true, :reload => true
end
