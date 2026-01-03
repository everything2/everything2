package Everything::Page::edit_weblog_menu;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $VARS = $USER->VARS;

    # Get the webloggables setting for dynamic names
    my $webloggables_node = $DB->getNode('webloggables', 'setting');
    my $webloggables = $webloggables_node ? $APP->getVars($webloggables_node) : {};

    # Get the user's can_weblog list
    my $can_weblog = $VARS->{can_weblog} || '';
    my @weblog_ids = split(',', $can_weblog);

    # Build list of weblogs with their visibility settings
    my @weblogs = ();
    foreach my $weblog_id (@weblog_ids) {
        next unless $weblog_id;

        my $group_node = $DB->getNodeById($weblog_id, 'light');
        next unless $group_node;

        # Get the title - either static or dynamic name
        my $static_title = ($weblog_id == 165580) ? 'News' : $group_node->{title};
        my $dynamic_title = $webloggables->{$weblog_id} || $static_title;

        push @weblogs, {
            node_id      => int($weblog_id),
            staticTitle  => $static_title,
            dynamicTitle => $dynamic_title,
            hidden       => $VARS->{'hide_weblog_' . $weblog_id} ? \1 : \0,
        };
    }

    return {
        type            => 'edit_weblog_menu',
        weblogs         => \@weblogs,
        nameifyWeblogs  => $VARS->{nameifyweblogs} ? \1 : \0,
    };
}

__PACKAGE__->meta->make_immutable;

1;
