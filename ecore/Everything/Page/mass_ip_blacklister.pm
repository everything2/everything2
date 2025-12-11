package Everything::Page::mass_ip_blacklister;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::mass_ip_blacklister - Mass IP Blacklist management tool

=head1 DESCRIPTION

Admin tool for bulk-adding IP addresses that are barred from creating new accounts.
Accepts multiple IPs (one per line) for batch processing.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns blacklist data and handles bulk add/remove operations.

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
            type  => 'mass_ip_blacklister',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my @success_messages = ();
    my @error_messages   = ();
    my $posted_ips       = '';
    my $posted_reason    = '';

    # Handle remove operation
    if ( my $idToRemove = $query->param("remove_ip_block_ref") ) {
        $idToRemove = int $idToRemove;

        my $result = $self->removeIPFromBlacklist( $idToRemove, $USER );
        if ( $result->{success} ) {
            push @success_messages, $result->{message};
        }
        else {
            push @error_messages, $result->{message};
        }
    }

    # Handle bulk add operation
    if ( $query->param("add_ip_block") ) {
        my $ipList      = $query->param("bad_ips")     || '';
        my $blockReason = $query->param("block_reason") || '';

        # Split IPs by newlines and trim whitespace
        my @ipsToAdd = split /\r?\n/, $ipList;
        @ipsToAdd = grep { $_ =~ /\S/ } @ipsToAdd;    # Remove empty lines
        @ipsToAdd = map  { s/^\s+|\s+$//gr } @ipsToAdd;    # Trim whitespace

        if ( !@ipsToAdd ) {
            push @error_messages, 'You must list IPs to block.';
            # Preserve posted values on error
            $posted_ips    = $ipList;
            $posted_reason = $blockReason;
        }
        elsif ( !$blockReason ) {
            push @error_messages, 'You must give a reason to block these IPs.';
            # Preserve posted values on error
            $posted_ips    = $ipList;
            $posted_reason = $blockReason;
        }
        else {
            # Process each IP
            my $had_error = 0;
            foreach my $ipToAdd (@ipsToAdd) {
                next unless $ipToAdd;    # Skip empty entries

                my $result = $self->addIPToBlacklist( $ipToAdd, $blockReason, $USER );
                if ( $result->{success} ) {
                    push @success_messages, $result->{message};
                }
                else {
                    push @error_messages, $result->{message};
                    $had_error = 1;
                }
            }
            # Only preserve posted values if there were errors
            if ($had_error) {
                $posted_ips    = $ipList;
                $posted_reason = $blockReason;
            }
        }
    }

    # Get blacklist entries with pagination
    my $offset    = int( $query->param('offset') ) || 0;
    my $page_size = 200;

    my $entries = $self->getBlacklistEntries( $offset, $page_size );

    # Get guest user ID for link
    my $guest_user_id = $Everything::CONF->guest_user;

    return {
        type             => 'mass_ip_blacklister',
        success_messages => \@success_messages,
        error_messages   => \@error_messages,
        entries          => $entries->{items},
        total_count      => $entries->{total},
        offset           => $offset,
        page_size        => $page_size,
        guest_user_id    => $guest_user_id,
        posted_ips       => $posted_ips,
        posted_reason    => $posted_reason
    };
}

=head2 addIPToBlacklist($ip, $reason, $USER)

Adds a single IP address to the blacklist.
Note: Unlike the regular IP Blacklist, this doesn't support CIDR ranges.

=cut

sub addIPToBlacklist {
    my ( $self, $ipToAdd, $blockReason, $USER ) = @_;

    my $DB  = $self->DB;
    my $APP = $self->APP;

    # Validate IP address
    unless ( $ipToAdd =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ ) {
        return {
            success => 0,
            message => "'$ipToAdd' is not a valid IP address"
        };
    }
    if ( $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255 ) {
        return {
            success => 0,
            message => "'$ipToAdd' is not a valid IP address"
        };
    }

    # Check if already blacklisted
    my $listRef = $DB->sqlSelect( 'ipblacklistref_id', 'ipblacklist',
        "ipblacklist_ipaddress = " . $DB->quote($ipToAdd) );

    my $data = {
        ipblacklist_user      => $USER->node_id,
        ipblacklist_ipaddress => $ipToAdd
    };

    my $update = 0;

    if ($listRef) {
        $data->{ipblacklistref_id} = $listRef;
        $update = {
            %$data,
            -ipblacklist_comment =>
              'CONCAT('
              . $DB->quote("$blockReason <br>&#91;")
              . ", ipblacklist_timestamp, ']: ', ipblacklist_comment)"
        };
    }
    else {
        $DB->sqlInsert( 'ipblacklistref', {} );
        $data->{-ipblacklistref_id}  = 'LAST_INSERT_ID()';
        $data->{ipblacklist_comment} = $blockReason;
    }

    my $result = $DB->sqlInsert( 'ipblacklist', $data, $update );

    if ($result) {
        my $action =
          $listRef ? "updated IP blacklist entry for" : "added $ipToAdd to IP blacklist";
        $APP->securityLog(
            $self->DB->getNode( 'Mass IP Blacklister', 'restricted_superdoc' ),
            $USER->NODEDATA,
            $USER->title . " $action: \"$blockReason.\""
        );
        my $message =
            $listRef
          ? "Updated IP blacklist entry for $ipToAdd"
          : "The IP \"$ipToAdd\" was successfully added to the blacklist.";
        return { success => 1, message => $message };
    }
    else {
        return {
            success => 0,
            message => "Error adding $ipToAdd to blacklist"
        };
    }
}

=head2 removeIPFromBlacklist($id, $USER)

Removes an IP address or range from the blacklist.

=cut

