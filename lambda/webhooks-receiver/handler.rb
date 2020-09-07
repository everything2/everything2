#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

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
  lambdaclient = Aws::Lambda::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])

  event = args[:event]
  context = args[:context]


  puts "Starting new request processing"

  signature = nil
  unless(event["headers"].nil?)
    signature = event["headers"]["X-Hub-Signature"]
  end

  if(signature.nil?)
    return http_response(400, "No signature found in headers")
  end

  puts "Signature found as: #{signature}"

  if(event.nil? or event["body"].nil?)
    return http_response(400, "Empty POST body")
  end

  begin
    secret = get_github_secret(s3client)
  rescue Aws::S3::Errors::AccessDenied => e
    return http_response(500, "No access to Github secret")
  end
  
  if(secret.nil?)
    return http_response(500, "Could not get Github secret")
  end

  puts "Github secret retrieved"

  expected_signature = generate_github_signature(secret, event["body"]) 
  unless(expected_signature.eql? signature)
    return http_response(403, "Signature does not match expected")
  end

  puts "Signature parsed okay"

  body = nil
  begin
    body = JSON.parse(event["body"])
  rescue JSON::ParserError => e
    return http_response(400, "JSON parsing failed")
  end

  html_url = nil

  if(body["repository"].nil? or body["repository"]["html_url"].nil?)
    return http_response(400, "No 'html_url' in body")
  else
    html_url = body["repository"]["html_url"]
  end

  puts "Evaluating ref: #{body['ref']}"
  unless(body['ref'].eql? "refs/heads/master")
    return http_response(200, "Non-master commit, skipping")
  end

  puts "Invoking zips puller function with repo: #{html_url}"

  lambdaclient.invoke(function_name: "cicd-zips-puller", payload: {"repo": html_url}.to_json, invocation_type: "Event")
  return http_response(200, "Pulled #{html_url}")
end
