#!/usr/bin/perl -w

use strict;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost:9080/api"));

done_testing();
