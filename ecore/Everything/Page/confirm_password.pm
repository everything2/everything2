package Everything::Page::confirm_password;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $q = $REQUEST->cgi;
    my $VARS = $USER->VARS;

    my $token = $q->param('token') // '';
    my $action = $q->param('action') // '';
    my $expiry = $q->param('expiry') // '';
    my $username = $q->param('user') // '';

    # Check for required parameters
    unless ($token && $action && $username) {
        return {
            type    => 'confirm_password',
            state   => 'missing_params',
            message => 'To use this page, please click on or copy and paste the link from the email we sent you. If we didn\'t send you an email, you don\'t need this page.',
        };
    }

    # Validate action
    unless ($action eq 'activate' || $action eq 'reset') {
        return {
            type  => 'confirm_password',
            state => 'invalid_action',
            error => 'Invalid action.',
        };
    }

    my $user = $DB->getNode($username, 'user');

    # Check expiry
    if ($expiry && time() > $expiry) {
        # Nuke unactivated account if applicable
        if ($action eq 'activate' && $user && !$user->{lasttime} && $expiry =~ /$user->{passwd}/) {
            $DB->nukeNode($user, -1, 'no tombstone');
        }

        my $link_page = $action eq 'reset' ? 'Reset password' : 'Sign up';
        my $link_node = $DB->getNode($link_page, 'superdoc');

        return {
            type       => 'confirm_password',
            state      => 'expired',
            message    => 'This link has expired.',
            renewLink  => $link_node ? "/node/$link_node->{node_id}" : undef,
            renewLabel => 'get a new one',
        };
    }

    # Check if user exists
    unless ($user) {
        my $signup = $DB->getNode('Sign up', 'superdoc');
        return {
            type       => 'confirm_password',
            state      => 'no_user',
            message    => 'The account you are trying to activate does not exist.',
            signupLink => $signup ? "/node/$signup->{node_id}" : undef,
        };
    }

    # Check for locked account
    if ($action eq 'activate' && $user->{acctlock}) {
        return {
            type  => 'confirm_password',
            state => 'locked',
            error => 'We\'re sorry, but we don\'t accept new users from the IP address you used to create this account. Please get in touch with us if you think this is a mistake.',
        };
    }

    # Check if login was attempted
    my $op = $q->param('op') // '';
    my $old_salt = $q->param('oldsalt') // '';
    my $prompt = '';

    if ($op ne 'login') {
        # Check for locked-user infection
        my $new_vars = $APP->getVars($user);
        my $display_action = $action;

        if ($new_vars->{infected}) {
            # New user infects current user
            $VARS->{infected} = 1 unless $USER->is_guest;
            $display_action = 'validate';
        }

        $prompt = "Please log in with your username and password to $display_action your account";
    } elsif ($USER->title ne $username || $USER->NODEDATA->{salt} eq $old_salt) {
        $prompt = 'Password or link invalid. Please try again';
    }

    # If prompt is set, show login form
    if ($prompt) {
        return {
            type          => 'confirm_password',
            state         => 'login_required',
            prompt        => $prompt,
            username      => $username,
            action        => $action,
            token         => $token,
            expiry        => $expiry,
            currentSalt   => $USER->NODEDATA->{salt},
        };
    }

    # Success - password was reset or account activated
    if ($action eq 'reset') {
        return {
            type    => 'confirm_password',
            state   => 'success_reset',
            message => 'Password updated. You are logged in.',
        };
    }

    # Account activation success - send welcome message
    my $virgil = $DB->getNode('Virgil', 'user');
    if ($virgil) {
        $APP->sendPrivateMessage({
            author_id    => $virgil->{node_id},
            recipient_id => $USER->NODEDATA->{node_id},
            message      => q|Welcome to E2! We hope you're enjoying the site. If you haven't already done so, we recommend reading both [E2 Quick Start] and [Links on Everything2] before you start writing anything. If you have any questions or need help, feel free to ask any editor (editors have a $ next to their names in the Other Users list)|
        });
    }

    return {
        type       => 'confirm_password',
        state      => 'success_activate',
        message    => 'Your account has been activated and you have been logged in.',
        profileUrl => "/node/" . $USER->NODEDATA->{node_id},
    };
}

__PACKAGE__->meta->make_immutable;

1;
