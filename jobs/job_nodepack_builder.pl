#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use JSON;
use Paws;
use File::Find;

initEverything 'everything';
print "Starting nodepack update job\n";
my $s3 = Paws->service('S3', 'region' => $Everything::CONF->current_region);

my $nodepack_bucket = "nodepack.everything2.com";
my $tmpdir = "/tmp/nodepack-$$";

`mkdir -p $tmpdir`;
print `cd $tmpdir && /usr/bin/perl -I/var/everything/ecore -I/var/libraries/lib/perl5  /var/everything/ecoretool/ecoretool.pl export 2>&1`;

my $files = [];
File::Find::find({wanted => sub {push @$files,$File::Find::name if -e && /\.xml$/}}, $tmpdir);

foreach my $file(@$files)
{
  my $filedata;
  if(open(my $fh, "<", $file))
  {
    local $/ = undef;
    $filedata = <$fh>;
  }else{
    print "Could not open file: $!";
    exit;
  }
  my $relative_file = $file;
  $relative_file =~ s/^$tmpdir\/nodepack\///g;
  $s3->PutObject("Bucket" => $nodepack_bucket, "Key" => $relative_file, "Body" => $filedata);
  print "Uploaded $relative_file\n"; 
}

print "Finished nodepack update job\n";
