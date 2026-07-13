package Everything::API::ip_hunter;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::ip_hunter - admin IP / login-history lookup

=head1 DESCRIPTION

Admin forensic tool: given a username, list the IPs they've logged in from (flagging banned ones);
given an IP, list the users who have logged in from it. Moved out of
C<Everything::Page::ip_hunter>'s buildReactData (#4530): the Page is a pure gate, React reads
hunt_name/hunt_ip off the URL and calls this.

  GET /api/ip_hunter?hunt_name=<name>
  GET /api/ip_hunter?hunt_ip=<ip>

Admin-only. Ships data + an error C<state> ('admin' / 'user_not_found'); the copy lives in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    # Logs before this id predate 2003 and are skipped (legacy noise); cap result rows.
    my $low_id = 1500000;
    my $limit  = 500;

    my $hunt_name = $REQUEST->param('hunt_name');
    my $hunt_ip   = $REQUEST->param('hunt_ip');
    $hunt_name = defined($hunt_name) ? $hunt_name : '';
    $hunt_ip   = defined($hunt_ip)   ? $hunt_ip   : '';
    $hunt_name =~ s/^\s+|\s+$//g;
    $hunt_ip   =~ s/^\s+|\s+$//g;

    # No search yet: empty shell (React shows the search form).
    return [$self->HTTP_OK, { success => 1, result_limit => $limit }]
        unless $hunt_name ne '' || $hunt_ip ne '';

    # --- search by IP: who logged in from this address ---------------------
    if ($hunt_ip ne '') {
        my $csr = $DB->sqlSelectMany(
            'iplog.*', 'iplog',
            "iplog_id > $low_id AND iplog_ipaddy = " . $DB->quote($hunt_ip) . " ORDER BY iplog_id DESC",
            "LIMIT $limit"
        );
        my @results;
        while (my $row = $csr->fetchrow_hashref) {
            my $u = $DB->getNodeById($row->{iplog_user}, 'light');
            push @results, {
                user_id    => $u ? int($u->{node_id}) : 0,
                user_title => $u ? $u->{title} : 'Deleted user',
                time       => $row->{iplog_time},
            };
        }
        return [$self->HTTP_OK, {
            success => 1, search_type => 'ip', search_value => $hunt_ip,
            results => \@results, result_limit => $limit,
        }];
    }

    # --- search by username: which IPs this user logged in from ------------
    # The banned / banned_ranged subselects flag IPs on the single-IP blacklist and
    # inside any blacklisted CIDR range, respectively.
    my $select = q|
        iplog.*
        , (SELECT ipblacklist.ipblacklistref_id
            FROM ipblacklist
            WHERE iplog.iplog_ipaddy = ipblacklist_ipaddress
        ) 'banned'
        , (SELECT MAX(ipblacklistrange.ipblacklistref_id)
            FROM ipblacklistrange
            WHERE INET_ATON(iplog.iplog_ipaddy) BETWEEN min_ip AND max_ip
        ) 'banned_ranged'|;

    my $usr = $DB->getNode($hunt_name, 'user');
    return [$self->HTTP_OK, { success => 0, state => 'user_not_found', search_value => $hunt_name }]
        unless $usr;

    my $uid = int($usr->{node_id});   # int -> injection-safe
    my $csr = $DB->sqlSelectMany(
        $select, 'iplog',
        "iplog_id > $low_id AND iplog_user = $uid ORDER BY iplog_id DESC",
        "LIMIT $limit"
    );
    my @results;
    while (my $row = $csr->fetchrow_hashref) {
        push @results, {
            ip            => $row->{iplog_ipaddy},
            time          => $row->{iplog_time},
            banned        => $row->{banned}        ? 1 : 0,
            banned_ranged => $row->{banned_ranged} ? 1 : 0,
        };
    }
    return [$self->HTTP_OK, {
        success => 1, search_type => 'user', search_value => $hunt_name,
        # 0 + $uid: $uid was interpolated into SQL above, which sets its string flag,
        # so JSON would otherwise ship the node_id as a string. Re-numify (#4152).
        user_id => 0 + $uid, user_title => $usr->{title},
        results => \@results, result_limit => $limit,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
