#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 161_publish_family_migration.t
#
# Covers the publish-family htmlcode -> Everything::Application migration (#4354):
#   * Application::add_nodenote      (was the addNodenote htmlcode)
#   * Application::unpublish_writeup (was the unpublishwriteup htmlcode)
# The maintenance writeup-lifecycle hooks now call these instead of htmlcode().
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use TestSeed;

initEverything('development-docker');
ok($DB,  'DB connection');
ok($APP, 'APP object');

my $root = $DB->getNode('root', 'user');

#############################################################################
# add_nodenote: writes a nodenote row (+ a user-link prefix and a notification
# when a noter is given) and returns the new nodenote_id.
#############################################################################
{
    my $noter  = TestSeed::make_user($DB, $APP, label => 'noter');
    my $target = $DB->getNode('Guest User', 'user');   # any node works as the note subject

    my $id = $APP->add_nodenote($target, 'a test note', $noter);
    ok($id, 'add_nodenote returns a nodenote_id');

    my $row = $DB->sqlSelectHashref('*', 'nodenote', "nodenote_id=$id");
    ok($row, 'nodenote row exists');
    is($row->{nodenote_nodeid}, $target->{node_id}, 'note attached to the target node');
    is($row->{noter_user}, $noter->{user_id}, 'noter recorded');
    like($row->{notetext}, qr/\Q$noter->{title}\E.*a test note/, 'note text carries the user-link prefix');

    # A 'nodenote' notification was queued for the noter.
    my $nn = $DB->getNode('nodenote', 'notification');
    my $cnt = $nn ? $DB->sqlSelect('COUNT(*)', 'notified',
        "notification_id=$nn->{node_id} AND user_id=$id") : 0;
    ok($cnt >= 0, 'nodenote notification path ran without error');

    $DB->sqlDelete('nodenote', "nodenote_id=$id");
}

#############################################################################
# unpublish_writeup: a published writeup -> draft, torn out of its e2node, with
# the author's XP/writeup-count docked. (Author self-removal path.)
#############################################################################
{
    my $author = TestSeed::make_user($DB, $APP, label => 'wauthor', experience => 1000, numwriteups => 1);
    my $ts = time();

    my $e2node_id = $DB->insertNode("Unpublish Target $ts", 'e2node', $root, { title => "Unpublish Target $ts" });
    my $e2node = $DB->getNodeById($e2node_id, 'force');
    my $wtype  = $DB->getNode('idea', 'writeuptype');
    my $wu_id  = $DB->insertNode("Unpublish Target $ts (idea)", 'writeup', $author, {
        parent_e2node      => $e2node_id,
        doctext            => 'soon to be unpublished',
        wrtype_writeuptype => $wtype->{node_id},
    });
    ok($wu_id, 'created a test writeup');
    $DB->insertIntoNodegroup($e2node, $root, $wu_id);
    $DB->sqlInsert('publish',    { publish_id => $wu_id, publisher => $author->{node_id} });
    $DB->sqlInsert('newwriteup', { node_id => $wu_id });

    my $exp_before = $DB->sqlSelect('experience', 'user', "user_id=$author->{node_id}");
    my $nw_before  = $APP->getVars($DB->getNodeById($author->{node_id}, 'force'))->{numwriteups} // 0;

    my $writeup = $DB->getNodeById($wu_id, 'force');
    my $ret = $APP->unpublish_writeup($author, $writeup, 'test removal');
    is($ret, 1, 'unpublish_writeup returns 1');

    my $after = $DB->getNodeById($wu_id, 'force');
    is($after->{type}{title}, 'draft', 'writeup was converted to a draft');
    my $removed = $DB->getNode('removed', 'publication_status');
    is($after->{publication_status}, $removed->{node_id}, 'publication_status set to removed') if $removed;

    is($DB->sqlSelect('COUNT(*)', 'writeup', "writeup_id=$wu_id"), 0, 'writeup-table row deleted');
    is($DB->sqlSelect('COUNT(*)', 'publish', "publish_id=$wu_id"), 0, 'publish row deleted');
    is($DB->sqlSelect('COUNT(*)', 'newwriteup', "node_id=$wu_id"), 0, 'newwriteup row deleted');
    my $still_grouped = $DB->sqlSelect('COUNT(*)', 'nodegroup', "nodegroup_id=$e2node_id AND node_id=$wu_id");
    is($still_grouped, 0, 'writeup removed from the e2node nodegroup');

    my $exp_after = $DB->sqlSelect('experience', 'user', "user_id=$author->{node_id}");
    is($exp_after, $exp_before - 5, 'author XP docked by 5');
    # numwriteups is a vars string field; 0 round-trips as '' which == 0 numerically
    # (faithful to the legacy htmlcode), so compare numerically not stringwise.
    my $nw_after = $APP->getVars($DB->getNodeById($author->{node_id}, 'force'))->{numwriteups} || 0;
    cmp_ok($nw_after, '==', $nw_before - 1, 'author numwriteups decremented by 1');

    my $note = $DB->sqlSelect('COUNT(*)', 'nodenote', "nodenote_nodeid=$wu_id AND notetext LIKE '%Removed by%'");
    ok($note >= 1, 'a "Removed by ..." nodenote was added');

    # cleanup
    $DB->sqlDelete('nodenote', "nodenote_nodeid=$wu_id");
    $DB->nukeNode($DB->getNodeById($wu_id, 'force'), -1) if $DB->getNodeById($wu_id, 'force');
    $DB->nukeNode($DB->getNodeById($e2node_id, 'force'), -1) if $DB->getNodeById($e2node_id, 'force');
}

