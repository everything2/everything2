#!/usr/bin/perl -w

# Poll changes made through the APIs are seen by every web worker, not just the one that made them.
# Each worker keeps its own node cache and checks a node's version before reusing it, so a change has
# to go through updateNode (which bumps the version). "Another worker" here is a second NodeBase with
# its own cache, warmed before the change, starting a new request (resetCache) after it.
#
# Serial in t/run.pl: making a poll current closes whichever poll is current for the whole site.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Encode;
use Everything;
use Everything::API::polls;
use Everything::API::poll_creator;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

{
    package PollTestRequest;
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
my $member = $APP->node_by_id($DB->getNode('normaluser8', 'user')->{node_id});
my $editors = $DB->getNode('Content Editors', 'usergroup');
ok($root && $root->is_admin && $member && !$member->is_admin && $editors, 'test users exist');

my $other = Everything::NodeBase->new;
ok($other && $other->{cache} != $DB->{cache}, 'a second worker with its own cache');

my @was_current = map { $_->{node_id} } $DB->getNodeWhere({ poll_status => 'current' }, 'e2poll');
my @planted;
END {
    return unless $DB;
    for my $id (@planted) {
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb', "node_id=$id");
    }
    # Put back whichever poll was current before the test.
    for my $id (@was_current) {
        my $poll = $DB->getNodeById($id, 'force') or next;
        $poll->{poll_status} = 'current';
        $DB->updateNode($poll, -1);
    }
}

sub plant_poll {
    my ($title, $status) = @_;
    my $id = $DB->insertNode("$title $$", 'e2poll', $root->NODEDATA, {
        poll_author => $root->node_id, question => 'Worker cache question?', doctext => "Yes\n\nNo",
        poll_status => $status, totalvotes => 0, e2poll_results => '0,0',
    }, 'skip maintenance');
    push @planted, $id;
    return $id;
}

# What the other worker sees on its next request.
sub other_status { $other->{cache}->resetCache; return $other->getNodeById($_[0])->{poll_status} }

subtest 'making a poll current' => sub {
    my $old = plant_poll('Worker cache old poll', 'current');
    my $new = plant_poll('Worker cache new poll', 'new');
    is(other_status($old), 'current', 'the other worker has the old poll as current');
    is(other_status($new), 'new', 'and the new one as new');

    my $r = Everything::API::polls->new->set_current_poll(PollTestRequest->new($root, { poll_id => $new }));
    ok($r->[1]{success}, 'poll made current') or diag explain $r->[1];

    is($DB->sqlSelect('poll_status', 'e2poll', "e2poll_id=$new"), 'current', 'the database has the new poll current');
    is(other_status($new), 'current', 'so does the other worker');
    is(other_status($old), 'closed', 'and it has the old poll closed');
    is(other_status($_), 'closed', "and the poll that was current before the test ($_)") for @was_current;

    $DB->{cache}->resetCache;
    is($DB->getNodeById($old)->{poll_status}, 'closed', 'the worker that made the change has the old poll closed too');
};

subtest 'creating a poll' => sub {
    my $title = "Worker cache created poll $$";
    my $r = Everything::API::poll_creator->new->create_poll(PollTestRequest->new($member,
        { title => $title, question => 'Created question?', options => ['Red', 'Blue'] }));
    ok($r->[1]{success}, 'poll created') or diag explain $r->[1];
    my $id = $r->[1]{poll_id};
    push @planted, $id if $id;

    $DB->{cache}->resetCache;
    my $poll = $DB->getNodeById($id);
    is($poll->{question}, 'Created question?', 'the creating worker has the question');
    is($poll->{doctext}, "Red\n\nBlue\n\nNone of the above", 'the options');
    is($poll->{e2poll_results}, '0,0,0', 'zeroed results');
    is($poll->{poll_status}, 'new', 'new status');
    is($poll->{poll_author}, $member->node_id, 'the creator as poll author');
    is($poll->{author_user}, $editors->{node_id}, 'and Content Editors as owner');

    $other->{cache}->resetCache;
    my $seen = $other->getNodeById($id);
    is($seen->{question}, 'Created question?', 'the other worker has the question');
    is($seen->{author_user}, $editors->{node_id}, 'and the owner');
};

done_testing();
