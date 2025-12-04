package Everything::Page::everything_user_poll;

use Moose;
use namespace::autoclean;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_user_poll - Display the current poll

=head1 DESCRIPTION

Displays the current active poll with voting interface or results.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'everything_user_poll'
    };
}

__PACKAGE__->meta->make_immutable;

1;
