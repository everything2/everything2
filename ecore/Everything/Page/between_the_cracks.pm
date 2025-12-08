package Everything::Page::between_the_cracks;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::between_the_cracks - Find neglected writeups with few votes

=head1 DESCRIPTION

Shows writeups that have "fallen between the cracks" - low vote counts that
the current user hasn't voted on yet. Encourages users to vote on neglected
content.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure. The actual writeup list is fetched via the
betweenthecracks API to allow dynamic filtering without page reload.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    my $is_guest = $APP->isGuest($USER->NODEDATA);

    return {
        type => 'between_the_cracks',
        is_guest => $is_guest ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::betweenthecracks>

=cut
