package Everything::API::cool;

use Moose;
extends 'Everything::API';

# API endpoint for awarding C!s (cools) to writeups
# POST /api/cool
# Body: { writeup_id: 123 }

sub command_post {
    my ( $self, $REQUEST ) = @_;

    my $user = $REQUEST->user;

    # Check if user is logged in
    if ( $user->is_guest ) {
        return $self->error('You must be logged in to award C!s');
    }

    # Check if user has C!s available
    my $cools_left = $user->coolsleft;
    unless ( $cools_left && $cools_left > 0 ) {
        return $self->error('You have no C!s remaining');
    }

    # Get request data
    my $data       = $self->get_json_data;
    my $writeup_id = int( $data->{writeup_id} || 0 );

    # Validate inputs
    unless ($writeup_id) {
        return $self->error('Missing writeup_id');
    }

    # Get writeup node
    my $writeup = $self->APP->node_by_id($writeup_id);
    unless ( $writeup && $writeup->type->title eq 'writeup' ) {
        return $self->error('Writeup not found');
    }

    # Check if user is the author
    if ( $writeup->author_user == $user->node_id ) {
        return $self->error('You cannot C! your own writeup');
    }

    # Check if user has already cooled this writeup
    my $existing_cool = $self->DB->sqlSelectHashref( '*', 'coolwriteups',
            'cooledby_user='
          . $user->node_id
          . ' AND coolwriteups_id='
          . $writeup_id );

    if ($existing_cool) {
        return $self->error('You have already C!\'d this writeup');
    }

    # Award the C!
    my $cool_result = $self->APP->insertCool( $user, $writeup );

    unless ($cool_result) {
        return $self->error('Failed to award C!');
    }

    return $self->success(
        {
            message         => 'C! awarded successfully',
            writeup_id      => $writeup_id,
            cools_remaining => $cools_left - 1
        }
    );
}

__PACKAGE__->meta->make_immutable;
1;
