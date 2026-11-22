#!/usr/bin/perl -w

# "Show who created a writeup page title (a.k.a. e2node)" (hideauthore2node, #4733) is a viewer
# preference: it reaches React in e2.display_prefs (and so /api/pagestate) as a JSON boolean, and
# the page header leaves the creator out for that viewer. The creator is still in e2.pageheader.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Everything;

initEverything('development-docker');
my $APP = $Everything::APP;

my $json = JSON->new->canonical;
sub pref { return $json->decode($json->encode($APP->display_preferences($_[0])))->{hideauthore2node} }

ok(defined pref({ hideauthore2node => 1 }), 'display_prefs carries hideauthore2node');
ok(pref({ hideauthore2node => 1 }), 'true when the viewer hides who created an e2node');
ok(!pref({ hideauthore2node => 0 }), 'false when they show it');
ok(!pref({}), 'false by default');
ok(!pref({ hideauthore2node => '' }), 'false for an unset (blank) value');
is($json->encode({ v => $APP->display_preferences({ hideauthore2node => 1 })->{hideauthore2node} }), '{"v":true}',
    'encoded as a JSON boolean, not a number React could render as "1"');

done_testing();
