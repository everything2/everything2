package Everything::API::websterbless;

use Moose;
extends 'Everything::API';
with 'Everything::Roles::Bestow';

use Everything::SecurityLog qw(:events);

# POST /api/websterbless/bless -- editor/admin-only (#4451, Refs #4298). Blesses users
# who suggested Webster 1913 corrections: per user, sends a thank-you PM from Webster
# 1913, +1 karma, a karma achievement check, +3 GP, and a securityLog entry. Replaces
# the render-time mutation loop in Everything::Page::websterbless.

my $GP_AMOUNT = 3;

sub routes {
    return { 'bless' => 'bless_users' };
}

sub bless_users {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK,
        {success => 0, error => 'Access denied. This tool is restricted to editors and administrators.'}]
        unless ($user->is_editor || $user->is_admin);

    my $data      = $REQUEST->JSON_POSTDATA;
    my $blessings = $data->{blessings};
    return [$self->HTTP_OK, {success => 0, error => 'No users to bless'}]
        unless (ref $blessings eq 'ARRAY' && @$blessings);

    my $webster = $self->webster_user;    # shared lookup via Everything::Roles::Bestow (#4497)
    return [$self->HTTP_OK, {success => 0, error => 'Webster 1913 user not found in database.'}]
        unless $webster;

    my @results;
    foreach my $b (@$blessings) {
        my $username = $b->{user};
        $username =~ s/^\s+|\s+$//g if defined $username;
        next unless (defined $username && length $username);    # skip blank rows

        my $recipient = $self->DB->getNode($username, 'user');
        unless ($recipient) {
            push @results, {success => 0, error => "Couldn't find user: $username"};
            next;
        }

        my $writeup = $b->{writeup};
        $writeup =~ s/^\s+|\s+$//g if defined $writeup;

        my $msg = $self->_send_webster_message($webster, $recipient, $writeup);
        unless ($msg->{success}) {
            push @results,
                {success => 0, error => "Failed to send message to $username: " . ($msg->{error} // '')};
            next;
        }

        # +1 karma
        $recipient->{karma} += 1;
        $self->DB->updateNode($recipient, -1);
        $self->APP->checkAchievementsByType('karma', $recipient->{user_id});

        # +3 GP
        $self->APP->adjustGP($recipient, $GP_AMOUNT);

        $self->APP->securityLog(SECLOG_WEBSTERBLESS, $user->NODEDATA,
            $user->title . " [Websterbless|Websterblessed] $recipient->{title} with $GP_AMOUNT GP.");

        push @results, {success => 1, message => "User $recipient->{title} was given $GP_AMOUNT GP"};
    }

    return [$self->HTTP_OK, {success => 1, results => \@results}];
}

# Automated thank-you PM from Webster 1913 to the recipient (renode = the writeup name
# when provided -- deliberately unchecked free text). Moved from the page.
sub _send_webster_message {
    my ($self, $webster, $recipient, $writeup_name) = @_;

    my $params = {
        from    => $webster,
        to      => $recipient,
        message => 'Thank you! My servants have attended to any errors.',
    };
    $params->{renode} = $writeup_name if ($writeup_name);

    my $result = $self->APP->send_message($params);
    if ($result->{errors}) {
        return {success => 0, error => $result->{errortext} || 'Failed to send message'};
    }
    return {success => 1};
}

__PACKAGE__->meta->make_immutable;

1;
