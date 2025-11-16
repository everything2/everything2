#!/usr/bin/env ruby
#
# Validation script for etc/apache_blocks.json
# Ensures the file is properly formatted and contains valid data
#

require 'json'

SCRIPT_DIR = File.dirname(__FILE__)
CONFIG_FILE = File.join(SCRIPT_DIR, 'apache_blocks.json')

def validate_ip(ip)
  # Basic IPv4 validation
  octets = ip.split('.')
  return false unless octets.length == 4
  octets.all? { |octet| octet =~ /^\d+$/ && octet.to_i >= 0 && octet.to_i <= 255 }
end

def validate_ip_block(block)
  # IP block should be partial IP (1-3 octets)
  octets = block.split('.')
  return false unless octets.length >= 1 && octets.length <= 3
  octets.all? { |octet| octet =~ /^\d+$/ && octet.to_i >= 0 && octet.to_i <= 255 }
end

puts "Validating Apache blocks configuration: #{CONFIG_FILE}"
puts

unless File.exist?(CONFIG_FILE)
  puts "ERROR: Configuration file not found: #{CONFIG_FILE}"
  exit 1
end

begin
  config = JSON.parse(File.read(CONFIG_FILE))
rescue JSON::ParserError => e
  puts "ERROR: Invalid JSON format"
  puts e.message
  exit 1
end

errors = []
warnings = []

# Validate required fields
%w[banned_user_agents banned_ips banned_ipblocks].each do |field|
  unless config.key?(field)
    errors << "Missing required field: #{field}"
  end
end

if errors.any?
  puts "ERRORS:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
end

# Validate banned_user_agents
if config['banned_user_agents']
  unless config['banned_user_agents'].is_a?(Array)
    errors << "banned_user_agents must be an array"
  else
    config['banned_user_agents'].each_with_index do |ua, index|
      unless ua.is_a?(String) && !ua.empty?
        errors << "banned_user_agents[#{index}]: must be a non-empty string"
      end
      if ua.include?('"')
        warnings << "banned_user_agents[#{index}]: contains quote character (may cause Apache config issues)"
      end
    end
  end
end

# Validate banned_ips
if config['banned_ips']
  unless config['banned_ips'].is_a?(Array)
    errors << "banned_ips must be an array"
  else
    config['banned_ips'].each_with_index do |ip, index|
      unless ip.is_a?(String) && validate_ip(ip)
        errors << "banned_ips[#{index}]: '#{ip}' is not a valid IPv4 address"
      end
    end
  end
end

# Validate banned_ipblocks
if config['banned_ipblocks']
  unless config['banned_ipblocks'].is_a?(Array)
    errors << "banned_ipblocks must be an array"
  else
    config['banned_ipblocks'].each_with_index do |block, index|
      unless block.is_a?(String) && validate_ip_block(block)
        errors << "banned_ipblocks[#{index}]: '#{block}' is not a valid IP block prefix"
      end
    end
  end
end

# Validate infected_ips (optional legacy field)
if config['infected_ips']
  unless config['infected_ips'].is_a?(Array)
    warnings << "infected_ips field exists but is not an array"
  else
    config['infected_ips'].each_with_index do |ip, index|
      unless ip.is_a?(String) && validate_ip(ip)
        warnings << "infected_ips[#{index}]: '#{ip}' is not a valid IPv4 address"
      end
    end
    warnings << "infected_ips is a legacy field - consider consolidating with banned_ips"
  end
end

# Report results
if errors.any?
  puts "VALIDATION FAILED"
  puts
  puts "ERRORS:"
  errors.each { |e| puts "  - #{e}" }
  puts
  exit 1
end

puts "✓ JSON syntax valid"
puts "✓ Required fields present"
puts "✓ #{config['banned_user_agents'].length} user agents configured"
puts "✓ #{config['banned_ips'].length} IP addresses configured"
puts "✓ #{config['banned_ipblocks'].length} IP blocks configured"
if config['infected_ips']
  puts "✓ #{config['infected_ips'].length} infected IPs configured (legacy)"
end
puts

if warnings.any?
  puts "WARNINGS:"
  warnings.each { |w| puts "  - #{w}" }
  puts
end

puts "VALIDATION PASSED"
exit 0
