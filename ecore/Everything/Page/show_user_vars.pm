package Everything::Page::show_user_vars;

use Moose;
extends 'Everything::Page';

use Everything qw(getNode getVars);
use Everything::HTML qw(encodeHTML);

=head1 Everything::Page::show_user_vars

React page for Show User Vars - displays user variables for debugging.
Admin/Developer tool.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Must be logged in
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type          => 'show_user_vars',
            access_denied => 1,
            message       => 'Try logging in.'
        };
    }

    my $is_admin = $APP->isAdmin( $USER->NODEDATA );
    my $is_edev  = $APP->isDeveloper( $USER->NODEDATA );

    # Must be admin or developer
    unless ( $is_admin || $is_edev ) {
        return {
            type          => 'show_user_vars',
            access_denied => 1,
            message       => 'Ummmm... no.'
        };
    }

    # Determine which user to inspect
    my $inspect_user = $USER->NODEDATA;
    my $username     = $query->param('username');

    if ( $is_admin && $username ) {
        my $target = $DB->getNode( $username, 'user' );
        $inspect_user = $target if $target;
    }

    my $inspect_vars = $APP->getVars($inspect_user) || {};

    # Filter keys based on permission level
    my @valid_keys;
    if ($is_admin) {
        @valid_keys = keys %$inspect_vars;
    } else {
        # Limited set for developers
        @valid_keys = qw(
            borged coolnotification cools coolsafety
            emailSubscribedusers employment ipaddy level
            mission motto nick nodelets nohints nowhynovotes
            nullvote numborged numwriteups nwriteups
            personal_nodelet specialties
        );

        # Developers also see weblog-related vars
        if ($is_edev) {
            push @valid_keys, 'can_weblog', 'hidden_weblog';
            foreach my $key ( keys %$inspect_vars ) {
                if ( $key =~ /^hide_weblog_\d+$/ ) {
                    push @valid_keys, $key;
                }
            }
        }
    }

    @valid_keys = sort @valid_keys;

    # Build vars data
    my @vars_data;
    foreach my $key (@valid_keys) {
        next unless length($key);
        my $val = $inspect_vars->{$key};
        $val = '(null)' unless defined $val;
        push @vars_data, {
            key   => $key,
            value => $val
        };
    }

    # Build user data (admin only)
    my @user_data;
    if ($is_admin) {
        my @user_keys = sort keys %$inspect_user;
        foreach my $key (@user_keys) {
            next unless length($key);
            next if $key eq 'vars' || $key eq 'passwd';
            my $val = $inspect_user->{$key};
            $val = '(null)' unless defined $val;
            # Skip complex refs
            next if ref($val);
            push @user_data, {
                key   => $key,
                value => $val
            };
        }
    }

    return {
        type         => 'show_user_vars',
        is_admin     => $is_admin ? 1 : 0,
        is_developer => $is_edev ? 1 : 0,
        inspect_user => {
            node_id => $inspect_user->{node_id},
            title   => $inspect_user->{title}
        },
        vars_data    => \@vars_data,
        user_data    => \@user_data
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
