#!/usr/bin/perl -w
#
# Request input validation: node ids from params/JSON must be plain numbers (anything else is
# treated as missing), and ?displaytype= only selects real views. Runs the real PSGI app
# in-process with real session cookies.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Plack::Util;
use Plack::Test;
use HTTP::Request::Common;
use URI::Escape;
use JSON;
use Everything;
use Everything::API;

chdir '/var/everything';
my $test = Plack::Test->create(Plack::Util::load_psgi('/var/everything/app.psgi'));
$test->request(GET '/api/sessions');   # boot the app

my $DB = $Everything::DB;
ok($DB, 'app booted');

sub cookie_for {
  my ($name) = @_;
  my $u = $DB->getNode($name, 'user');
  return 'userpass=' . uri_escape("$name|$u->{passwd}");
}
my $member = cookie_for('e2e_user');

sub get_json {
  my ($path, $cookie) = @_;
  my $res = $test->request(GET $path, ($cookie ? (Cookie => $cookie) : ()));
  return decode_json($res->content);
}
sub post_json {
  my ($path, $data, $cookie) = @_;
  my $res = $test->request(POST $path, Cookie => $cookie, 'Content-Type' => 'application/json',
    Content => encode_json($data));
  return decode_json($res->content);
}

subtest 'as_id' => sub {
  my $api = Everything::API->new;
  is($api->as_id('123'), 123, 'digits');
  is($api->as_id('0012'), 12, 'leading zeros');
  is($api->as_id(7), 7, 'a number');
  is($api->as_id($_), 0, "'" . ($_ // 'undef') . "' is not an id") for (undef, '', ' 12', '12 ', '12 OR 1=1', '-1', '1e3', '12abc');
  is($api->as_id([1]), 0, 'a reference is not an id');
};

# A category with two member e2nodes, owned by e2e_user.
my $e2node_type = $DB->getType('e2node');
my @members = map { $_->[0] } @{ $DB->{dbh}->selectall_arrayref(
  "SELECT node_id FROM node WHERE type_nodetype=$e2node_type->{node_id} ORDER BY node_id LIMIT 2") };
is(scalar @members, 2, 'two e2nodes to use as members');
my ($a_id, $b_id) = @members;

my $created = post_json('/api/category/create', { title => "Id check $$" }, $member);
ok($created->{success}, 'category created') or diag explain $created;
my $cat = $created->{node_id};
ok(post_json('/api/category/add_member', { category_id => $cat, node_id => $_ }, $member)->{success}, "member $_ added") for @members;

my $linktype = $DB->getNode('category', 'linktype');
sub member_ids {
  return [ sort { $a <=> $b } map { $_->[0] } @{ $DB->{dbh}->selectall_arrayref(
    "SELECT to_node FROM links WHERE from_node=" . int($cat) . " AND linktype=" . int($linktype->{node_id})) } ];
}
is_deeply(member_ids(), [sort { $a <=> $b } @members], 'both members linked');

subtest 'categories of a node (public)' => sub {
  my $ok = get_json("/api/category/node_categories?node_id=$a_id");
  ok(scalar(grep { $_->{node_id} == $cat } @{ $ok->{categories} || [] }), 'a numeric node_id finds the category');
  for my $bad ("$a_id OR 1=1", "${a_id}x", " $a_id") {
    my $r = get_json('/api/category/node_categories?node_id=' . uri_escape($bad));
    is($r->{success}, 0, "node_id '$bad' is treated as missing");
    ok(!$r->{categories} || !@{ $r->{categories} }, '... and lists nothing');
  }
};

subtest 'category list' => sub {
  my $plain = get_json('/api/category/list', $member);
  my $junk  = get_json('/api/category/list?node_id=' . uri_escape("$a_id OR 1=1"), $member);
  is_deeply($junk, $plain, 'a non-numeric node_id behaves like no node_id');
};

subtest 'removing and reordering members' => sub {
  my $r = post_json('/api/category/remove_member', { node_id => $cat, member_id => "$a_id OR 1=1" }, $member);
  is($r->{success}, 0, 'remove_member with a non-numeric member_id is refused');
  is_deeply(member_ids(), [sort { $a <=> $b } @members], '... and both members are still there');

  $r = post_json('/api/category/reorder_members', { node_id => $cat, member_ids => ["$b_id OR 1=1", $a_id] }, $member);
  ok(defined $r->{success}, 'reorder_members with a non-numeric id in the list completes');
  is_deeply(member_ids(), [sort { $a <=> $b } @members], '... and leaves the members as they were');
};

subtest 'displaytype selects only real views' => sub {
  my $display = $test->request(GET "/node/$a_id");
  is($display->code, 200, 'the node page');
  for my $name (qw(layout page_class)) {
    my $res = $test->request(GET "/node/$a_id?displaytype=$name");
    is($res->code, 200, "displaytype=$name: served");
    is($res->header('Content-Type'), $display->header('Content-Type'), '... as the normal page');
    like($res->content, qr/e2-react-page-root/, '... with the page shell');
  }
};

END {
  if ($cat) {
    $DB->{dbh}->do('DELETE FROM links WHERE from_node=' . int($cat));
    my $root = $DB->getNode('root', 'user');
    local $Everything::HTML::USER = $root;
    my $node = $DB->getNodeById($cat);
    eval { $DB->nukeNode($node, $root, 1); 1 } or diag("cleanup failed: $@") if $node;
  }
}

done_testing();
