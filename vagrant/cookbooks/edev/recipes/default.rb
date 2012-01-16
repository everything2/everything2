# We create a chef_setup directory so that we know what steps we've finished

directory "/etc/chef_setup" do
  action "create"
  owner "root"
  group "root"
  mode "0755"
end

include_recipe "edev::webhead"
include_recipe "edev::tools"
include_recipe "edev::devel"
include_recipe "edev::database"
