#!/usr/bin/perl -w
# Everything::API::websterbless -- POST /api/websterbless/bless (#4451, Refs #4298).
#
# The editor/admin "bless a user for a Webster 1913 correction" action -- a Webster
# thank-you PM + karma + GP + securityLog per user -- used to run inside
# Everything::Page::websterbless's buildReactData off webbyblessUser* query params. It
# now lives here. Tests the gate, empty/missing input, a per-user not-found, and a real
# bless (with best-effort cleanup of the karma/GP it grants).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::websterbless;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::websterbless->new();
ok($api, 'Created websterbless API instance');
is_deeply($api->routes, {'bless' => 'bless_users'}, 'routes: bless -> bless_users');

#############################################################################
# Gate: neither editor nor admin -> refused (200 + success=0)
#############################################################################
my $r = $api->bless_users(MockRequest->new(
    is_editor_flag => 0, is_admin_flag => 0,
    postdata => {blessings => [{user => 'normaluser1'}]}));
is($r->[0], $api->HTTP_OK, 'returns 200');
is($r->[1]{success}, 0, 'non-editor/non-admin refused');
like($r->[1]{error}, qr/editor|admin/i, 'editor/admin-required error');

#############################################################################
# Editor, empty / missing blessings -> error
#############################################################################
$r = $api->bless_users(MockRequest->new(is_editor_flag => 1, postdata => {blessings => []}));
is($r->[1]{success}, 0, 'empty blessings rejected');

$r = $api->bless_users(MockRequest->new(is_editor_flag => 1, postdata => {}));
is($r->[1]{success}, 0, 'missing blessings rejected');

#############################################################################
# Editor, a bogus user -> per-user error, no mutation
#############################################################################
SKIP: {
    skip 'Webster 1913 not present', 2 unless $DB->getNode('Webster 1913', 'user');

    $r = $api->bless_users(MockRequest->new(is_editor_flag => 1,
        postdata => {blessings => [{user => 'no_such_user_xyz123'}]}));
    is($r->[1]{success}, 1, 'API call succeeds (per-user results inside)');
    like($r->[1]{results}[0]{error}, qr/find/i, 'bogus user reported as a per-user error');
}

#############################################################################
# Admin, a real bless (+1 karma, +3 GP, PM, seclog) -- with best-effort cleanup
#############################################################################
SKIP: {
    my $webster = $DB->getNode('Webster 1913', 'user');
    my $target  = $DB->getNode('normaluser1', 'user');
    my $root    = $DB->getNode('root', 'user');
    skip 'Webster/normaluser1/root not all present', 3 unless ($webster && $target && $root);

    my $karma_before = $target->{karma} // 0;

    $r = $api->bless_users(MockRequest->new(
        is_admin_flag => 1, nodedata => $root,
        postdata => {blessings => [{user => 'normaluser1', writeup => 'Test Writeup'}]}));
    is($r->[1]{success}, 1, 'admin bless succeeds');
    is($r->[1]{results}[0]{success}, 1, 'per-user bless succeeded');
    like($r->[1]{results}[0]{message}, qr/3 GP/, 'message reports the 3 GP grant');

    # Reverse the +1 karma and the +3 GP so re-runs stay stable.
    my $after = $DB->getNode('normaluser1', 'user');
    $after->{karma} = $karma_before;
    $DB->updateNode($after, -1);
    $APP->adjustGP($after, -3);
}

done_testing;
