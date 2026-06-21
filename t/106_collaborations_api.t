#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use POSIX qw(strftime);
use Everything;
use Everything::API::collaborations;
use MockRequest;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $APP->{db};
my $api = Everything::API::collaborations->new();

ok($DB,  'Database connection established');
ok($api, 'Created collaborations API instance');

# --- _is_lock_expired NULL semantics (#4085) -----------------------------
# locktime is nullable now: NULL = "not locked". The old unset-sentinel
# '0000-00-00 00:00:00' is gone, so undef must read as expired/no-lock.
{
    ok($api->_is_lock_expired(undef), 'undef (NULL) locktime reads as no lock / expired');
    ok($api->_is_lock_expired('1999-01-01 00:00:00'), 'an old locktime is expired');

    my $fresh = strftime('%Y-%m-%d %H:%M:%S', localtime(time()));
    ok(!$api->_is_lock_expired($fresh), 'a just-now locktime is an active lock');
}

# --- Unlock writes NULL, not the zero-date (the strict-mode breaker) ------
{
    my $collab_type = $DB->getType('collaboration');
    my $root = $DB->getNode('root', 'user');
    my $other = $DB->getNode('normaluser1', 'user');

    my $collab_id = $DB->insertNode('Locktime Test Collab ' . time(),
        $collab_type, $root, {});
    ok($collab_id, 'created a collaboration node');

    # Simulate a live lock held by someone else: recent locktime + their id.
    my $now = strftime('%Y-%m-%d %H:%M:%S', localtime(time()));
    $DB->sqlUpdate('collaboration',
        { locktime => $now, lockedby_user => $other->{node_id} },
        "collaboration_id=$collab_id");
    $DB->getCache->removeNode($DB->getNodeById($collab_id, 'force'));

    # Sanity: it really is locked in the DB before we unlock.
    my $before = $DB->sqlSelectHashref('locktime, lockedby_user',
        'collaboration', "collaboration_id=$collab_id");
    ok($before->{locktime} && $before->{locktime} ne '0000-00-00 00:00:00',
        'collaboration is locked before unlock');
    is($before->{lockedby_user}, $other->{node_id}, 'locked by the other user');

    # Admin (root) unlocks someone else's lock.
    my $request = MockRequest->new(
        node_id       => $root->{node_id},
        title         => 'root',
        nodedata      => $root,
        is_admin_flag => 1,
        is_editor_flag=> 1,
        is_guest_flag => 0,
    );

    my ($status, $resp) = @{ $api->unlock($request, $collab_id) };
    is($status, $api->HTTP_OK, 'unlock returns HTTP_OK');
    ok($resp->{success}, 'unlock reports success');

    # The payoff: locktime is a real SQL NULL now, not '0000-00-00 00:00:00'.
    my $after = $DB->sqlSelectHashref('locktime, lockedby_user',
        'collaboration', "collaboration_id=$collab_id");
    ok(!defined($after->{locktime}),
        'locktime is NULL after unlock (not a zero-date) (#4085)');
    is($after->{lockedby_user}, 0, 'lockedby_user cleared to 0');

    # Cleanup.
    $DB->sqlDelete('collaboration', "collaboration_id=$collab_id");
    $DB->nukeNode($DB->getNodeById($collab_id, 'force'), -1);
}

# --- delete action: op=nuke -> POST /api/collaborations/:id/action/delete (#4335 Phase 2) ---
{
    my $collab_type = $DB->getType('collaboration');
    my $root  = $DB->getNode('root', 'user');
    my $plain = $DB->getNode('normaluser1', 'user');

    my $admin_req = MockRequest->new(
        node_id => $root->{node_id}, title => 'root', nodedata => $root,
        is_admin_flag => 1, is_guest_flag => 0,
    );

    # Guest is blocked (the unauthorized_if_guest guard)
    my $guest_req = MockRequest->new(nodedata => {}, is_guest_flag => 1);
    is($api->delete($guest_req, 1)->[0], $api->HTTP_UNAUTHORIZED,
        'guest cannot delete a collaboration');

    # Non-author, non-admin is forbidden (can_delete_node, same as the generic node API)
    my $cid = $DB->insertNode('Delete Test Collab ' . time(), $collab_type, $root, {});
    ok($cid, 'created a collaboration to delete');
    my $plain_req = MockRequest->new(
        node_id => $plain->{node_id}, title => 'normaluser1', nodedata => $plain,
        is_admin_flag => 0, is_guest_flag => 0,
    );
    is($api->delete($plain_req, $cid)->[0], $api->HTTP_FORBIDDEN,
        'non-author non-admin cannot delete');
    ok($DB->getNodeById($cid, 'force'), 'collaboration survives the forbidden delete');

    # prevent_nuke blocks deletion even for an admin (own node so the param can't
    # interfere with the happy-path delete below)
    my $pcid = $DB->insertNode('Prevent Nuke Collab ' . time(), $collab_type, $root, {});
    $APP->setParameter($pcid, $root, 'prevent_nuke', 1);
    my ($pns, $pnresp) = @{ $api->delete($admin_req, $pcid) };
    is($pns, $api->HTTP_OK, 'prevent_nuke delete returns HTTP_OK');
    ok(!$pnresp->{success}, 'prevent_nuke blocks the deletion');
    ok($DB->getNodeById($pcid, 'force'), 'collaboration survives the prevent_nuke delete');
    $DB->nukeNode($DB->getNodeById($pcid, 'force'), -1);  # cleanup

    # Admin deletes successfully (happy path) -- a fresh node with no prevent_nuke
    my ($as, $aresp) = @{ $api->delete($admin_req, $cid) };
    is($as, $api->HTTP_OK, 'admin delete returns HTTP_OK');
    ok($aresp->{success}, 'admin delete reports success');
    is($aresp->{deleted}, $cid, 'deleted node id is returned');
    ok(!$DB->getNodeById($cid, 'force'), 'collaboration node is gone after delete');
}

done_testing();
