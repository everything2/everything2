package Everything::Page::super_mailbox;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::super_mailbox - Super Mailbox page for bot message monitoring

=head1 DESCRIPTION

One-stop check for messages to bot and support mailboxes. Shows message counts
for authorized bot accounts that the logged-in user has permission to view.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about bot mailboxes the user can access.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    # Get bot inbox configuration
    my $bot_inboxes_setting = $DB->getNode('bot inboxes', 'setting');
    return {
        type => 'super_mailbox',
        access_denied => 1,
        message => 'Configuration error: bot inboxes setting not found'
    } unless $bot_inboxes_setting;

    my $options = $APP->getVars($bot_inboxes_setting);
    my @names = sort { lc($a) cmp lc($b) } keys(%$options);

    my $is_editor = $APP->isEditor($USER);
    my @accessible_bots = ();
    my %groups_cache = ();

    foreach my $bot_name (@names) {
        my $ug_name = $options->{$bot_name};
        my $ug = $groups_cache{$ug_name} ||= $DB->getNode($ug_name, 'usergroup');
        next unless $is_editor || $DB->isApproved($USER, $ug);

        my $botuser = $DB->getNode($bot_name, 'user');
        next unless $botuser;

        my $message_count = $DB->sqlSelect('COUNT(*)', 'message', 'for_user=' . $botuser->{node_id});

        push @accessible_bots, {
            username => $bot_name,
            user_id => $botuser->{node_id},
            message_count => $message_count + 0
        };
    }

    # Access denied if user has no bot mailboxes they can view
    unless (@accessible_bots) {
        return {
            type => 'super_mailbox',
            access_denied => 1,
            message => 'Restricted area. You are not allowed in here. Leave now or suffer the consequences.'
        };
    }

    return {
        type => 'super_mailbox',
        access_denied => 0,
        bots => \@accessible_bots
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
