package Everything::Page::everything_poll_directory;

use Moose;
use namespace::autoclean;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_poll_directory - Poll directory page

=head1 DESCRIPTION

Displays list of active polls with admin management options.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    return {
        type => 'everything_poll_directory',
        is_admin => $APP->isAdmin($USER) ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;

1;
