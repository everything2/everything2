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

# PAWS for ACM API
git '/var/paws' do
  repository 'https://github.com/pplu/aws-sdk-perl.git'
  revision 'release-0.32'
  action :sync
end

# MooseX::ClassAttribute for PAWS
git '/var/MooseX-ClassAttribute' do
  repository 'https://github.com/moose/MooseX-ClassAttribute.git'
  revision 'v0.29'
  action :sync
end

# List::Utils as needed by MooseX::ClassAttribute
git '/var/Scalar-List-Utils' do
  repository "https://github.com/Dual-Life/Scalar-List-Utils.git"
  revision 'v1.47'
  action :sync
end

# JSON::MaybeXS as needed by MooseX::ClassAttribute
git '/var/JSON-MaybeXS' do
  repository "https://github.com/p5sagit/JSON-MaybeXS.git"
  revision 'v1.003009'
  action :sync
end

# Net::Amazon::Signature::V4 needed by PAWS
git '/var/Net-Amazon-Signature-S4' do
  repository "https://github.com/gitpan/Net-Amazon-Signature-V4.git"
  revision 'gitpan_version/0.14'
  action :sync
end

# URL::Encode as needed by PAWS
git '/var/p5-url-encode' do
  repository "https://github.com/chansen/p5-url-encode.git"
  revision 'v0.03'
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
  hour '3'
  minute '0'
  command "/var/everything/tools/aws_acm_cert_upload.pl 2>&1 >> #{logdir}/e2tls.aws_acm_cert_upload.#{datelog}"
end
