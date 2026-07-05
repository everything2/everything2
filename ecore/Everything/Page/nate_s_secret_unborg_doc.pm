package Everything::Page::nate_s_secret_unborg_doc;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::nate_s_secret_unborg_doc

React page for Nate's Secret Unborg Doc.

Pure-render: the instant un-borg moved to POST /api/nate_s_secret_unborg_doc/unborg
(Everything::API::nate_s_secret_unborg_doc, #4468, Refs #4298) -- loading this page no
longer mutates. It just reports whether the viewer may use the tool; the React component
shows an admin the button (which POSTs the unborg and reloads so chat re-enables).

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $USER = $REQUEST->user;

    unless ( $self->APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type     => 'nate_s_secret_unborg_doc',
            is_admin => 0,
            message  => "Maybe you'd better just stay in there"
        };
    }

    return {
        type     => 'nate_s_secret_unborg_doc',
        is_admin => 1
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::nate_s_secret_unborg_doc>

=cut
