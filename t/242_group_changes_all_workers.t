#!/usr/bin/perl -w

# Group changes made through the APIs are seen by every web worker, not just the one that made
# them. Each worker keeps its own node cache and checks a node's version before reusing it, so a
# change has to bump the group's version. "Another worker" here is a second NodeBase with its own
# cache, warmed before the change, starting a new request (resetCache) after it.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Encode;
use Everything;
use Everything::API::usergroups;
use Everything::API::nodegroups;
use Everything::API::drafts;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

{
    package GroupTestRequest;
    sub new {
        my ($class, $user, $data) = @_;
        return bless { user => $user, postdata => Encode::encode_utf8(JSON::encode_json($data)) }, $class;
    }
    sub user           { return $_[0]{user} }
    sub is_guest       { return $_[0]{user}->is_guest }
    sub POSTDATA       { return $_[0]{postdata} }
    sub JSON_POSTDATA  { return JSON::decode_json($_[0]{postdata}) }
    sub request_method { return 'POST' }
    sub param          { return }
}

my $root   = $APP->node_by_id($DB->getNode('root', 'user')->{node_id});
my $author = $APP->node_by_id($DB->getNode('normaluser7', 'user')->{node_id});
my @members = map { $DB->getNode("normaluser$_", 'user') } (5, 6);
ok($root && $root->is_admin && $author && $members[0] && $members[1], 'test users exist');

my $other = Everything::NodeBase->new;
ok($other && $other->{cache} != $DB->{cache}, 'a second worker with its own cache');

my (@planted, @drafts);
END {
    return unless $DB;
    for my $id (@drafts) {
        $DB->sqlDelete($_, "${_}_id=$id") for qw(writeup draft document publish);
        $DB->sqlDelete('newwriteup', "node_id=$id");
        $DB->sqlDelete('nodegroup', "node_id=$id");
        $DB->sqlDelete('node', "node_id=$id");
        $DB->sqlDelete('nodenote', "nodenote_nodeid=$id");
    }
    for my $id (@planted) {
        $DB->sqlDelete('nodegroup', "nodegroup_id=$id");
        $DB->sqlDelete('nodenote', "nodenote_nodeid=$id");
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb', "node_id=$id");
    }
}

sub plant {
    my ($title, $type, @member_ids) = @_;
    my $id = $DB->insertNode("$title $$", $type, $root->NODEDATA, {}, 'skip maintenance');
    push @planted, $id;
    $DB->insertIntoNodegroup($DB->getNodeById($id, 'force'), -1, $_) for @member_ids;
    return $id;
}

# What the other worker sees on its next request.
sub other_group   { $other->{cache}->resetCache; return [ @{ $other->getNodeById($_[0])->{group} || [] } ] }
sub other_member  {
    my ($group_id, $user_id) = @_;
    $other->{cache}->resetCache;
    return $other->isApproved($other->getNodeById($user_id), $other->getNodeById($group_id), 'nogods') ? 1 : 0;
}

subtest 'usergroup membership' => sub {
    my ($m5, $m6) = map { $_->{node_id} } @members;
    my $g = plant('Worker cache usergroup', 'usergroup', $m5);
    my $api = Everything::API::usergroups->new;

    is(other_member($g, $m5), 1, 'the other worker sees the member');
    is_deeply(other_group($g), [$m5], 'and the member list');

    my $r = $api->removeuser(GroupTestRequest->new($root, [$m5]), $g);
    is($r->[0], 200, 'member removed');
    is_deeply($DB->sqlSelectMany('node_id', 'nodegroup', "nodegroup_id=$g")->fetchall_arrayref, [], 'gone from the database');
    is(other_member($g, $m5), 0, 'the other worker no longer counts them as a member');
    is_deeply(other_group($g), [], 'or lists them');
    $DB->{cache}->resetCache;
    ok(!$DB->isApproved($DB->getNodeById($m5), $DB->getNodeById($g), 'nogods'), 'nor does the worker that made the change');

    $r = $api->adduser(GroupTestRequest->new($root, [$m5, $m6]), $g);
    is($r->[0], 200, 'members added');
    is(other_member($g, $m6), 1, 'the other worker sees a new member');
    is_deeply(other_group($g), [$m5, $m6], 'in order');

    $r = $api->reorder(GroupTestRequest->new($root, [$m6, $m5]), $g);
    is($r->[0], 200, 'members reordered');
    is_deeply(other_group($g), [$m6, $m5], 'the other worker sees the new order');

    my $m6_user = $APP->node_by_id($m6);
    $r = $api->leave(GroupTestRequest->new($m6_user, {}), $g);
    ok($r->[1]{success}, 'a member leaves');
    is(other_member($g, $m6), 0, 'the other worker no longer counts them as a member');
    is_deeply(other_group($g), [$m5], 'or lists them');

    $r = $api->update_description(GroupTestRequest->new($root, { doctext => '<p>Worker cache description</p>' }), $g);
    ok($r->[1]{success}, 'description updated');
    $other->{cache}->resetCache;
    is($other->getNodeById($g)->{doctext}, '<p>Worker cache description</p>', 'the other worker sees the new description');
};

