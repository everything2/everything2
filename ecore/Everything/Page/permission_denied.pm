package Everything::Page::permission_denied;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::permission_denied - Permission Denied page

=head1 DESCRIPTION

Simple page displayed when a user doesn't have access to a node.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data for the Permission Denied message.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'permission_denied',
        message => "You don't have access to that node."
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
