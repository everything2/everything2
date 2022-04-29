#!/usr/bin/env ruby

require 'erb'

bootstrap = nil

['/var/everything/vagrant/cookbooks/e2engine/templates/default','/var/bootstrap/etc'].each do |bootstrapdir|
  if Dir.exist? bootstrapdir
    bootstrap = bootstrapdir
  end
end

if bootstrap.nil?
  puts "Could not find a bootstrap directory"
  exit
end

files = [{template: "#{bootstrap}/apache2.conf.erb", file: '/etc/apache2/apache2.conf'},
	 {template: "#{bootstrap}/everything.erb", file: '/etc/apache2/everything.conf'}]

files.each do |f|
  template = ERB.new(File.open(f[:template]).read)

  bind = binding
  bind.local_variable_set(:node, {}) 

  File.write(f[:file], template.result(bind))
end
