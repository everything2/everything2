package Everything::Page::mark_all_discussions_as_read;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::mark_all_discussions_as_read - Mark all debates as read

=head1 DESCRIPTION

Allows CE members to mark all CE debates as read, and admins to mark
admin debates as read as well.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    my $is_admin  = $APP->isAdmin($USER->NODEDATA);
    my $is_editor = $APP->isEditor($USER->NODEDATA);

    unless ($is_editor || $is_admin) {
        return {
            type => 'mark_all_discussions_as_read',
            error => 'You must be a Content Editor or Administrator to use this tool.'
        };
    }

    # The mark-read actions moved to POST /api/markdiscussionsread/{ce,admin}
    # (Everything::API::markdiscussionsread) so rendering this page no longer
    # writes lastreaddebate off GET params (#4410). buildReactData is pure-render
    # -- the React component drives the two buttons via the API, and reads
    # admin-ness from the global e2.user prop.
    return {
        type => 'mark_all_discussions_as_read'
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
