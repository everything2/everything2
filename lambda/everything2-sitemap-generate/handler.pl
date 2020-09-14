#!/usr/bin/env perl

use Everything;
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
