#!/usr/bin/env ruby

require 'fileutils'
require 'getoptlong'

dldir = '/dl'
debname = 'amazon-cloudwatch-agent.deb'
full_debname = "#{dldir}/#{debname}"

agent_config = __dir__+'/../etc/aws-cloudwatch-agent-config.json'

opts = GetoptLong.new(
  ['--force', GetoptLong::NO_ARGUMENT],
)

do_force = nil

opts.each do |opt|
  case opt
    when '--force'
      do_force = 1
  end
end

if File.exist?('/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent') and do_force.nil? 
  puts "Cloudwatch agent already installed, not touching"
else

  FileUtils.mkdir_p dldir

  puts "Cleaning old deb"
  `dpkg --purge amazon-cloudwatch-agent 2>&1 > /dev/null`
  File.delete full_debname if File.exist? full_debname

  puts "Downloading deb"
  `cd #{dldir} && curl -s -S -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/#{debname}`

  puts "Installing new deb"
  `dpkg -i #{full_debname}`
end

config_location = '/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/config.json'
puts "Installing configuration file"
`cp #{agent_config} #{config_location}`
`rm /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/default.tmp`

puts "Restarting agent"
agent_ctl = '/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl'
`#{agent_ctl} -a stop`
`#{agent_ctl} -a remove-config -c default:`
`#{agent_ctl} -a append-config -c #{config_location} -s`
