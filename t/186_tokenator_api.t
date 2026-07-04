#!/usr/bin/perl -w
# Everything::API::the_tokenator -- POST /api/the_tokenator/tokenate (#4455, Refs #4298).
#
# The admin "give users a token" action -- a Cool Man Eddie notification + a `tokens`
# var increment per user -- used to run inside Everything::Page::the_tokenator's
# buildReactData off tokenateUser<N> query params. It now lives here. Tests the admin
# gate, empty/missing input, a per-user not-found, and a real tokenation (restoring the
# recipient's tokens var afterward so re-runs stay stable).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::the_tokenator;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::the_tokenator->new();
ok($api, 'Created the_tokenator API instance');
is_deeply($api->routes, {'tokenate' => 'give_tokens'}, 'routes: tokenate -> give_tokens');

#############################################################################
# Gate: non-admin -> refused (200 + success=0)
#############################################################################
my $r = $api->give_tokens(MockRequest->new(is_admin_flag => 0, is_guest_flag => 0,
    postdata => {users => ['normaluser1']}));
is($r->[0], $api->HTTP_OK, 'returns 200');
is($r->[1]{success}, 0, 'non-admin refused');
like($r->[1]{error}, qr/admin/i, 'admin-required error');

#############################################################################
# Admin, empty / missing users -> error
#############################################################################
$r = $api->give_tokens(MockRequest->new(is_admin_flag => 1, postdata => {users => []}));
is($r->[1]{success}, 0, 'empty users rejected');

$r = $api->give_tokens(MockRequest->new(is_admin_flag => 1, postdata => {}));
is($r->[1]{success}, 0, 'missing users rejected');

#############################################################################
# Admin, a bogus user -> per-user error (API call still succeeds)
#############################################################################
$r = $api->give_tokens(MockRequest->new(is_admin_flag => 1,
    postdata => {users => ['no_such_user_xyz123']}));
is($r->[1]{success}, 1, 'API call succeeds (per-user results inside)');
is($r->[1]{results}[0]{success}, 0, 'bogus user reported as a per-user failure');
like($r->[1]{results}[0]{message}, qr/find/i, 'bogus user "couldn\'t find" message');

#############################################################################
# Admin, a real tokenation (+1 token var) -- with restore
#############################################################################
SKIP: {
    my $target = $DB->getNode('normaluser1', 'user');
    skip 'normaluser1 not present', 3 unless $target;

    my $before = $APP->getVars($target)->{tokens} || 0;

    $r = $api->give_tokens(MockRequest->new(is_admin_flag => 1,
        postdata => {users => ['normaluser1']}));
    is($r->[1]{success}, 1, 'admin tokenation succeeds');
    is($r->[1]{results}[0]{success}, 1, 'per-user tokenation succeeded');

    my $after = $APP->getVars($DB->getNode('normaluser1', 'user'))->{tokens} || 0;
    is($after, $before + 1, 'recipient tokens var incremented by 1');

    # Restore the tokens var so re-runs stay stable.
    my $restore = $DB->getNode('normaluser1', 'user');
    my $v = $APP->getVars($restore);
    $v->{tokens} = $before;
    Everything::setVars($restore, $v);
    $DB->updateNode($restore, -1);
}

done_testing;
