#!/usr/bin/perl -w
# Everything::API::usergroup_message_archive_manager -- POST /apply (#4479, Refs #4298).
#
# The archive on/off writes used to run in the page's buildReactData off the
# umam_what_id_/umam_sure_id_ query params. They now live here (admin-only), sharing the
# status payload + apply logic with the pure-render page via Everything::Roles::UsergroupArchive.
# The mutating test toggles one real usergroup and restores its original state.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::usergroup_message_archive_manager;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $APP = $Everything::APP;
my $api = Everything::API::usergroup_message_archive_manager->new();
ok($api, 'Created API instance');
is_deeply($api->routes, {apply => 'apply'}, 'routes: apply');

my $normal = $DB->getNode('normaluser1', 'user');
my $root   = $DB->getNode('root', 'user');

#############################################################################
# Gate: non-admin -> refused (200 + success=0)
#############################################################################
SKIP: {
    skip 'normaluser1 not present', 3 unless $normal;
    my $r = $api->apply(MockRequest->new(is_guest_flag => 0, nodedata => $normal, postdata => {changes => []}));
    is($r->[0], $api->HTTP_OK, 'returns 200 for non-admin');
    is($r->[1]{success}, 0, 'non-admin refused');
    like($r->[1]{error}, qr/administrator/i, 'error mentions administrators');
}

#############################################################################
# Admin apply (empty) -> success + status payload shape, no mutation
#############################################################################
SKIP: {
    skip 'root not present', 4 unless $root;
    my $r = $api->apply(MockRequest->new(is_guest_flag => 0, nodedata => $root, postdata => {changes => []}));
    is($r->[1]{success}, 1, 'admin empty-apply succeeds');
    is_deeply($r->[1]{changes}, [], 'no changes applied for empty batch');
    ok(ref $r->[1]{usergroups} eq 'ARRAY', 'payload carries usergroups list');
    ok(exists $r->[1]{num_archiving} && exists $r->[1]{num_not_archiving}, 'payload carries counts');
}

#############################################################################
# Admin apply a real toggle -> persists, then restore original state
#############################################################################
SKIP: {
    skip 'root not present', 4 unless $root;

    # Pick the first usergroup from the payload.
    my $payload = $api->apply(MockRequest->new(is_guest_flag => 0, nodedata => $root, postdata => {changes => []}))->[1];
    my ($ug) = @{ $payload->{usergroups} || [] };
    skip 'no usergroups present', 4 unless $ug;

    my $ug_id     = $ug->{group_id};
    my $was_on    = $ug->{is_archiving};
    my $toggle_to = $was_on ? '1' : '2';   # 1=disable, 2=enable -- flip it

    my $r = $api->apply(MockRequest->new(
        is_guest_flag => 0, nodedata => $root,
        postdata => {changes => [{group_id => $ug_id, action => $toggle_to}]},
    ));
    is($r->[1]{success}, 1, 'admin toggle succeeds');
    is(scalar(@{$r->[1]{changes}}), 1, 'one change applied');
    my ($now) = grep { $_->{group_id} == $ug_id } @{ $r->[1]{usergroups} };
    is($now->{is_archiving}, ($was_on ? 0 : 1), 'archive flag flipped in the fresh payload');

    # Restore original state.
    my $restore = $was_on ? '2' : '1';
    $api->apply(MockRequest->new(
        is_guest_flag => 0, nodedata => $root,
        postdata => {changes => [{group_id => $ug_id, action => $restore}]},
    ));
    my $after = $api->apply(MockRequest->new(is_guest_flag => 0, nodedata => $root, postdata => {changes => []}))->[1];
    my ($restored) = grep { $_->{group_id} == $ug_id } @{ $after->{usergroups} };
    is($restored->{is_archiving}, $was_on, 'original archive state restored');
}

done_testing;
