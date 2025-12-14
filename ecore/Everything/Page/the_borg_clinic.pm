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

    # Handle borg count update
    if (defined $q->param('clinic_borgcount')) {
        my $new_count = $q->param('clinic_borgcount');

        if ($USER->title eq $borged_user->{title}) {
            # Updating own borg count - get vars for the blessed user object
            my $user_vars = $APP->getVars($USER->NODEDATA);
            $user_vars->{numborged} = $new_count;
            Everything::setVars($USER->NODEDATA, $user_vars);
            $num = $new_count;
        } else {
            # Updating another user's borg count
            $borged_vars->{numborged} = $new_count;
            Everything::setVars($borged_user, $borged_vars);
            $num = $new_count;
        }
        $result->{updated} = 1;
    }

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
