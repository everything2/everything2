#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'json'
require 'aws-sdk-s3'
require 'aws-sdk-lambda'
require 'archive/zip'
require 'find'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  event = args[:event]

  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  lambdaclient = Aws::Lambda::Client.new(region: ENV['AWS_DEFAULT_REGION'])

  bucket = 'githubzips.everything2.com'
  zipfile = 'everything2.zip'

  puts "Using bucket: #{bucket}\n"
  puts "Fetching zip file from #{bucket}/#{zipfile} to /tmp\n"
  disk_zipfile = "/tmp/#{zipfile}"
  expandir = "/tmp/expand"
  
  filepart = "everything2-library-layer.zip"
  new_filename = "/tmp/#{filepart}"

  File.unlink(disk_zipfile) if File.exist? disk_zipfile
  File.unlink(new_filename) if File.exist? new_filename

  FileUtils.rm_rf(expandir) if Dir.exist? expandir
  resp = s3client.get_object(response_target: disk_zipfile, bucket: bucket, key: zipfile)

  puts "Fetching done... unzipping\n"
  Archive::Zip.extract(disk_zipfile, "#{expandir}/.")

  puts "Creating new file\n"
  Archive::Zip.archive(new_filename, "/tmp/expand/ecore/.", :path_prefix => 'lib/')

  puts "Uploading library layer zip\n"
  s3client.put_object(bucket: 'e2liblambdabase.everything2.com', key: filepart, body: File.open(new_filename).read)

end
