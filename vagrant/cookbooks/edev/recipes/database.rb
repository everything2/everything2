package 'mysql-server'

template '/tmp/grant.sql' do
  owner "www-data"
  group "www-data"
  source "grant.erb"
  action "create"
  mode "0755"
end

execute "mysql permissions" do
  command "cat /tmp/grant.sql | mysql -u root; touch /etc/chef_setup/mysql_permissions"
  creates "/etc/chef_setup/mysql_permissions"
end

#execute "mysql standup" do
#  command "zcat /dropfiles/everything.sql.gz | mysql -u root everything; touch /etc/chef_setup/mysql_standup"
#  creates "/etc/chef_setup/mysql_standup"
#  timeout 10800
#end

