#
# Cookbook Name:: e2tls
# Recipe:: default
#
# Copyright 2017, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# PAWS for ACM API
git '/var/paws' do
  repository 'https://github.com/pplu/aws-sdk-perl.git'
  revision 'release-0.32'
  action :sync
end

package 'dehydrated'
package 'libmoosex-classattribute-perl'
package 'libaws-signature4-perl'
package 'liburi-encode-perl'

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

['curl','libdata-printer-perl','build-essential','libmodule-find-perl','liburi-template-perl','libmodule-runtime-perl','libconfig-ini-perl'].each do |pkg|
  package pkg
end

# Also in e2engine,e2web,e2tls
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

cron 'dehydrated' do
  hour '2'
  minute '0'
  command "/var/dehydrated/dehydrated -c 2>&1 >> #{logdir}/e2tls.dehydrated.#{datelog}"
end

cron 'aws acm key upload' do
  day '1,15'
  hour '3'
  minute '0'
  command "/var/everything/tools/aws_acm_cert_upload.pl 2>&1 >> #{logdir}/e2tls.aws_acm_cert_upload.#{datelog}"
end
