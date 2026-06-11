package Everything::API::pagestate;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use Everything::PageState;
use URI::Escape qw(uri_unescape);

=head1 Everything::API::pagestate

The full page payload the React app boots from: chrome (nodelets, identity, prefs, feeds) +
the node's content (contentData) + the rendering key (contentData.type, which React's
DocumentComponent maps to a view). The e2 blob, delivered as an API resource instead of
inlined into every pageload. Ways to address the node:

  GET /api/pagestate[?node_id=N]               -- by node_id
  GET /api/pagestate?title=T[&type=X]          -- by title; type defaults to e2node
  GET /api/pagestate/lookup/:type/:title       -- by (type, title), path form
  GET /api/pagestate                           -- the site default node

The URL-pattern resolution lives in React's client router -- it parses the legacy
node-router / Apache forms (/title/X, /node/:type/:title, /user/X, /user/X/writeups/Y, /s/X,
...) inline and reduces each to one of the above: a node_id, or a type/title (defaulting to
e2node when no type is implied). This API only needs id or type/title. Everything accepts
?displaytype= (display | edit | editvars | replyto | useredit | ...).

Step 2a of the API-driven architecture (docs/pagestate-design.md): a FACADE. It builds the
existing e2 blob via Everything::Application::buildNodeInfoStructure, type-normalizes it
(Everything::PageState->normalize_types), and returns it. No assembly logic has moved yet
-- 2b migrates each key's assembly into PageState. The chrome/content partition
(from_blob) is retained for the future cache + ?lite= subset, not as the endpoint boundary.

Caveats (facade-only, resolved in 2b):
  * It builds the FULL blob (content included) and discards the content half -- wasted
    work, and it runs buildNodeInfoStructure's content-side effects (e.g. the nodetrail
    bump). Latent today (no consumer yet); 2b separates chrome assembly from those.
  * A couple of "chrome" keys are still node-derived (masterControl actions,
    quickRefSearchTerm). They reflect the context node; empty/irrelevant for guests.

=cut

sub routes {
    return {
        "/"                   => "get",
        "lookup/:type/:title" => "get_by_name(:type, :title)",
    };
}

# By ?node_id, or ?title (+ optional ?type, defaulting to e2node -- the common title-URL
# case); no params -> the site default node. React's router resolves every other URL form
# and supplies an explicit type when it isn't e2node.
sub get {
    my ( $self, $REQUEST ) = @_;

    my $node;
    my $node_id = $REQUEST->param('node_id');
    my $title   = $REQUEST->param('title');

    if ( defined $node_id && $node_id =~ /\A\d+\z/ ) {
        $node = $self->APP->node_by_id($node_id);
    }
    elsif ( defined $title && length $title ) {
        $node = $self->APP->node_by_name( $title, $REQUEST->param('type') || 'e2node' );
    }
    else {
        $node = $self->APP->node_by_id( $self->CONF->default_node );
    }

    return [ $self->HTTP_OK, { success => 0, error => 'node not found' } ]
        unless $node;

    return $self->_render_pagestate( $node, $REQUEST );
}

# By (type, title) -- React-owned routing navigates by title-based URL, not node_id.
# Mirrors Everything::API::nodes::get_by_name. type/title are URL-encoded path segments.
sub get_by_name {
    my ( $self, $REQUEST, $type, $title ) = @_;

    $type  = uri_unescape($type);
    $title = uri_unescape($title);

    # Guard the ecore ISE on a non-existent nodetype (same workaround as API::nodes).
    return [ $self->HTTP_OK, { success => 0, error => "unknown type '$type'" } ]
        unless $self->APP->node_by_name( $type, 'nodetype' );

    my $node = $self->APP->node_by_name( $title, $type );
    return [ $self->HTTP_OK, { success => 0, error => "node not found: $type/$title" } ]
        unless $node;

    return $self->_render_pagestate( $node, $REQUEST );
}

# Drive the REAL render path so the facade output is identical to the inline page for EVERY
# node type. The node's controller builds the full e2 blob (chrome + its own contentData +
# the rendering key contentData.type), and Everything::Controller::layout normalizes +
# stashes it on the request (pagestate_e2). The rendered HTML is printed into the STDOUT
# capture, which app.psgi DISCARDS for the return-based API path -- we want only the blob.
# This is what lets the facade serve controller-class nodes (user/e2node/category/*_edit),
# not just superdoc Page-class views. ?displaytype= selects the view. #4255.
#
# (Facade caveat: route_node renders the whole page to harvest the blob -- wasteful, and it
# runs the page-view side effects. Step 3 -- controllers RETURN their content -- replaces
# this with a direct call. See docs/api-driven-architecture.md.)
sub _render_pagestate {
    my ( $self, $node, $REQUEST ) = @_;

    $REQUEST->node($node);
    my $displaytype = $REQUEST->param('displaytype') || 'display';

    $REQUEST->pagestate_e2(undef);
    eval { $Everything::ROUTER->route_node( $node->NODEDATA, $displaytype, $REQUEST ); 1 }
        or $self->devLog( "pagestate route_node failed for node " . $node->node_id . " ($displaytype): " . ( $@ || 'unknown' ) );

    my $e2 = $REQUEST->pagestate_e2;
    if ( ref $e2 eq 'HASH' && %$e2 ) {
        # Build + merge the <head> metadata here (not in the inline blob) so the API ships it
        # without duplicating the JSON-LD bytes -- or paying for ->as_hashref -- on every
        # server pageload. layout() stashed the producer; we compute it now. See layout().
        my $pm = $REQUEST->pagestate_meta;
        $e2->{meta} = $pm->as_hashref if $pm;
        return [ $self->HTTP_OK, $e2 ];
    }

    # Fallback: the node didn't render through Controller::layout (e.g. a non-React view).
    # Build the blob directly -- already normalized at the source (buildNodeInfoStructure).
    my $e2b = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST,
    );

    # ?lite= -- documented future seam: Everything::PageState->from_blob($e2b)->{chrome} for a
    # chrome-only subset once a consumer needs it. See docs/pagestate-design.md.
    return [ $self->HTTP_OK, $e2b ];
}

__PACKAGE__->meta->make_immutable;

1;
