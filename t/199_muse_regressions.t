#!/usr/bin/perl -w
# Regressions reported by Serjeant's Muse -- server-side fixes on issue/4515/muse-regressions.
#
#  * #4516  Everything::NodeBase::sqlSelect{,Many} silently dropped a bind-params array, so a '?'
#           placeholder bound to NULL. my_achievements passed [$user_id] for its LEFT JOIN and got
#           0 matches -> "0 out of 42". Fixed: the 5th arg (an arrayref) is now bound to execute().
#  * Golden Trinkets  golden_trinkets returned { contentData => {...} }, but buildNodeInfoStructure
#           already wraps buildReactData in contentData -> the data ended up double-nested under
#           contentData.contentData and the React component read nothing. Fixed: return flat.
#
# (#4515, the profile "writeups" -> empty User Search, is covered by the jest UserSearch tests.)

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;

initEverything('development-docker');
ok($DB, 'DB connection established');

#############################################################################
# #4516: sqlSelect / sqlSelectMany honor a bind-params array
#############################################################################
my $root = $DB->getNode('root', 'user');
ok($root, 'got root user');
my $rid = $root->{node_id};

# sqlSelect binds the '?' (was silently NULL before the fix)
is($DB->sqlSelect('title', 'node', 'node_id=?', '', [ $rid ]), 'root',
    'sqlSelect binds ? -> resolves root by node_id');

# a bound '?' that matches nothing returns falsy (proves the value is actually bound, not ignored:
# an unbound/NULL '?' would behave identically for every id, but here -1 finds no row while $rid does)
ok(!$DB->sqlSelect('title', 'node', 'node_id=?', '', [ -1 ]),
    'sqlSelect with a non-matching bound id returns nothing (the ? really binds)');

# sqlSelectMany binds too
my $csr = $DB->sqlSelectMany('title', 'node', 'node_id=?', '', [ $rid ]);
ok($csr, 'sqlSelectMany returns a cursor with a bind');
my ($t) = $csr->fetchrow; $csr->finish;
is($t, 'root', 'sqlSelectMany binds ? -> root');

# the achievements-shaped query (LEFT JOIN with a bound user) runs without error
my $achieved = $DB->sqlSelect('COUNT(*)',
    'achievement LEFT OUTER JOIN achieved ON achieved_achievement=achievement_id AND achieved_user=?',
    'achieved_achievement IS NOT NULL', '', [ $rid ]);
ok(defined $achieved, 'bound achievement LEFT JOIN runs and returns a count');

# legacy 4-arg callers are unchanged (no bind arg -> execute() with no params, as before)
is($DB->sqlSelect('COUNT(*)', 'node', 'node_id=' . $rid), 1,
    'legacy 4-arg sqlSelect still works (byte-identical path)');

#############################################################################
# Golden Trinkets: buildReactData returns flat contentData, not double-nested
#############################################################################
require Everything::Page::golden_trinkets;

{
    package MuseKarmaUser;
    sub new      { bless { k => $_[1], a => $_[2] }, $_[0] }
    sub karma    { $_[0]->{k} }
    sub is_admin { $_[0]->{a} }
    sub title    { 'someuser' }
    sub node_id  { 999 }

    package MuseReq;
    sub new   { bless { u => $_[1] }, $_[0] }
    sub user  { $_[0]->{u} }
    sub param { undef }
    sub cgi   { $_[0] }
}

my $page = Everything::Page::golden_trinkets->new;
my $req  = MuseReq->new(MuseKarmaUser->new(42, 0));   # non-admin, karma 42
my $data = $page->buildReactData($req);

ok(!exists $data->{contentData}, 'golden_trinkets does NOT wrap in an extra contentData key');
is($data->{type},  'golden_trinkets', 'type is at the top level');
is($data->{karma}, 42, 'karma is at the top level (was buried under contentData.contentData)');
ok(exists $data->{forUser}, 'forUser key present at top level');

done_testing();
