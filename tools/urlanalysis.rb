#!/usr/bin/env ruby

require 'zlib'

elbregex = %r{(?<type>[^ ]*) (?<time>[^ ]*) (?<elb>[^ ]*) (?<client_ip>[^ ]*):(?<client_port>[0-9]*) (?<target_ip>[^ ]*)[:-]([0-9]*) (?<request_processing_time>[-.0-9]*) (?<target_processing_time>[-.0-9]*) (?<response_processing_time>[-.0-9]*) (?<elb_status_code>|[-0-9]*) (?<target_status_code>\-|[-0-9]*) (?<received_bytes>[-0-9]*) (?<sent_bytes>[-0-9]*) \"(?<request_verb>[^ ]*) (?<request_url>.*) (?<request_proto>- |[^ ]*)\" \"(?<user_agent>[^\"]*)\" (?<ssl_cipher>[A-Z0-9\-_]+) (?<ssl_protocol>[A-Za-z0-9.-]*) (?<target_group_arn>[^ ]*) \"(?<trace_id>[^\"]*)\" \"(?<domain_name>[^\"]*)\" \"(?<chosen_cert_arn>[^\"]*)\" (?<matched_rule_priority>[\-.0-9]*) (?<request_creation_time>[^ ]*) \"(?<actions_executed>[^\"]*)\" \"(?<redirect_url>[^\"]*)\" \"(?<lambda_error_reason>[^ ]*)\" \"(?<target_port_list>[^\\s]+?)\" \"(?<target_status_code_list>[^\\s]+)\" \"(?<classification>[^ ]*)\" \"(?<classification_reason>[^ ]*)\" ?(?<conn_trace_id>[^ ]*)?}

urls = {}

Dir.children('.').each do |file|
  next unless file.match(/\.gz$/)
  gz = Zlib::GzipReader.new(File.open(file))
  gz.each_line do |line|
    linedata = line.match(elbregex)
    next unless linedata[:actions_executed].match "forward"
    if urls[linedata[:request_url]].nil? 
      urls[linedata[:request_url]] = 1 
    end
    urls[linedata[:request_url]] = urls[linedata[:request_url]] + 1
  end
end


top_urls = urls.keys.sort_by {|a| urls[a]}.reverse
top_urls[0..9].each do |url|
  puts "#{url} - #{urls[url]}"
end
