#!/usr/bin/ruby

require 'json'

config_file = "/etc/everything/everything.conf.json"
config = JSON.parse(File.open(config_file, 'r').read)

passconfig = "-p#{config['everypass']}"
if config['everypass'].eql? ""
  passconfig = ""
end

exec("mysql -u#{config['everyuser']} #{passconfig} -h#{config['everything_dbserv']} everything")
