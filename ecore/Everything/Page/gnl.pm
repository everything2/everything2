package Everything::Page::gnl;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::gnl - Gigantic Node Lister (God Node Lister)

=head1 DESCRIPTION

Admin-only tool for listing all nodes by type. Uses the same interface as
List Nodes of Type but restricted to gods and includes additional node types.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with node types list for gods.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Security check - gods only
    unless ($USER->is_admin) {
        return {
            type => 'gnl',
            access_denied => 1,
            message => 'The Gigantic Node Lister is available to gods only.'
        };
    }

    # Get all node types (no filtering for gods)
    my $sth = $DB->{dbh}->prepare(
        'SELECT title, node_id FROM node, nodetype WHERE node_id = nodetype_id ORDER BY title'
    );
    $sth->execute();

    # Build node types list - gods can see everything
    my @node_types;
    while (my $item = $sth->fetchrow_arrayref) {
        my ($title, $node_id) = @$item;
        push @node_types, {
            node_id => $node_id,
            title => $title
        };
    }

    return {
        type => 'gnl',
        access_denied => 0,
        node_types => \@node_types,
        is_admin => 1,
        is_editor => 1,
        user_id => $USER->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::list_nodes_of_type>

=cut
