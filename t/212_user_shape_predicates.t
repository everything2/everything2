#!/usr/bin/perl -w
# The permission primitives must agree across ALL THREE user shapes: a bare node_id scalar, a
# NODEDATA hashref, and a blessed Everything::Node::user ($REQUEST->user).
#
# A blessed node is hashref-based, so it satisfies UNIVERSAL::isa($x,'HASH') checks, but its
# underlying hash holds Moose attributes (NODEDATA, author, is_group, notes) and has no node_id
# key. These assertions pin that every shape resolves to the same answer.
#
# MockUser is a plain `bless {node_id=>...}` that carries the key a real node lacks, so these
# assertions deliberately use REAL blessed objects rather than the mock.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $guest_id  = $APP->{conf}->guest_user;
my $guest_h   = $DB->getNodeById($guest_id);
my $guest_b   = $APP->node_by_id($guest_id);

my $root_h    = $DB->getNode('root', 'user');
my $root_b    = $APP->node_by_id($root_h->{node_id});

ok($guest_b && $guest_b->isa('Everything::Node'), 'guest resolves to a blessed node');
ok($root_b  && $root_b->isa('Everything::Node'),  'root resolves to a blessed node');

# The precise trap: the blessed object has no node_id HASH KEY, only a method.
ok(!exists $guest_b->{node_id}, 'a blessed node has no {node_id} hash key');

#############################################################################
# getId agrees across shapes
#############################################################################
is($DB->getId($guest_id), $guest_id, 'getId(scalar id)');
is($DB->getId($guest_h),  $guest_id, 'getId(hashref)');
is($DB->getId($guest_b),  $guest_id, 'getId(blessed)');
is($DB->getId($root_b), $root_h->{node_id}, 'getId(blessed root)');

#############################################################################
# isGuest agrees across shapes
#############################################################################
ok($APP->isGuest($guest_id), 'isGuest(scalar id) is true for the guest user');
ok($APP->isGuest($guest_h),  'isGuest(hashref) is true for the guest user');
ok($APP->isGuest($guest_b),  'isGuest(blessed) is true for the guest user');

ok(!$APP->isGuest($root_h), 'isGuest(hashref) is false for root');
ok(!$APP->isGuest($root_b), 'isGuest(blessed) is false for root');

#############################################################################
# The role predicates agree across shapes
#############################################################################
for my $pred (qw(isAdmin isEditor isDeveloper isChanop)) {
    my $h = $APP->$pred($root_h) ? 1 : 0;
    my $b = $APP->$pred($root_b) ? 1 : 0;
    is($b, $h, "$pred(blessed) matches $pred(hashref) for root");
}
ok($APP->isAdmin($root_b), 'isAdmin(blessed) is true for root');

#############################################################################
# isApproved / inUsergroup: the group check that emptied the publications list
#############################################################################
my $gods = $DB->getNode('gods', 'usergroup');
ok($gods, 'gods usergroup exists');
ok($DB->isApproved($root_h, $gods), 'isApproved(hashref root, gods)');
ok($DB->isApproved($root_b, $gods), 'isApproved(blessed root, gods)');

is($APP->inUsergroup($root_b, 'gods') ? 1 : 0,
   $APP->inUsergroup($root_h, 'gods') ? 1 : 0,
   'inUsergroup(blessed) matches inUsergroup(hashref)');

done_testing();
