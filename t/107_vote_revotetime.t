#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 107_vote_revotetime.t
#
# Guards the MySQL 8.4 zero-date fix on the `vote` table (#4078):
#   votetime   datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#   revotetime datetime NULL     DEFAULT NULL
#
# The subtlety (found by reading insertVote): votetime is always set to
# now() on insert, but revotetime is NOT set on insert — it takes the column
# default, and is only written on a revote. So the default IS exercised on
# every vote. Under the old zero-date default this breaks insertVote under
# 8.4 strict mode; with DEFAULT NULL, a never-revoted vote is NULL ("no
# revote"), which the one reader (API/reputation.pm) already tolerates via
# its `$row->{revotetime} && ...` truthiness guard.
#
# This is schema-only — no app code changed — so these tests assert the
# *behavior* the schema produces, and the read-contract the reputation code
# depends on.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use TestSeed;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

# Dedicated voter + author so concurrent tests don't race normaluser1's
# votesleft or normaluser2's GP/XP under prove -j4. #4267
my $voter  = TestSeed::make_user($DB, $APP, label => 'voter',  experience => 1000, votesleft => 10);
my $author = TestSeed::make_user($DB, $APP, label => 'author', experience => 1000);
ok($voter && $author, 'Got voter + author users');

# Fresh writeup to vote on.
my $title = 'Vote Revotetime Test ' . time();
my $e2node_id  = $DB->insertNode($title, 'e2node', $author, { title => $title });
my $writeup_id = $DB->insertNode($title, 'writeup', $author,
    { parent_e2node => $e2node_id, doctext => 'revotetime test' });
ok($writeup_id, 'Created test writeup');
my $writeup = $DB->getNodeById($writeup_id, 'force');

# Belt-and-suspenders: no stale vote from a previous run.
$DB->sqlDelete('vote', "vote_id=$writeup_id");

#############################################################################
# 1. Schema defaults: a bare insert (no votetime/revotetime supplied) must
#    yield a real votetime and a NULL revotetime — not a zero-date. This is
#    the direct test of the #4078 column-default change.
#############################################################################
{
    $DB->sqlInsert('vote',
        { vote_id => $writeup_id, voter_user => $voter->{node_id}, weight => 0 });
    my $row = $DB->sqlSelectHashref('*', 'vote',
        "vote_id=$writeup_id AND voter_user=$voter->{node_id}");

    ok(!defined $row->{revotetime},
        'bare insert: revotetime defaults to NULL (not a zero-date)');
    ok(defined $row->{votetime} && $row->{votetime} !~ /^0000-00-00/,
        'bare insert: votetime defaults to a real timestamp (CURRENT_TIMESTAMP)');
    like($row->{votetime}, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/,
        'bare insert: votetime is a well-formed datetime');

    $DB->sqlDelete('vote', "vote_id=$writeup_id AND voter_user=$voter->{node_id}");
}

#############################################################################
# 2. The app path: insertVote() sets votetime=now() and leaves revotetime
#    unset → NULL. Mirrors how every real vote is created.
#############################################################################
{
    my $ret = $APP->insertVote($writeup, $voter, 1);
    ok($ret, 'insertVote succeeded');

    my $row = $DB->sqlSelectHashref('*', 'vote',
        "vote_id=$writeup_id AND voter_user=$voter->{node_id}");

    ok(!defined $row->{revotetime},
        'insertVote: revotetime is NULL on a fresh (never-revoted) vote (#4078)');
    ok(defined $row->{votetime} && $row->{votetime} !~ /^0000-00-00/,
        'insertVote: votetime is set to now()');
}

#############################################################################
# 3. The read contract: API/reputation.pm uses
#       if ($row->{revotetime} && $row->{revotetime} gt $votetime) { ... }
#    A NULL revotetime must be ignored (falsy), so the effective time is the
#    votetime. This guards the reader against the NULL default.
#############################################################################
{
    my $row = $DB->sqlSelectHashref('*', 'vote',
        "vote_id=$writeup_id AND voter_user=$voter->{node_id}");
    my $votetime = $row->{votetime};

    # Verbatim mirror of the reputation.pm:119 expression.
    my $effective =
        ($row->{revotetime} && $row->{revotetime} gt $votetime)
        ? $row->{revotetime}
        : $votetime;

    is($effective, $votetime,
        'NULL revotetime is ignored by the reputation read; votetime is used');
}

#############################################################################
# 4. A revote writes a real revotetime (the only path that sets it).
#############################################################################
{
    $DB->sqlUpdate('vote',
        { -weight => -1, -revotetime => 'NOW()' },
        "vote_id=$writeup_id AND voter_user=$voter->{node_id}");
    my $row = $DB->sqlSelectHashref('*', 'vote',
        "vote_id=$writeup_id AND voter_user=$voter->{node_id}");

    ok(defined $row->{revotetime} && $row->{revotetime} !~ /^0000-00-00/,
        'revote sets a real revotetime');
}

# Cleanup
$DB->sqlDelete('vote', "vote_id=$writeup_id");
$DB->nukeNode($DB->getNodeById($writeup_id, 'force'), -1) if $DB->getNodeById($writeup_id, 'force');
$DB->nukeNode($DB->getNodeById($e2node_id, 'force'), -1)  if $DB->getNodeById($e2node_id, 'force');

TestSeed::cleanup($DB);

done_testing();
