#!/usr/bin/perl -w

# Node Heaven XML Ticker: a member's own deleted writeups, and the text of one when asked (#4615).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Data::Dumper;
use Everything;
use Everything::Page::node_heaven_xml_ticker;
use MockRequest;
use TestSeed;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

my $member  = TestSeed::make_user($DB, $APP, label => 'heaven');
my $angel   = 990_000_000 + ($$ % 1_000_000);
my $title   = "Heaven Test $$";
END {
    $DB->sqlDelete('heaven', 'node_id=' . int($angel)) if $DB;
    TestSeed::cleanup($DB) if $DB;
}

local $Data::Dumper::Sortkeys = 1;
$DB->sqlInsert('heaven', {
    node_id       => $angel,
    type_nodetype => $DB->getId($DB->getType('writeup')),
    title         => $title,
    author_user   => $member->{node_id},
    reputation    => 3,
    data          => Data::Dumper->Dump([{ doctext => 'Gone but [not forgotten].', wrtype_writeuptype => 0 }]),
});

sub ticker {
    my (%params) = @_;
    my $req = MockRequest->new(
        node_id => $member->{node_id}, title => $member->{title}, nodedata => $member,
        is_guest_flag => 0, query_params => { %params },
    );
    my $xml = eval { Everything::Page::node_heaven_xml_ticker->new->generate_xml($req) };
    ok(defined $xml, 'ticker rendered') or diag $@;
    return $xml // '';
}

my $list = ticker();
like($list, qr/<nodeangel[^>]*node_id="$angel"/, 'the deleted writeup is listed');
like($list, qr/\Q$title\E/, 'with its title');

my $one = ticker(visitnode_id => $angel);
like($one, qr/not forgotten/, 'asking for one shows its text');
like($one, qr{<a [^>]*>not forgotten</a>}, 'with its links made');

my $raw = ticker(visitnode_id => $angel, links_noparse => 1);
like($raw, qr/\[not forgotten\]/, 'links_noparse leaves the text as written');

done_testing();
