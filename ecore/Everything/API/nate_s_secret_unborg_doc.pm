package Everything::API::nate_s_secret_unborg_doc;

use Moose;
extends 'Everything::API';

use Everything qw(setVars);

# POST /api/nate_s_secret_unborg_doc/unborg -- admin-only (#4468, Refs #4298). The "secret
# escape hatch": instantly un-borgs the requesting admin regardless of the borg timer, by
# clearing the active `borged` var + room `borgd` flag via the shared
# Everything::Application::unborg_user. Replaces the GET-mutation that ran in
# Everything::Page::nate_s_secret_unborg_doc's buildReactData (un-borged you just by
# loading the page).

sub routes {
    return { 'unborg' => 'unborg_self' };
}

sub unborg_self {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    # Non-admins get the easter-egg brush-off (mirrors the old page).
    return [$self->HTTP_OK, {success => 0, message => "Maybe you'd better just stay in there"}]
        unless $user->is_admin;

    my $USER = $user->NODEDATA;
    my $vars = $self->APP->getVars($USER);

    $self->APP->unborg_user($USER, $vars);
    setVars($USER, $vars);
    $self->DB->updateNode($USER, -1);

    return [$self->HTTP_OK, {success => 1, message => "you're unborged"}];
}

__PACKAGE__->meta->make_immutable;

1;
