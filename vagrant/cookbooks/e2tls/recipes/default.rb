#
# Cookbook Name:: e2tls
# Recipe:: default
#
# Copyright 2017, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# letsencrypt.org pieces
git '/var/dehydrated' do
  repository 'https://github.com/lukas2511/dehydrated.git'
  revision 'v0.4.0'
  action :sync
end

directory '/etc/dehydrated/' do
  owner 'root'
  group 'root'
  mode 0700
  action :create
end

['certs','accounts','wellknown'].each do |newdir|
  directory "/etc/dehydrated/#{newdir}" do
    owner 'root'
    group 'root'
    mode 0700
    action :create
  end
end

template '/etc/dehydrated/config' do
  owner 'root'
  group 'root'
  mode 0700
  source 'dehydrated.config.erb'
end

template '/etc/dehydrated/domains.txt' do
  owner 'root'
  group 'root'
  mode 0700
  source 'domains.txt.erb'
end
