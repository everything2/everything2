package Everything::API::customstyle;

use Moose;
extends 'Everything::API';

=head1 Everything::API::customstyle

The viewer's custom stylesheet override (C<$VARS-E<gt>{customstyle}>).

C<POST /api/customstyle/clear> deletes it. This replaces the legacy C<?clearVandalism>
GET that mutated VARS as a side effect inside the_catwalk / theme_nirvana's
C<buildReactData>, so those page controllers can be pure-render resolvers
(roadmap step 2 — every mutating page action becomes a React-driven API call).

=cut

sub routes {
    return {
        'clear' => 'clear_customstyle',
    };
}

# POST /api/customstyle/clear -- drop the viewer's custom stylesheet override.
sub clear_customstyle {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    my $VARS = $user->VARS;
    delete $VARS->{customstyle};
    $user->set_vars($VARS);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Your custom theme has been cleared.',
    }];
}

__PACKAGE__->meta->make_immutable;

1;
