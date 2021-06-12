#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'aws-sdk-s3'
require 'aws-sdk-lambda'
require 'archive/zip'
require 'json'

deployonly = ARGV[0]

@s3client = Aws::S3::Client.new(region: 'us-west-2') 
@lambdaclient = Aws::Lambda::Client.new(region: 'us-west-2')

@lambdadir = "#{File.expand_path(File.dirname(__FILE__))}/../lambda"

@lambdasource = "lambdasource.everything2.com"
@builddir = "#{@lambdadir}/.build"

FileUtils.mkdir_p @builddir

def function_exists?(function)
  @lambdaclient.list_functions.functions.each do |func|
    return true if func['function_name'].eql? function
  end
  nil
end

Dir.children("#{@lambdadir}").each do |entry|

  if File.directory?("#{@lambdadir}/#{entry}")
    if !deployonly.nil? and !entry.eql? deployonly
      next
    end

    next if entry.match(/^\./)
    filename = "#{entry}.zip"
    output = "#{@builddir}/#{filename}"

    if File.exists? output
      puts "Removing old file: '#{output}'"
      File.unlink(output)
    end

    puts "Creating archive: '#{output}'"
    Archive::Zip.archive(output, "#{@lambdadir}/#{entry}/.")

    puts "Uploading archive: '#{output}'"
    @s3client.put_object(body: File.open(output).read, key: filename, bucket: @lambdasource)
    
    if function_exists?(entry)
      puts "Updating function code: '#{entry}'"
      @lambdaclient.update_function_code(function_name: entry, s3_bucket: @lambdasource, s3_key: filename)
    end
  end
end
