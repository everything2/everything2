package Everything::Page::usergroup_message_archive_manager;

use Moose;
extends 'Everything::Page';

with 'Everything::Roles::UsergroupArchive';

=head1 NAME

Everything::Page::usergroup_message_archive_manager - Manage usergroup message archiving

=head1 DESCRIPTION

Admin tool for enabling/disabling automatic message archiving for usergroups. Archived
messages can be read at the usergroup message archive superdoc.

Pure-render (#4479, Refs #4298): the archive on/off WRITES moved to POST
/api/usergroup_message_archive_manager/apply, so rendering the page no longer mutates
usergroup parameters off query params. The status payload is shared with the API via
Everything::Roles::UsergroupArchive.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'usergroup_message_archive_manager',
            error => 'This page is restricted to administrators.'
        };
    }

    return {
        type    => 'usergroup_message_archive_manager',
        node_id => $REQUEST->node->node_id,
        %{ $self->usergroup_archive_payload },
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::usergroup_message_archive_manager>,
L<Everything::Roles::UsergroupArchive>

=cut
