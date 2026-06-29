#!/usr/bin/perl -w
# Everything::API::nodeforbiddance -- POST /api/nodeforbiddance/{forbid,unforbid}
# (#4408). The admin forbid/unforbid actions used to mutate the nodelock table as
# a side effect in Everything::Page::node_forbiddance (a POST `forbid` form and a
# GET `?unforbid=` link). Now admin-gated API. Tests gates, validation, and the
# forbid/unforbid round-trip (self-cleaning).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::nodeforbiddance;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::nodeforbiddance->new();
ok($api, 'Created nodeforbiddance API instance');
is_deeply($api->routes,
    { 'forbid' => 'forbid_user', 'unforbid' => 'unforbid_user' },
    'routes map to forbid_user / unforbid_user');

my $TARGET = 'normaluser2';
my $tnode  = $DB->getNode($TARGET, 'user');
# Start clean (drop any lock left by a prior failed run).
$DB->sqlDelete('nodelock', 'nodelock_node=' . $tnode->{user_id}) if $tnode;

#############################################################################
# forbid: gates + validation
#############################################################################
my $r = $api->forbid_user(MockRequest->new(node_id => 999999, is_admin_flag => 0,
    postdata => { user => $TARGET, reason => 'x' }));
is($r->[1]{success}, 0,        'non-admin cannot forbid');
like($r->[1]{error}, qr/admin/i, 'admin-required error');

$r = $api->forbid_user(MockRequest->new(node_id => 113, is_admin_flag => 1, postdata => {}));
is($r->[1]{success}, 0,           'missing username rejected');
like($r->[1]{error}, qr/username/i, 'username-required error');

$r = $api->forbid_user(MockRequest->new(node_id => 113, is_admin_flag => 1,
    postdata => { user => 'no_such_user_xyz123' }));
is($r->[1]{success}, 0,            'unknown user rejected');
like($r->[1]{error}, qr/not found/i, 'user-not-found error');

#############################################################################
# forbid/unforbid round-trip against a real target
#############################################################################
SKIP: {
    skip "$TARGET seed user not present", 6 unless $tnode;
    my $uid = $tnode->{user_id};

    my $admin = MockRequest->new(node_id => 113, is_admin_flag => 1,
        postdata => { user => $TARGET, reason => 'test forbiddance' });

    $r = $api->forbid_user($admin);
    is($r->[1]{success}, 1, 'admin forbid succeeds');
    is($DB->sqlSelect('count(*)', 'nodelock', "nodelock_node=$uid"), 1, 'one nodelock row created');

    # Idempotent -- forbidding again does not stack rows
    $api->forbid_user($admin);
    is($DB->sqlSelect('count(*)', 'nodelock', "nodelock_node=$uid"), 1, 'forbid is idempotent');

    # unforbid: non-admin gate
    my $u = $api->unforbid_user(MockRequest->new(node_id => 999999, is_admin_flag => 0,
        postdata => { user_id => $uid }));
    is($u->[1]{success}, 0, 'non-admin cannot unforbid');

    # unforbid: success -> row removed
    $u = $api->unforbid_user(MockRequest->new(node_id => 113, is_admin_flag => 1,
        postdata => { user_id => $uid }));
    is($u->[1]{success}, 1, 'admin unforbid succeeds');
    is($DB->sqlSelect('count(*)', 'nodelock', "nodelock_node=$uid"), 0, 'nodelock row removed');
}

# unforbid: validation
$r = $api->unforbid_user(MockRequest->new(node_id => 113, is_admin_flag => 1, postdata => {}));
is($r->[1]{success}, 0, 'missing user_id rejected');

# Final safety cleanup.
$DB->sqlDelete('nodelock', 'nodelock_node=' . $tnode->{user_id}) if $tnode;

done_testing;
