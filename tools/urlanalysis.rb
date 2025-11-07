#!/usr/bin/env ruby

require 'find'
require 'zlib'

elbregex = %r{(?<type>[^ ]*) (?<time>[^ ]*) (?<elb>[^ ]*) (?<client_ip>[^ ]*):(?<client_port>[0-9]*) (?<target_ip>[^ ]*)[:-]([0-9]*) (?<request_processing_time>[-.0-9]*) (?<target_processing_time>[-.0-9]*) (?<response_processing_time>[-.0-9]*) (?<elb_status_code>|[-0-9]*) (?<target_status_code>\-|[-0-9]*) (?<received_bytes>[-0-9]*) (?<sent_bytes>[-0-9]*) \"(?<request_verb>[^ ]*) (?<request_url>.*) (?<request_proto>- |[^ ]*)\" \"(?<user_agent>[^\"]*)\" (?<ssl_cipher>[A-Z0-9\-_]+) (?<ssl_protocol>[A-Za-z0-9.-]*) (?<target_group_arn>[^ ]*) \"(?<trace_id>[^\"]*)\" \"(?<domain_name>[^\"]*)\" \"(?<chosen_cert_arn>[^\"]*)\" (?<matched_rule_priority>[\-.0-9]*) (?<request_creation_time>[^ ]*) \"(?<actions_executed>[^\"]*)\" \"(?<redirect_url>[^\"]*)\" \"(?<lambda_error_reason>[^ ]*)\" \"(?<target_port_list>[^\\s]+?)\" \"(?<target_status_code_list>[^\\s]+)\" \"(?<classification>[^ ]*)\" \"(?<classification_reason>[^ ]*)\" ?(?<conn_trace_id>[^ ]*)?}

summary = {}
total_requests = 0
forwarded_requests = 0
files_inspected = 0
http_requests = 0

Find.find('.').each do |file|
  next if FileTest.directory?(file)
  next unless file.match(/\.gz$/)
  files_inspected += 1
  puts "Reading #{file}"
  gz = Zlib::GzipReader.new(File.open(file))
  gz.each_line do |line|
    linedata = line.match(elbregex)
    total_requests += 1
    if linedata[:type].eql? 'http'
      http_requests += 1
    end
    next unless linedata[:actions_executed].match "forward"
    forwarded_requests += 1
    path = ''
    if pathdata = linedata[:request_url].match(%r{:443/(?<path>[^ ]*)})
      path = pathdata[:path]
    end
    [:request_url,:elb_status_code,:target_status_code, :domain_name, :type, :path, :client_ip, :user_agent].each do |sym|

      datakey = nil
      if sym.eql? :path
        datakey = path
      else
        datakey = linedata[sym]
      end

      if summary[sym].nil?
        summary[sym] = {}
      end
      if summary[sym][datakey].nil?
        summary[sym][datakey] = 0
      end

      summary[sym][datakey] += 1
    end
  end
end

puts "Files inspected: #{files_inspected}"
puts "HTTP requests: #{http_requests}"
puts "Total requests: #{total_requests}"
puts "Forwarded requests: #{forwarded_requests}"

summary.keys.each do |key|
  puts
  puts "#{key.to_s}:"
  sorted = summary[key].keys.sort {|a,b| summary[key][b] <=> summary[key][a]}
  sorted.first(50).each do |item|
    puts "#{item} - #{summary[key][item]}"
  end
end
