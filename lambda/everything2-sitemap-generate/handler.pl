#!/usr/bin/env perl

BEGIN {
  print `nm -g /lib64/libm.so.6`;
  print `ls -al /lib64`;
}

use lib qw(/opt/lib);
use POSIX;
#use Everything;
use JSON;

sub http_response
{
  my ($code, $message) = @_;
  JSON->new->encode({
    "statusCode" => $code,
    "headers" => {"Content-Type" => "application/json"},
    "body" => {"message" => $message}});
}

sub lambda_handler
{
  my ($event) = @_;

  print "Lambda test!\n";
  http_response(200, "OK");
}

1;
