package Everything::Page::ip_blacklist;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::ip_blacklist - IP Blacklist management tool

=head1 DESCRIPTION

Admin tool for managing IP addresses that are barred from creating new accounts.
Supports individual IPs and CIDR ranges.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns blacklist data and handles add/remove operations.

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
            type  => 'ip_blacklist',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my $success_message = '';
    my $error_message   = '';
    my $posted_ip       = '';
    my $posted_reason   = '';

    # Handle remove operation
    if ( my $idToRemove = $query->param("remove_ip_block_ref") ) {
        $idToRemove = int $idToRemove;

        my $result = $self->removeIPFromBlacklist( $idToRemove, $USER );
        if ( $result->{success} ) {
            $success_message = $result->{message};
        }
        else {
            $error_message = $result->{message};
        }
    }

    # Handle add operation
    if ( $query->param("add_ip_block") ) {
        my $ipToAdd     = $query->param("bad_ip")      || '';
        my $blockReason = $query->param("block_reason") || '';

        if ( !$ipToAdd ) {
            $error_message = 'You must list an IP to block.';
            # Preserve posted values on error
            $posted_ip     = $ipToAdd;
            $posted_reason = $blockReason;
        }
        elsif ( !$blockReason ) {
            $error_message = 'You must give a reason to block this IP.';
            # Preserve posted values on error
            $posted_ip     = $ipToAdd;
            $posted_reason = $blockReason;
        }
        else {
            my $result = $self->addIPToBlacklist( $ipToAdd, $blockReason, $USER );
            if ( $result->{success} ) {
                $success_message = $result->{message};
                # Clear form on success
            }
            else {
                $error_message = $result->{message};
                # Preserve posted values on error
                $posted_ip     = $ipToAdd;
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
        type            => 'ip_blacklist',
        success_message => $success_message,
        error_message   => $error_message,
        entries         => $entries->{items},
        total_count     => $entries->{total},
        offset          => $offset,
        page_size       => $page_size,
        guest_user_id   => $guest_user_id,
        posted_ip       => $posted_ip,
        posted_reason   => $posted_reason
    };
}

=head2 addIPToBlacklist($ip, $reason, $USER)

Adds an IP address or CIDR range to the blacklist.

=cut

sub addIPToBlacklist {
    my ( $self, $ipToAdd, $blockReason, $USER ) = @_;

    my $DB  = $self->DB;
    my $APP = $self->APP;

    # Check if it's a CIDR range
    my ( $isRangeAddr, $rangeMin, $rangeMax ) = $self->parseCIDRRange($ipToAdd);

    # For single IPs, use the blacklistIP htmlcode
    if ( !$isRangeAddr ) {
        # Validate single IP
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
            $data->{-ipblacklistref_id} = 'LAST_INSERT_ID()';
            $data->{ipblacklist_comment} = $blockReason;
        }

        my $result = $DB->sqlInsert( 'ipblacklist', $data, $update );

        if ($result) {
            my $action = $listRef ? "updated IP blacklist entry for" : "added $ipToAdd to IP blacklist";
            $APP->securityLog(
                $self->DB->getNode( 'IP Blacklist', 'restricted_superdoc' ),
                $USER->NODEDATA,
                $USER->title . " $action: \"$blockReason.\""
            );
            my $message = $listRef ? "Updated IP blacklist entry for $ipToAdd" : "The IP \"$ipToAdd\" was successfully added to the blacklist.";
            return { success => 1, message => $message };
        }
        else {
            return {
                success => 0,
                message => "Error adding $ipToAdd to blacklist"
            };
        }
    }

    # Add CIDR range
    # Add CIDR range
    my $addBlacklistRefSQL = q|INSERT INTO ipblacklistref () VALUES ()|;

    my $addBlacklistSQL = "INSERT INTO ipblacklistrange\n";
    $addBlacklistSQL .= "    (banner_user_id, min_ip, max_ip, comment, ipblacklistref_id)\n";
    $addBlacklistSQL .= "    VALUES (" . $USER->node_id . ", "
      . $rangeMin . ", "
      . $rangeMax . ", "
      . $DB->quote($blockReason)
      . ", LAST_INSERT_ID())";


    my $saveRaise = $DB->{dbh}->{RaiseError};
    $DB->{dbh}->{RaiseError} = 1;
    my $eval_ok = eval {
        $DB->{dbh}->do($addBlacklistRefSQL);
        $DB->{dbh}->do($addBlacklistSQL);
        1;
    };
    $DB->{dbh}->{RaiseError} = $saveRaise;

    if (!$eval_ok) {
        return {
            success => 0,
            message =>
              "There was an error adding this block to the database: " . $DB->{dbh}->errstr()
        };
    }
    else {
        $APP->securityLog(
            $self->DB->getNode( 'IP Blacklist', 'restricted_superdoc' ),
            $USER->NODEDATA,
            $USER->title . " added $ipToAdd to the IP blacklist: \"$blockReason.\""
        );

        return {
            success => 1,
            message => "The IP range \"$ipToAdd\" was successfully added to the blacklist."
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
            $self->DB->getNode( 'IP Blacklist', 'restricted_superdoc' ),
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

=head2 parseCIDRRange($cidr)

Parses a CIDR notation IP range (e.g., "192.168.1.0/24") into min and max integer values.

Returns (1, $min, $max) if valid CIDR range, or () if not.

=cut

sub parseCIDRRange {
    my ( $self, $cidrIP ) = @_;

    return () unless $cidrIP =~ m/^(\d{1,3}\.\d{1,3}.\d{1,3}\.\d{1,3})\s*\/(\d{1,2})$/;
    my $addr = $1;
    my $bits = $2;

    my $intAddr = $self->intFromAddr($addr);
    return () unless $intAddr;
    return () unless $bits < 33 && $bits > 7;

    my $maxAddr = $self->intFromAddr('255.255.255.255');
    my $mask    = ( $maxAddr << ( 32 - $bits ) ) & $maxAddr;

    my $validAddr = 1;
    my $addrMin   = $intAddr & $mask;
    my $addrMax   = $addrMin + ( $maxAddr >> $bits );

    return ( $validAddr, $addrMin, $addrMax );
}

=head2 intFromAddr($ipaddr)

Converts an IP address string to an integer.

=cut

sub intFromAddr {
    my ( $self, $addr ) = @_;

    return unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return if $1 > 255 or $2 > 255 or $3 > 255 or $4 > 255;

    return ( ( int $1 ) * 256 * 256 * 256
          + ( int $2 ) * 256 * 256
          + ( int $3 ) * 256
          + ( int $4 ) );
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
