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

execute "database bootstrap" do
  command "/var/everything/tools/ecoretool.pl bootstrap -d everything -n /var/everything/nodepack; touch /etc/chef_setup/database_bootstrap"
  creates "/etc/chef_setup/database_bootstrap"
end

apt_repo "percona" do
  url "http://repo.percona.com/apt"
  distribution "squeeze"
  components ["main"]
  key_id "1C4CBDCDCD2EFD2A"
end

package 'xtrabackup'
