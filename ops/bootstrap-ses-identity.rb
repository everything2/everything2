#!/usr/bin/ruby
#frozen_string_literal: true

require 'aws-sdk-ses'

@sesclient = Aws::SES::Client.new(region: 'us-west-2')

identities=@sesclient.list_identities.identities


if identities.include?("everything2.com")
  puts "everything2.com already created"
  pp @sesclient.get_identity_verification_attributes(identities: ["everything2.com"])
else
  pp @sesclient.verify_domain_identity(domain: "everything2.com")
end

if identities.include?('accounthelp@everything2.com')
  puts "Accounthelp already created"
else
  pp @sesclient.verify_email_identity(email_address: 'accounthelp@everything2.com')
end



