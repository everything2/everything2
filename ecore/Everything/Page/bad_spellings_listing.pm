package Everything::Page::bad_spellings_listing;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::bad_spellings_listing - Display list of common spelling errors

=head1 DESCRIPTION

Shows the dictionary of common bad spellings that are flagged in writeups.
The list is stored in the 'bad spellings en-US' setting node.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns spelling dictionary data with user's current preference setting.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $VARS = $REQUEST->VARS;

    my $is_admin = $user->is_admin;
    my $is_editor = $user->is_editor;

    # Get spelling setting node
    my $spell_info_node = $DB->getNode('bad spellings en-US', 'setting');
    unless ($spell_info_node) {
        return {
            type => 'bad_spellings_listing',
            error => 'config',
            message => 'Error: unable to get spelling setting.'
        };
    }

    # Get spelling data from vars
    my $spell_info = Everything::getVars($spell_info_node);
    unless ($spell_info) {
        return {
            type => 'bad_spellings_listing',
            error => 'config',
            message => 'Error: unable to get spelling information.'
        };
    }

    # Build spelling list (exclude internal keys starting with _)
    my @spellings = ();
    my $total_entries = scalar(keys %$spell_info);

    foreach my $key (sort keys %$spell_info) {
        # Skip internal keys and 'nwing' (special case from original code)
        next if substr($key, 0, 1) eq '_';
        next if $key eq 'nwing';

        # Convert underscores to spaces for display
        my $display_key = $key;
        $display_key =~ tr/_/ /;

        push @spellings, {
            invalid => $display_key,
            correction => $spell_info->{$key}
        };
    }

    return {
        type => 'bad_spellings_listing',
        spellings => \@spellings,
        shown_count => scalar(@spellings),
        total_count => $total_entries,
        user_has_disabled => $VARS->{nohintSpelling} ? 1 : 0,
        is_admin => $is_admin ? 1 : 0,
        is_editor => $is_editor ? 1 : 0,
        setting_node_id => $spell_info_node->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
