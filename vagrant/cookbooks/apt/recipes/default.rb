#
# Cookbook Name:: apt
# Recipe:: default
#
# Taken from:
# http://stackoverflow.com/questions/9246786/how-can-i-get-chef-to-run-apt-get-update-before-running-other-recipes
#

execute "apt-get-update-periodic" do
  command "apt-get update && apt-get dist-upgrade -y"
  ignore_failure true
  only_if do
    File.exists?('/var/cache/apt/pkgcache.bin') &&
    File.mtime('/var/cache/apt/pkgcache.bin') < Time.now - 86400
  end
end

