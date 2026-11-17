package Everything::API::password;

use utf8;
use Moose;
use Everything::SecurityLog qw(SECLOG_ACCOUNT_LINK_REQUEST);
extends 'Everything::API';

sub routes {
    return {
        'reset-request' => 'reset_request',
    };
}

sub reset_request {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;

    my $data = $REQUEST->JSON_POSTDATA;
    my $who = $data->{who} // '';
    my $password = $data->{password} // '';
    my $password_confirm = $data->{passwordConfirm} // '';

    # Validate inputs
    return [$self->HTTP_OK, {success => 0, error => 'Please enter your username or email address'}]
        unless $who;

    return [$self->HTTP_OK, {success => 0, error => 'Please enter a new password'}]
        unless $password;

    return [$self->HTTP_OK, {success => 0, error => "Passwords don't match"}]
        unless $password eq $password_confirm;

    return [$self->HTTP_OK, {success => 0, error => 'Password must be at least 6 characters'}]
        if length($password) < 6;

    # Find user by username or email
    my $user = $DB->getNode($who, 'user');

    if (!$user && $who =~ /^\S+\@\S+\.\S+$/) {
        # Try to find by email
        my @users = $DB->getNodeWhere({email => $who}, 'user');
        $user = $users[0] if @users;
    }

    return [$self->HTTP_OK, {success => 0, error => 'Unknown user or email address'}]
        unless $user;

    # Guest User is not an account anyone can take over by setting a password.
    return [$self->HTTP_OK, {success => 0, error => 'Unknown user or email address'}]
        if $user->{node_id} == $self->CONF->guest_user;

    # Reset tokens are derived from the salt, so a pre-salt account gets its migrated form
    # first (never a hash of its stored value as if that were a password, which for an
    # account with no password would make the no-password marker itself work as one).
    # Only the password columns are written: never the rest of the row (lasttime is a memorial
    # for some accounts).
    unless ($user->{salt}) {
        ($user->{passwd}, $user->{salt}) = $APP->migrated_legacy_password($user);
        $DB->sqlUpdate('user', { passwd => $user->{passwd}, salt => $user->{salt} }, 'user_id=' . int($user->{node_id}));
        $DB->sqlInsert('version', { version_id => int($user->{node_id}), version => 1 }, { -version => 'version + 1' });
        $DB->{cache}->cacheNode($user) if $DB->{cache};
    }

    my $valid_for_minutes = 20;
    my ($action, $expiry, $mail_title, $blurb);

    if ($user->{lasttime}) {
        # Existing user - password reset
        $action = 'reset';
        $expiry = time() + $valid_for_minutes * 60;
        $mail_title = 'Everything2 password reset';
        $blurb = 'Your password reset link is on its way.';
    } else {
        # New user - account activation
        $action = 'activate';
        my ($mail_part, $expiry_part) = split /\|/, $user->{passwd};
        $mail_title = 'Welcome to Everything2';
        $blurb = 'You have been sent a new account activation link.';
        $expiry = $expiry_part || (time() + $valid_for_minutes * 60);
    }

    # Generate token link
    my $params = $APP->getTokenLinkParameters($user, $password, $action, $expiry);
    my $confirm_page = $DB->getNode('Confirm password', 'superdoc');

    return [$self->HTTP_OK, {success => 0, error => 'System configuration error'}]
        unless $confirm_page;

    my $link = $APP->urlGen($params, 'no quotes', $confirm_page);

    my $name = $user->{realname} || $user->{title};
    # The site's public host, from configuration. Not $ENV{SERVER_NAME}: under Starman that's
    # the listen address (127.0.0.1), whatever Host the request came in on (#4614).
    my $server_name = $self->CONF->canonical_web_server;

    my $mail = $APP->mail_from_template($mail_title, { name => $name, link => $link, servername => $server_name });
    return [$self->HTTP_OK, {success => 0, error => 'Email template not found'}]
        unless $mail;

    # Send email
    $APP->node2mail($user->{email}, $mail, 1);

    # Log the action
    my $email_display = $user->{email} // '(no email)';
    $APP->securityLog(
        SECLOG_ACCOUNT_LINK_REQUEST,
        $user,
        "$action link requested for [$user->{title}\[user]] ($email_display)"
    );

    return [$self->HTTP_OK, {
        success => 1,
        message => $blurb,
    }];
}

__PACKAGE__->meta->make_immutable;

1;
