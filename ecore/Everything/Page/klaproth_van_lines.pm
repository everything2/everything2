package Everything::Page::klaproth_van_lines;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::klaproth_van_lines

React page for Klaproth Van Lines - bulk reparenting of writeups for a single user.
Admin-only tool that allows reparenting multiple writeups at once.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Admins only
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type          => 'klaproth_van_lines',
            access_denied => 1
        };
    }

    # Get Altar of Sacrifice node_id for reference link
    my $altar_node = $DB->getNode( 'Altar of Sacrifice', 'oppressor_superdoc' );

    return {
        type          => 'klaproth_van_lines',
        altar_node_id => $altar_node ? $altar_node->{node_id} : undef
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::writeup_reparent>

=cut
