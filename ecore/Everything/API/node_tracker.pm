package Everything::API::node_tracker;

use Moose;
extends 'Everything::API';

with 'Everything::Roles::NodeTrackerStats';

# POST /api/node_tracker/update -- logged-in self-service (#4458, Refs #4298). Saves the
# requesting user's current writing-stats snapshot as the new baseline and returns the
# refreshed tracker payload (diffs now reset against the freshly-saved state). Replaces
# the render-time ?update mutation in Everything::Page::node_tracker's buildReactData.
# Stats computation is shared with that page via Everything::Roles::NodeTrackerStats.

sub routes {
    return { 'update' => 'update_stats' };
}

sub update_stats {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'You must be logged in to use the node tracker.'}]
        if $user->is_guest;

    my $userid = $user->NODEDATA->{user_id};
    my $data   = $self->build_tracker_payload($userid, 1);

    return [$self->HTTP_OK, {success => 1, %$data}];
}

__PACKAGE__->meta->make_immutable;

1;
