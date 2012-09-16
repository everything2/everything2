#
# Cookbook Name:: e2cron
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself
#

template '/etc/cron.d/e2cron' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'e2cron.erb'
end

