#!/usr/bin/env ruby
#
# reCAPTCHA Enterprise Statistics Tool
#
# Queries the Google Cloud reCAPTCHA Enterprise API for metrics
# from the last 7 days to help monitor site protection.
#
# Usage:
#   ./tools/recaptcha-stats.rb                    # Uses gcloud auth
#   ./tools/recaptcha-stats.rb -s <service_account.json>  # Uses service account
#
# Prerequisites:
#   The metrics API requires OAuth2 authentication (not API keys).
#   Either:
#   1. Run `gcloud auth application-default login` first, OR
#   2. Use -s to specify a service account JSON key file
#
# Configuration:
#   - Project ID: everything2-production (hardcoded, same as Configuration.pm)
#   - Site Key: 6LeF2BwsAAAAAMrkwFG7CXJmF6p0hV2swBxYfqc2 (hardcoded)
#
# Output:
#   - Total assessments by day
#   - Score distribution (0.0-0.1, 0.1-0.3, 0.3-0.7, 0.7-0.9, 0.9-1.0)
#   - Pass/fail counts based on 0.5 threshold
#

require 'net/http'
require 'json'
require 'uri'
require 'date'
require 'optparse'
require 'openssl'
require 'base64'

# Configuration (matches Configuration.pm)
PROJECT_ID = 'everything2-production'
SITE_KEY = '6LeF2BwsAAAAAMrkwFG7CXJmF6p0hV2swBxYfqc2'

# Score bucket labels (Google's default buckets)
SCORE_BUCKETS = [
  { range: '0.0-0.1', label: 'Very likely bot', threshold: :fail },
  { range: '0.1-0.3', label: 'Likely bot', threshold: :fail },
  { range: '0.3-0.7', label: 'Uncertain', threshold: :mixed },
  { range: '0.7-0.9', label: 'Likely human', threshold: :pass },
  { range: '0.9-1.0', label: 'Very likely human', threshold: :pass }
]

# Get access token from gcloud CLI
def get_gcloud_token
  token = `gcloud auth application-default print-access-token 2>/dev/null`.strip
  if token.empty? || $?.exitstatus != 0
    # Try regular auth token
    token = `gcloud auth print-access-token 2>/dev/null`.strip
  end

  if token.empty? || $?.exitstatus != 0
    $stderr.puts "Error: Could not get access token from gcloud"
    $stderr.puts ""
    $stderr.puts "Please authenticate with one of these methods:"
    $stderr.puts "  1. gcloud auth application-default login"
    $stderr.puts "  2. gcloud auth login"
    $stderr.puts "  3. Use -s <service_account.json> option"
    exit 1
  end

  token
end

# Get access token from service account JSON file
def get_service_account_token(json_path)
  unless File.exist?(json_path)
    $stderr.puts "Error: Service account file not found: #{json_path}"
    exit 1
  end

  sa_data = JSON.parse(File.read(json_path))

  # Create JWT
  now = Time.now.to_i
  jwt_header = { alg: 'RS256', typ: 'JWT' }
  jwt_claims = {
    iss: sa_data['client_email'],
    scope: 'https://www.googleapis.com/auth/cloud-platform',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }

  # Sign with private key
  key = OpenSSL::PKey::RSA.new(sa_data['private_key'])

  segments = [
    Base64.urlsafe_encode64(JSON.generate(jwt_header), padding: false),
    Base64.urlsafe_encode64(JSON.generate(jwt_claims), padding: false)
  ]
  signing_input = segments.join('.')
  signature = key.sign('SHA256', signing_input)
  segments << Base64.urlsafe_encode64(signature, padding: false)
  jwt = segments.join('.')

  # Exchange JWT for access token
  uri = URI('https://oauth2.googleapis.com/token')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request.set_form_data(
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: jwt
  )

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    $stderr.puts "Error: Failed to get access token from service account"
    $stderr.puts response.body
    exit 1
  end

  JSON.parse(response.body)['access_token']
end

def get_access_token(options)
  if options[:service_account]
    get_service_account_token(options[:service_account])
  else
    get_gcloud_token
  end
end

def fetch_metrics(access_token)
  # API endpoint: GET /v1/projects/{project}/keys/{key}/metrics
  url = URI("https://recaptchaenterprise.googleapis.com/v1/projects/#{PROJECT_ID}/keys/#{SITE_KEY}/metrics")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30

  request = Net::HTTP::Get.new(url)
  request['Accept'] = 'application/json'
  request['Authorization'] = "Bearer #{access_token}"

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    $stderr.puts "Error: API request failed with status #{response.code}"
    $stderr.puts response.body
    exit 1
  end

  JSON.parse(response.body)
end