subtest 'nodegroup contents' => sub {
    my ($a, $b) = map { $_->{node_id} } @members;
    my $g = plant('Worker cache nodegroup', 'nodegroup', $a);
    my $api = Everything::API::nodegroups->new;

    is_deeply(other_group($g), [$a], 'the other worker sees the contents');

    my $r = $api->addnode(GroupTestRequest->new($root, { node_ids => [$b] }), $g);
    is($r->[0], 200, 'node added');
    is_deeply(other_group($g), [$a, $b], 'the other worker sees it');

    $r = $api->reorder(GroupTestRequest->new($root, [$b, $a]), $g);
    is($r->[0], 200, 'reordered');
    is_deeply(other_group($g), [$b, $a], 'the other worker sees the new order');

    $r = $api->removenode(GroupTestRequest->new($root, { node_ids => [$a] }), $g);
    is($r->[0], 200, 'node removed');
    is_deeply(other_group($g), [$b], 'the other worker sees it gone');
};

my $thing = $DB->getNode('thing', 'writeuptype');
my $drafts_api = Everything::API::drafts->new;

sub new_draft {
    my ($title) = @_;
    my $r = $drafts_api->create_draft(GroupTestRequest->new($author, { title => $title, doctext => '<p>Worker cache body.</p>' }));
    my $id = $r->[1]{draft}{node_id};
    push @drafts, $id if $id;
    return $id;
}

subtest 'publishing a draft into an e2node' => sub {
    my $e2 = plant('Worker cache e2node', 'e2node');
    is_deeply(other_group($e2), [], 'the other worker has the e2node, with no writeups yet');

    my $draft = new_draft("Worker cache e2node $$");
    ok($draft, 'draft created');
    my $r = $drafts_api->publish_draft(GroupTestRequest->new($author,
        { parent_e2node => $e2, wrtype_writeuptype => $thing->{node_id}, feedback_policy_id => 0 }), $draft);
    ok($r->[1]{success}, 'published');
    is_deeply(other_group($e2), [$draft], 'the other worker sees the new writeup in the e2node');
};

subtest 'republishing a removed draft into an e2node' => sub {
    my $e2 = plant('Worker cache republish e2node', 'e2node');
    is_deeply(other_group($e2), [], 'the other worker has the e2node, with no writeups yet');

    my $draft = new_draft("Worker cache republish e2node $$");
    ok($draft, 'draft created');
    $DB->sqlUpdate('draft', { publication_status => $DB->getNode('removed', 'publication_status')->{node_id} }, "draft_id=$draft");
    $DB->getCache->incrementGlobalVersion($DB->getNodeById($draft, 'force'));
    $DB->getNodeById($draft, 'force');

    my $r = $drafts_api->republish_draft(GroupTestRequest->new($root,
        { e2node_title => "Worker cache republish e2node $$", e2node_id => $e2, wrtype_writeuptype => $thing->{node_id} }), $draft);
    ok($r->[1]{success}, 'republished') or diag explain $r->[1];
    is_deeply(other_group($e2), [$draft], 'the other worker sees the writeup in the e2node');
};

done_testing();
