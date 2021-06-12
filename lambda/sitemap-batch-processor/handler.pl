#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Data::Dumper;
use JSON;

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
  my $s3 = Everything::S3->new("sitemapdispatch");
  my $current_batch = $event->{batch};

  print "Batch: $current_batch\n";
  my $batchkey = "$current_batch.json";
 
  my $batchdata = $s3->get_key($batchkey);
  if(length($batchdata) > 0)
  {
    my $nodes = JSON->new->utf8->decode($batchdata);

    my $xml = $Everything::APP->sitemap_batch_xml($nodes);
    my $sitemapbucket = Everything::S3->new("sitemap");
    $sitemapbucket->upload_data("$current_batch.xml",$xml, {"content_type" => "application/xml"});
    print "Uploaded xml: $current_batch.xml";
  }else{
    print "ContentLength of batch is zero, exiting\n";
    return http_response(400, "OK");
  }
  http_response(200, "OK");
}

1;
