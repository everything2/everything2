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

puts "Restarting agent"
agent_ctl = '/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl'
puts `#{agent_ctl} -a stop`
puts `#{agent_ctl} -a append-config -c file:#{agent_config}`
puts `#{agent_ctl} -a start`
