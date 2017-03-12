#
# Cookbook Name:: e2web
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'base64'

to_install = [
    'apache2-mpm-prefork',
    'libapache2-mod-perl2',
    'build-essential'
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
rm -rf Linux-Pid*
wget "http://search.cpan.org/CPAN/authors/id/R/RG/RGARCIA/Linux-Pid-0.04.tar.gz" &>> /tmp/linux-pid.log;
tar xzvf Linux-Pid-0.04.tar.gz &>> /tmp/linux-pid.log
cd Linux-Pid-0.04
perl Makefile.PL INSTALLDIRS=vendor &>> /tmp/linux-pid.log
make install &>> /tmp/linux-pid.log
rm -rf Linux-Pid*
cd ..
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

['rewrite','proxy','proxy_http','ssl'].each do |apache_mod|
  link "/etc/apache2/mods-enabled/#{apache_mod}.load" do
    action "create"
    to "../mods-available/#{apache_mod}.load"
    link_type :symbolic
    owner "root"
    group "root"
    notifies :reload, "service[apache2]", :delayed
  end
end

if node["e2web"]["tls_key"]
  file '/etc/apache2/e2.key' do
    owner 'root'
    group 'root'
    mode '0700'
    action 'create'
    content (node["e2web"]["tls_key"])?(Base64.decode64(node["e2web"]["tls_key"])):("")
    notifies :reload, "service[apache2]", :delayed
  end
end

if node["e2web"]["tls_cert"]
  file '/etc/apache2/e2.cert' do
    owner 'root'
    group 'root'
    mode '0700'
    action 'create'
    content (node["e2web"]["tls_cert"])?(Base64.decode64(node["e2web"]["tls_cert"])):("")
    notifies :reload, "service[apache2]", :delayed
  end
end

if node["e2web"]["tls_cert"].nil? and node["e2web"]["tls_key"].nil?
  bash "Create E2 snakeoil certs" do
    cwd "/tmp"
    user "root"
    creates "/etc/apache2/e2.key"
    code <<-EOH
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 -batch -keyout /etc/apache2/e2.key -out /etc/apache2/e2.cert -subj '/C=US/ST=MA/L=Maynard/O=Everything2.com/OU=edev/CN=vagranttest.everything2.com'
    EOH
  end
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
