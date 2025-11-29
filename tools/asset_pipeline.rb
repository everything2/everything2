#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'zlib'
require 'getoptlong'
require 'open3'
require 'stringio'
require 'brotli'
require 'zlib'

# Zstd support is optional - only load if gem is available
begin
  require 'zstd-ruby'
  ZSTD_AVAILABLE = true
rescue LoadError
  ZSTD_AVAILABLE = false
  puts "Warning: zstd-ruby gem not available, skipping zstd compression"
end

def mem_gzip(data)
  gz = Zlib::GzipWriter.new(StringIO.new)
  gz << data
  gz.close.string
end

opts = GetoptLong.new(
  [ '--assets', GetoptLong::REQUIRED_ARGUMENT],
  [ '--region', GetoptLong::REQUIRED_ARGUMENT],
  [ '--testonly', GetoptLong::NO_ARGUMENT],
  [ '--ignore-warnings', GetoptLong::NO_ARGUMENT]
)

asset_bucket = 'deployed.everything2.com'
region = 'us-west-2'
testonly = nil
ignore_warnings = nil

opts.each do |opt, arg|
  case opt
    when '--assets'
      asset_bucket = arg
    when '--region'
      region = arg
    when '--testonly'
      testonly = 1
    when '--ignore-warnings'
      ignore_warnings = 1
  end
end

s3client = Aws::S3::Client.new(region: region)

puts "Using asset bucket: #{asset_bucket}"

everydir = File.expand_path(__dir__ + "/..")

assets = {'js' => {}, 'css' => {}, 'react' => {}}

['js','css','react'].each do |asset_type|
  Dir["#{everydir}/www/#{asset_type}/**/**"].each do |f|
    puts "Evaluating #{f}"
    next if File.directory?(f)
    basefile = f.gsub(/^#{everydir}\/www\/#{asset_type}\//,"")

    assets[asset_type][basefile] = {}

    if(asset_type.eql? 'js')
      out, err, status = Open3.capture3("npx terser #{f}")
      if(!err.eql? '' and ignore_warnings.nil?)
        puts "Got terser problem: #{err}"
        exit 1
      else
        assets[asset_type][basefile]['min'] = out
      end
    elsif(asset_type.eql? 'css')
      out, err, status = Open3.capture3("npx clean-css-cli #{f}")
      if(!err.eql? '' and ignore_warnings.nil?)
        puts "Got clean-css-cli problem: #{err}"
        exit 1
      else
        assets[asset_type][basefile]['min'] = out
      end
    elsif(asset_type.eql? 'react')
      assets[asset_type][basefile]['min'] = File.open(f).read
    end

    assets[asset_type][basefile]['gzip'] = mem_gzip(assets[asset_type][basefile]['min'])
    assets[asset_type][basefile]['br'] = Brotli.deflate(assets[asset_type][basefile]['min'])
    assets[asset_type][basefile]['deflate'] = Zlib::Deflate.deflate(assets[asset_type][basefile]['min'])

    # Add zstd compression if available
    if ZSTD_AVAILABLE
      assets[asset_type][basefile]['zstd'] = Zstd.compress(assets[asset_type][basefile]['min'], level: 19)
    end

    puts "Minified #{basefile}"
  end
end

git_history = []

(0..8).to_a.each do |num|
  git_history.push `git -C #{everydir} log -n 1 --skip #{num} --pretty=format:"%H"`
  puts "Preserving commit: "+git_history[-1]
end

current_rev = git_history[0]

puts "Uploading to: #{current_rev}"

assets.keys.each do |asset_type|
  assets[asset_type].keys.each do |filename|
    content_type = "application/javascript"

    if filename.match(/\.css$/)
      content_type = "text/css"
    end

    if filename.match(/\.ico$/)
      content_type = "image/x-icon" 
    end

    upload_types = ['min','gzip','br','deflate']
    upload_types.push('zstd') if ZSTD_AVAILABLE

    upload_types.each do |upload_type|
      content_encoding = {}
      encodingpath = ""
      if(upload_type.eql? 'gzip')
        content_encoding = {content_encoding: 'gzip'}
        encodingpath = "gzip/"
      end

      if(upload_type.eql? 'br')
        content_encoding = {content_encoding: 'br'}
        encodingpath = "br/"
      end

      if(upload_type.eql? 'deflate')
        content_encoding = {content_encoding: 'deflate'}
        encodingpath = "deflate/"
      end

      if(upload_type.eql? 'zstd')
        content_encoding = {content_encoding: 'zstd'}
        encodingpath = "zstd/"
      end

      if testonly.nil?
        ["#{current_rev}/#{encodingpath}#{filename}"].each do |to_upload|
          s3args = {bucket: asset_bucket, key: to_upload, content_type: content_type, body: assets[asset_type][filename][upload_type], cache_control: "max-age=31536000"}
          s3args.merge!(content_encoding)
          upload_result = s3client.put_object(s3args)
          if upload_result.etag.nil?
            puts "File upload failed: #{to_upload}"
            exit 1
          else
            puts "Uploaded: #{to_upload}"
          end
        end
      else
        puts "Test only, not uploading for real"
      end
    end
  end
end

if testonly.nil?
  s3client.list_objects_v2(bucket: asset_bucket).contents.each do |file|
    matched = nil
    git_history.each do |rev|
      if file.key.match(/^#{rev}\//)
        matched = true
      end
    end

    if matched.nil?
      s3client.delete_object(bucket: asset_bucket, key: file.key)
      puts "Expired asset: #{file.key}"
    end
  end
else
  puts "Test only, not expiring old assets"
end
