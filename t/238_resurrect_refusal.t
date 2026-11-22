#!/usr/bin/perl -w

# A stored copy whose type no longer exists or is retired, or that can't be read back, is not
# resurrected; the reason is given instead (#4717).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Data::Dumper;
use Everything;
use Everything::Page::the_node_crypt;
use Everything::API::resurrect;
use MockRequest;

initEverything('development-docker');
my $DB = $Everything::DB;

my $root     = $DB->getNode('root', 'user');
my $document = $DB->getType('document');
my $htmlcode = $DB->getType('htmlcode');
ok($document && $htmlcode, 'the document and htmlcode types exist');

# Ids nothing uses, well past the highest node.
my $base = int($DB->sqlSelect('GREATEST(MAX(node_id), (SELECT MAX(node_id) FROM tomb))', 'node')) + 1_000_000 + ($$ % 1000) * 100;
my @planted;

END {
    if ($DB) {
        for my $id (@planted) {
            if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
            $DB->sqlDelete($_, "${_}_id=" . int($id)) for qw(node document htmlcode);
            $DB->sqlDelete('tomb', 'node_id=' . int($id));
        }
    }
}

sub plant {
    my ($id, $type_id, $title, $data) = @_;
    push @planted, $id;
    $DB->sqlInsert('tomb', {
        node_id => $id, type_nodetype => $type_id, title => $title, author_user => $root->{node_id},
        killa_user => $root->{node_id}, createtime => '2009-05-13 12:52:11',
        data => ref $data ? Data::Dumper->Dump([$data]) : $data,
    });
    return $id;
}

sub node_rows { return $DB->sqlSelect('COUNT(*)', 'node', 'node_id=' . int($_[0])) }

sub api {
    my ($id) = @_;
    my $req = MockRequest->new(node_id => $root->{node_id}, title => $root->{title}, nodedata => $root,
        is_guest_flag => 0, is_admin_flag => 1, postdata => { node_id => $id, source => 'tomb' });
    return Everything::API::resurrect->new->resurrect_node($req)->[1];
}

sub coffin { return Everything::Page::the_node_crypt->new->_view_coffin($DB, $_[0], 0) }

my $doc = { title => "Refusal doc $$", doctext => 'some text', document_id => 0 };
my $oldtype = "oldtype$$";

my %case = (
    'its type no longer exists' => {
        id => plant($base + 1, $base + 90, "Refusal gone type $$", $doc),
        reason => qr/\AIts type no longer exists\.\z/,
    },
    'its type no longer exists, named from the type\'s own tomb copy' => {
        id => do {
            plant($base + 91, 1, $oldtype, { title => $oldtype });
            plant($base + 2, $base + 91, "Refusal named type $$", $doc);
        },
        reason => qr/\AIts type, \Q$oldtype\E, no longer exists\.\z/,
    },
    'its type is retired' => {
        id => plant($base + 3, $htmlcode->{node_id}, "Refusal htmlcode $$", { title => "Refusal htmlcode $$", code => '' }),
        reason => qr/\AIts type, htmlcode, is retired\.\z/,
    },
    'it cannot be read back' => {
        id => plant($base + 4, $document->{node_id}, "Refusal cut off $$", q[$VAR1 = { 'doctext' => 'cut off at 64K]),
        reason => qr/\AIts stored copy can't be read back\.\z/,
    },
);

for my $name (sort keys %case) {
    my ($id, $reason) = @{ $case{$name} }{qw(id reason)};
    subtest "a copy is not resurrected when $name" => sub {
        ok(!$DB->resurrectNode($id), 'resurrectNode refuses');
        is(node_rows($id), 0, 'no node row is written');
        ok($DB->sqlSelect('COUNT(*)', 'tomb', 'node_id=' . int($id)), 'the stored copy is kept');
        like($DB->resurrect_refusal($id), $reason, 'resurrect_refusal gives the reason');

        my $r = api($id);
        ok(!$r->{success}, 'the resurrect API refuses');
        like($r->{error}, qr/can't be resurrected/, 'saying it cannot be resurrected');
        my ($text) = $DB->resurrect_refusal($id);
        like($r->{error}, qr/\Q$text\E/, 'and why');
        is(node_rows($id), 0, 'still no node row');

        my $page = coffin($id);
        ok($page->{viewing_coffin}, 'The Node Crypt still shows the copy');
        is($page->{resurrect_refusal}, $text, 'with the reason in place of RESURRECT');
        my %shown = map { $_->{key} => $_->{value} } @{ $page->{fields} || [] };
        like($shown{title} // '', qr/\ARefusal /, 'and its title');
    };
}

subtest 'an ordinary copy still resurrects' => sub {
    my $id = plant($base + 5, $document->{node_id}, "Refusal ok doc $$",
        { title => "Refusal ok doc $$", doctext => 'restored text' });
    is($DB->resurrect_refusal($id), undef, 'nothing refuses it');
    ok(!defined coffin($id)->{resurrect_refusal}, 'The Node Crypt offers RESURRECT');
    my $r = api($id);
    ok($r->{success}, 'the resurrect API restores it') or diag explain $r;
    my $back = $DB->getNodeById($id, 'force');
    is($back && $back->{doctext}, 'restored text', 'with its text');
};

is($DB->resurrect_refusal($base + 99), 'There is no copy of it in the tomb.', 'a node with no copy says so');

done_testing();
