#
# Cookbook Name:: e2database
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

package 'mysql-server'

template '/tmp/grant.sql' do
  owner "www-data"
  group "www-data"
  source "grant.erb"
  action "create"
  mode "0755"
end

directory "/etc/chef_setup" do
  owner "root"
  group "root"
  mode  "0755"
  action :create
end

execute "mysql permissions" do
  command "cat /tmp/grant.sql | mysql -u root; touch /etc/chef_setup/mysql_permissions"
  creates "/etc/chef_setup/mysql_permissions"
end

execute "database bootstrap" do
  command "/var/everything/tools/qareload.pl"
  creates "/etc/chef_setup/database_bootstrap"
end

service "mysql" do
  action :start
end
