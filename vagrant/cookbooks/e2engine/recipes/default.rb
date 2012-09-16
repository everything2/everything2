#
# Cookbook Name:: e2engine
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'json'

to_install = [
    'perl',
    'libalgorithm-diff-perl',
    'libarchive-zip-perl',
    'libcgi-pm-perl',
    'libcache-perl',
    'libcache-memcached-perl',
    'libcaptcha-recaptcha-perl',
    'libconfig-simple-perl',
    'libdbi-perl',
    'libdate-calc-perl',
    'libdatetime-perl',
    'libdatetime-format-strptime-perl',
    'libdigest-sha1-perl',
    'libhtml-tiny-perl',
    'libheap-perl',
    'libio-string-perl',
    'perlmagick',
    'libjson-perl',
    'libxml-generator-perl',
    'libxml-simple-perl',
    'libyaml-perl',
    'libapache-dbi-perl',
    'libclone-perl',
    'libtest-deep-perl',
    'libdevel-caller-perl',
    'libdbd-mysql-perl',
    'git',
    'libnet-amazon-s3-perl',
    'libemail-sender-perl',
    'libnet-smtp-ssl-perl',
    'libauthen-sasl-perl'
]

to_install.each do |p|
  package p
end

git '/var/everything/' do
  repository node["e2engine"]["gitrepo"]
  enable_submodules true
  action :sync
end

directory '/etc/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
end

everything_conf_variables = {
    "everyuser" => node["e2engine"]["everyuser"],
    "everypass" => node["e2engine"]["everypass"],
    "everything_dbserv" => node["e2engine"]["everything_dbserv"],
    "cookiepass" => node["e2engine"]["cookiepass"],
    "canonical_web_server" => node["e2engine"]["canonical_web_server"],
    "use_captcha" => node["e2engine"]["use_captcha"],
    "use_compiled" => node["e2engine"]["use_compiled"],
    "aws_e2media_access_key_id" => node["e2engine"]["aws_e2media_access_key_id"],
    "aws_e2media_secret_access_key" => node["e2engine"]["aws_e2media_secret_access_key"],
    "homenode_image_host" => node["e2engine"]["homenode_image_host"],
    "smtp_host" => node["e2engine"]["smtp_host"],
    "smtp_use_ssl" => node["e2engine"]["smtp_use_ssl"],
    "smtp_port" => node["e2engine"]["smtp_port"],
    "smtp_user" => node["e2engine"]["smtp_user"],
    "smtp_pass" => node["e2engine"]["smtp_pass"],
    "environment" => node["e2engine"]["environment"] }

template '/etc/everything/everything.conf' do
  owner "www-data"
  group "www-data"
  source "everything.conf.erb"
  action "create"
  mode "0755"
  variables(everything_conf_variables)
end

file '/etc/everything/everything.conf.json' do
  owner "www-data"
  group "www-data"
  content JSON.pretty_generate(everything_conf_variables)
  mode "0755"
end
