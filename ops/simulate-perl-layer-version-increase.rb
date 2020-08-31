#!/usr/bin/env ruby

require 'aws-sdk-lambda'

lambda_client = Aws::Lambda::Client.new(region: 'us-west-2')

pp lambda_client.publish_layer_version(
  compatible_runtimes: ['provided'],
  content: {
    s3_bucket: 'perllambdabase.everything2.com',
    s3_key: 'e2serverless.zip'
  },
  description: 'Perl layer for E2',
  layer_name: 'e2-perl-layer'
)
