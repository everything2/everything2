#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);

use Everything::S3;

# This script is designed to interact with the acme verification hook through dehydrated
# All of the domains go to the same app, so we just have good reverse proxy rules
# It receives one of three commands
# deploy_challenge domain token value
# clean_challenge domain token value 
# invalid_challenge domain

my $acme = Everything::S3->new("acme");
my $keyexchange = Everything::S3->new("keyexchange");

if($ARGV[0] eq "deploy_challenge")
{
  $acme->upload_data($ARGV[2],$ARGV[3]);
  print "Uploaded $ARGV[2]\n";
}elsif($ARGV[0] eq "clean_challenge"){
  $acme->delete_key($ARGV[2]);
  print "Deleted $ARGV[2]\n";
}elsif($ARGV[0] eq "invalid_challenge"){
# TODO mail here
}elsif($ARGV[0] eq "unchanged_cert"){
# Do nothing
}elsif($ARGV[0] eq "exit_hook"){
# Do nothing
}elsif($ARGV[0] eq "deploy_cert"){
  unless($keyexchange->upload_file("e2.cert","/etc/dehydrated/certs/everything2.com/cert.pem"))
  {
    print "E2 Cert upload failed: ".$keyexchange->errstr()."\n";
    exit;
  }
  unless($keyexchange->upload_file("e2.key","/etc/dehydrated/certs/everything2.com/privkey.pem"))
  {
    print "E2 Key upload failed: ".$keyexchange->errstr()."\n";
    exit;
  }
  unless($keyexchange->upload_file("e2.chain","/etc/dehydrated/certs/everything2.com/chain.pem"))
  {
    print "E2 Chain upload failed: ".$keyexchange->errstr()."\n";
    exit;
  }

  print "Uploaded keys to e2 keyexchange server\n";
}else{
  print "Invalid token hook! (".$ARGV[0].")\n";
}
