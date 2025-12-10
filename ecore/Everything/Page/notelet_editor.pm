package Everything::Page::notelet_editor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::notelet_editor - Notelet Editor for managing user notelet content

=head1 DESCRIPTION

Provides two main features:
1. Notelet Castrator - Comments out all JavaScript by adding // to each line
2. Notelet Editor - Edit the noteletRaw VARS field with character limits

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns notelet data and handles save/castrate operations.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $CGI = $REQUEST->cgi;
    my $USER = $REQUEST->user;
    my $APP = $self->APP;
    my $VARS = $USER->VARS;

    my $success_message = '';
    my $error = '';

    # Handle Castrate operation
    if ($CGI->param('YesReallyCastrate')) {
        my $notelet_raw = $VARS->{noteletRaw} || '';
        $notelet_raw =~ s,\n,\n//,g;
        $notelet_raw = '// ' . $notelet_raw;
        $VARS->{noteletRaw} = $notelet_raw;
        $VARS->{noteletScreened} = '';
        $USER->set_vars($VARS);
        $success_message = 'Notelet castrated successfully!';
    }

    # Handle Edit/Save operation
    if ($CGI->param('makethechange')) {
        my $notelet_source = $CGI->param('notelet_source');

        # Handle legacy personalRaw migration
        $VARS->{noteletRaw} = $VARS->{personalRaw} if exists $VARS->{personalRaw};
        delete $VARS->{personalRaw};

        # Handle nodeletKeepComments setting
        my $keep_comments = $CGI->param('nodeletKeepComments');
        if (defined $keep_comments && $keep_comments eq '1') {
            $VARS->{nodeletKeepComments} = 1;
        } else {
            delete $VARS->{nodeletKeepComments};
        }

        if (!defined $notelet_source || !length($notelet_source)) {
            delete $VARS->{noteletRaw};
        } else {
            # Apply character limit based on user level (matches screenNotelet logic)
            my $user_level = $APP->getLevel($USER->NODEDATA) || 0;
            my $max_length = $user_level * 100;

            if ($max_length > 1000) { $max_length = 1000; }
            elsif ($max_length < 500) { $max_length = 500; }

            # Power users get more (matches screenNotelet)
            if ($APP->isAdmin($USER->NODEDATA)) {
                $max_length = 32768;
            } elsif ($APP->isEditor($USER->NODEDATA)) {
                $max_length += 100;
            } elsif ($APP->isDeveloper($USER->NODEDATA)) {
                $max_length = 16384;
            }

            if (length($notelet_source) > $max_length) {
                $notelet_source = substr($notelet_source, 0, $max_length);
                $error = "Content was truncated to $max_length characters.";
            }
            $VARS->{noteletRaw} = $notelet_source;
        }

        # Call screenNotelet htmlcode to process the notelet
        # This modifies $VARS directly
        require Everything::Delegation::htmlcode;
        Everything::Delegation::htmlcode::screenNotelet($DB, $CGI, $REQUEST->node->NODEDATA, $USER->NODEDATA, $VARS, undef, $APP);

        # Save the updated VARS (including noteletScreened set by screenNotelet)
        $USER->set_vars($VARS);

        $success_message = 'Notelet saved successfully!' unless $error;
    }

    # Get current notelet content
    my $notelet_raw = $VARS->{noteletRaw} || '';
    my $notelet_screened = $VARS->{noteletScreened} || '';
    my $char_count = length($notelet_raw);

    # Check if Notelet nodelet is enabled
    my $notelet_enabled = ($VARS->{nodelets} || '') =~ /1290534/ ? 1 : 0;

    # Calculate character limits based on user level
    my $user_level = $APP->getLevel($USER->NODEDATA) || 0;
    my $max_length = $user_level * 100;

    if ($max_length > 1000) { $max_length = 1000; }
    elsif ($max_length < 500) { $max_length = 500; }

    # Power users get more
    if ($APP->isAdmin($USER->NODEDATA)) {
        $max_length = 32768;
    } elsif ($APP->isEditor($USER->NODEDATA)) {
        $max_length += 100;
    } elsif ($APP->isDeveloper($USER->NODEDATA)) {
        $max_length = 16384;
    }

    return {
        type => 'notelet_editor',
        notelet_raw => $notelet_raw,
        notelet_screened => $notelet_screened,
        char_count => $char_count,
        max_length => $max_length,
        user_level => $user_level,
        notelet_enabled => $notelet_enabled,
        keep_comments => $VARS->{nodeletKeepComments} ? 1 : 0,
        success_message => $success_message,
        error => $error
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
