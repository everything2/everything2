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

    return {
        type => 'everything_poll_directory',
    };
}

__PACKAGE__->meta->make_immutable;

1;
