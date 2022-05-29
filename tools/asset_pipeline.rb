#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'zlib'
require 'getoptlong'


opts = GetoptLong.new(
  [ '--assets', GetoptLong::REQUIRED_ARGUMENT],
  [ '--region', GetoptLong::REQUIRED_ARGUMENT]
)

asset_bucket = 'deployed.everything2.com'
region = 'us-west-2'

opts.each do |opt, arg|
  case opt
    when '--assets'
      asset_bucket = arg
    when '--region'
      region = arg
  end
end

s3client = Aws::S3::Client.new(region: region)

puts "Using asset bucket: #{asset_bucket}"

everydir = File.expand_path(__dir__ + "/..")

assets = {'js' => {}, 'css' => {}}

['js','css'].each do |asset_type|
  Dir["#{everydir}/www/#{asset_type}/*"].each do |f|
    basefile = File.basename(f)
    assets[asset_type][basefile] = {}
    assets[asset_type][basefile]['plain'] = File.open(f).read

    if(asset_type.eql? 'js')
      assets[asset_type][basefile]['min'] = `npx terser #{f}`
    elsif(asset_type.eql? 'css')
      assets[asset_type][basefile]['min'] = `npx clean-css-cli #{f}`
    end

    assets[asset_type][basefile]['min_gz'] = Zlib::Deflate.deflate(assets[asset_type][basefile]['min'])
    puts "Minified #{basefile}"
  end
end

git_history = []

(0..4).to_a.each do |num|
  git_history.push `git -C #{everydir} log -n 1 --skip #{num} --pretty=format:"%H"`
  puts "Preserving commit: "+git_history[-1]
end

current_rev = git_history[0]

puts "Uploading to: #{current_rev}"

assets.keys.each do |asset_type|
  assets[asset_type].keys.each do |k|
    if matches = k.match(/([^\.]+)\.#{asset_type}/)
      filepart = matches[1]

      content_type = "application/javascript"

      if asset_type.eql? "css"
        content_type = "text/css"
      end

      ['plain','min','min_gz'].each do |upload_type|

        content_encoding = {}
        file_ending = asset_type
        if(upload_type.eql? 'min_gz')
          content_encoding = {content_encoding: 'gzip'}
          file_ending = "min.gz.#{asset_type}"
        end

        if(upload_type.eql? 'min')
          file_ending = "min.#{asset_type}"
        end

        filename = "#{current_rev}/#{filepart}.#{file_ending}"
        s3args = {bucket: asset_bucket, key: filename, content_type: content_type, body: assets[asset_type][k][upload_type], cache_control: "max-age=31536000"}
        s3args.merge!(content_encoding)
        upload_result = s3client.put_object(s3args)
        if upload_result.etag.nil?
          puts "File upload failed: #{filename}"
          exit 1
        else
          puts "Uploaded: #{filename}"
        end
      end
    else
      puts "Could not determine bucket key from filename: #{k}"
      exit 1
    end
  end
end

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
