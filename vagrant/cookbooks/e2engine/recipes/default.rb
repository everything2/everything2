#
# Cookbook Name:: e2engine
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'json'
require 'net/http'
require 'uri'

Chef::Resource::Git.send(:include, E2)
Chef::Resource::Bash.send(:include, E2)
Chef::Resource::File.send(:include, E2)


everythingdir = "/var/everything"

# Minor copy and paste from e2cron
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

to_install = [
    'perl',
    'libalgorithm-diff-perl',
    'libarchive-zip-perl',
    'libcgi-pm-perl',
    'libcache-perl',
    'libcache-memcached-perl',
    'libdbi-perl',
    'libdate-calc-perl',
    'libdatetime-perl',
    'libdatetime-format-strptime-perl',
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
    'libauthen-sasl-perl',
    'libxml-rss-perl',
    'libmoose-perl',
    'libnamespace-autoclean-perl',
    'libwww-perl',
    'libperl-critic-perl',
    'libmason-perl',
    'libmason-plugin-htmlfilters-perl',
    'libtry-tiny-perl',
    'yui-compressor',
    'libapache-db-perl',
    'libdevel-nytprof-perl',
    'libdevel-cycle-perl',
# Practical helper utils
    'strace',
    'vim',
    'locate',
    'screen',
    'mysql-client',
    'xz-utils',
    'xdelta3',
# Needed for Amazon provisioning
    'ruby',
    'ruby-dev',
    'ruby-bundler'
]

to_install.each do |p|
  package p
end

Chef::Log.info("Primary runlist: #{node.primary_runlist}")

git everythingdir do
  repository node["e2engine"]["gitrepo"]
  enable_submodules true
  action :sync
  if is_webhead?
    notifies :restart, "service[apache2]", :delayed
  end
end

directory '/etc/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
end

directory '/var/mason' do
  owner "www-data"
  group "www-data"
  mode 0755
  action "create"
end

bash "Clear Mason2 cache" do
  code "rm -rf /var/mason/obj"

  if is_webhead?
    notifies :restart, "service[apache2]", :delayed
  end
end

nosearch_words = ['a','an','and','are','at','definition','everything','for','if','in','is','it','my','new','node','not','of','on','that','the','thing','this','to','we','what','why','with','writeup','you','your']
nosearch_words_hash = {}
nosearch_words.each { |x| nosearch_words_hash[x] = 1 }

everything_conf_variables = node["e2engine"].dup
everything_conf_variables["basedir"] = everythingdir
everything_conf_variables["permanent_cache"] = {
  "usergroup" => 1,
  "container" => 1,
  "htmlcode" => 1,
  "maintenance" => 1,
  "setting" => 1,
  "fullpage" => 1,
  "nodetype" => 1,
  "writeuptype" => 1,
  "linktype" => 1,
  "sustype" => 1,
  "nodelet" => 1,
  "datastash" => 1,
  "theme" => 1
  }

everything_conf_variables["nosearch_words"] = nosearch_words_hash


file '/etc/everything/everything.conf.json' do
  owner "www-data"
  group "www-data"
  content JSON.pretty_generate(everything_conf_variables)
  mode "0755"
  if is_webhead?
    notifies :restart, "service[apache2]", :delayed 
  end
end

if node['e2engine']['environment'].eql? 'production'
  Chef::Log.info('In production, doing instance registrations')
  Chef::Log.info('Setting up ingress to production DB')

  gem_package 'aws-sdk' do
    timeout 240
    retries 3
  end

  bash "AWS: Register instance with db security group" do
    code "/var/everything/tools/aws_registration.rb --db"
  end
else
  Chef::Log.info('Not in production, not doing instance registrations')
end
