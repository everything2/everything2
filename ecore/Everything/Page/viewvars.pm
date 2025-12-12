package Everything::Page::viewvars;

use Moose;
extends 'Everything::Page';

use Everything qw(getNode getVars);
use Everything::HTML qw(encodeHTML);

=head1 Everything::Page::viewvars

React page for Viewvars - displays current user's variables for debugging.
Admin-only tool. Reuses the ShowUserVars React component.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;

    # Must be logged in
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type          => 'show_user_vars',
            access_denied => 1,
            message       => 'Try logging in.'
        };
    }

    my $is_admin = $APP->isAdmin( $USER->NODEDATA );

    # Must be admin (Viewvars is restricted_superdoc)
    unless ( $is_admin ) {
        return {
            type          => 'show_user_vars',
            access_denied => 1,
            message       => 'Access denied. Admin only.'
        };
    }

    # Show current user's vars only (Viewvars doesn't allow username param)
    my $inspect_user = $USER->NODEDATA;
    my $inspect_vars = $APP->getVars($inspect_user) || {};

    # Show all vars for admin
    my @valid_keys = sort keys %$inspect_vars;

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

    # Build user data
    my @user_data;
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

    return {
        type         => 'show_user_vars',
        is_admin     => 1,
        is_developer => 0,
        inspect_user => {
            node_id => $inspect_user->{node_id},
            title   => $inspect_user->{title}
        },
        vars_data    => \@vars_data,
        user_data    => \@user_data,
        # Viewvars doesn't show the username form - it's current user only
        viewvars_mode => 1
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::show_user_vars>

=cut
