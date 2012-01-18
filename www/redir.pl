#!/usr/bin/perl
use CGI qw/:standard/;
my $location="http://everything2.com/index.html";
my $query=CGI::new();
print redirect($location);
