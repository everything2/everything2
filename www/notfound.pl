#!/usr/bin/perl -w
use strict;

my $location = "/index.pl?node=Not%20Found";

if ( $ENV{'REQUEST_URI'} =~ m|.*\/([^/]+)$| ) {
  $location = "/index.pl?node=$1";
}

print "HTTP/1.0 301 Moved Permanently\nLocation: $location\n\n";
