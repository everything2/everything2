#!/usr/bin/perl -w
#
# Discussion replies between ordinary (non-admin) usergroup members are linked into the
# thread (#4687). Runs the real PSGI app in-process with real session cookies: no mocks, no
# skip_maintenance. genericeditor and e2e_editor are both Content Editors members; neither
# is an admin.
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

chdir '/var/everything';
my $test = Plack::Test->create(Plack::Util::load_psgi('/var/everything/app.psgi'));
$test->request(GET '/api/sessions');   # boot the app

my $DB  = $Everything::DB;
my $APP = $Everything::APP;
ok($DB, 'app booted');

my $CONTENT_EDITORS = 923653;
sub cookie_for {
  my ($name) = @_;
  my $u = $DB->getNode($name, 'user');
  return 'userpass=' . uri_escape("$name|$u->{passwd}");
}
my %as = map { $_ => cookie_for($_) } qw(genericeditor e2e_editor e2e_admin normaluser26);
ok(!$APP->isAdmin($DB->getNode($_, 'user')), "$_ is not an admin") for qw(genericeditor e2e_editor);

sub api {
  my ($who, $path, $data) = @_;
  my $res = $test->request(POST $path, Cookie => $as{$who},
    'Content-Type' => 'application/json', Content => encode_json($data // {}));
  return decode_json($res->content);
}
sub in_thread {
  my ($parent, $child) = @_;
  return $DB->sqlSelect('COUNT(*)', 'nodegroup', 'nodegroup_id=' . int($parent) . ' AND node_id=' . int($child)) ? 1 : 0;
}
sub exists_node { my ($id) = @_; return $id && $DB->sqlSelect('COUNT(*)', 'node', 'node_id=' . int($id)) ? 1 : 0 }

my $title = 'Member reply ' . time() . $$;
my ($disc, $reply, $nested);

subtest 'one member replies to another member\'s discussion' => sub {
  my $c = api('genericeditor', '/api/debatecomments/action/create',
    { title => $title, restricted => $CONTENT_EDITORS, doctext => '<p>Thoughts?</p>' });
  is($c->{success}, 1, 'genericeditor starts a Content Editors discussion');
  $disc = $c->{node_id};

  # Both have browsed first, the way real members arrive.
  $test->request(GET "/node/$disc", Cookie => $as{$_}) for qw(genericeditor e2e_editor);

  my $r = api('e2e_editor', "/api/debatecomments/$disc/action/reply", { title => "re: $title", doctext => '<p>Mine.</p>' });
  is($r->{success}, 1, 'e2e_editor replies');
  $reply = $r->{node_id};
  ok(in_thread($disc, $reply), 'the reply is in the discussion\'s thread');
};

subtest 'a nested reply to the other member\'s comment' => sub {
  my $r = api('genericeditor', "/api/debatecomments/$reply/action/reply", { title => "re: re: $title", doctext => '<p>Thanks.</p>' });
  is($r->{success}, 1, 'genericeditor replies to e2e_editor\'s reply');
  $nested = $r->{node_id};
  ok(in_thread($reply, $nested), 'linked under the reply it answers');
};

subtest 'a non-member still cannot reply' => sub {
  my $r = api('normaluser26', "/api/debatecomments/$disc/action/reply", { title => "re: $title (outsider)", doctext => 'x' });
  is($r->{success}, 0, 'refused');
  is($r->{error}, 'Permission denied', '... as permission denied');
  is($DB->sqlSelect('COUNT(*)', 'nodegroup', 'nodegroup_id=' . int($disc)), 1, 'the thread still has just the one reply');
};

subtest 'deleting the discussion removes the whole thread' => sub {
  my $d = api('e2e_admin', "/api/debatecomments/$disc/action/delete", {});
  ok($d->{success}, 'admin deletes the discussion');
  ok(!exists_node($_), "node $_ is gone") for grep { $_ } ($disc, $reply, $nested);
};

END {
  # Anything a failed run left behind.
  my $root = $DB->getNode('root', 'user');
  local $Everything::HTML::USER = $root;
  for my $id (grep { $_ && exists_node($_) } ($nested, $reply, $disc)) {
    eval { $DB->nukeNode($DB->getNodeById($id), -1, 1); 1 } or diag("cleanup of $id failed: $@");
  }
}

done_testing();
