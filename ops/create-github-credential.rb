#!/usr/bin/env ruby

require 'aws-sdk-iam'

client = Aws::IAM::Client.new(region: 'us-west-2')
name = 'External-Github-Actions-User'

unless(File.exists?(name.downcase))
  `ssh-keygen -t rsa -C "#{name.downcase}" -P '' -f #{name.downcase} -m PKCS8`
end

result = client.upload_ssh_public_key(user_name: name, ssh_public_key_body: File.open("#{name.downcase}.pub").read)

File.open("#{name.downcase}.ssh_public_key_id",'w') {|f| f.write result.ssh_public_key.ssh_public_key_id}

puts "Uploaded key: #{result.ssh_public_key.ssh_public_key_id}"
