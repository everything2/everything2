package Everything::Page::node_tracker;

use Moose;
extends 'Everything::Page';

with 'Everything::Security::NoGuest';

sub buildReactData {
    my ( $self, $REQUEST, $node ) = @_;

    # Get the current node (Node Tracker superdoc)
    # If $node is provided, it's a blessed object, get hashref
    # Otherwise, getNode returns hashref directly
    my $NODE = $node ? $node->NODEDATA : $self->DB->getNode( 'Node Tracker', 'superdoc' );

    # Call the legacy document::node_tracker function
    my $html = Everything::Delegation::document::node_tracker(
        $self->DB,
        $REQUEST->cgi,
        $NODE,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        undef,    # $PAGELOAD
        $self->APP
    );

    return { html => $html };
}

__PACKAGE__->meta->make_immutable;

1;
