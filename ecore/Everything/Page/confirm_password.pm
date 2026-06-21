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

    # Render the login form for a valid link. The actual activation/reset is
    # finalized client-side by POST /api/users/confirm, which validates the
    # token, sets the password, logs in, and (on activation) sends the welcome
    # PM, then returns the success state. #4335
    my $new_vars = $APP->getVars($user);
    my $display_action = $action;

    if ($new_vars->{infected}) {
        # New user infects current user
        $VARS->{infected} = 1 unless $USER->is_guest;
        $display_action = 'validate';
    }

    return {
        type     => 'confirm_password',
        state    => 'login_required',
        prompt   => "Please log in with your username and password to $display_action your account",
        username => $username,
        action   => $action,
        token    => $token,
        expiry   => $expiry,
    };
}

__PACKAGE__->meta->make_immutable;

1;
