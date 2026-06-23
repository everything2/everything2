package Everything::Page::the_old_hooked_pole;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::the_old_hooked_pole

React page for The Old Hooked Pole - editor tool for mass user account management.

This is now a thin read-only scaffold: it just confirms the viewer is an editor
and hands the React component what it needs to render the form. All the actual
work (the safety checks + delete/lock/smite) moved to the editor-gated
POST /api/admin/users/cleanup endpoint, which the component calls on submit.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;
    my $NODE = $REQUEST->node;

    # Editor check
    unless ( $APP->isEditor( $USER->NODEDATA ) ) {
        return {
            type      => 'the_old_hooked_pole',
            is_editor => 0,
            message   => "You've got other things to snoop on, don't ya."
        };
    }

    # prefill username, for links coming in from the spam-detection tools
    my $prefill = scalar( $REQUEST->cgi->param('prefill') ) || '';

    return {
        type      => 'the_old_hooked_pole',
        is_editor => 1,
        node_id   => $NODE->NODEDATA->{node_id},
        prefill   => $prefill,
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
