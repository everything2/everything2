#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything::S3;
use Digest::SHA;

# If called from chef, we never want to reload the server
my $never_reload = $ARGV[0];

my $keyexchange = Everything::S3->new("keyexchange");

unless($keyexchange)
{
  print "No keyexchange credentials, quitting\n";
  exit;
}

my $apachedir="/etc/apache2";


unless(-d $apachedir)
{
  print "Not on a webhead machine. Exiting.\n";
  exit;
}

my $new_cert_response = $keyexchange->get_key("e2.cert");
unless($new_cert_response and $new_cert_response->{value})
{
  print "Could not fetch the cert: ".$keyexchange->errstr."\n";
  exit;
}

my $new_key_response = $keyexchange->get_key("e2.key");
unless($new_key_response and $new_key_response->{value})
{
  print "Could not fetch the key: ".$keyexchange->errstr."\n";
  exit; 
}

my $new_chain_response = $keyexchange->get_key("e2.chain");
unless($new_chain_response and $new_chain_response->{value})
{
  print "Could not fetch the chain: ".$keyexchange->errstr."\n";
  exit;
}


my $old_cert_sha = "";
my $old_key_sha = "";
my $old_chain_sha = "";

if(-e "$apachedir/e2.cert")
{
  my $cert_handle;
  open $cert_handle,"$apachedir/e2.cert";

  my $cert_data;
  {
    local $/ = undef;
    $cert_data = <$cert_handle>;
    close $cert_handle;
  }

  $old_cert_sha = Digest::SHA::sha1_hex($cert_data);
}

if(-e "$apachedir/e2.chain")
{
  my $chain_handle;
  open $chain_handle,"$apachedir/e2.chain";

  my $chain_data;
  {
    local $/ = undef;
    $chain_data = <$chain_handle>;
    close $chain_handle;
  }

  $old_chain_sha = Digest::SHA::sha1_hex($chain_data);
}

if(-e "$apachedir/e2.key")
{
  my $key_handle;
  open $key_handle,"$apachedir/e2.key";
  
  my $key_data;
  {
    local $/ = undef;
    $key_data = <$key_handle>;
    close $key_handle;
  }

  $old_key_sha = Digest::SHA::sha1_hex($key_data);
}

#SHA1 is fine, we're just trying to see if the file is different
my $new_cert_sha = Digest::SHA::sha1_hex($new_cert_response->{value});
my $new_key_sha = Digest::SHA::sha1_hex($new_key_response->{value});
my $new_chain_sha = Digest::SHA::sha1_hex($new_chain_response->{value});

my $reload_apache;

if($old_cert_sha ne $new_cert_sha)
{
  print "Old cert SHA1: $old_cert_sha\n";
  print "New cert SHA1: $new_cert_sha\n";

  $reload_apache = 1;

  my $cert_handle;
  open $cert_handle,">$apachedir/e2.cert";
  print $cert_handle $new_cert_response->{value};
  close $cert_handle;
}else{
  print "Cert is current\n";
}

if($old_key_sha ne $new_key_sha)
{
  print "Old key SHA1: $old_key_sha\n";
  print "New key SHA1: $new_key_sha\n";

  $reload_apache = 1;
  my $key_handle;
  open $key_handle,">$apachedir/e2.key";
  print $key_handle $new_key_response->{value};
  close $key_handle;
}else{
  print "Key is current\n";
}

if($old_chain_sha ne $new_chain_sha)
{
  print "Old chain SHA1: $old_chain_sha\n";
  print "New chain SHA1: $new_chain_sha\n";

  $reload_apache = 1;
  my $chain_handle;
  open $chain_handle,">$apachedir/e2.chain";
  print $chain_handle $new_key_response->{value};
  close $chain_handle;
}else{
  print "Chain is current\n";
}

if($reload_apache and -e "/etc/init.d/apache2" and $never_reload ne "never_reload")
{
  print "Reloading apache\n";
#  `/etc/init.d/apache2 reload`;
}

