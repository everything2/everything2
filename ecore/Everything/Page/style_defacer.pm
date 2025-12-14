package Everything::Page::style_defacer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::style_defacer - Custom CSS editor

=head1 DESCRIPTION

Allows users to add custom CSS styles that override the default theme.
The custom styles are stored in the user's customstyle variable.

Note: This will eventually be migrated to use CSS variables instead
of raw CSS injection.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Must be logged in
    if ($APP->isGuest($USER->NODEDATA)) {
        return {
            type  => 'style_defacer',
            error => 'You must be logged in to use the Style Defacer.'
        };
    }

    my $node_id = $REQUEST->node->node_id;
    my $VARS = $USER->VARS;

    # Handle form submission
    if (defined $q->param('vandalism')) {
        my $new_style = $q->param('vandalism') || '';

        if (length($new_style)) {
            $VARS->{customstyle} = $new_style;
        } else {
            delete $VARS->{customstyle};
        }

        # Save the updated vars
        $USER->set_vars($VARS);
    }

    # Get ekw_shredder node for link
    my $shredder = $DB->getNode('ekw shredder', 'superdoc');
    my $shredder_id = $shredder ? int($shredder->{node_id}) : undef;

    # Get Theme Nirvana for link
    my $nirvana = $DB->getNode('Theme Nirvana', 'superdoc');
    my $nirvana_id = $nirvana ? int($nirvana->{node_id}) : undef;

    return {
        type         => 'style_defacer',
        node_id      => $node_id,
        customstyle  => $VARS->{customstyle} || '',
        shredder_id  => $shredder_id,
        nirvana_id   => $nirvana_id
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
