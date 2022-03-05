#!/usr/bin/env ruby

require 'erb'

files = [{template: '/var/everything/vagrant/cookbooks/e2engine/templates/default/apache2.conf.erb', file: '/etc/apache2/apache2.conf'},
	 {template: '/var/everything/vagrant/cookbooks/e2engine/templates/default/everything.erb', file: '/etc/apache2/everything.conf'}]

files.each do |f|
  template = ERB.new(File.open(f[:template]).read)

  bind = binding
  bind.local_variable_set(:node, {}) 

  File.write(f[:file], template.result(bind))
end
