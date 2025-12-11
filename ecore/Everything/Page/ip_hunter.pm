package Everything::Page::ip_hunter;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::ip_hunter - IP Hunter admin tool

=head1 DESCRIPTION

Admin tool for tracking IP addresses and user login history.
Allows searching by username or IP address to see login patterns.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns IP lookup results based on query parameters.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Only admins can access
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type  => 'ip_hunter',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    # Get search params from POST or GET
    my $hunt_name = $query->param('hunt_name') || '';
    my $hunt_ip   = $query->param('hunt_ip')   || '';

    # Trim whitespace
    $hunt_name =~ s/^\s+|\s+$//g if $hunt_name;
    $hunt_ip   =~ s/^\s+|\s+$//g if $hunt_ip;

    # Constants
    my $result_limit = 500;
    my $low_id       = 1500000;    # Logs before 2003

    # No search params - show search form only
    if ( !$hunt_name && !$hunt_ip ) {
        return {
            type         => 'ip_hunter',
            result_limit => $result_limit
        };
    }

    # Search by IP
    if ($hunt_ip) {
        my $ip = $APP->encodeHTML($hunt_ip);

        my $csr = $DB->sqlSelectMany(
            'iplog.*',
            'iplog',
            "iplog_id > $low_id AND iplog_ipaddy = "
              . $DB->quote($ip)
              . " ORDER BY iplog_id DESC",
            "LIMIT $result_limit"
        );

        my @results = ();
        while ( my $row = $csr->fetchrow_hashref ) {
            my $logged_user = $DB->getNodeById( $row->{iplog_user}, 'light' );

            push @results,
              {
                user_id    => $logged_user ? $logged_user->{node_id} : 0,
                user_title => $logged_user
                ? $logged_user->{title}
                : 'Deleted user',
                time => $row->{iplog_time}
              };
        }

        return {
            type         => 'ip_hunter',
            search_type  => 'ip',
            search_value => $ip,
            results      => \@results,
            result_limit => $result_limit
        };
    }

    # Search by username
    if ( defined $hunt_name ) {
        my $usr = undef;
        my $csr = undef;

        my $select_string = q|
        iplog.*
        , (SELECT ipblacklist.ipblacklistref_id
            FROM ipblacklist
            WHERE iplog.iplog_ipaddy = ipblacklist_ipaddress
        ) 'banned'
        , (SELECT MAX(ipblacklistrange.ipblacklistref_id)
            FROM ipblacklistrange
            WHERE ip_to_uint(iplog.iplog_ipaddy) BETWEEN min_ip AND max_ip
        ) 'banned_ranged'|;

        if ( $hunt_name ne '' ) {
            $usr = $DB->getNode( $hunt_name, 'user' );
            unless ($usr) {
                return {
                    type  => 'ip_hunter',
                    error => "No such user: $hunt_name"
                };
            }

            $csr = $DB->sqlSelectMany(
                $select_string,
                'iplog',
"iplog_id > $low_id AND iplog_user = '$usr->{user_id}' ORDER BY iplog_id DESC",
                "LIMIT $result_limit"
            );
        }
        else {
            # Empty username = search for deleted users
            $csr = $DB->sqlSelectMany(
                $select_string,
                'iplog LEFT JOIN user ON iplog_user = user.user_id',
"iplog_id > $low_id AND user.user_id IS NULL ORDER BY iplog_id DESC",
                "LIMIT $result_limit"
            );
        }

        my @results = ();
        while ( my $row = $csr->fetchrow_hashref ) {
            push @results,
              {
                ip            => $row->{iplog_ipaddy},
                time          => $row->{iplog_time},
                banned        => $row->{banned}        ? 1 : 0,
                banned_ranged => $row->{banned_ranged} ? 1 : 0
              };
        }

        return {
            type         => 'ip_hunter',
            search_type  => 'user',
            search_value => $hunt_name,
            user_id      => $usr ? $usr->{user_id} : 0,
            user_title   => $usr ? $usr->{title}   : 'Deleted users',
            results      => \@results,
            result_limit => $result_limit
        };
    }

    return { type => 'ip_hunter' };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
