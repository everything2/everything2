#!/usr/bin/perl -w
# NodeBase::getId is foundational -- 113 call sites, and it sits under getRef, isApproved, isGod,
# canReadNode/canUpdateNode/canCreateNode and genWhereString. This test pins its contract for every
# argument shape that actually reaches it, so the blessed-node branch cannot drift and cannot
# quietly change what the OTHER shapes return.
#
# A blessed Everything::Node is a hashref, so `UNIVERSAL::isa($x,'HASH')` is true, but the object's
# hash holds Moose attributes (NODEDATA, author, is_group, notes), never node_id.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root_h = $DB->getNode('root', 'user');
my $root_b = $APP->node_by_id($root_h->{node_id});
my $rid    = $root_h->{node_id};

#############################################################################
# Scalars pass through untouched (ids, and the -1 superuser sentinel)
#############################################################################
is($DB->getId($rid),   $rid,   'scalar node_id passes through');
is($DB->getId("$rid"), "$rid", 'string node_id passes through');
is($DB->getId(-1),     -1,     '-1 superuser sentinel passes through');
is($DB->getId(0),      0,      '0 passes through (falsy but defined)');
is($DB->getId(undef),  undef,  'undef stays undef, no die');

#############################################################################
# Plain hashrefs: the historical path, unchanged
#############################################################################
is($DB->getId($root_h), $rid, 'hashref node -> node_id');
is($DB->getId({ node_id => 42 }), 42, 'bare hashref with node_id');
is($DB->getId({ title => 'no id here' }), undef, 'hashref without node_id -> undef (unchanged)');
is($DB->getId({}), undef, 'empty hashref -> undef (unchanged)');

#############################################################################
# Blessed Everything::Node -- the branch under test
#############################################################################
ok($root_b && $root_b->isa('Everything::Node'), 'root resolves to a blessed node');
ok(!exists $root_b->{node_id}, 'the blessed node has no {node_id} hash key');
is($DB->getId($root_b), $rid, 'blessed node -> node_id');
is($DB->getId($root_b), $DB->getId($root_h), 'blessed and hashref agree for the same node');

# Several node classes, not just user: they all root at Everything::Node.
foreach my $spec (['root','user'], ['gods','usergroup'], ['edev','usergroup']) {
    my ($title, $type) = @$spec;
    my $h = $DB->getNode($title, $type) or next;
    my $b = $APP->node_by_id($h->{node_id});
    is($DB->getId($b), $h->{node_id}, "blessed $type '$title' -> node_id");
}

# Nodetype nodes reach getId too (getType(...) results are passed straight in).
my $usertype = $DB->getType('user');
is($DB->getId($usertype), $usertype->{node_id}, 'nodetype hashref -> node_id');

#############################################################################
# NON-node blessed objects must KEEP the old hashref behaviour. The guard is
# isa('Everything::Node'), not can('node_id'), precisely so test doubles and
# unrelated helper objects are not silently re-routed.
#############################################################################
{
    package T::FakeNodeish;
    sub new { my ($c,%a)=@_; return bless {%a}, $c }
    sub node_id { return 999999 }   # a method that DISAGREES with the key
}
my $fake = T::FakeNodeish->new(node_id => 7);
ok(!$fake->isa('Everything::Node'), 'the double is not an Everything::Node');
is($DB->getId($fake), 7, 'blessed non-node uses its {node_id} KEY, not its method');

{
    package T::NoIdAtAll;
    sub new { return bless {}, shift }
}
is($DB->getId(T::NoIdAtAll->new), undef, 'blessed non-node with no node_id -> undef, no die');

#############################################################################
# Arrayrefs are not hashrefs: returned as-is (historical behaviour)
#############################################################################
my $aref = [1,2,3];
is($DB->getId($aref), $aref, 'arrayref returned unchanged');

#############################################################################
# Downstream consumers agree across shapes
#############################################################################
my $gods = $DB->getNode('gods', 'usergroup');
ok($gods, 'gods usergroup exists');

is($DB->isGod($root_b) ? 1 : 0, $DB->isGod($root_h) ? 1 : 0, 'isGod agrees across shapes');
is($DB->isApproved($root_b, $gods) ? 1 : 0, $DB->isApproved($root_h, $gods) ? 1 : 0,
   'isApproved agrees across shapes');

foreach my $can (qw(canReadNode canUpdateNode canDeleteNode)) {
    my $target = $DB->getNodeById($rid);
    is($DB->$can($root_b, $target) ? 1 : 0, $DB->$can($root_h, $target) ? 1 : 0,
       "$can agrees across shapes");
}

# genWhereString resolves a blessed node to its id, the same clause as the hashref form.
my $ws = $DB->genWhereString({ author_user => $root_b });
like($ws, qr/author_user=.?$rid.?/, 'genWhereString resolves a blessed node to its id');
is($DB->genWhereString({ author_user => $root_h }),
   $ws, 'genWhereString gives the same clause for hashref and blessed');

done_testing();
