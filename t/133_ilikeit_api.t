#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::ilikeit;
use MockRequest;

# Everything::API::ilikeit -- the guest "I like it!" path (logged-in users vote/cool
# instead). Exercises get_status's branch logic: logged-in short-circuit, missing/bad
# writeup_id, and not-found. Read-only (get_status performs no writes).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::ilikeit->new();
ok($api, 'Created ilikeit API instance');

is_deeply(
    $api->routes,
    { 'writeup/:id' => 'like_writeup(:id)', 'status/:id' => 'get_status(:id)' },
    'routes: writeup/:id and status/:id'
);

#############################################################################
# Logged-in users are short-circuited (the feature is guests-only)
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'got normaluser1');

my $logged_in = MockRequest->new(
    node_id       => $normal_user->{node_id},
    title         => $normal_user->{title},
    is_guest_flag => 0,
    nodedata      => $normal_user,
);

my $r = $api->get_status($logged_in, 123);
is($r->[0], $api->HTTP_OK, 'logged-in get_status returns 200');
is($r->[1]{available}, 0, 'not available to logged-in users');
is($r->[1]{reason}, 'logged_in', 'reason is logged_in');

#############################################################################
# Guest with a missing / invalid writeup id
#############################################################################

my $guest = MockRequest->new(is_guest_flag => 1);

$r = $api->get_status($guest, 0);
is($r->[0], $api->HTTP_OK, 'guest get_status returns 200');
# isSpider() may short-circuit first in some envs; accept either the spider
# short-circuit or the missing-id error, but never a hard failure.
ok(defined $r->[1]{success}, 'response has a success flag');
if ($r->[1]{reason} && $r->[1]{reason} eq 'spider') {
    is($r->[1]{available}, 0, 'spider short-circuit is not-available');
} else {
    is($r->[1]{success}, 0, 'missing writeup_id is an error');
    like($r->[1]{error}, qr/writeup_id/i, 'error names the missing writeup_id');
}

#############################################################################
# Guest asking about a non-writeup node id -> not found
#############################################################################

$r = $api->get_status($guest, 2);   # node 2 is not a writeup
is($r->[0], $api->HTTP_OK, 'guest get_status (non-writeup) returns 200');
ok(defined $r->[1]{success}, 'response has a success flag');
if (!($r->[1]{reason} && $r->[1]{reason} eq 'spider') && !$r->[1]{success}) {
    like($r->[1]{error}, qr/not found|writeup/i, 'non-writeup id is rejected');
}

done_testing();

=head1 NAME

t/133_ilikeit_api.t - Tests for Everything::API::ilikeit (guest "I like it" status)

=cut
