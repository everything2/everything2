#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'fileutils'
require 'json'
require 'aws-sdk-s3'
require 'aws-sdk-lambda'
require 'openssl'
require 'net/http'
require 'archive/zip'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def get_github_secret(s3client)
  return s3client.get_object(bucket: "secrets.everything2.com", key: "github_webhook_secret").body.read
end

def generate_github_signature(secret, payload)
  return 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload)
end

def lambda_handler(args)
  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  lambdaclient = Aws::Lambda::Client.new(region: ENV['AWS_DEFAULT_REGION'])

  bucket = 'githubzips.everything2.com'

  event = args[:event]

  if event['repo'].nil?
    return http_response(400, "No repo to pull")
  end

  html_url = event['repo']

  filename = nil
  filepart = nil
  
  html_url.gsub!("github.com", "codeload.github.com")
  if matches = /\/([^\/]+)$/.match(html_url)
    filepart = matches[1] + '.zip'
    filename = '/tmp/' + filepart
  end

  zipurl = html_url + '/legacy.zip/master'

  if filename.nil?
    return http_response(400, "Could not extract filename part from html_url: '#{html_url}'")
  end

  downloaded_filename = filename+".downloaded"

  File.write(downloaded_filename, Net::HTTP.get(URI.parse(zipurl)))  

  downloaded_file = Archive::Zip.new(downloaded_filename)

  puts "Downloaded file: #{downloaded_filename}"
  prefix = nil


  downloaded_file.each do |item|
    next if item.directory?
    puts "Item: #{item.zip_path}"
    if matches = item.zip_path.match(/^([^\/]+)/)
      prefix = matches[1]
    end
    
    puts "Prefix detected as: #{prefix}"
    break
  end

  puts "Extracting file"
  Archive::Zip.extract(downloaded_filename, "/tmp/.")

  puts "Creating new file"
  Archive::Zip.archive(filename, "/tmp/#{prefix}/.")

  s3client.put_object(bucket: bucket, key: filepart, body: File.open(filename).read)

  if filepart.eql? "everything2.zip"
    puts "Invoking processor handler for 'everything2.zip'"
    lambdaclient.invoke(function_name: "everything2-zipfile-processor", payload: {"bucket": bucket, "zipfile": filepart}.to_json, invocation_type: "Event")
  end

  puts "Cleaning up download"
  File.unlink(filename)

  puts "Cleaning expanded zip directory"
  FileUtils.rm_rf("/tmp/#{prefix}")

  http_response(200, "OK - Cloned #{zipurl}")
end
