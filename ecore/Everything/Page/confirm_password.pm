package Everything::Page::confirm_password;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $q = $REQUEST->cgi;

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

    # Check expiry. We no longer delete the unactivated account here -- expired
    # unactivated accounts just linger (harmless; can't log in) and cleanup is deferred to
    # a safe, phased maintenance job in the post-ORM / login-with-Google account rework
    # (#4476). This keeps buildReactData free of the GET-mutation.
    if ($expiry && time() > $expiry) {
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

    # Render the login form for a valid link. The actual activation/reset is finalized
    # client-side by POST /api/users/confirm, which validates the token, sets the password,
    # logs in, and (on activation) sends the welcome PM, then returns the success state.
    # #4335. (The old "infection spreads to the viewer here" GET-mutation was removed --
    # the infected_ips shadowban has been effectively dead since 2010; retiring it wholesale
    # is tracked in #4465.)
    return {
        type     => 'confirm_password',
        state    => 'login_required',
        prompt   => "Please log in with your username and password to $action your account",
        username => $username,
        action   => $action,
        token    => $token,
        expiry   => $expiry,
    };
}

__PACKAGE__->meta->make_immutable;

1;
