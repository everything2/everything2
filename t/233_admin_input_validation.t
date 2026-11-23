#!/usr/bin/perl -w
#
# Input validation on admin and node-maintenance paths: ids are numbers, node edits only touch
# real columns with plain values, table and column names are identifiers, and homenode image
# keys are per user. Runs the real PSGI app in-process. Deletes and DDL are recorded instead of
# executed, so nothing here changes the database except one throwaway document node.
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
use Everything::HTML;
use Everything::API::user;

chdir '/var/everything';
my $test = Plack::Test->create(Plack::Util::load_psgi('/var/everything/app.psgi'));
$test->request(GET '/api/sessions');   # boot the app

my $DB  = $Everything::DB;
my $APP = $Everything::APP;
ok($DB, 'app booted');

my $admin_user = $DB->getNode('e2e_admin', 'user');
my $admin = 'userpass=' . uri_escape("e2e_admin|$admin_user->{passwd}");
sub post_json {
  my ($path, $data) = @_;
  my $res = $test->request(POST $path, Cookie => $admin, 'Content-Type' => 'application/json', Content => encode_json($data));
  return decode_json($res->content);
}
sub type_id { return $DB->sqlSelect('node_id', 'node', 'title=' . $DB->quote($_[0]) . ' AND type_nodetype=1') }

# Record deletes and raw queries instead of running them.
my @recorded;
sub recording(&) {
  my ($code) = @_;
  @recorded = ();
  no warnings 'redefine';
  local *Everything::NodeBase::sqlDelete = sub { my ($self, $table, $where) = @_; push @recorded, "DELETE $table WHERE $where"; return 0 };
  my $run = \&Everything::NodeBase::executeQuery;
  local *Everything::NodeBase::executeQuery = sub {    # record DDL; everything else runs as normal
    my ($self, $sql) = @_;
    if ($sql =~ /^\s*(?:CREATE|ALTER|DROP)\b/i) { push @recorded, $sql; return 0 }
    return $run->(@_);
  };
  return $code->();
}

subtest 'removing nodes from a nodegroup' => sub {
  my $group = $DB->sqlSelect('node_id', 'node', 'type_nodetype=' . type_id('nodegroup'), 'ORDER BY node_id LIMIT 1');
  ok($group, 'a nodegroup');
  recording { post_json("/api/nodegroups/$group/action/removenode", { node_ids => ['5 OR 1=1', 'abc', ' 7'] }) };
  is(scalar(grep { /^DELETE nodegroup/ } @recorded), 0, 'ids that are not numbers delete nothing');
  recording { post_json("/api/nodegroups/$group/action/removenode", { node_ids => [12345] }) };
  my @deletes = grep { /^DELETE nodegroup/ } @recorded;
  is(scalar(@deletes), 1, 'a numeric id deletes one row');
  like($deletes[0] // '', qr/^DELETE nodegroup WHERE nodegroup_id=$group (?:AND|&&) node_id=12345$/, '... just that one');
};

subtest 'deleting a poll vote' => sub {
  my $poll = $DB->sqlSelect('node_id', 'node', 'type_nodetype=' . type_id('e2poll'), 'ORDER BY node_id LIMIT 1');
  ok($poll, 'a poll');
  my $r = recording { post_json('/api/poll/delete_vote', { poll_id => $poll, voter_user => '0 OR 1=1' }) };
  is($r->{success}, 0, 'a voter_user that is not a user id is refused');
  is(scalar(grep { /^DELETE pollvote/ } @recorded), 0, '... and no votes are deleted (in particular, not all of them)');
};

subtest 'basic edit touches only real columns, with plain values' => sub {
  my $created = post_json('/api/node/create', { type => 'document', title => "Basic edit check $$" });
  my $doc = $created->{node_id};
  ok($doc, 'a throwaway document');
  my $type_before = $DB->sqlSelect('type_nodetype', 'node', "node_id=" . int($doc));

  my $r = post_json("/api/admin/node/$doc/basicedit", { fields => {
    title         => "Basic edit check $$ (edited)",
    type_nodetype => '1 AND 1=1',
    no_such_field => 'x',
    type          => { title => 'nodetype', restrictdupes => 1 },
  } });
  is($r->{success}, 1, 'the edit is saved');
  is_deeply($r->{updatedFields}, ['title'], 'only the real column with a plain value is updated');
  is_deeply([sort @{ $r->{skippedFields} || [] }], [sort qw(type type_nodetype no_such_field)], 'the rest are reported as skipped');
  is($DB->sqlSelect('title', 'node', "node_id=" . int($doc)), "Basic edit check $$ (edited)", 'the title changed');
  is($DB->sqlSelect('type_nodetype', 'node', "node_id=" . int($doc)), $type_before, 'the node type did not');

  $DB->{dbh}->do('DELETE FROM document WHERE document_id=' . int($doc));
  $DB->{dbh}->do('DELETE FROM node WHERE node_id=' . int($doc));
};

subtest 'table and column names' => sub {
  ok($DB->is_sql_identifier($_), "'$_' is an identifier") for qw(writeup my_table _x T1);
  ok(!$DB->is_sql_identifier($_), "'" . ($_ // 'undef') . "' is not") for (undef, '', '1abc', 'a b', 'a;b', 'x) AS SELECT 1 --', 'a' x 65);

  recording { $DB->createNodeTable('zzt (zzt_id int) AS SELECT 1 --') };
  is_deeply(\@recorded, [], 'createNodeTable refuses a non-identifier without running anything');
  recording { $DB->dropNodeTable('zzt; DROP TABLE node') };
  is_deeply(\@recorded, [], 'dropNodeTable refuses a non-identifier');
  recording { $DB->addFieldToTable('zzt', 'c1', 'int; DROP TABLE node', 0) };
  is_deeply(\@recorded, [], 'addFieldToTable refuses a column type that is not a type');
  recording { $DB->addFieldToTable('zzt', 'c1', 'varchar(10)', 0, q{a"b}) };
  is($recorded[0] // '', q{ALTER TABLE zzt ADD c1 varchar(10) DEFAULT 'a\"b' NOT NULL}, 'addFieldToTable quotes the default value');
  recording { $DB->dropFieldFromTable('zzt', 'c1') };
  is_deeply(\@recorded, ['ALTER TABLE zzt DROP c1'], 'dropFieldFromTable names the column plainly');
};

subtest 'homenode image keys are per user' => sub {
  my $api = Everything::API::user->new;
  my @users = map { $APP->node_by_name($_, 'user') } qw(e2e_user e2e_editor);
  my @keys = map { $api->homenode_image_key($_) } @users;
  like($keys[0], qr/^id-\d+$/, 'the key is the user id');
  isnt($keys[0], $keys[1], 'two users, two keys');
};

done_testing();
