#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'zlib'
require 'getoptlong'
require 'open3'
require 'stringio'
require 'brotli'

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

# S3 requests are the slow part of this script and they're independent, so run them on a
# fixed pool of threads (#4602). The AWS SDK client is thread-safe. The first exception in
# any worker is re-raised once all workers finish, which fails the build.
UPLOAD_THREADS = 16

def in_parallel(items, threads: UPLOAD_THREADS)
  queue = Queue.new
  items.each { |item| queue << item }
  errors = Queue.new
  workers = Array.new([threads, items.size].min) do
    Thread.new do
      loop do
        item = begin
          queue.pop(true)
        rescue ThreadError
          break
        end
        begin
          yield item
        rescue StandardError => e
          errors << e
        end
      end
    end
  end
  workers.each(&:join)
  raise errors.pop unless errors.empty?
end

def log(line)
  $stdout.write("#{line}\n")
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
static_assets = {}  # Separate hash for static assets (no minification/compression)

# MIME type mapping for static assets
STATIC_MIME_TYPES = {
  '.ttf' => 'font/ttf',
  '.woff' => 'font/woff',
  '.woff2' => 'font/woff2',
  '.eot' => 'application/vnd.ms-fontobject',
  '.otf' => 'font/otf',
  '.png' => 'image/png',
  '.gif' => 'image/gif',
  '.jpg' => 'image/jpeg',
  '.jpeg' => 'image/jpeg',
  '.svg' => 'image/svg+xml',
  '.ico' => 'image/x-icon',
  '.webp' => 'image/webp',
  '.css' => 'text/css',
  '.js' => 'application/javascript',
  '.json' => 'application/json',
  '.txt' => 'text/plain',
  '.html' => 'text/html',
  '.htm' => 'text/html',
  '.xml' => 'application/xml',
  '.swf' => 'application/x-shockwave-flash'
}.freeze

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

    # Add zstd compression if available
    if ZSTD_AVAILABLE
      assets[asset_type][basefile]['zstd'] = Zstd.compress(assets[asset_type][basefile]['min'], level: 19)
    end

    puts "Minified #{basefile}"
  end
end

# Process static assets (fonts, images) - no minification or compression
# These are binary files that are already optimized
Dir["#{everydir}/www/static/**/*"].each do |f|
  next if File.directory?(f)
  basefile = f.gsub(/^#{everydir}\/www\/static\//, "")

  # Read file content as binary
  content = File.binread(f)
  ext = File.extname(f).downcase
  content_type = STATIC_MIME_TYPES[ext] || 'application/octet-stream'

  static_assets[basefile] = {
    'content' => content,
    'content_type' => content_type
  }

  puts "Static asset: #{basefile} (#{content_type}, #{content.bytesize} bytes)"
end

puts "Found #{static_assets.size} static assets"

git_history = []

(0..8).to_a.each do |num|
  git_history.push `git -C #{everydir} log -n 1 --skip #{num} --pretty=format:"%H"`
  puts "Preserving commit: "+git_history[-1]
end

current_rev = git_history[0]

puts "Uploading to: #{current_rev}"

# Encoded copies, and the key prefix each is stored under. There is no deflate copy:
# Application::best_compression_type never picks it (#4602).
ENCODING_PATHS = { 'min' => nil, 'gzip' => 'gzip', 'br' => 'br' }
ENCODING_PATHS['zstd'] = 'zstd' if ZSTD_AVAILABLE

uploads = []

assets.each_value do |files|
  files.each do |filename, encoded|
    content_type = "application/javascript"
    content_type = "text/css" if filename.match(/\.css$/)
    content_type = "image/x-icon" if filename.match(/\.ico$/)

    ENCODING_PATHS.each do |upload_type, encoding|
      args = {
        key: "#{current_rev}/#{encoding ? "#{encoding}/" : ''}#{filename}",
        content_type: content_type,
        body: encoded[upload_type],
      }
      args[:content_encoding] = encoding if encoding
      uploads << args
    end
  end
end

# Static assets (fonts, images) go to [commit]/static/[path] with no compression variants.
static_assets.each do |filename, data|
  uploads << { key: "#{current_rev}/static/#{filename}", content_type: data['content_type'], body: data['content'] }
end

if testonly.nil?
  puts "Uploading #{uploads.size} files with #{UPLOAD_THREADS} threads..."
  in_parallel(uploads) do |args|
    result = s3client.put_object(args.merge(bucket: asset_bucket, cache_control: "max-age=31536000"))
    raise "File upload failed: #{args[:key]}" if result.etag.nil?
    log "Uploaded: #{args[:key]}"
  end
  puts "Upload complete (#{uploads.size} files, #{static_assets.size} static)"
else
  uploads.each { |args| puts "Test only: would upload #{args[:key]} (#{args[:content_type]})" }
end

# Expire assets from commits older than the last 9. list_objects_v2 returns at most 1000
# keys per call, so walk every page; deleting from only the first page left most old
# assets in the bucket.
if testonly.nil?
  keep = git_history.map { |rev| "#{rev}/" }
  expired = []
  s3client.list_objects_v2(bucket: asset_bucket).each do |page|
    page.contents.each do |file|
      expired << file.key unless keep.any? { |prefix| file.key.start_with?(prefix) }
    end
  end

  puts "Expiring #{expired.size} old assets..."
  in_parallel(expired.each_slice(1000).to_a) do |batch|
    result = s3client.delete_objects(bucket: asset_bucket, delete: { objects: batch.map { |key| { key: key } }, quiet: true })
    raise "Failed to expire: #{result.errors.map(&:key).first(5).join(', ')}" unless result.errors.empty?
    log "Expired #{batch.size} assets"
  end
else
  puts "Test only, not expiring old assets"
end
