#
# Cookbook Name:: e2engine
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

require 'json'

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
    'libcaptcha-recaptcha-perl',
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
    'libauthen-sasl-perl',
    'libxml-rss-perl',
    'yui-compressor',
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

nosearch_words = ['a','an','and','are','at','definition','everything','for','if','in','is','it','my','new','node','not','of','on','that','the','thing','this','to','we','what','why','with','writeup','you','your']
nosearch_words_hash = {}
nosearch_words.each { |x| nosearch_words_hash[x] = 1 }

everything_conf_variables = {
    "everyuser" => node["e2engine"]["everyuser"],
    "everypass" => node["e2engine"]["everypass"],
    "everything_dbserv" => node["e2engine"]["everything_dbserv"],
    "cookiepass" => node["e2engine"]["cookiepass"],
    "canonical_web_server" => node["e2engine"]["canonical_web_server"],
    "use_captcha" => node["e2engine"]["use_captcha"],
    "use_compiled" => node["e2engine"]["use_compiled"],
    "homenode_image_host" => node["e2engine"]["homenode_image_host"],
    "smtp_host" => node["e2engine"]["smtp_host"],
    "smtp_use_ssl" => node["e2engine"]["smtp_use_ssl"],
    "smtp_port" => node["e2engine"]["smtp_port"],
    "smtp_user" => node["e2engine"]["smtp_user"],
    "smtp_pass" => node["e2engine"]["smtp_pass"],
    "mail_from" => node["e2engine"]["mail_from"],
    "environment" => node["e2engine"]["environment"],
    "notification_email" => node["e2engine"]["notification_email"],
    "nodecache_size" => node["e2engine"]["nodecache_size"],
    "recaptcha" => node["e2engine"]["recaptcha"].to_hash,
    "s3" => node["e2engine"]["s3"].to_hash,
    "static_nodetypes" => node["e2engine"]["static_nodetypes"],
    "memcache" => node["e2engine"]["memcache"].to_hash,
    "clean_search_words_aggressively" => node["e2engine"]["clean_search_words_aggressively"],
    "search_row_limit" => node["e2engine"]["search_row_limit"],
    "logdirectory" => node["e2engine"]["logdirectory"],
    "system" => node["e2engine"]["system"].to_hash,
    "permanent_cache" => {
      "usergroup" => 1,
      "htmlpage" => 1,
      "container" => 1,
      "htmlcode" => 1,
      "maintenance" => 1,
      "setting" => 1,
      "fullpage" => 1,
      "nodetype" => 1,
      "writeuptype" => 1,
      "linktype" => 1,
      "theme" => 1,
      "themesetting" => 1
    },
    "utf8" => 1,
    "nosearch_words" => nosearch_words_hash,
    "create_room_level" => node["e2engine"]["create_room_level"],
    "stylesheet_fix_level" => node["e2engine"]["stylesheet_fix_level"],
    "maintenance_mode" => node["e2engine"]["maintenance_mode"],
    "writeuplowrepthreshold" => node["e2engine"]["writeuplowrepthreshold"]
}

file '/etc/everything/everything.conf.json' do
  owner "www-data"
  group "www-data"
  content JSON.pretty_generate(everything_conf_variables)
  mode "0755"
end
