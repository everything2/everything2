#
# Cookbook Name:: e2cron
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself
#

logdir = "/var/log/everything"
datelog = "`date +\\%Y\\%m\\%d\\%H`.log"

directory logdir do
  owner "root"
  group "root"
  mode 0755
  action :create
end

cron 'database_backup_to_s3.pl' do
  hour "0"
  minute "2"
  command "/var/everything/tools/database_backup_to_s3.pl 2>&1 >> #{logdir}/e2cron.database_backup_to_s3.#{datelog}" 
end

cron 'generate_sitemap.pl' do
  hour "1"
  minute "0"
  command "/var/everything/tools/generate_sitemap.pl 2>&1 >> #{logdir}/e2cron.generate_sitemap.#{datelog}"
end

cron 'updateNodelet.pl' do
  user "root"
  minute "0-59/5"
  command "/var/everything/ecore/bin/updateNodelet.pl 2>&1 >> #{logdir}/e2cron.updateNodelet.#{datelog}"
end

cron 'refreshRoom.pl' do
  user "root"
  minute "0-59/5"
  command "/var/everything/ecore/bin/refreshRoom.pl 2>&1 >> #{logdir}/e2cron.refreshRoom.#{datelog}"
end

cron 'cleanCbox.pl' do
  user "root"
  minute "50"
  command "/var/everything/ecore/bin/cleanCbox.pl 2>&1 >> #{logdir}/e2cron.cleanCbox.#{datelog}"
end

cron 'newstats.pl' do
  user "root"
  minute "10"
  hour "6"
  command "/var/everything/ecore/bin/newstats.pl 2>&1 >> #{logdir}/e2cron.newstats.#{datelog}"
end

cron 'expirerooms.pl' do
  user "root"
  minute "30"
  hour "6"
  command "/var/everything/ecore/bin/expirerooms.pl 2>&1 >> #{logdir}/e2cron.expirerooms.#{datelog}"
end

cron 'reaper.pl' do
  user "root"
  minute "50"
  hour "6"
  command "/var/everything/ecore/bin/reaper.pl 2>&1 >> #{logdir}/e2cron.reaper.#{datelog}"
end
