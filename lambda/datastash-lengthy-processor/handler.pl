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

  my $plugin = $event->{plugin};

  if(defined($plugin))
  {
    my $generator = $FACTORY->{datastash}->available($plugin)->new();

    print "Evaluating generator '$plugin'...";
    if($generator->update_needed)
    {
      $generator->generate_if_needed;
      print "updated";
    }else{
      print "not needed";
    }
    print "\n";
  }

  http_response(200, "OK");
}

1;
