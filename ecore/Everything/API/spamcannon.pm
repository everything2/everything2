package Everything::API::spamcannon;

use Moose;
extends 'Everything::API';

=head1 NAME

Everything::API::spamcannon - API for bulk private messaging (editors only)

=head1 DESCRIPTION

Provides endpoint for editors to send a single message to multiple recipients.

=head1 METHODS

=head2 routes

POST /api/spamcannon - Send message to multiple recipients

=cut

sub routes {
    return {
        '/' => 'send_bulk_message'
    };
}

=head2 send_bulk_message

Send a private message to multiple recipients.

Request body (JSON):
  {
    "recipients": ["user1", "user2", ...],
    "message": "Your message text"
  }

Response:
  {
    "success": 1,
    "sent_to": [{"user_id": 123, "username": "user1"}, ...],
    "errors": ["user3 does not exist", ...]
  }

=cut

sub send_bulk_message {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    # Must be logged in
    unless ($user && !$user->is_guest) {
        return [$self->HTTP_OK, {success => 0, error => 'Not logged in'}];
    }

    # Must be an editor
    unless ($self->APP->isEditor($user->NODEDATA)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied. Editor access required.'}];
    }

    # Parse request body
    my $data = $REQUEST->JSON_POSTDATA;
    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid JSON body'}];
    }

    my $recipients = $data->{recipients};
    my $message = $data->{message};

    # Validate recipients
    unless ($recipients && ref($recipients) eq 'ARRAY' && @$recipients) {
        return [$self->HTTP_OK, {success => 0, error => 'No recipients specified'}];
    }

    # Limit recipients
    my $MAX_RECIPIENTS = 20;
    if (@$recipients > $MAX_RECIPIENTS) {
        return [$self->HTTP_OK, {
            success => 0,
            error => "Too many recipients. Maximum is $MAX_RECIPIENTS."
        }];
    }

    # Validate message
    unless (defined $message && length($message)) {
        return [$self->HTTP_OK, {success => 0, error => 'No message specified'}];
    }

    # Truncate message (243 chars like original)
    if (length($message) > 243) {
        $message = substr($message, 0, 243);
    }

    # Resolve recipients to node objects (users or usergroups)
    # Uses deliver_message pattern from messages API for consistent behavior
    my @target_nodes = ();
    my @errors = ();
    my %seen_ids = ();

    foreach my $recip (@$recipients) {
        $recip =~ s/^\s+|\s+$//g;
        next unless length($recip);

        # Try as user first, then usergroup (same lookup order as messages API)
        my $target = $self->DB->getNode($recip, 'user');
        $target = $self->DB->getNode($recip, 'usergroup') unless $target;

        unless ($target) {
            push @errors, "\"$recip\" does not exist";
            next;
        }

        my $target_node = $self->APP->node_by_id($target->{node_id});
        push @target_nodes, $target_node if $target_node;
    }

    # Use the same deliver_message pattern as messages API
    # This ensures consistent behavior for message forwarding, ignores,
    # usergroup membership checks, etc.
    my @sent_to = ();
    my $msgtext = "(massmail): $message";

    foreach my $target_node (@target_nodes) {
        # Skip duplicates
        next if $seen_ids{$target_node->node_id};
        $seen_ids{$target_node->node_id} = 1;

        # Use the node's deliver_message method (same as messages API)
        if ($target_node->can('deliver_message')) {
            my $result = $target_node->deliver_message({
                from => $user,
                message => $msgtext
            });

            if ($result->{ignores}) {
                push @errors, $target_node->title . " is ignoring you";
            } elsif ($result->{successes}) {
                push @sent_to, $target_node->title;
            } elsif ($result->{errors}) {
                # Include any error text from usergroup delivery
                my $err_text = $result->{errortext} ? join('; ', @{$result->{errortext}}) : 'delivery failed';
                push @errors, $target_node->title . ": $err_text";
            }
        }
    }

    # Create outbox entry for sender (same as messages API)
    if (@sent_to) {
        my $recipient_list = join(', ', map { "[$_]" } @sent_to);
        my $outbox_msg = 'you said "' . $msgtext . '" to ' . $recipient_list;
        $self->DB->sqlInsert('message_outbox', {
            author_user => $user->node_id,
            msgtext => $outbox_msg,
            archive => 0
        });
    }

    return [$self->HTTP_OK, {
        success => @sent_to ? 1 : 0,
        sent_to => \@sent_to,
        errors => \@errors,
        message => $message
    }];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::Page::spam_cannon>

=cut
