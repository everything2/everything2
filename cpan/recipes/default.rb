#
# Cookbook Name:: cpan
# Recipe:: default
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

directory '/tmp/local-lib/' do
  action :delete
  recursive true 
end

directory '/tmp/local-lib/' do
  action :create
  mode '0777'
end

directory '/tmp/local-lib/install' do
  action :create
  mode '0777'
end

cookbook_file '/tmp/local-lib/.modulebuildrc' do
 action :create
 source '.modulebuildrc'
 mode '0644'
end

