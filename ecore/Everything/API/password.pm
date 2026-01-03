package Everything::API::password;

use Moose;
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

    # Ensure user has salt (update password hash if needed)
    $APP->updatePassword($user, $user->{passwd}) unless $user->{salt};

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

    # Get mail template
    my $mail = $DB->getNode($mail_title, 'mail');
    return [$self->HTTP_OK, {success => 0, error => 'Email template not found'}]
        unless $mail;

    my %mail_data = %$mail;

    # Substitute template variables
    my $name = $user->{realname} || $user->{title};
    my $server_name = $ENV{SERVER_NAME} || 'everything2.com';

    $mail_data{doctext} =~ s/«name»/$name/g;
    $mail_data{doctext} =~ s/«link»/$link/g;
    $mail_data{doctext} =~ s/«servername»/$server_name/g;

    # Send email
    $APP->node2mail($user->{email}, \%mail_data, 1);

    # Log the action
    my $email_display = $user->{email} // '(no email)';
    $APP->securityLog(
        undef,
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
