#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use JSON;
use Paws;
use Data::Dumper;
use File::Find;

sub http_response
{
  my ($code, $message) = @_;
  return JSON->new->encode({
    "statusCode" => $code,
    "headers" => {"Content-Type" => "application/json"},
    "body" => {"message" => $message}});
}

sub lambda_handler
{
  my ($event) = @_;
  initEverything 'everything';
  my $s3 = Paws->service('S3', 'region' => $Everything::CONF->current_region);

  my $nodepack_bucket = "nodepack.everything2.com";
  my $tmpdir = "/tmp/nodepack-$$";

  `mkdir -p $tmpdir`;
  `cd $tmpdir && /tmp/bin/perl -I/opt/everything2/ecore /opt/everything2/ecoretool/ecoretool.pl export 2>&1`;

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
      print STDERR "Could not open file: $!";
      exit;
    }
    my $relative_file = $file;
    $relative_file =~ s/^$tmpdir\/nodepack\///g;
    $s3->PutObject("Bucket" => $nodepack_bucket, "Key" => $relative_file, "Body" => $filedata);
    print STDERR "Uploaded $relative_file\n"; 
  }

  http_response(200, "OK");
}

1;
