#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

# convertDateToEpoch parses "YYYY-MM-DD HH:MM:SS" (UTC) into a Unix epoch.
# Backed by Time::Local::timegm (UTC) since the Date::Calc->Bit::Vector dep was
# dropped for the Ubuntu 26.04 / gcc-15 bump -- these assertions lock in that the
# swap is behaviour-identical (the two historic values below are the exact epochs
# the old Date::Calc::Date_to_Time produced).

# Special case: zero-date guard returns 0
is($APP->convertDateToEpoch("0000-00-00 00:00:00"), 0, "zero-date -> 0");

# Epoch boundary
is($APP->convertDateToEpoch("1970-01-01 00:00:00"), 0, "unix epoch start -> 0");

#jaybonci
is($APP->convertDateToEpoch("2000-03-21 17:04:34"), 953658274, "known UTC date -> epoch (jaybonci)");
#oolong
is($APP->convertDateToEpoch("2001-04-14 23:28:51"), 987290931, "known UTC date -> epoch (oolong)");

# Leading-zero month/day/hour components parse numerically (no octal trap)
is($APP->convertDateToEpoch("2020-01-05 08:09:07"), 1578211747, "leading-zero components -> epoch");

done_testing();
