#!/usr/bin/perl -w

# A deleted node's tomb copy records the person who deleted it, not the superuser (-1) (#4718).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::drafts;
use Everything::API::debatecomments;
use Everything::API::polls;
use MockRequest;

initEverything('development-docker');
my $DB = $Everything::DB;

my $admin  = $DB->getNode('root', 'user');
my $member = $DB->getNode('normaluser7', 'user');
ok($admin && $member, 'root and normaluser7 exist');
ok(!$DB->isGod($member), 'normaluser7 is not an admin');

my @made;
END {
    if ($DB) {
        for my $id (@made) {
            $DB->sqlDelete($_, "${_}_id=" . int($id)) for qw(node document draft debatecomment e2poll);
            $DB->sqlDelete('nodegroup', 'nodegroup_id=' . int($id) . ' OR node_id=' . int($id));
            $DB->sqlDelete('tomb', 'node_id=' . int($id));
        }
    }
}

sub request_as {
    my ($user, %post) = @_;
    return MockRequest->new(node_id => $user->{node_id}, title => $user->{title}, nodedata => $user,
        is_guest_flag => 0, is_admin_flag => $DB->isGod($user) ? 1 : 0, request_method => 'POST',
        postdata => \%post);
}

sub killa { return $DB->sqlSelect('killa_user', 'tomb', 'node_id=' . int($_[0])) }
sub gone  { return !$DB->sqlSelect('COUNT(*)', 'node', 'node_id=' . int($_[0])) }

sub make_draft {
    my ($author) = @_;
    my $id = $DB->insertNode("Killa draft $$ " . scalar(@made), 'draft', $author,
        { doctext => 'draft text', publication_status => 0 }, 'skip maintenance');
    push @made, $id;
    return $id;
}

subtest 'a member deleting their own draft is recorded as its killa' => sub {
    my $id = make_draft($member);
    my $r = Everything::API::drafts->new->delete_draft(request_as($member), $id)->[1];
    ok($r->{success}, 'the draft is deleted') or diag explain $r;
    ok(gone($id), 'its node is gone');
    is(killa($id), $member->{node_id}, 'the tomb records the member who deleted it');
};

subtest "an admin deleting a member's draft is recorded as its killa" => sub {
    my $id = make_draft($member);
    my $r = Everything::API::drafts->new->delete_draft(request_as($admin), $id)->[1];
    ok($r->{success}, 'the draft is deleted') or diag explain $r;
    is(killa($id), $admin->{node_id}, 'the tomb records the admin, not the author or -1');
};

subtest "a member still can't delete someone else's draft" => sub {
    my $id = make_draft($admin);
    my $r = Everything::API::drafts->new->delete_draft(request_as($member), $id)->[1];
    ok(!$r->{success}, 'refused');
    ok(!gone($id), 'the draft is still there');
};

subtest 'an admin deleting a comment thread is recorded on every copy' => sub {
    my $type = $DB->getType('debatecomment');
    my $root_id = $DB->insertNode("Killa comment $$", $type, $member,
        { doctext => 'top', restricted => 923653, parent_debatecomment => 0, root_debatecomment => 0 });
    push @made, $root_id;
    $DB->sqlUpdate('debatecomment', { root_debatecomment => $root_id }, "debatecomment_id=$root_id");
    my $reply_id = $DB->insertNode("Killa reply $$", $type, $member,
        { doctext => 'reply', restricted => 923653, parent_debatecomment => $root_id, root_debatecomment => $root_id });
    push @made, $reply_id;
    $DB->insertIntoNodegroup($DB->getNodeById($root_id), -1, $reply_id);

    my $r = Everything::API::debatecomments->new->delete_comment(request_as($admin), $root_id)->[1];
    ok($r->{success}, 'the thread is deleted') or diag explain $r;
    is($r->{deleted_count}, 2, 'both comments');
    ok(gone($root_id) && gone($reply_id), 'both nodes are gone');
    is(killa($root_id), $admin->{node_id}, 'the comment records the admin');
    is(killa($reply_id), $admin->{node_id}, 'and so does the reply');
};

subtest 'an admin deleting a poll is recorded as its killa' => sub {
    my $id = $DB->insertNode("Killa poll $$", 'e2poll', $admin, {
        poll_author => $admin->{node_id}, question => 'Who?', doctext => "A\nB",
        poll_status => 'closed', totalvotes => 0, e2poll_results => '0,0',
    });
    push @made, $id;
    my $r = Everything::API::polls->new->delete_poll(request_as($admin, poll_id => $id))->[1];
    ok($r->{success}, 'the poll is deleted') or diag explain $r;
    ok(gone($id), 'its node is gone');
    is(killa($id), $admin->{node_id}, 'the tomb records the admin');
};

subtest 'nukeNode records $KILLA when given, otherwise the user it was called with' => sub {
    my $a = make_draft($member);
    ok($DB->nukeNode($a, -1, undef, undef, $member), 'deleted as the superuser on the member\'s behalf');
    is(killa($a), $member->{node_id}, 'the member is recorded');

    my $b = make_draft($member);
    ok($DB->nukeNode($b, $admin), 'deleted as the admin');
    is(killa($b), $admin->{node_id}, 'the admin is recorded');

    my $c = make_draft($member);
    ok(!$DB->nukeNode($c, $member, undef, undef, $member), 'naming a killa grants no permission');
    ok(!gone($c), 'the draft is still there');
};

done_testing();
