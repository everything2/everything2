#!/usr/bin/env perl

BEGIN {
  $ENV{LD_LIBRARY_PATH}.=":/tmp/lib";
  print "$ENV{LD_LIBRARY_PATH}\n";
}

use strict;
#use Everything;
#use JSON;

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
  print "Lambda test!\n";
  return http_response(200, "OK");
}

1;