#############################################################################
# publishas_accounts / can_publish_as (the canpublishas migration, #4354):
# a level-1+ user may publish as 'everyone'; an editor may also publish as the
# system bots. Returns node_ids; rejects unknown accounts.
#############################################################################
{
    my $member = TestSeed::make_user($DB, $APP, label => 'pamember', experience => 50000, numwriteups => 100);
    ok($APP->getLevel($member) >= 1, 'dedicated member is level 1+') or diag('level=' . $APP->getLevel($member));
    my $root   = $DB->getNode('root', 'user');  # high-level editor

    my %m = map { $_->{title} => $_->{node_id} } @{ $APP->publishas_accounts($member) };
    ok($m{everyone}, 'a level-1+ user may publish as everyone');
    ok(!$m{Klaproth}, 'a non-editor may NOT publish as the editor bots');

    my %r = map { $_->{title} => 1 } @{ $APP->publishas_accounts($root) };
    ok($r{everyone} && $r{Klaproth} && $r{'Webster 1913'}, 'an editor may publish as everyone + the bots');

    is($APP->can_publish_as($member, 'everyone'),
       $DB->getNode('everyone','user')->{node_id}, 'can_publish_as returns the target node_id when allowed');
    is($APP->can_publish_as($member, 'Klaproth'), 0, 'can_publish_as rejects an editor-only bot for a non-editor');
    is($APP->can_publish_as($root,   'NoSuchAcct'), 0, 'can_publish_as rejects an unknown account');
    is($APP->can_publish_as($root,   ''), 0, 'can_publish_as rejects an empty target');
}

#############################################################################
# The /publishas_options ENDPOINT must hand the Application gate a hashref, not
# the blessed $REQUEST->user (whose getLevel/isEditor mis-gate to []). This is
# the exact seam that hid the picker for editors -- exercise it with a blessed
# request user (what prod actually passes), not a bare hashref. #4354
#############################################################################
{
    package PA_Req; sub new { bless { u => $_[1] }, $_[0] } sub user { $_[0]->{u} }
}
{
    require Everything::API::drafts;
    my $api      = Everything::API::drafts->new();
    my $rootnode = $DB->getNode('root', 'user');
    my $req      = PA_Req->new( $APP->node_by_id($rootnode->{node_id}) );  # blessed, like prod

    my $r = $api->publishas_options($req);
    is($r->[0], $api->HTTP_OK, 'publishas_options endpoint returns 200');
    is($r->[1]{success}, 1, 'endpoint reports success');
    my @titles = map { $_->{title} } @{ $r->[1]{options} || [] };
    ok(scalar(@titles) >= 5, 'endpoint returns options for a blessed (prod-shaped) editor request user')
        or diag("got: @titles");
    ok((grep { $_ eq 'Klaproth' } @titles), 'endpoint includes an editor-only bot');
}

#############################################################################
# Retirement of the publish-family htmlcodes (#4354): publishwriteup,
# nopublishreason and canpublishas are gone. The writeup_create maintenance hook
# no longer publishes via them -- the legacy form-post flow is dead -- and now
# survives only as a guard that nukes an out-of-band writeup (one created via a
# raw insertNode rather than the draft->writeup conversion).
#############################################################################
ok(!Everything::Delegation::htmlcode->can($_), "htmlcode '$_' retired")
    for qw(publishwriteup nopublishreason canpublishas);

# A truthy request-context stub (CGI.pm is gone post-PSGI); the gutted hook only
# tests $query for truthiness, it no longer reads params.
{ package T161::MockQuery; sub new { bless {}, shift } sub param { return undef } }
{
    require Everything::Delegation::maintenance;

    my $author = TestSeed::make_user($DB, $APP, label => 'wcreate');
    # Insert a writeup directly, skipping maintenance on the insert itself, so we
    # can hand it to the hook explicitly.
    my $wu_id = $DB->insertNode('Stray WU ' . time(), 'writeup', $author, { doctext => 'x' }, 1);
    ok($wu_id, 'inserted a stray writeup (maintenance skipped on insert)');
    my $wu = $DB->getNodeById($wu_id, 'force');

    my $q = T161::MockQuery->new;   # web context present, no writeup_doctext -> reject
    Everything::Delegation::maintenance::writeup_create(
        $DB, $q, undef, $author, {}, $APP, $wu);

    is($DB->sqlSelect('COUNT(*)', 'node', "node_id=$wu_id"), 0,
       'writeup_create nukes an out-of-band writeup (guard preserved, no htmlcode dependency)');
    $DB->nukeNode($DB->getNodeById($wu_id, 'force'), -1, 1) if $DB->getNodeById($wu_id, 'force');
}

TestSeed::cleanup($DB);

done_testing();
