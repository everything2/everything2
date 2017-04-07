#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More tests => 3;
use Everything;

initEverything 'everything';

unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

# Special case
ok($APP->convertDateToEpoch("0000-00-00 00:00:00") == 0);
#jaybonci
ok($APP->convertDateToEpoch("2000-03-21 17:04:34") == 953658274);
#oolong
ok($APP->convertDateToEpoch("2001-04-14 23:28:51") == 987290931);
done_testing();

