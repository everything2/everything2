#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::S3;
use Digest::SHA;

initEverything 'everything';

my $force = $ARGV[0];
$force ||= 0;

my $jscss = Everything::S3->new("jscss");

unless($jscss)
{
  print "No jscss credentials, quitting\n";
  exit;
}

my $jsdir = "/var/everything/www/js";

my $jsdirhandle;
opendir($jsdirhandle,$jsdir);
while(my $file = readdir($jsdirhandle))
{
  my $full_filename = "$jsdir/$file";
  next unless -f $full_filename and -e $full_filename;

  my $full_file_handle;
  my $full_file_data;
  if(open($full_file_handle,$full_filename))
  {
    local $/ = undef;
    $full_file_data = <$full_file_handle>;
    close $full_file_handle;
  }else{
    print "Could not read js file: '$full_filename'!\n";
    exit;
  }

  my $local_file_sha=Digest::SHA::sha1_hex($full_file_data);
  my $needs_upload = 0;

  print "Fetching $file...\n";
  my $jsfile = $jscss->get_key("$file");
  if($jsfile and $jsfile->{value})
  {
    my $remote_file_sha=Digest::SHA::sha1_hex($jsfile->{value});
    print "Local file SHA1: $local_file_sha\n";
    print "Remote file SHA1: $remote_file_sha\n";

    if($local_file_sha ne $remote_file_sha)
    {
      print "Remote file needs update: $file\n";
      $needs_upload = 1;
    }else{
      if(!$force)
      {
        print "SHA1 match, skipping update for: $file\n";
      }else{
        print "SHA1 match, updating anyway due to force: $file\n";
      }
    }

  }else{
    print "File not found on S3: '$file'\n";
    $needs_upload = 1;

  }

  if($needs_upload == 1 || $force)
  {
    my ($key) = $file =~ /^([^\.]+)/;
    my $content_version = 1;
    if($key =~ /^\d+$/)
    {
      # This is a node;
      my $node = getNodeById($key);
      $node->{contentversion}++;
      $Everything::DB->updateNode($node, -1);
      $content_version = $node->{contentversion};

    }else{
      print "Non-nodes unsupported versioning scheme\n";
      next;
    }
 
    $Everything::APP->uploadS3Content($jscss, "$key", $full_file_data, "js", "$content_version");
    print "Uploaded $file \@$content_version\n";
  }

  print "\n";
}
