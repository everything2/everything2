#
# Cookbook Name:: e2cron
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself
#

# Also in e2engine,e2web,e2tls
logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "www-data"
  group "root"
  mode 0755
  action :create
end

cron 'log_deliver_to_s3.pl' do
  minute '5'
  command "/var/everything/tools/log_deliver_to_s3.pl 2>&1 >> #{logdir}/e2cron.log_deliver_to_s3.#{datelog}"
end

cron 'reaper.pl' do
  user "root"
  minute "50"
  hour "6"
  command "/var/everything/tools/reaper.pl 2>&1 >> #{logdir}/e2cron.reaper.#{datelog}"
end

cron 'data_generator_heartbeat.pl' do
  user "root"
  command "/var/everything/tools/data_generator_heartbeat.pl 2>&1 >> #{logdir}/data_generator_heartbeat.reaper.#{datelog}"
end

cron 'data_generator_heartbeat lenghty' do
  user "root"
  command "/var/everything/tools/data_generator_heartbeat.pl --lengthy 2>&1 >> #{logdir}/data_generator_lengthy.reaper.#{datelog}"
  minute 15
end

# We need this on the bastion. Place a 1g swapfile in the root dir
#
bash 'createswap' do
  creates "/swapfile"
  code "
    dd if=/dev/zero of=/swapfile bs=1024 count=1M
    mkswap /swapfile
    swapon /swapfile
  "
end
