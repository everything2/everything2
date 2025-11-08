#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use Test::More;
use Data::Dumper;

ok(my $ua = LWP::UserAgent->new, "Create a new LWP::UA object");
ok(my $response = $ua->get("http://localhost/api/"), "Get a the base URL");
ok($response->code eq 405, "Default route gives unimplemented"); # Unimplemented

ok($response = $ua->get("http://localhost/api/badroute"),"Get an unimplemented route API");
ok($response->code eq 405, "Bad route gives unimplemented code");

done_testing();
