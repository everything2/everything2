package Everything::Page::edev_faq;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::edev_faq - EDev FAQ

=head1 DESCRIPTION

FAQ for members of the edev usergroup.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with FAQ content.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;

    my $is_edev = $APP->isDeveloper($USER, "nogods");

    return {
        type => 'edev_faq',
        is_edev => $is_edev ? 1 : 0,
        user_title => $USER->{title}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
