#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON::PP;
use Everything;
use Everything::Request;
use Everything::PageState;
use Everything::DataStash::guestchrome;

# Guest nodeinfo hydration (#4371): for a guest on a non-React node, buildNodeInfoStructure
# serves the node-independent chrome from the build-keyed guestchrome cache + builds only the
# per-node content. React-document types fall back to the full build.
#
# NOTE on verification: the cached chrome carries feeds (staffpicks/coolnodes) that are
# ORDER BY rand() + cron-regenerated, so they intentionally differ from a fresh build across
# a regeneration. So we assert CONTENT against a fresh build (deterministic) and CHROME
# against the cache snapshot (what hydration actually serves) -- not a fresh full build.

initEverything("development-docker");
my $j = JSON::PP->new->canonical->allow_nonref;

my $guest = $DB->getNode( 'Guest User', 'user' );
my $gvars = Everything::getVars($guest);

my $gc = Everything::DataStash::guestchrome->new(
    APP => $APP, CONF => $APP->{conf}, DB => $DB );

# Populating the cache exercises the RECURSION GUARD: generate() -> _build_chrome ->
# buildNodeInfoStructure(skip_guest_cache) must NOT loop back through current_or_build.
$gc->generate;
my $cache = $gc->current_chrome;
ok( $cache, 'guestchrome cache present for current build (recursion guard held)' );

for my $spec ( [ 'tomato', 'e2node' ], [ 'Content Editors', 'usergroup' ], [ 'root', 'user' ] ) {
    my ( $title, $type ) = @$spec;
    my $NODE = $DB->getNode( $title, $type );
    next unless $NODE;
    my $req = Everything::Request->new(
        user => $APP->node_by_id( $guest->{node_id} ),
        node => $APP->node_by_id( $NODE->{node_id} ) );

    my $full = $APP->buildNodeInfoStructure( $NODE, $guest, $gvars, $req->cgi, $req, { skip_guest_cache => 1 } );
    my $hyd  = $APP->buildNodeInfoStructure( $NODE, $guest, $gvars, $req->cgi, $req );

    # CONTENT (per-node) -- must match a fresh full build exactly (deterministic).
    for my $k (qw(node_id title nodetype node)) {
        is( $j->encode( $hyd->{$k} ), $j->encode( $full->{$k} ), "$type: content '$k' matches fresh build" );
    }

    # CHROME -- served verbatim from the cache snapshot (not a fresh build, since feeds rotate).
    my %hyd_chrome = map { $_ => $hyd->{$_} } keys %$cache;
    is( $j->encode( \%hyd_chrome ), $j->encode($cache), "$type: chrome served verbatim from the cache" );

    # Nothing leaks unclassified (the coolnodes/staffpicks manifest fix).
    is_deeply( Everything::PageState->unclassified_keys($hyd), [], "$type: hydrated blob fully classified" );
}

# React-document type (superdoc) must fall back to the full build -- its content + page-dependent
# chrome (notificationsData/etc.) are rendered fresh and cannot come from the node-independent cache.
my $sd = $DB->getNode( 'Cool Archive', 'superdoc' );
if ($sd) {
    my $req = Everything::Request->new(
        user => $APP->node_by_id( $guest->{node_id} ),
        node => $APP->node_by_id( $sd->{node_id} ) );
    my $blob = $APP->buildNodeInfoStructure( $sd, $guest, $gvars, $req->cgi, $req );
    ok( defined $blob->{contentData}, 'React-type (superdoc) renders contentData fresh -- fast-path skipped' );
}

# Chatterbox room build is skipped for guests (#4419). The Guest User node has
# in_room=0 (defined), which used to drag every guest render through Room Topics +
# a getRecentChatter query + mini-message loads. Guests have no chatterbox nodelet
# and can't chat; the catbox-archive bot reads chatter via the universal message
# ticker, not this chrome key. Guests keep only the minimal borged/numborged.
{
    my $NODE = $DB->getNode( 'tomato', 'e2node' ) || $DB->getNode( 'Guest User', 'user' );
    my $req = Everything::Request->new(
        user => $APP->node_by_id( $guest->{node_id} ),
        node => $APP->node_by_id( $NODE->{node_id} ) );
    my $blob = $APP->buildNodeInfoStructure( $NODE, $guest, $gvars, $req->cgi, $req, { skip_guest_cache => 1 } );

    ok( defined $blob->{chatterbox}, 'guest still gets a (minimal) chatterbox chrome key' );
    ok( !exists $blob->{chatterbox}{messages},
        'guest chatterbox carries NO messages (getRecentChatter skipped)' );
    ok( !exists $blob->{chatterbox}{roomTopic},
        'guest chatterbox carries NO roomTopic (Room Topics setting not loaded)' );
}

done_testing();

=head1 NAME

t/166_guest_nodeinfo_hydrate.t - guest chrome hydration from the guestchrome cache (#4371)

=cut
