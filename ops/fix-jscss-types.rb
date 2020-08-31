#!/usr/bin/env ruby

require 'aws-sdk-s3'

bucket = 'jscssw.everything2.com'

s3client = Aws::S3::Client.new(region: 'us-west-2')
continuation_token = nil

loop do
  resp = s3client.list_objects_v2(bucket: bucket, continuation_token: continuation_token)

  resp.contents.each do |item|
    puts item['key']
    ct = nil
    ce = nil
    if item['key'].match(/\.css$/)
      ct = "text/css"
    end

    if item['key'].match(/\.js$/)
      ct = "application/javascript"
    end

    if item['key'].match(/\.gzip\.(css|js)$/)
      ce = "gzip"
    end

    body = s3client.get_object(bucket: bucket, key: item['key'])
    s3client.put_object(bucket: bucket, metadata: {}, content_type: ct, content_encoding: ce, key: item['key'], body: body.body.read)
  end

  continuation_token = resp.next_continuation_token
  break unless resp.is_truncated
end