sub removeIPFromBlacklist {
    my ( $self, $idToRemove, $USER ) = @_;

    my $DB  = $self->DB;
    my $APP = $self->APP;

    my $selectAddrFromBlacklistSQL = qq|
SELECT
    IFNULL(ipblacklist.ipblacklist_ipaddress,
        CONCAT(ipblacklistrange.min_ip, ' - ', ipblacklistrange.max_ip)
    ) ipblacklist_ipaddress
    FROM ipblacklistref
    LEFT JOIN ipblacklist
        ON ipblacklistref.ipblacklistref_id =
            ipblacklist.ipblacklistref_id
    LEFT JOIN ipblacklistrange
        ON ipblacklistref.ipblacklistref_id =
            ipblacklistrange.ipblacklistref_id
    WHERE ipblacklistref.ipblacklistref_id = $idToRemove|;

    my @blacklistAddressArray =
      @{ $DB->{dbh}->selectall_arrayref($selectAddrFromBlacklistSQL) };
    my $blAddress = $blacklistAddressArray[0]->[0];

    my $removeFromBlacklistSQL = qq|
DELETE ipblacklist, ipblacklistref, ipblacklistrange
    FROM ipblacklistref
    LEFT JOIN ipblacklist
        ON ipblacklistref.ipblacklistref_id =
            ipblacklist.ipblacklistref_id
    LEFT JOIN ipblacklistrange
        ON ipblacklistref.ipblacklistref_id =
            ipblacklistrange.ipblacklistref_id
    WHERE ipblacklistref.ipblacklistref_id = $idToRemove|;

    my $saveRaise = $DB->{dbh}->{RaiseError};
    $DB->{dbh}->{RaiseError} = 1;
    my $eval_ok = eval { $DB->{dbh}->do($removeFromBlacklistSQL); 1 };
    $DB->{dbh}->{RaiseError} = $saveRaise;

    if (!$eval_ok) {
        return {
            success => 0,
            message =>
              "There was an error removing this block from the database: " . $DB->{dbh}->errstr()
        };
    }
    else {
        $APP->securityLog(
            $self->DB->getNode( 'Mass IP Blacklister', 'restricted_superdoc' ),
            $USER->NODEDATA,
            $USER->title . " removed $blAddress from the IP blacklist."
        );
        return {
            success => 1,
            message => "The IP \"$blAddress\" was successfully removed from the blacklist."
        };
    }
}

=head2 getBlacklistEntries($offset, $limit)

Retrieves blacklist entries with pagination.

=cut

sub getBlacklistEntries {
    my ( $self, $offset, $limit ) = @_;

    my $DB = $self->DB;

    my $sql = qq|
SELECT
    ipblacklistref.ipblacklistref_id,
    ipblacklist.ipblacklist_ipaddress,
    ipblacklist.ipblacklist_comment,
    ipblacklist.ipblacklist_timestamp,
    ipblacklistrange.min_ip,
    ipblacklistrange.max_ip,
    ipblacklistrange.comment AS range_comment,
    ipblacklistrange.ban_timestamp AS range_timestamp
FROM ipblacklistref
LEFT JOIN ipblacklist
    ON ipblacklistref.ipblacklistref_id = ipblacklist.ipblacklistref_id
LEFT JOIN ipblacklistrange
    ON ipblacklistref.ipblacklistref_id = ipblacklistrange.ipblacklistref_id
ORDER BY ipblacklistref.ipblacklistref_id DESC
LIMIT $offset, $limit|;

    my $csr = $DB->{dbh}->prepare($sql);
    $csr->execute();

    my @entries = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        my $entry = {
            id => $row->{ipblacklistref_id},
        };

        # Handle ranges vs individual IPs
        if ( defined $row->{min_ip} ) {
            my ( $minAddr, $maxAddr ) =
              ( $self->addrFromInt( $row->{min_ip} ), $self->addrFromInt( $row->{max_ip} ) );
            my $bits = $self->rangeBitsFromInts( $row->{min_ip}, $row->{max_ip} );

            if ( defined $bits ) {
                $entry->{ip_address} = "$minAddr/$bits";
            }
            else {
                $entry->{ip_address} = "$minAddr - $maxAddr";
            }

            $entry->{comment}   = $row->{range_comment};
            $entry->{timestamp} = $row->{range_timestamp};
        }
        else {
            $entry->{ip_address} = $row->{ipblacklist_ipaddress};
            $entry->{comment}    = $row->{ipblacklist_comment};
            $entry->{timestamp}  = $row->{ipblacklist_timestamp};
        }

        push @entries, $entry;
    }

    # Get total count for pagination
    my $total = $DB->sqlSelect( 'COUNT(*)', 'ipblacklistref' );

    return {
        items => \@entries,
        total => $total
    };
}

=head2 addrFromInt($int)

Converts an integer to an IP address string.

=cut

sub addrFromInt {
    my ( $self, $intAddr ) = @_;

    my ( $oc1, $oc2, $oc3, $oc4 ) = (
        $intAddr & 255,
        ( $intAddr >> 8 ) & 255,
        ( $intAddr >> 16 ) & 255,
        ( $intAddr >> 24 ) & 255
    );

    return "$oc4.$oc3.$oc2.$oc1";
}

=head2 rangeBitsFromInts($min, $max)

Calculates the number of CIDR bits from a range min/max.

Returns the number of bits if it's a valid CIDR range, undef otherwise.

=cut

sub rangeBitsFromInts {
    my ( $self, $minAddr, $maxAddr ) = @_;

    my $diff     = abs( $maxAddr - $minAddr ) + 1;
    my $log2diff = log($diff) / log(2);
    my $epsilon  = 1e-11;

    return if ( ( $log2diff - int($log2diff) ) > $epsilon );
    return ( 32 - $log2diff );
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
