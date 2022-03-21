#!/usr/bin/env ruby

require 'digest'
require 'find'
require 'getoptlong'
require 'aws-sdk-s3'
require 'json'
require 'fileutils'

opts = GetoptLong.new(
  [ '--region', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--bucket', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--update', GetoptLong::NO_ARGUMENT ]
)

@aws_region = nil
@buildcache_bucket = nil
@cache_update = nil

opts.each do |opt, arg|
  case opt
    when '--region'
      @aws_region = arg
    when '--update'
      @cache_update = true
    when '--bucket'
      @buildcache_bucket = arg
  end
end

build_elements = [
  {locations: ['serverless','docker/e2lib'], name: "E2Lib Docker Build", rule: 'docker_e2lib.build'},
  {locations: ['ecore','docker/e2base','www','templates','etc','t'], name: "E2Base Docker Build", rule: 'docker_e2base.build'},
  {locations: ['docker/e2app','vagrant/cookbooks/e2engine'], name: "E2App Docker Build", rule: 'docker_e2app.build'},
]

def fetch_checksum_cache
  if @aws_region.nil?
    target_file = checksum_base+'/'+last_build_file
    if File.exists? target_file
      JSON.parse(File.open(checksum_base+'/'+last_build_file).read)
    else
      {}
    end
  else
    s3client = Aws::S3::Client.new(region: @aws_region)
    puts "Getting buildcache from #{@buildcache_bucket}/#{last_build_file}"
    begin
      body = s3client.get_object(bucket: @buildcache_bucket, key: last_build_file)
      JSON.parse(body.body.read)
    rescue Aws::S3::Errors::NoSuchKey
      puts "No existing buildcache found"
      {}
    end
  end
end

def last_build_file
  if @aws_region.nil?
    '.buildcache/last_build.json'
  else
    'last_build.json'
  end
end

def checksum_base
  File.expand_path('..',File.dirname(__FILE__))
end

def checksum_location(location)
  all_files = []
  checksums = {}

  ignore_files = []
  Find.find(checksum_base + '/' + location) do |path|
    if FileTest.file?(path) and path.match('/.gitignore$')
      f = File.open(path)
      f.readlines.each do |l|
        ignore_files.push(*Dir.glob(File.dirname(path) + '/'+l.chomp))
      end
      f.close
    end
  end

  Find.find(checksum_base + '/' + location) do |path|
    if FileTest.file?(path) and !File.dirname(path).match?(/\.git/) 
      is_ignored = nil
      ignore_files.each do |ignore_me|
        if path.match("^#{ignore_me}")
          is_ignored = true
          break
        end
      end

      if(!is_ignored)
        all_files.push(path)
      end
    end
  end

  all_files.each do |f|
    h = File.open(f)
    checksums[f.gsub(checksum_base+'/','')] = Digest::SHA256.hexdigest(h.read)
    h.close
  end
  checksums
end

if !@cache_update.nil?
  if(@aws_region.nil?)
    File.write(checksum_base + '/' + last_build_file,JSON.pretty_generate(checksum_location('')))
  else
    s3client = Aws::S3::Client.new(region: @aws_region)
    s3client.put_object(body: JSON.pretty_generate(checksum_location('')), key: last_build_file, bucket: @buildcache_bucket)
  end
else
  latest_checksums = fetch_checksum_cache 
  build_elements.each do |build|
 
    needs_rebuild = nil?
    build[:locations].each do |l|
      incoming_checksums = checksum_location(l)
      incoming_checksums.each do |k,v|
        if !latest_checksums.has_key?(k)
          puts "File new: #{k}, rebuilding #{build[:name]}"
          needs_rebuild = true
        elsif !latest_checksums[k].eql? v
          puts "File modified: #{k}, rebuilding #{build[:name]}"
          needs_rebuild = true
        end
      end
      latest_checksums.each do |k,v|
        if(k.match?(/^#{l}\//) and !incoming_checksums.has_key?(k))
          puts "#{k} was deleted, rebuilding #{build[:name]}"
          needs_rebuild = true
        end
      end
    end

    if needs_rebuild
      to_touch = checksum_base + '/.buildcache/'+build[:rule]
      puts "Touching '#{to_touch}'"
      FileUtils.touch(to_touch)
    end  
  end
end

