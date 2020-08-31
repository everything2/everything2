#!/usr/bin/env ruby
# frozen_string_literal: true

require 'aws-sdk-cloudformation'
require 'aws-sdk-s3'
require 'getoptlong'
require 'json'
require 'pathname'

opts = GetoptLong.new(
  ['--stack', GetoptLong::REQUIRED_ARGUMENT],
  ['--file', GetoptLong::REQUIRED_ARGUMENT],
  ['--update', GetoptLong::NO_ARGUMENT],
  ['--delete', GetoptLong::NO_ARGUMENT]
)

@s3client = Aws::S3::Client.new(region: 'us-west-2')
@cfclient = Aws::CloudFormation::Client.new(region: 'us-west-2')

@cfbucket = 'cloudformation.everything2.com'
@stack = nil
@operation = nil
@file = nil

def stack_exists?(stack)
  @cfclient.describe_stacks().stacks.each do |s|
    if s['stack_name'].eql? stack
      return true
    end
  end
  nil
end

def do_update(file, stack)
  begin
    data = JSON.parse File.open(file).read
  rescue JSON::ParserError => e
    puts "JSON file is not valid: #{e.message}"
    exit
  rescue Errno::ENOENT => e
    puts "Could not open file: '#{e.message}'"
    exit
  end

  filekey = Pathname.new(file).split.last.to_s
  puts "Uploading '#{file}' to '#{@cfbucket}' as '#{filekey}'"
 
  File.open(file) do |f|
    @s3client.put_object(body: f, bucket: @cfbucket, key: filekey)
  end

  cfparams = {stack_name: stack, template_url: "https://s3-us-west-2.amazonaws.com/#{@cfbucket}/#{filekey}", capabilities: ['CAPABILITY_NAMED_IAM']}

  if stack_exists?(stack)
    @cfclient.update_stack(cfparams)
    puts "Stack updated"
  else
    @cfclient.create_stack(cfparams)
    puts "Stack created"
  end
end

opts.each do |opt, arg|
  case opt
  when '--update'
    @op = 'update'
  when '--delete'
    if @op.eql? 'update'
      puts "Only one of '--update' or '--delete'"
      exit
    end
    @op = 'delete'
  when '--stack'
    @stack = arg
  when '--file'
    @file = arg
  end
end

case @op
  when 'update'
    if @file.nil?
      puts 'Need --file when using --update'
      exit
    end
    if @stack.nil?
      puts 'Need --stack when using --update'
      exit
    end
    do_update(@file, @stack)
end

