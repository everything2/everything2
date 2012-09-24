#
# Cookbook Name:: e2cron
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself
#

cron 'updateNodelet.pl' do
  user "root"
  minute "0-59/5"
  command "/var/everything/ecore/bin/updateNodelet.pl"
end

cron 'refreshRoom.pl' do
  user "root"
  minute "0-59/5"
  command "/var/everything/ecore/bin/refreshRoom.pl"
end

cron 'cleanCbox.pl' do
  user "root"
  minute "50"
  command "/var/everything/ecore/bin/cleanCbox.pl"
end

cron 'newstats.pl' do
  user "root"
  minute "10"
  hour "6"
  command "/var/everything/ecore/bin/newstats.pl"
end

cron 'expirerooms.pl' do
  user "root"
  minute "30"
  hour "6"
  command "/var/everything/ecore/bin/expirerooms.pl"
end

cron 'reaper.pl' do
  user "root"
  minute "50"
  hour "6"
  command "/var/everything/ecore/bin/reaper.pl"
end