def format_number(n)
  n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def print_metrics(metrics)
  puts "=" * 60
  puts "reCAPTCHA Enterprise Statistics"
  puts "Project: #{PROJECT_ID}"
  puts "Site Key: #{SITE_KEY[0..10]}..."
  puts "=" * 60
  puts

  # Check for score metrics
  score_metrics = metrics['scoreMetrics'] || []

  if score_metrics.empty?
    puts "No score metrics available yet."
    puts "Metrics may take up to 24 hours to populate after first use."
    return
  end

  # Overall metrics (aggregated across all time)
  overall = score_metrics.find { |m| m['overallMetrics'] }
  if overall && overall['overallMetrics']
    puts "OVERALL METRICS (All Time)"
    puts "-" * 40
    print_score_distribution(overall['overallMetrics'])
    puts
  end

  # Daily metrics (last 7 days)
  daily = score_metrics.select { |m| m['startTime'] }
                       .sort_by { |m| m['startTime'] }
                       .last(7)

  if daily.any?
    puts "DAILY METRICS (Last #{daily.length} days)"
    puts "-" * 40

    daily.each do |day_data|
      date = Date.parse(day_data['startTime']).strftime('%Y-%m-%d')
      buckets = day_data['scoreBuckets'] || {}
      total = buckets.values.map(&:to_i).sum

      # Calculate pass/fail based on 0.5 threshold (buckets 4-5 pass, 1-3 fail)
      # Bucket indices: 0=0.0-0.1, 1=0.1-0.3, 2=0.3-0.7, 3=0.7-0.9, 4=0.9-1.0
      fail_count = (buckets['SCORE_BUCKET_0_1'] || 0).to_i +
                   (buckets['SCORE_BUCKET_1_3'] || 0).to_i +
                   (buckets['SCORE_BUCKET_3_5'] || 0).to_i
      pass_count = (buckets['SCORE_BUCKET_5_7'] || 0).to_i +
                   (buckets['SCORE_BUCKET_7_9'] || 0).to_i +
                   (buckets['SCORE_BUCKET_9_10'] || 0).to_i +
                   (buckets['SCORE_BUCKET_10'] || 0).to_i

      pass_rate = total > 0 ? (pass_count.to_f / total * 100).round(1) : 0

      puts "  #{date}: #{format_number(total)} assessments, #{pass_rate}% would pass (score >= 0.5)"
    end
    puts
  end

  # Action metrics (by action name, e.g., 'signup')
  action_metrics = score_metrics.find { |m| m['actionMetrics'] }
  if action_metrics && action_metrics['actionMetrics']
    puts "ACTION METRICS"
    puts "-" * 40
    action_metrics['actionMetrics'].each do |action, data|
      puts "  Action: #{action}"
      print_score_distribution(data, "    ")
    end
    puts
  end
end

def print_score_distribution(metrics, indent = "  ")
  buckets = metrics['scoreBuckets'] || metrics
  return if buckets.empty?

  total = 0
  distribution = []

  # Map API bucket names to human-readable ranges
  bucket_mapping = {
    'SCORE_BUCKET_0_1' => { range: '0.0-0.1', label: 'Very likely bot' },
    'SCORE_BUCKET_1_3' => { range: '0.1-0.3', label: 'Likely bot' },
    'SCORE_BUCKET_3_5' => { range: '0.3-0.5', label: 'Suspicious' },
    'SCORE_BUCKET_5_7' => { range: '0.5-0.7', label: 'Uncertain' },
    'SCORE_BUCKET_7_9' => { range: '0.7-0.9', label: 'Likely human' },
    'SCORE_BUCKET_9_10' => { range: '0.9-1.0', label: 'Very likely human' },
    'SCORE_BUCKET_10' => { range: '1.0', label: 'Definitely human' }
  }

  bucket_mapping.each do |key, info|
    count = (buckets[key] || 0).to_i
    total += count
    distribution << { key: key, count: count, **info }
  end

  puts "#{indent}Total assessments: #{format_number(total)}"
  puts "#{indent}Score distribution:"

  distribution.each do |bucket|
    next if bucket[:count] == 0
    pct = total > 0 ? (bucket[:count].to_f / total * 100).round(1) : 0
    bar = '#' * [pct.to_i / 2, 1].max
    puts "#{indent}  #{bucket[:range].ljust(8)} #{bucket[:label].ljust(18)} #{format_number(bucket[:count]).rjust(8)} (#{pct.to_s.rjust(5)}%) #{bar}"
  end

  # Summary: pass vs fail at 0.5 threshold
  fail_count = distribution.select { |b| b[:range].start_with?('0.0', '0.1', '0.3') }
                          .map { |b| b[:count] }.sum
  pass_count = total - fail_count

  if total > 0
    puts
    puts "#{indent}At 0.5 threshold (E2's setting):"
    puts "#{indent}  Would PASS: #{format_number(pass_count)} (#{(pass_count.to_f / total * 100).round(1)}%)"
    puts "#{indent}  Would FAIL: #{format_number(fail_count)} (#{(fail_count.to_f / total * 100).round(1)}%)"
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-s", "--service-account FILE", "Service account JSON key file") do |file|
    options[:service_account] = file
  end

  opts.on("-j", "--json", "Output raw JSON response") do
    options[:json] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    puts
    puts "Authentication methods (in order of preference):"
    puts "  1. -s <file>  Use a service account JSON key file"
    puts "  2. gcloud     Uses 'gcloud auth print-access-token' automatically"
    puts
    puts "To authenticate with gcloud:"
    puts "  gcloud auth login"
    puts "  gcloud config set project everything2-production"
    exit
  end
end.parse!

# Main execution
access_token = get_access_token(options)
metrics = fetch_metrics(access_token)

if options[:json]
  puts JSON.pretty_generate(metrics)
else
  print_metrics(metrics)
end
