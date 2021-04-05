#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Net::Amazon::S3;
use Everything::S3;
use Data::Dumper;
use JSON;
use Paws;

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

  print "Initializing Everything Engine\n";
  initEverything 'everything';

  my $nets3 =   Net::Amazon::S3->new(
                {
                        use_iam_role => 1,
                        retry => 1,
                        host => 's3-us-west-2.amazonaws.com'
                });


  print "Starting up sitemap dispatcher\n";
  print "Net::S3: ".Data::Dumper->Dump([$nets3])."\n";
  print "Conf: ".Data::Dumper->Dump([$Everything::CONF->s3])."\n";
  my $s3 = Everything::S3->new("sitemapdispatch");
  return http_response(200, "OK");

  my $lambda = Paws->service('Lambda', 'region' => $Everything::CONF->current_region);

  my $current_batch = 1;
  #my $batches = $APP->sitemap_batches;

  my $batches = [['459692'],['2177337']];
  foreach my $batch(@$batches)
  {
    print "Uploading batch: $current_batch.json\n";
    $s3->upload_data("$current_batch.json", JSON->new->utf8->encode($batch), {"content_type" => "application/json"});
    $lambda->InvokeAsync('FunctionName' => 'sitemap-batch-processor', 'InvokeArgs' => JSON->new->utf8->encode({"batch" => $current_batch}));
    $current_batch++;
  }

  http_response(200, "OK");
}

1;
