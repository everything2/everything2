#!/usr/bin/perl -w

use strict;
use lib qw(/home/admin/everything2/ecore);

use Everything::S3;

# This script is designed to interact with the acme verification hook through dehydrated
# All of the domains go to the same app, so we just have good reverse proxy rules
# It receives one of three commands
# deploy_challenge domain token value
# clean_challenge domain token value 
# invalid_challenge domain

my $s3 = Everything::S3->new("acme");

if($ARGV[0] eq "deploy_challenge")
{
  $s3->upload_data($ARGV[2],$ARGV[3]);
}elsif($ARGV[0] eq "clean_challenge"){
  $s3->delete($ARGV[2]);
}elsif($ARGV[0] eq "invalid_challenge"){
# TODO mail here
}else{
  print "Invalid token hook!\n";
}
