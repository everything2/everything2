package Everything::Page::usergroup_press_gang;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::usergroup_press_gang - Bulk add users to a usergroup

=head1 DESCRIPTION

Admin tool for adding multiple users to a usergroup at once.
More convenient than adding them one at a time via the node bucket.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'simple_usergroup_editor',
            error => 'This page is restricted to administrators.'
        };
    }

    # This is just a wrapper around simple_usergroup_editor
    # Delegate to that Page class
    require Everything::Page::simple_usergroup_editor;
    my $editor = Everything::Page::simple_usergroup_editor->new(
        APP => $APP,
        DB  => $DB
    );

    return $editor->buildReactData($REQUEST);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
