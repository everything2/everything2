package Everything::Page::macro_faq;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::macro_faq - Macro FAQ page

=head1 DESCRIPTION

Displays information about the /macro command system and shows
the user's currently defined macros.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $user = $REQUEST->user;
    my $VARS = $REQUEST->VARS;

    my $is_guest = $user->is_guest;
    my $is_editor = !$is_guest && $APP->isEditor($user->NODEDATA);

    # Get user's defined macros
    my @user_macros;
    unless ($is_guest) {
        foreach my $key (sort keys %$VARS) {
            next unless $key =~ /^chatmacro_(.+)/;
            my $name = $1;
            my $text = $VARS->{$key};
            push @user_macros, {
                name => $name,
                text => $text
            };
        }
    }

    # Get the Content Editors and gods usergroups for display
    my $ce_group = $DB->getNode('Content Editors', 'usergroup');
    my $gods_group = $DB->getNode('gods', 'usergroup');

    return {
        type => 'macro_faq',
        isGuest => $is_guest ? 1 : 0,
        isEditor => $is_editor ? 1 : 0,
        username => $is_guest ? '' : $user->title,
        userMacros => \@user_macros,
        contentEditorsId => $ce_group ? int($ce_group->{node_id}) : 0,
        godsId => $gods_group ? int($gods_group->{node_id}) : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
