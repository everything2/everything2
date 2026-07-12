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

    # The Page computes the backend-derived STATE (token/action/expiry/user validation); React
    # (ConfirmPassword) owns the human-readable copy for each state, keyed on it (#4511). We ship
    # only { type, state } plus genuinely backend-derived data (resolved node links, the login-form
    # inputs), never the message/error/prompt copy.

    # Check for required parameters
    unless ($token && $action && $username) {
        return {
            type  => 'confirm_password',
            state => 'missing_params',
        };
    }

    # Validate action
    unless ($action eq 'activate' || $action eq 'reset') {
        return {
            type  => 'confirm_password',
            state => 'invalid_action',
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
            type      => 'confirm_password',
            state     => 'expired',
            renewLink => $link_node ? "/node/$link_node->{node_id}" : undef,
        };
    }

    # Check if user exists
    unless ($user) {
        my $signup = $DB->getNode('Sign up', 'superdoc');
        return {
            type       => 'confirm_password',
            state      => 'no_user',
            signupLink => $signup ? "/node/$signup->{node_id}" : undef,
        };
    }

    # Check for locked account
    if ($action eq 'activate' && $user->{acctlock}) {
        return {
            type  => 'confirm_password',
            state => 'locked',
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
        username => $username,
        action   => $action,
        token    => $token,
        expiry   => $expiry,
    };
}

__PACKAGE__->meta->make_immutable;

1;
