#!/usr/bin/perl -w
# Everything::API::nodetype_changer -- POST /api/nodetype_changer/lookup|change (#4461,
# Refs #4298). The admin "change a node's nodetype" tool used to run a raw sqlUpdate inside
# Everything::Page::nodetype_changer's buildReactData off query params. It now lives here.
# Tests the admin gate, lookup, change validation, the mutation, and -- the careful bit --
# that changing INTO a permanently-cached type (setting/usergroup/datastash/room) is
# refused without confirmed => 1. Uses a throwaway document node it creates and nukes.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::nodetype_changer;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::nodetype_changer->new();
ok($api, 'Created nodetype_changer API instance');
is_deeply($api->routes, {'lookup' => 'lookup_node', 'change' => 'change_type'},
    'routes: lookup/change');

#############################################################################
# Admin gate on both routes
#############################################################################
for my $pair (['lookup', 'lookup_node'], ['change', 'change_type']) {
    my ($label, $method) = @$pair;
    my $r = $api->$method(MockRequest->new(is_admin_flag => 0, is_guest_flag => 0, postdata => {}));
    is($r->[1]{success}, 0, "$label refused for non-admin");
    like($r->[1]{error}, qr/administrator/i, "$label admin-required error");
}

#############################################################################
# lookup validation
#############################################################################
my $r = $api->lookup_node(MockRequest->new(is_admin_flag => 1, postdata => {}));
is($r->[1]{success}, 0, 'lookup without node_id rejected');

$r = $api->lookup_node(MockRequest->new(is_admin_flag => 1, postdata => {node_id => 999999999}));
is($r->[1]{success}, 0, 'lookup of a missing node rejected');
like($r->[1]{error}, qr/not found/i, 'missing-node error');

#############################################################################
# Real lookup + change against a throwaway document node
#############################################################################
SKIP: {
    my $root     = $DB->getNode('root', 'user');
    my $doctype  = $DB->getType('document');
    my $superdoc = $DB->getType('superdoc');
    my $setting  = $DB->getType('setting');
    skip 'root / document / superdoc / setting types not all present', 12
        unless ($root && $doctype && $superdoc && $setting);

    my $title = "nodetype changer api test $$";
    my $id    = $DB->insertNode($title, $doctype, $root, {});
    skip 'could not create throwaway node', 12 unless $id;

    my $type_of = sub { $DB->sqlSelect('type_nodetype', 'node', 'node_id=' . int($id)) };

    # lookup
    $r = $api->lookup_node(MockRequest->new(is_admin_flag => 1, postdata => {node_id => $id}));
    is($r->[1]{success}, 1, 'lookup succeeds');
    is($r->[1]{target}{current_type}, 'document', 'lookup reports current type');
    is($r->[1]{target}{type_id}, $doctype->{node_id}, 'lookup reports type id');

    # invalid target type: root (a user node) is not a nodetype
    $r = $api->change_type(MockRequest->new(is_admin_flag => 1,
        postdata => {change_id => $id, new_nodetype => $root->{node_id}}));
    is($r->[1]{success}, 0, 'non-nodetype target rejected');
    like($r->[1]{error}, qr/valid nodetype/i, 'invalid-target error');

    # change to a normal (non-permanent) type -> succeeds, flips the row
    $r = $api->change_type(MockRequest->new(is_admin_flag => 1,
        postdata => {change_id => $id, new_nodetype => $superdoc->{node_id}}));
    is($r->[1]{success}, 1, 'change to superdoc succeeds');
    is($type_of->(), $superdoc->{node_id}, 'node type flipped to superdoc');

    # change to a permanent-cache type WITHOUT confirm -> refused, no mutation
    $r = $api->change_type(MockRequest->new(is_admin_flag => 1,
        postdata => {change_id => $id, new_nodetype => $setting->{node_id}}));
    is($r->[1]{success}, 0, 'permanent-cache target refused without confirm');
    is($r->[1]{needs_confirm}, 1, 'needs_confirm flagged');
    like($r->[1]{warning}, qr/permanent/i, 'permanent-cache warning present');
    is($type_of->(), $superdoc->{node_id}, 'no mutation on the refused change');

    # change to the permanent-cache type WITH confirm -> succeeds
    $r = $api->change_type(MockRequest->new(is_admin_flag => 1,
        postdata => {change_id => $id, new_nodetype => $setting->{node_id}, confirmed => 1}));
    is($r->[1]{success}, 1, 'confirmed permanent-cache change succeeds');
    is($type_of->(), $setting->{node_id}, 'node type flipped to setting after confirm');

    # cleanup: reset to document so it loads cleanly, then nuke
    $DB->sqlUpdate('node', {type_nodetype => $doctype->{node_id}}, 'node_id=' . int($id));
    my $n = $DB->getNodeById($id, 'nocache');
    $DB->nukeNode($n, $root, 1) if $n;
}

done_testing;
