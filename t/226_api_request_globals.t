#!/usr/bin/perl -w
#
# API requests set the request globals that node maintenance hooks read
# (Everything::HTML::$query/$USER/$VARS/$GNODE).
#
# Runs the real PSGI app in-process, mixing page and API requests.
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
use Everything::HTML;   # declares the request globals checked below

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
my $admin = cookie_for('e2e_admin');
my $root  = cookie_for('root');

sub api {
  my ($cookie, $path, $data) = @_;
  my $res = $test->request(POST $path, ($cookie ? (Cookie => $cookie) : ()),
    'Content-Type' => 'application/json', Content => encode_json($data // {}));
  return decode_json($res->content);
}
sub exists_node { my ($id) = @_; return $id && $DB->sqlSelect('COUNT(*)', 'node', "node_id=$id") ? 1 : 0 }

my @cleanup;

subtest 'a reply created after a page view survives' => sub {
  my $disc = api($admin, '/api/debatecomments/action/create', { title => "globals check $$", restricted => 114 });
  ok($disc->{success}, 'discussion created');
  push @cleanup, $disc->{node_id};

  my $first = api($admin, "/api/debatecomments/$disc->{node_id}/action/reply", { title => "re: first $$", doctext => 'one' });
  push @cleanup, $first->{node_id};
  ok(exists_node($first->{node_id}), 'reply before any page view exists');

  # A page view in between.
  $test->request(GET "/?node_id=$disc->{node_id}", Cookie => $root);

  my $second = api($admin, "/api/debatecomments/$disc->{node_id}/action/reply", { title => "re: second $$", doctext => 'two' });
  push @cleanup, $second->{node_id};
  ok($second->{success}, 'reply after a page view reports success');
  ok(exists_node($second->{node_id}), 'reply after a page view exists');

  my $group = $DB->getNodeById($disc->{node_id}, 'force')->{group} || [];
  my %in = map { $_ => 1 } @$group;
  ok($in{$first->{node_id}} && $in{$second->{node_id}}, 'both replies are in the discussion');
};

subtest 'request globals during an API request' => sub {
  $test->request(GET '/', Cookie => $root);
  ok($Everything::HTML::query, 'a page request sets the form query');

  api($admin, '/api/debatecomments/action/create', { title => '' });   # any API request
  ok(!$Everything::HTML::query, 'an API request has no form query');
  is(ref($Everything::HTML::USER) && $Everything::HTML::USER->{title}, 'e2e_admin', 'the user is the API caller');
  is(ref($Everything::HTML::VARS), 'HASH', 'the caller\'s vars are set');

  $test->request(GET '/api/sessions');   # no cookie
  is($Everything::HTML::USER->{title}, 'Guest User', 'a guest API request has the guest user');
};

done_testing();

# Runs even if a check above dies. Deleting a discussion also deletes its replies.
END {
  for my $id (reverse grep { exists_node($_) } @cleanup) {
    eval { api($admin, "/api/debatecomments/$id/action/delete"); 1 } or diag("cleanup of $id failed: $@");
  }
}
