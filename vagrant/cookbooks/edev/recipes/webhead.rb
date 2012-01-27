include_recipe 'cpan'

to_install = [
    'apache2-mpm-prefork',
    'libapache2-mod-perl2',
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
    'libdigest-md5-perl',
    'libdigest-sha1-perl',
    'libhtml-tiny-perl',
    'libheap-perl',
    'libio-string-perl',
    'libimage-magick-perl',
    'libjson-perl',
    'libxml-generator-perl',
    'libxml-simple-perl',
    'libyaml-perl',
    'libapache-dbi-perl',
    'libclone-perl',
    'libtest-deep-perl',
    'libdevel-caller-perl',
    'libdbd-mysql-perl',
    'mercurial',
    'git',

]

to_install.each do |p|
  package p
end 

cpan_to_install = ['Mail::Sender','Mail::Internet','String::Similarity']

cpan_to_install.each do |cpan_item|
  cpan_client cpan_item do
    action 'install'
   install_type 'cpan_module'
   user 'root'
   group 'root'
  end
end

template '/etc/apache2/conf.d/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'everything.erb'
end

link '/etc/apache2/mods-enabled/rewrite.load' do
  action "create"
  to "../mods-available/rewrite.load"
  link_type :symbolic
  owner "www-data"
  group "www-data"
end

template '/etc/apache2/conf.d/everything_rewrite.conf' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  source 'mod_rewrite.conf.erb'
end

directory '/usr/local/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
  recursive true
end

directory '/var/everything' do
  owner "www-data"
  group "www-data"
  mode "0755"
  action "create"
  recursive true
end

git '/var/everything/' do
  repository 'git://github.com/everything2/everything2.git'
  revision 'jaybonci_local_development_fixes'
  action :sync
end

directory '/etc/everything' do
  owner "root"
  group "root"
  mode "0755"
  action "create"
end

template '/etc/everything/everything.conf' do
  owner "www-data"
  group "www-data"
  source "everything.conf.erb"
  action "create"
  mode "0755"
end
