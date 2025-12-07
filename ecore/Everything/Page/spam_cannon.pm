package Everything::Page::spam_cannon;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::spam_cannon - Editor tool for bulk private messaging

=head1 DESCRIPTION

Spam Cannon allows editors to send a single message to multiple recipients
without creating a usergroup. Supports up to 20 recipients per message.
Handles message forwarding aliases and validates users exist.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about the current user's editor status.
Requires editor privileges to use.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $is_editor = $self->APP->isEditor($user->NODEDATA);

    return {
        is_editor => $is_editor ? 1 : 0,
        max_recipients => 20,
        username => $user->title
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::spamcannon>

=cut
