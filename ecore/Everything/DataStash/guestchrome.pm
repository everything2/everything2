package Everything::DataStash::guestchrome;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

use Everything::Request;
use Everything::PageState;

# Caches the guest "chrome" -- the per-session, page-independent half of the
# page-state blob (nodelets, identity, feeds) that is IDENTICAL for every guest
# on every page (see Everything::PageState chrome/content partition). Guests are
# the bulk of crawler/bot traffic, and rebuilding this blob per request is the
# largest slice of guest render CPU; caching it lets the guest render path
# (a separate, later change) serve the chrome from here and build only the
# per-node content fresh.
#
# Refresh ~every minute so the cached feeds inside the chrome (New Writeups,
# Random Nodes, etc.) don't go more than a minute stale.
has '+interval' => ( default => 60 );

# Heavy build (it runs buildNodeInfoStructure), so route this to the dedicated
# datastash-lengthy cron tick rather than the ~120s general tick, where a slow
# run could pressure request latency / hold the cron lock.
has '+lengthy' => ( default => 1 );

sub generate
{
    my ($this) = @_;

    # buildNodeInfoStructure is built to run outside a live request: when handed
    # an undef $REQUEST it self-builds a minimal Everything::Request. We give it
    # a synthetic guest request (no $query/$REQUEST exists in cron context) and
    # keep only the chrome half of the resulting blob.
    my $chrome = eval {
        my $db    = $this->DB;
        my $guest = $db->getNode( 'Guest User', 'user' )
          or die "Guest User not found\n";

        my $guest_node = $this->APP->node_by_id( $guest->{node_id} );
        my $vars       = $this->APP->getVars($guest);

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
        # Never clobber a good stash on a transient build failure -- log and
        # keep the last value. (Latent today: nothing consumes guestchrome yet.)
        $this->APP->devLog("guestchrome generate failed: $err");
        return;
    }

    return $this->SUPER::generate($chrome);
}

__PACKAGE__->meta->make_immutable;
1;
