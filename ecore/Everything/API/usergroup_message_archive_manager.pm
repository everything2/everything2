package Everything::API::usergroup_message_archive_manager;

use Moose;
extends 'Everything::API';

with 'Everything::Roles::UsergroupArchive';

# Admin usergroup-archive management mutation (#4479, Refs #4298). Replaces the render-time
# umam_what_id_/umam_sure_id_ query-param writes in
# Everything::Page::usergroup_message_archive_manager's buildReactData. Admin-only; the shared
# status payload + apply logic live in Everything::Roles::UsergroupArchive so the page stays
# pure-render.
#
#   POST /api/usergroup_message_archive_manager/apply
#     { changes: [ { group_id, action } ] }   action '1'=disable, '2'=enable

sub routes {
    return { 'apply' => 'apply' };
}

sub apply {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $APP  = $self->APP;

    return [$self->HTTP_OK, {success => 0, error => 'This tool is restricted to administrators.'}]
        unless $APP->isAdmin($user->NODEDATA);

    my $data = $REQUEST->JSON_POSTDATA;
    $data = {} unless ref $data eq 'HASH';
    my $changes = ref $data->{changes} eq 'ARRAY' ? $data->{changes} : [];

    my $applied = $self->apply_archive_changes($user->NODEDATA, $changes);

    return [$self->HTTP_OK, {
        success => 1,
        changes => $applied,
        %{ $self->usergroup_archive_payload },
    }];
}

__PACKAGE__->meta->make_immutable;
1;
