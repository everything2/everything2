#!/usr/bin/perl -w
#
# Saving a draft (PUT /api/drafts/:id) on one worker must reach every other worker's cached copy:
# each worker serves its cached copy as current until the node's version moves, so a save that
# doesn't bump it leaves the author's older text on the other workers (and the editor's next
# autosave can send that older text back). Each case saves through the API on this worker, with
# a second worker already holding the draft in its cache, then checks the second worker's next
# request sees the save.
#
# "Another worker" is a second NodeBase with its own cache.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use JSON;
use Encode qw(encode_utf8);
use Everything;
use Everything::API::drafts;
use TestSeed;

initEverything 'everything';
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

{
    package DraftSaveUser;
    sub new      { my ($c, $n, %f) = @_; return bless { n => $n, %f }, $c }
    sub node_id  { $_[0]{n}{node_id} }
    sub title    { $_[0]{n}{title} }
    sub NODEDATA { $_[0]{n} }
    sub is_guest { 0 }
    sub is_admin { $_[0]{admin} // 0 }
    sub is_editor { $_[0]{editor} // 0 }
    sub VARS     { {} }

    package DraftSaveRequest;
    sub new      { my ($c, $user, $data) = @_; return bless { user => $user, data => $data }, $c }
    sub user     { $_[0]{user} }
    sub is_guest { 0 }
    sub POSTDATA { Encode::encode_utf8(JSON::encode_json($_[0]{data} || {})) }
    sub JSON_POSTDATA { $_[0]{data} }
    sub param    { return }
    sub request_method { 'PUT' }
}

my @drafts;
END {
    for my $id (@drafts) {
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb',     "node_id=$id");
        $DB->sqlDelete('autosave', "node_id=$id");
        $DB->sqlDelete('nodenote', "nodenote_nodeid=$id");
    }
    TestSeed::cleanup($DB);
}

my $api    = Everything::API::drafts->new;
my $author = TestSeed::make_user($DB, $APP, label => 'draftsave', experience => 1000);
my $writer = DraftSaveUser->new($author);
my $root   = DraftSaveUser->new($DB->getNode('root', 'user'), admin => 1, editor => 1);
my $other  = Everything::NodeBase->new;
ok($other && $other->{cache} != $DB->{cache}, 'a second worker with its own cache');

sub new_draft {
    my ($label) = @_;
    my (undef, $res) = @{ $api->create_draft(DraftSaveRequest->new($writer,
        { title => "Draft save $label $$", doctext => 'first' })) };
    my $id = $res->{draft}{node_id};
    push @drafts, $id if $id;
    return $id;
}

# Each save is a request of its own on this worker.
sub save {
    my ($id, %data) = @_;
    $DB->{cache}->resetCache;
    return $api->update_draft(DraftSaveRequest->new($writer, \%data), $id)->[1];
}

# What the other worker serves on its next request.
sub other_next_request { $other->{cache}->resetCache; return $other->getNodeById($_[0]) }

subtest 'saving new text' => sub {
    my $id = new_draft('text');
    ok($id, 'a draft');
    is(other_next_request($id)->{doctext}, 'first', 'the other worker has it cached');

    ok(save($id, doctext => 'second')->{success}, 'the author saves new text');
    is(other_next_request($id)->{doctext}, 'second', "the other worker's next request has the new text");
};

subtest 'renaming' => sub {
    my $id = new_draft('rename');
    my $old = other_next_request($id)->{title};

    my $res = save($id, title => "Draft save renamed $$");
    is($res->{updated}{title}, "Draft save renamed $$", 'the author renames the draft');
    is(other_next_request($id)->{title}, "Draft save renamed $$", "the other worker's next request has the new title");
    $other->{cache}->resetCache;
    my $by_title = $other->getNode("Draft save renamed $$", 'draft');
    is($by_title && $by_title->{node_id}, $id, 'and finds it by the new title');
};

subtest 'renaming to a title the author already has' => sub {
    my $first = new_draft('taken');
    my $id    = new_draft('second');
    my $taken = $DB->getNodeById($first)->{title};
    is(save($id, title => $taken)->{updated}{title}, "$taken (1)", 'the save picks the next free title');
    is(other_next_request($id)->{title}, "$taken (1)", 'and the other worker sees it');
};

subtest 'sending it for review, and an editor marking it reviewed' => sub {
    my $id = new_draft('review');
    my $review  = $DB->getNode('review',  'publication_status');
    my $private = $DB->getNode('private', 'publication_status');
    is(other_next_request($id)->{publication_status}, $private->{node_id}, 'the other worker has it as private');

    ok(save($id, status => 'review')->{success}, 'the author asks for review');
    is(other_next_request($id)->{publication_status}, $review->{node_id}, "the other worker's next request has it in review");
    ok($DB->sqlSelect('nodenote_id', 'nodenote', "nodenote_nodeid=$id AND noter_user=0"), 'with the review request noted');

    my (undef, $res) = @{ $api->mark_reviewed(DraftSaveRequest->new($root), $id) };
    ok($res->{success}, 'an editor marks it reviewed');
    is(other_next_request($id)->{publication_status}, $private->{node_id}, "the other worker's next request has it back to private");
};

subtest "an autosave keeps an editor's change made on another worker" => sub {
    my $id = new_draft('autosave');
    ok(save($id, status => 'review')->{success}, 'the author asks for review');
    is($DB->getNodeById($id)->{publication_status}, $DB->getNode('review', 'publication_status')->{node_id},
        'this worker has it cached in review');

    my $copy = $other->getNodeById($id, 'force');
    $copy->{publication_status} = $DB->getNode('private', 'publication_status')->{node_id};
    ok($other->updateNode($copy, -1, undef, 'skip maintenance'), 'another worker sets it back to private');

    ok(save($id, doctext => 'autosaved')->{success}, "the author's editor autosaves the text on this worker");
    my $stored = $DB->sqlSelect('publication_status', 'draft', "draft_id=$id");
    is($stored, $copy->{publication_status}, 'the stored status is still private');
    is($DB->sqlSelect('doctext', 'document', "document_id=$id"), 'autosaved', 'and the text is saved');
};

subtest 'text, title and status in one save' => sub {
    my $id = new_draft('all');
    other_next_request($id);
    my $res = save($id, doctext => 'all three', title => "Draft save all renamed $$", status => 'review');
    ok($res->{success}, 'saved');
    is($res->{doctext}, 'all three', 'the response has the saved text');
    my $seen = other_next_request($id);
    is($seen->{doctext}, 'all three', 'the other worker has the text');
    is($seen->{title}, "Draft save all renamed $$", 'and the title');
    is($seen->{publication_status}, $DB->getNode('review', 'publication_status')->{node_id}, 'and the status');
    is($DB->sqlSelect('doctext', 'autosave', "node_id=$id"), 'first', 'the previous text went to the version history');
};

done_testing();
