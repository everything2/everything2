package Everything::Page::the_borg_clinic;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_borg_clinic - Admin tool for managing user borg counts

=head1 DESCRIPTION

Allows admins to view and modify user borg counts. Users stay borged for
4 minutes plus two minutes times the borg count (4 + 2*x). Negative numbers
provide "borg insurance" causing instant unborg.

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
            type  => 'the_borg_clinic',
            error => 'This page is restricted to administrators.'
        };
    }

    my $clinic_user = $q->param('clinic_user') || $USER->title;
    my $result = {
        type         => 'the_borg_clinic',
        clinic_user  => $clinic_user,
        node_id      => $REQUEST->node->node_id,
    };

    # Look up the target user
    my $borged_user = $DB->getNode($clinic_user, 'user');

    unless ($borged_user) {
        $result->{error} = "Can't find a user \"$clinic_user\" on the system!";
        return $result;
    }

    my $borged_vars = $APP->getVars($borged_user);
    my $num = $borged_vars->{numborged} // 0;

    # The borg-count WRITE moved to POST /api/borgclinic/setborg
    # (Everything::API::borgclinic, #4449), so rendering this page no longer mutates a
    # user's vars off query params. buildReactData is now pure-render -- the user
    # lookup and the current count below are reads only.

    $result->{user_found}  = 1;
    $result->{user_id}     = int($borged_user->{node_id});
    $result->{user_title}  = $borged_user->{title};
    $result->{borg_count}  = int($num // 0);
    $result->{show_editor} = defined($q->param('clinic_user')) ? 1 : 0;

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
