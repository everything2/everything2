#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
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

  foreach my $action (@{$APP->process_reaper_targets})
  {
    print "Reaper: Killer: $action->{killer}, Node: $action->{node}\n"
  }
  http_response(200, "OK");
}

1;
