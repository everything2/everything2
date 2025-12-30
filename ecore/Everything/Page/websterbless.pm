package Everything::Page::websterbless;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::websterbless

React page for Websterbless - rewards users who suggest corrections to Webster 1913.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Only editors and admins can access this tool
    unless ( $APP->isEditor( $USER->NODEDATA ) || $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type  => 'websterbless',
            error => 'Access denied. This tool is restricted to editors and administrators.'
        };
    }

    # Get Webster 1913 user node
    my $webster = $DB->getNode( 'Webster 1913', 'user' );
    unless ($webster) {
        return {
            type  => 'websterbless',
            error => 'Webster 1913 user not found in database.'
        };
    }

    my $webster_id = $webster->{node_id};

    # Count Webster 1913's messages
    my $msg_count = $DB->sqlSelect( 'COUNT(*)', 'message', "for_user=$webster_id" ) || 0;

    # Handle form submission
    my @results = ();
    my @params  = $query->param;

    # Check if this is a submission
    my $has_submission = 0;
    foreach my $param (@params) {
        if ( $param =~ /^webbyblessUser\d+$/ && $query->param($param) ) {
            $has_submission = 1;
            last;
        }
    }

    if ($has_submission) {
        # Get the list of users to be thanked
        my ( @users, @writeups );
        foreach my $param (@params) {
            if ( $param =~ /^webbyblessUser(\d+)$/ ) {
                $users[$1] = $query->param($param);
            }
            if ( $param =~ /^webbyblessNode(\d+)$/ ) {
                $writeups[$1] = $query->param($param);
            }
        }

        # Fixed blessing amount
        my $gp_amount = 3;

        # Process each user
        for ( my $i = 0 ; $i < @users ; $i++ ) {
            next unless $users[$i];

            my $username = $users[$i];
            $username =~ s/^\s+|\s+$//g;
            next unless $username;

            # Get the user node
            my $recipient = $DB->getNode( $username, 'user' );
            unless ($recipient) {
                push @results,
                  {
                    success => 0,
                    error   => "Couldn't find user: $username"
                  };
                next;
            }

            # Send automated thank-you message
            my $writeup_name = $writeups[$i] || '';
            $writeup_name =~ s/^\s+|\s+$//g;

            my $result = $self->sendWebsterMessage( $webster, $recipient, $writeup_name );
            unless ( $result->{success} ) {
                push @results,
                  {
                    success => 0,
                    error   => "Failed to send message to $username: $result->{error}"
                  };
                next;
            }

            # Update karma
            $recipient->{karma} += 1;
            $DB->updateNode( $recipient, -1 );
            $APP->checkAchievementsByType( 'karma', $recipient->{user_id} );

            # Adjust GP
            $APP->adjustGP( $recipient, $gp_amount );

            # Security log
            my $superbless_node = $DB->getNode( 'Superbless', 'superdoc' );
            $APP->securityLog(
                $superbless_node,
                $USER->NODEDATA,
                $USER->title . " [Websterbless|Websterblessed] $recipient->{title} with $gp_amount GP."
            );

            push @results,
              {
                success => 1,
                message => "User $recipient->{title} was given $gp_amount GP"
              };
        }
    }

    # Get prefill_username from URL parameter (for user tools modal integration)
    my $prefill_username = $query->param('prefill_username') || '';

    return {
        type             => 'websterbless',
        msg_count        => $msg_count,
        webster_id       => $webster_id,
        results          => \@results,
        prefill_username => $prefill_username
    };
}

=head2 sendWebsterMessage

Sends an automated thank-you message from Webster 1913 to the recipient.

=cut

sub sendWebsterMessage
{
    my ( $self, $webster, $recipient, $writeup_name ) = @_;

    my $message = 'Thank you! My servants have attended to any errors.';

    # Build message params
    my $params = {
        from    => $webster,
        to      => $recipient,
        message => $message
    };

    # Add renode if writeup name is provided
    if ($writeup_name) {
        $params->{renode} = $writeup_name;
    }

    my $result = $self->APP->send_message($params);

    if ( $result->{errors} ) {
        return {
            success => 0,
            error   => $result->{errortext} || 'Failed to send message'
        };
    }

    return { success => 1 };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
