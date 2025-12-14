package Everything::Page::nodetype_changer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::nodetype_changer - Admin tool to change a node's type

=head1 DESCRIPTION

Allows admins to change the nodetype of any node by providing its node_id.
This is a powerful tool that should be used carefully.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'nodetype_changer',
            error => 'This page is restricted to administrators.'
        };
    }

    my $result = {
        type    => 'nodetype_changer',
        node_id => $REQUEST->node->node_id
    };

    # Get all nodetypes for the dropdown
    my $nodetype_type = $DB->getType('nodetype');
    my @nodetypes = $DB->getNodeWhere({type_nodetype => $nodetype_type->{node_id}});

    my @type_list = ();
    foreach my $nt (sort { lc($a->{title}) cmp lc($b->{title}) } @nodetypes) {
        push @type_list, {
            node_id => int($nt->{node_id}),
            title   => $nt->{title}
        };
    }
    $result->{nodetypes} = \@type_list;

    # Handle type change
    if (my $new_type = $q->param('new_nodetype')) {
        my $change_id = $q->param('change_id');
        if ($change_id && $new_type) {
            $DB->sqlUpdate('node', {type_nodetype => $new_type}, 'node_id=' . int($change_id));
            $result->{message} = "Node type updated successfully.";
        }
    }

    # Viewing a specific node
    if (my $oldtype_id = $q->param('oldtype_id')) {
        my $N = $DB->getNodeById($oldtype_id);

        if ($N) {
            my $current_type = $DB->getNodeById($N->{type_nodetype}, 'light');
            $result->{target_node} = {
                node_id       => int($N->{node_id}),
                title         => $N->{title},
                current_type  => $current_type ? $current_type->{title} : 'unknown',
                type_id       => int($N->{type_nodetype})
            };
        } else {
            $result->{error} = "Node $oldtype_id not found.";
        }
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
