package Everything::Page::node_parameter_editor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::node_parameter_editor - Edit node parameters

=head1 DESCRIPTION

Admin tool for viewing and editing node parameters. Parameters are
typed key-value pairs that can be attached to nodes, separate from
the older $VARS system.

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
            type  => 'node_parameter_editor',
            error => 'This page is restricted to administrators.'
        };
    }

    my $page_node_id = $REQUEST->node->node_id;

    my $result = {
        type    => 'node_parameter_editor',
        node_id => $page_node_id
    };

    my $for_node = $q->param('for_node');

    unless (defined $for_node && $for_node =~ /^\d+$/) {
        $result->{no_node} = 1;
        $result->{message} = 'No node to check the parameters for. Use this from the C_E tools menu in Master Control.';
        return $result;
    }

    my $target_node = $DB->getNodeById($for_node);
    unless ($target_node) {
        $result->{error} = "No such node_id '$for_node'";
        return $result;
    }

    # Get parameter types available for this node's type
    my $param_types = $APP->getParametersForType($target_node->{type});

    my @available_params = ();
    foreach my $param_name (sort keys %$param_types) {
        push @available_params, {
            name        => $param_name,
            description => $param_types->{$param_name}{description} || ''
        };
    }

    # Get current parameters on this node
    my $current_params = $DB->getNodeParams($target_node);
    my @params = ();
    foreach my $key (sort keys %$current_params) {
        push @params, {
            name  => $key,
            value => $current_params->{$key}
        };
    }

    $result->{target_node} = {
        node_id => int($target_node->{node_id}),
        title   => $target_node->{title},
        type    => $target_node->{type}{title}
    };
    $result->{available_params} = \@available_params;
    $result->{current_params}   = \@params;

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
