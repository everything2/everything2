package Everything::Page::edev_documentation_index;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::edev_documentation_index - Edev Documentation Index

=head1 DESCRIPTION

Lists all edevdoc nodes with ability for developers to create new ones.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with edevdoc list and user permissions.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;

    # Get all edevdoc nodes, sorted by title
    my @edocs = $DB->getNodeWhere({}, 'edevdoc', 'title');

    my @doc_list;
    foreach my $doc (@edocs) {
        push @doc_list, {
            node_id => $doc->{node_id},
            title => $doc->{title}
        };
    }

    my $is_developer = $APP->isDeveloper($USER) ? 1 : 0;

    return {
        type => 'edev_documentation_index',
        docs => \@doc_list,
        is_developer => $is_developer
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
