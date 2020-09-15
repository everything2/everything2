#!/usr/bin/env perl

use strict;
#use Everything;
#use JSON;

BEGIN {
  print `ls -1 /lib64/libxml*`;
}

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
