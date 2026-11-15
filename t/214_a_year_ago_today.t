#!/usr/bin/perl -w
# A Year Ago Today (#4579). The page 500'd whenever a writeup existed from exactly N years ago:
# Application::previous_years_nodes shipped blessed Everything::Node objects into contentData and
# the controller's JSON encoder (a bare JSON->new, no convert_blessed) refused them. Its ints also
# arrived as strings, breaking React pagination ("50" + 50 = "5050").
#
# Every encode here uses a bare JSON->new -- the same encoder as Everything::Controller -- so this
# fails the way production did. The serializer tests don't depend on today's date; the
# previous_years_nodes test only exercises real rows on days with matches (always, in November,
# thanks to the Iron Noder seeds).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Scalar::Util qw(blessed);
use Everything;
use Everything::Page::a_year_ago_today;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $J = JSON->new;   # exactly Everything::Globals::_build_JSON
my $encodes = sub { my $ok = eval { $J->encode($_[0]); 1 }; return $ok };

#############################################################################
# previous_years_entry: a writeup with a parent and an author
#############################################################################
my $wid = $DB->sqlSelect('w.writeup_id', 'writeup w JOIN node p ON p.node_id=w.parent_e2node JOIN node n ON n.node_id=w.writeup_id JOIN node a ON a.node_id=n.author_user', '1=1 LIMIT 1');
ok($wid, 'found a writeup with a live parent and author');
my $wu = $APP->node_by_id($wid);
ok(blessed($wu) && $wu->isa('Everything::Node'), 'node_by_id returns a blessed node (what used to be shipped)');
ok(!$encodes->([$wu]), 'sanity: the bare encoder does refuse a blessed node');
ok(!$wu->parent->is_null && !$wu->author->is_null, 'sanity: a live parent/author report is_null false');

my $e = $APP->previous_years_entry($wu);
ok(!blessed($e) && ref($e) eq 'HASH', 'entry is a plain hashref');
ok($encodes->($e), 'entry JSON-encodes with the controller\'s encoder');
is_deeply([sort keys %$e], [qw(author createtime node_id parent)], 'exactly the fields the page renders');
is($e->{node_id}, int($wid), 'node_id');
like($J->encode({ id => $e->{node_id} }), qr/"id":\d/, 'node_id is a JSON number');
like($e->{createtime} // '', qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'createtime is ISO-8601 UTC');
is(ref($e->{parent}), 'HASH', 'parent is a plain {node_id,title}');
is($e->{parent}{node_id}, int($wu->NODEDATA->{parent_e2node}), 'parent node_id');
is($e->{parent}{title}, $wu->parent->title, 'parent title');
is($e->{author}{node_id}, int($wu->NODEDATA->{author_user}), 'author node_id');
is($e->{author}{title}, $wu->author->title, 'author title');

#############################################################################
# Missing parent / author come back as Everything::Node::null -> null in JSON
#############################################################################
my $orphan = Everything::Node::writeup->new({ %{ $wu->NODEDATA }, parent_e2node => 0, author_user => 0 });
ok($orphan->parent->is_null && $orphan->author->is_null,
   'a writeup missing parent and author yields null-object nodes');
my $oe = $APP->previous_years_entry($orphan);
ok(exists $oe->{parent} && !defined $oe->{parent}, 'missing parent -> undef (JSON null), key still present');
ok(exists $oe->{author} && !defined $oe->{author}, 'missing author -> undef (JSON null), key still present');
ok($encodes->($oe), 'orphan entry still encodes');

#############################################################################
# previous_years_nodes: whatever today's data is, the result must encode
#############################################################################
my $prev = $APP->previous_years_nodes(1, 0);
ok($encodes->($prev), 'previous_years_nodes(1,0) encodes with the controller\'s encoder');
like($J->encode({ c => $prev->{count} }), qr/"c":\d/, 'count is a JSON number');
ok(!(grep { blessed($_) } @{ $prev->{nodes} }), 'no blessed objects in nodes');
note(scalar(@{ $prev->{nodes} }) . " writeup(s) from exactly a year ago in this DB today");

#############################################################################
# The page payload: ints are ints, no stray blessed `node` field
#############################################################################
my $page = Everything::Page::a_year_ago_today->new;
my $req = MockRequest->new(is_guest_flag => 0, node_id => 1, query_params => { yearsago => '2', startat => '50' });
my $data = $page->buildReactData($req);
ok($encodes->($data), 'page payload encodes');
ok(!exists $data->{node}, 'no `node` field in the payload');
my $json = $J->encode($data);
like($json, qr/"yearsago":2[,}]/, 'yearsago is a JSON number (was "2")');
like($json, qr/"startat":50[,}]/, 'startat is a JSON number (was "50")');
like($json, qr/"count":\d/,       'count is a JSON number');

my $dflt = $J->encode($page->buildReactData(MockRequest->new(is_guest_flag => 0, node_id => 1)));
like($dflt, qr/"yearsago":1[,}]/, 'yearsago defaults to 1');
like($dflt, qr/"startat":0[,}]/,  'startat defaults to 0');

my $junk = $J->encode($page->buildReactData(MockRequest->new(is_guest_flag => 0, node_id => 1, query_params => { yearsago => '2; DROP TABLE node', startat => 'x' })));
like($junk, qr/"yearsago":2[,}]/, 'non-digits stripped from yearsago before it reaches SQL');
like($junk, qr/"startat":0[,}]/,  'garbage startat falls back to 0');

done_testing();
