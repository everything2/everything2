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

# Belongs in its own section under "apps"
execute "e2_stylesheet_gen" do
  command "/var/everything/ecore/bin/generateStylesheets.pl"
  cwd "/var/everything/ecore/bin"
  creates "/var/everything/www/stylesheets"
end

