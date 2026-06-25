#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 162_final_htmlcode_migration.t
#
# Covers the final htmlcode tranche migrated into Everything::Application (#4358):
#   * screen_notelet  (was the screenNotelet htmlcode)
#   * atomise_node    (was atomiseNode)
#   * user_atom_feed  (was userAtomFeed)
# addNotification was a pass-through to the existing add_notification; urlToNode
# was dead. After this the Delegation::htmlcode module holds no subs.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use TestSeed;

initEverything('development-docker');
ok($DB,  'DB connection');
ok($APP, 'APP object');

my $root = $DB->getNode('root', 'user');

#############################################################################
# screen_notelet: length-limits by level, strips comments + <script>, writes
# $vars->{noteletScreened} (or clears it when empty). Mutates $vars in place.
#############################################################################
{
    my $u = TestSeed::make_user($DB, $APP, label => 'notelet');

    my $vars = { noteletRaw => '<b>keep me</b><script>evil()</script><!-- secret -->' };
    $APP->screen_notelet($u, $vars);
    ok($vars->{noteletScreened}, 'screen_notelet sets noteletScreened');
    unlike($vars->{noteletScreened}, qr/<script/i, 'strips <script> tags');
    unlike($vars->{noteletScreened}, qr/secret/,    'strips HTML comments');
    like($vars->{noteletScreened},   qr/keep me/,   'keeps allowed content');

    # length cap (a low-level user caps at 500)
    my $big = { noteletRaw => ('a' x 600) };
    $APP->screen_notelet($u, $big);
    is(length($big->{noteletScreened}), 500, 'length capped to 500 for a base-level user');

    # empty input clears noteletScreened
    my $empty = { noteletRaw => '' };
    $APP->screen_notelet($u, $empty);
    ok(!exists $empty->{noteletScreened}, 'empty raw clears noteletScreened');
}

#############################################################################
# atomise_node + user_atom_feed: Atom <entry>/<feed> rendering for the feeds.
#############################################################################
{
    my $author = TestSeed::make_user($DB, $APP, label => 'atomauth');
    my $ts = time();

    my $e2node_id = $DB->insertNode("Atom Target $ts", 'e2node', $root, { title => "Atom Target $ts" });
    my $wtype  = $DB->getNode('idea', 'writeuptype');
    my $wu_id  = $DB->insertNode("Atom Target $ts (idea)", 'writeup', $author, {
        parent_e2node      => $e2node_id,
        doctext            => 'Hello [world] from the atom test.',
        wrtype_writeuptype => $wtype->{node_id},
    });
    ok($wu_id, 'created a test writeup');
    $DB->sqlUpdate('writeup', { publishtime => '2021-05-05 12:00:00' }, "writeup_id=$wu_id");

    my $entry = $APP->atomise_node($wu_id);
    like($entry, qr/<entry>/,                'atomise_node emits <entry>');
    like($entry, qr/<title>/,                'has <title>');
    like($entry, qr{<content type="html">},  'has <content>');
    like($APP->atomise_node([$wu_id]), qr/<entry>/, 'accepts an arrayref of ids');

    my $feed = $APP->user_atom_feed($author->{title});
    like($feed, qr/<feed/,    'user_atom_feed emits <feed>');
    like($feed, qr/<entry>/,  'feed contains an <entry>');
    like($feed, qr/<updated>2021-05-05T12:00:00Z/, 'feed <updated> derives from publishtime');

    my $noatoms = TestSeed::make_user($DB, $APP, label => 'noatoms');
    is($APP->user_atom_feed($noatoms->{title}), undef, 'a user with no writeups yields an undef feed');

    # cleanup
    $DB->nukeNode($DB->getNodeById($wu_id, 'force'), -1, 1)     if $DB->getNodeById($wu_id, 'force');
    $DB->nukeNode($DB->getNodeById($e2node_id, 'force'), -1, 1) if $DB->getNodeById($e2node_id, 'force');
}

#############################################################################
# The htmlcode delegation module now holds no subs (the migration endpoint).
#############################################################################
ok(!Everything::Delegation::htmlcode->can($_), "htmlcode '$_' retired")
    for qw(screenNotelet atomiseNode userAtomFeed addNotification urlToNode);

TestSeed::cleanup($DB);

done_testing();
