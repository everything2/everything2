#!/usr/bin/perl -w

use strict;
use Test::More;
use lib qw(/var/everything/ecore);
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"));

done_testing();
