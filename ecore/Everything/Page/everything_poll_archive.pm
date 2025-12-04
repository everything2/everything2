package Everything::Page::everything_poll_archive;

use Moose;
use namespace::autoclean;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_poll_archive - Poll archive page

=head1 DESCRIPTION

Displays list of closed polls with voting results.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'everything_poll_archive'
    };
}

__PACKAGE__->meta->make_immutable;

1;
