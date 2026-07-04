package Everything::Page::node_tracker;

use Moose;
extends 'Everything::Page';

with 'Everything::Security::NoGuest';
with 'Everything::Roles::NodeTrackerStats';

=head1 NAME

Everything::Page::node_tracker - Node Tracker statistics page

=head1 DESCRIPTION

Tracks user writing statistics over time, including XP, reputation, cools,
and individual node changes. Originally ported from cow of doom's node tracker.

Pure-render: the "update" snapshot-save moved to POST /api/node_tracker/update
(Everything::API::node_tracker, #4458, Refs #4298). The stats computation is shared with
that endpoint via Everything::Roles::NodeTrackerStats, so this page just renders the
current stats (diffs vs the saved baseline) and the React "Update" button drives the API.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $userid = $REQUEST->user->NODEDATA->{user_id};

    # The static intro (with its [cow of doom]/[pbuh]/[kthejoker|me] links) lives in the
    # React component now, rendered as real LinkNode elements rather than lifted E2 link
    # markup dumped through dangerouslySetInnerHTML (#4458).
    return {
        type => 'node_tracker',
        %{ $self->build_tracker_payload( $userid, 0 ) }
    };
}

__PACKAGE__->meta->make_immutable;
1;
