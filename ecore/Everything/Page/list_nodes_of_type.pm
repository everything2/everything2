package Everything::Page::list_nodes_of_type;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::list_nodes_of_type - List Nodes of Type tool

=head1 DESCRIPTION

Administrative tool for listing nodes by type with filtering and sorting.
Available to editors and developers.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with node types, nodes list, and configuration.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Security check - editors (includes admins) or developers
    unless ($USER->is_editor || $USER->is_developer) {
        return {
            type => 'list_nodes_of_type',
            access_denied => 1,
            message => 'Sorry, cowboy. You must be at least this tall to ride the Node Type Lister!'
        };
    }

    my $is_admin = $USER->is_admin;
    my $is_editor = $USER->is_editor;

    # Get all node types
    my $sth = $DB->{dbh}->prepare(
        'SELECT title, node_id FROM node, nodetype WHERE node_id = nodetype_id ORDER BY title'
    );
    $sth->execute();

    # Define skipped types based on user role
    my %skips;
    $skips{$_} = 1 for qw(user e2node writeup draft);

    unless ($is_admin) {
        $skips{$_} = 1 for qw(restricted_superdoc);
        unless ($is_editor) {
            $skips{$_} = 1 for qw(oppressor_superdoc debate debatecomment);
        }
    }

    # Build node types list
    my @node_types;
    while (my $item = $sth->fetchrow_arrayref) {
        my ($title, $node_id) = @$item;
        next if exists $skips{$title};

        push @node_types, {
            node_id => $node_id,
            title => $title
        };
    }

    return {
        type => 'list_nodes_of_type',
        access_denied => 0,
        node_types => \@node_types,
        is_admin => $is_admin ? 1 : 0,
        is_editor => $is_editor ? 1 : 0,
        user_id => $USER->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
