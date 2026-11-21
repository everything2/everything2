#!/usr/bin/perl -w

# Deleting a node keeps its newest copy in the tomb, and the stale-row cleanup job (#4715).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Data::Dumper;
use Everything;
use Everything::Serialization qw(safe_deserialize_dumper);

initEverything('development-docker');
my $DB = $Everything::DB;

my $root     = $DB->getNode('root', 'user');
my $document = $DB->getType('document');
my $JOB      = "$FindBin::Bin/../tools/jobs/tomb_stale_rows.pl";
my @made;

END {
    if ($DB) {
        for my $id (@made) {
            if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
            $DB->sqlDelete('tomb', 'node_id=' . int($id));
        }
    }
}

sub make_document {
    my ($label, $text) = @_;
    my $id = $DB->insertNode("Tomb stale $label $$", $document, $root, { doctext => $text });
    push @made, $id;
    return $DB->getNodeById($id, 'force');
}

# A tomb copy left over from an earlier deletion of a node that is alive again.
sub plant_old_copy {
    my ($node, %copy) = @_;
    my $createtime = delete $copy{createtime} // $node->{createtime};
    local $Data::Dumper::Sortkeys = 1;
    $DB->sqlInsert('tomb', {
        node_id       => $node->{node_id},
        type_nodetype => $node->{type_nodetype},
        title         => $node->{title},
        author_user   => $node->{author_user},
        killa_user    => -1,
        createtime    => $createtime,
        data          => Data::Dumper->Dump([{ doctext => 'the old version', %copy }]),
    });
    return;
}

sub tomb_copy {
    my ($id) = @_;
    my $row = $DB->sqlSelectHashref('*', 'tomb', 'node_id=' . int($id)) or return;
    my $data = safe_deserialize_dumper('my ' . $row->{data}) || {};
    return { %$row, %$data };
}

sub node_alive {
    my ($id) = @_;
    return $DB->sqlSelect('node_id', 'node', 'node_id=' . int($id)) ? 1 : 0;
}

subtest 'deleting a node that already has an old tomb copy keeps the newest copy' => sub {
    my $node = make_document('newest', 'the newest version');
    plant_old_copy($node);

    {
        # Production's database handle reports errors instead of dying.
        local $DB->{dbh}{RaiseError} = 0;
        local $DB->{dbh}{PrintError} = 0;
        $DB->nukeNode($node, $root);
    }

    ok(!node_alive($node->{node_id}), 'the node is deleted');
    my $copy = tomb_copy($node->{node_id});
    is($copy->{doctext}, 'the newest version', 'the tomb holds the text as it was when deleted');
    is($copy->{killa_user}, $root->{node_id}, 'and who deleted it');

    my $back = $DB->resurrectNode($node->{node_id});
    is($back && $back->{doctext}, 'the newest version', 'resurrecting brings back the newest text');
};

subtest 'a node is not deleted when its tomb copy cannot be written' => sub {
    my $node = make_document('kept', 'still here');
    {
        no warnings 'redefine';    ## no critic (ProhibitNoWarnings)
        local *Everything::NodeBase::tombstoneNode = sub { return 0 };
        ok(!$DB->nukeNode($node, $root), 'the delete reports failure');
    }
    ok(node_alive($node->{node_id}), 'the node is still there');
    ok(!tomb_copy($node->{node_id}), 'and nothing was written to the tomb');

    ok($DB->nukeNode($node, $root, 1), 'a delete that asks for no tomb copy still deletes');
    ok(!node_alive($node->{node_id}), 'the node is gone');
};

sub job {
    my ($ids, $apply) = @_;
    my $env = 'E2_TOMB_ONLY=' . join(',', @$ids) . ($apply ? ' E2_APPLY=1' : '');
    my $out = `$env perl $JOB 2>&1`;
    return ($? >> 8, $out);
}

subtest 'the cleanup job prunes tomb rows that are older copies of live nodes' => sub {
    my $stale = make_document('job', 'alive and well');
    plant_old_copy($stale, edittime => '2001-01-01 00:00:00');
    my $reused = make_document('reused', 'a different node');
    plant_old_copy($reused, createtime => '2003-03-03 03:03:03');
    my $newer = make_document('newer', 'edited before the copy');
    plant_old_copy($newer, edittime => '2099-01-01 00:00:00');
    my @ids = map { $_->{node_id} } $stale, $reused, $newer;
    my ($s, $r, $n) = @ids;

    my ($rc, $dry) = job(\@ids);
    is($rc, 0, 'the dry run succeeds') or diag $dry;
    like($dry, qr/prune\s+node $s\b/, 'it identifies the older copy');
    like($dry, qr/keep\s+node $r\b.*different createtime/, 'it keeps a copy that is a different node');
    like($dry, qr/keep\s+node $n\b.*newer than the live/, "and one newer than the live node");
    like($dry, qr/1 to prune, 2 kept \(dry run/, 'and says nothing was deleted');
    is(scalar(grep { tomb_copy($_) } @ids), 3, 'every tomb row is still there');
    unlike($dry, qr/the old version/, 'stored contents are never printed');

    ($rc, my $apply) = job(\@ids, 1);
    is($rc, 0, 'applying succeeds') or diag $apply;
    like($apply, qr/pruned 1 of 1/, 'it reports what it pruned');
    ok(!tomb_copy($s), 'the older copy is gone');
    ok(tomb_copy($r) && tomb_copy($n), 'the rows that did not validate are left alone');
    ok(node_alive($_), "live node $_ is untouched") for @ids;

    ($rc, my $again) = job([$s], 1);
    is($rc, 0, 'a second run succeeds') or diag $again;
    like($again, qr/0 to prune/, 'and finds nothing to prune');
};

done_testing();
