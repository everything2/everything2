#
# Cookbook Name:: apt
# Recipe:: default
#
# Taken from:
# http://stackoverflow.com/questions/9246786/how-can-i-get-chef-to-run-apt-get-update-before-running-other-recipes
#

execute "apt-get-update-periodic" do
  command "apt-get update"
  #ignore_failure true
  #only_if do
  #  File.exists?('/var/lib/apt/periodic/update-success-stamp') &&
  #  File.mtime('/var/lib/apt/periodic/update-success-stamp') < Time.now - 86400
  #end
end
