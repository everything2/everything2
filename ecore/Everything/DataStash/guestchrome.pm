package Everything::DataStash::guestchrome;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

use Everything::Request;
use Everything::PageState;

# Caches the guest "chrome" -- the per-session, page-independent half of the page-state
# blob (nodelets, identity, feeds) that is IDENTICAL for every guest on every page (see
# Everything::PageState chrome/content partition). Guests are the bulk of crawler/bot
# traffic, and rebuilding this blob per request is the largest slice of guest render CPU;
# caching it lets the guest render path serve the chrome from here and build only the
# per-node content fresh.
#
# Refreshed by the regular ~2-min datastash tick (NOT lengthy -- the build is one
# synthetic-guest render, cheap against that tick's 600s timeout), so the embedded feeds
# (New Writeups, Random Nodes) stay ~2 min fresh. (#4369)
has '+interval' => ( default => 60 );

# BUILD-KEYED CACHE (#4369). The stash is { $buildid => $chrome }, where $buildid is the
# git last_commit the chrome was generated under. A consumer only uses the entry when the
# cached build == the running build, so after a deploy we never serve stale-asset chrome --
# the entry simply misses until the next tick (or the first guest request, via
# current_or_build) rebuilds it under the new build id. This is what makes a 2-min refresh
# safe across deploys.

# The build identifier the chrome is keyed under (git commit of the running code).
sub _buildid {
    my ($this) = @_;
    return $this->APP->{conf}->last_commit;
}

# Build the guest chrome from a synthetic guest (no live request). Returns the chrome
# hashref, or undef on any build error (logged) so we never clobber a good stash.
sub _build_chrome {
    my ($this) = @_;

    my $chrome = eval {
        my $db    = $this->DB;
        my $guest = $db->getNode( 'Guest User', 'user' )
          or die "Guest User not found\n";

        my $guest_node = $this->APP->node_by_id( $guest->{node_id} );
        my $vars       = $this->APP->getVars($guest);

        # buildNodeInfoStructure self-builds a minimal Everything::Request from the synthetic
        # guest when there's no live $REQUEST (cron context). Keep only the chrome half.
        my $request = Everything::Request->new(
            user => $guest_node,
            node => $guest_node,
        );
        my $query = $request->cgi;

        my $e2 = $this->APP->buildNodeInfoStructure(
            $guest, $guest, $vars, $query, $request );

        Everything::PageState->from_blob($e2)->{chrome};
    };

    if ( my $err = $@ ) {
        $this->APP->devLog("guestchrome build failed: $err");
        return;    # scalar caller -> undef -> generate() keeps the last stash
    }
    return $chrome;
}

# Cron path: build the chrome and stash it keyed by the current build id.
sub generate {
    my ($this) = @_;

    my $chrome = $this->_build_chrome;
    return unless defined $chrome;    # build failed (already logged) -- keep the last value

    return $this->SUPER::generate( { $this->_buildid => $chrome } );
}

# The cached chrome IFF it was generated under the currently-running build; else undef
# (cold start, or a stale entry from a previous deploy).
sub current_chrome {
    my ($this) = @_;
    return $this->current_data->{ $this->_buildid };
}

# Consumer accessor: the current guest chrome, building + stashing it INLINE on a cache
# miss (cold start / first guest after a deploy) so subsequent guests hit a warm cache
# instead of every one rebuilding until the next cron tick (#4369). Returns undef only if
# the inline build also failed, in which case the caller falls back to a normal full render.
sub current_or_build {
    my ($this) = @_;

    my $chrome = $this->current_chrome;
    return $chrome if $chrome;

    $this->generate;                  # build + stash { buildid => chrome }
    return $this->current_chrome;     # the freshly-stashed value (undef if the build errored)
}

__PACKAGE__->meta->make_immutable;
1;
