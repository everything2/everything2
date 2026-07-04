package Everything::Page::nodetype_changer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::nodetype_changer - Admin tool to change a node's type

=head1 DESCRIPTION

Allows admins to change the nodetype of any node by providing its node_id.
This is a powerful tool that should be used carefully.

Pure-render: the node lookup and the type change moved to POST
/api/nodetype_changer/lookup|change (Everything::API::nodetype_changer, #4461,
Refs #4298). This page just gates on admin and hands the React component the nodetypes
list, each flagged with C<permanent_cache> so the UI can warn when a target type is one
of the permanently-cached types (the change endpoint also enforces a confirm there).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'nodetype_changer',
            error => 'This page is restricted to administrators.'
        };
    }

    # Get all nodetypes for the dropdown, flagging the permanently-cached ones.
    my $nodetype_type = $DB->getType('nodetype');
    my @nodetypes = $DB->getNodeWhere({type_nodetype => $nodetype_type->{node_id}});

    my @type_list = ();
    foreach my $nt (sort { lc($a->{title}) cmp lc($b->{title}) } @nodetypes) {
        push @type_list, {
            node_id         => int($nt->{node_id}),
            title           => $nt->{title},
            permanent_cache => (exists $Everything::CONF->permanent_cache->{$nt->{title}} ? 1 : 0)
        };
    }

    return {
        type      => 'nodetype_changer',
        node_id   => $REQUEST->node->node_id,
        nodetypes => \@type_list
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
