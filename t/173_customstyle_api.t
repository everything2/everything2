#!/usr/bin/perl -w
# Everything::API::customstyle -- POST /api/customstyle/clear (#4401).
# Replaces the legacy ?clearVandalism GET that mutated VARS inside the_catwalk /
# theme_nirvana's buildReactData. Tests the login gate + the clear semantics
# (deletes customstyle, leaves other VARS alone).
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";
use Test::More;
use Everything;
use Everything::API::customstyle;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::customstyle->new();
ok($api, 'Created customstyle API instance');
is_deeply($api->routes, { 'clear' => 'clear_customstyle' }, 'routes: clear -> clear_customstyle');

#############################################################################
# Guest -> login required
#############################################################################
my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->clear_customstyle($guest);
is($r->[0], $api->HTTP_OK, 'guest clear returns 200');
is($r->[1]{success}, 0,    'guest cannot clear');
like($r->[1]{error}, qr/login required/i, 'login-required error');

#############################################################################
# Logged-in -> deletes customstyle, leaves other VARS untouched
#############################################################################
my $req = MockRequest->new(
    is_guest_flag => 0,
    nodedata => { node_id => 999999 },
    vars     => { customstyle => 'body{display:none}', userstyle => 5 },
);
$r = $api->clear_customstyle($req);
is($r->[0], $api->HTTP_OK,         'clear returns 200');
is($r->[1]{success}, 1,            'clear succeeds');
like($r->[1]{message}, qr/cleared/i, 'cleared message');
ok(!exists $req->user->VARS->{customstyle}, 'customstyle VAR deleted');
is($req->user->VARS->{userstyle}, 5, 'unrelated VARS (userstyle) left intact');

#############################################################################
# Idempotent: clearing again when there's nothing set still succeeds
#############################################################################
my $req2 = MockRequest->new(is_guest_flag => 0, nodedata => { node_id => 999999 }, vars => {});
$r = $api->clear_customstyle($req2);
is($r->[1]{success}, 1, 'clearing an already-clean style still succeeds');

done_testing;
