#
# Cookbook Name:: apt
# Recipe:: default
#
# Taken from:
# http://stackoverflow.com/questions/9246786/how-can-i-get-chef-to-run-apt-get-update-before-running-other-recipes

aptstamp = '/tmp/apt.timestamp'

execute "apt-get-update-periodic" do
  command "apt-get update && apt-get dist-upgrade -y && touch #{aptstamp}"
  only_if do
    not File.exists?(aptstamp) or File.mtime(aptstamp) < Time.now - 86400
  end
end
