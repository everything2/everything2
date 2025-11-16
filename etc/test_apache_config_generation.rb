#!/usr/bin/env ruby
#
# Test script to verify Apache configuration generation
# Simulates what the ERB template does with apache_blocks.json
#

require 'json'

SCRIPT_DIR = File.dirname(__FILE__)
CONFIG_FILE = File.join(SCRIPT_DIR, 'apache_blocks.json')

puts "Testing Apache configuration generation..."
puts "Reading: #{CONFIG_FILE}"
puts

blocks = JSON.parse(File.read(CONFIG_FILE))

coreconfig = ""

coreconfig += "\t# Explicit IP address bans\n"
if blocks['banned_ips']
  blocks['banned_ips'].each do |ip|
    coreconfig += "\tSetEnvIf X-FORWARDED-FOR \"#{ip}\" denyip\n"
  end
end

coreconfig += "\t# IP address block bans\n"
if blocks['banned_ipblocks']
  blocks['banned_ipblocks'].each do |block|
    coreconfig += "\tSetEnvIf X-FORWARDED-FOR ^#{block.gsub(".", "\\.")} denyip\n"
  end
end

coreconfig += "\t# User agent bans\n"
if blocks['banned_user_agents']
  blocks['banned_user_agents'].each do |ua|
    # Quote user agents that contain spaces
    ua_quoted = ua.include?(' ') ? "\"#{ua}\"" : ua
    coreconfig += "\tBrowserMatchNoCase #{ua_quoted} denyip\n"
  end
end

puts "Generated Apache configuration directives:"
puts "=" * 80
puts coreconfig
puts "=" * 80
puts
puts "✓ Configuration generated successfully"
puts "✓ Total directives: #{coreconfig.lines.count}"
puts "✓ IP bans: #{blocks['banned_ips'].length}"
puts "✓ IP block bans: #{blocks['banned_ipblocks'].length}"
puts "✓ User agent bans: #{blocks['banned_user_agents'].length}"
