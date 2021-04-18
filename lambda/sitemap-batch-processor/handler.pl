#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::S3;
use Data::Dumper;

initEverything 'everything';
my $xg = XML::Generator->new(':pretty');

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

  print "Hello\n";
  print Data::Dumper->Dump([$event])."\n";
  return http_response(200, "OK");
}
