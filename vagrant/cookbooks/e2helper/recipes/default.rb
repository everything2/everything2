#
# Cookbook Name:: e2helper
# Recipe:: default
#
# Copyright 2012, Everything2 Media LLC
#
# You are free to use/modify these files under the same terms as the Everything Engine itself

to_install = [
  'strace',
  'vim',
  'locate',
  'screen',
  'mysql-client'
]

to_install.each do |p|
  package p
end


