#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'getoptlong'
require 'io/console'

@s3client = Aws::S3::Client.new(region: 'us-west-2')
@bucket = 'secrets.everything2.com'

opts = GetoptLong.new(
  ['--secret', GetoptLong::REQUIRED_ARGUMENT],
  ['--file', GetoptLong::REQUIRED_ARGUMENT]
)

key = nil
filename = nil
opts.each do |opt,arg|
  case opt
  when '--secret'
    key = arg
  when '--file'
    filename = arg
  end
end

if key.nil?
  puts "Need --secret to act upon"
  exit
end

if filename.nil?

  print "Enter secret: "
  STDOUT.flush
  secret1 = STDIN.noecho(&:gets).chomp
  puts ""

  print "Enter secret again: "
  STDOUT.flush
  secret2 = STDIN.noecho(&:gets).chomp
  puts ""

  if secret1.eql? ""
    puts "Secret cannot be blank"
    exit
  end

  if secret1.eql? secret2
    @s3client.put_object(bucket: @bucket, body: secret1, key: key)
    puts "Secret '#{key}' provisioned"
  else
    puts "Secrets do not match!"
  end
else
  puts "Provisioning contents of '#{filename}' as secret: '#{key}'"
  File.open(filename) do |f|
    @s3client.put_object(bucket: @bucket, body: f, key: key)
  end
end
