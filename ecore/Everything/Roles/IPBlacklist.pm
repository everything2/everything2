package Everything::Roles::IPBlacklist;

use Moose::Role;

# Shared IP-blacklist logic (#4464, Refs #4298). Extracted from the ~90%-duplicated
# Everything::Page::ip_blacklist and Everything::Page::mass_ip_blacklister so both the
# pure-render pages and the new Everything::API::ip_blacklist / ::mass_ip_blacklister
# endpoints share one implementation. The securityLog event is passed in by the caller
# (SECLOG_IP_BLACKLIST vs SECLOG_IP_BLACKLIST_MASS), which is the only real difference in
# the mutation path.
#
# Consumers must provide DB() and APP() (Everything::Page and Everything::API both do).
requires qw(DB APP);

# ---- reads ----------------------------------------------------------------

# Human-readable address label for a joined row (ipblacklist_ipaddress / min_ip / max_ip).
# Ranges render as CIDR (min/bits) when they line up, else "min - max" -- always dotted
# addresses, never the raw integers stored in ipblacklistrange.
sub _format_entry_address {
    my ($self, $row) = @_;
    return unless $row;

    if (defined $row->{min_ip}) {
        my ($minAddr, $maxAddr) =
            ($self->addr_from_int($row->{min_ip}), $self->addr_from_int($row->{max_ip}));
        my $bits = $self->range_bits_from_ints($row->{min_ip}, $row->{max_ip});
        return defined $bits ? "$minAddr/$bits" : "$minAddr - $maxAddr";
    }
    return $row->{ipblacklist_ipaddress};
}

# Paginated blacklist entries: { items => [...], total => N }.
sub get_blacklist_entries {
    my ($self, $offset, $limit) = @_;
    my $DB = $self->DB;

    $offset = 0   unless (defined $offset && $offset =~ /^\d+$/);
    $limit  = 200 unless (defined $limit  && $limit  =~ /^\d+$/);

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
-- Skip orphaned refs (no ipblacklist/ipblacklistrange partner); they'd otherwise render
-- as blank rows with a live Remove button (#4464 follow-up).
WHERE ipblacklist.ipblacklist_ipaddress IS NOT NULL OR ipblacklistrange.min_ip IS NOT NULL
ORDER BY ipblacklistref.ipblacklistref_id DESC
LIMIT | . int($offset) . ', ' . int($limit);

    my $csr = $DB->{dbh}->prepare($sql);
    $csr->execute();

    my @entries = ();
    while (my $row = $csr->fetchrow_hashref) {
        my $entry = {
            id         => $row->{ipblacklistref_id},
            ip_address => $self->_format_entry_address($row),
        };

        if (defined $row->{min_ip}) {
            $entry->{comment}   = $row->{range_comment};
            $entry->{timestamp} = $row->{range_timestamp};
        } else {
            $entry->{comment}   = $row->{ipblacklist_comment};
            $entry->{timestamp} = $row->{ipblacklist_timestamp};
        }

        push @entries, $entry;
    }

    # Count only refs that actually have an address partner, so the total matches the
    # filtered rows above (orphaned refs are excluded from both).
    my ($total) = $DB->{dbh}->selectrow_array(q|
SELECT COUNT(*)
FROM ipblacklistref
LEFT JOIN ipblacklist
    ON ipblacklistref.ipblacklistref_id = ipblacklist.ipblacklistref_id
LEFT JOIN ipblacklistrange
    ON ipblacklistref.ipblacklistref_id = ipblacklistrange.ipblacklistref_id
WHERE ipblacklist.ipblacklist_ipaddress IS NOT NULL OR ipblacklistrange.min_ip IS NOT NULL|);

    return {items => \@entries, total => ($total || 0)};
}

# ---- mutations ------------------------------------------------------------

# Add a single IP (no CIDR). Used directly by the mass tool.
sub add_single_ip {
    my ($self, $ipToAdd, $blockReason, $USER, $event) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    unless ($ipToAdd =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
        return {success => 0, message => "'$ipToAdd' is not a valid IP address"};
    }
    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
        return {success => 0, message => "'$ipToAdd' is not a valid IP address"};
    }

    my $listRef = $DB->sqlSelect('ipblacklistref_id', 'ipblacklist',
        'ipblacklist_ipaddress = ' . $DB->quote($ipToAdd));

    my $data = {
        ipblacklist_user      => $USER->node_id,
        ipblacklist_ipaddress => $ipToAdd,
    };

    my $update = 0;

    if ($listRef) {
        $data->{ipblacklistref_id} = $listRef;
        $update = {
            %$data,
            -ipblacklist_comment => 'CONCAT('
                . $DB->quote("$blockReason <br>&#91;")
                . ", ipblacklist_timestamp, ']: ', ipblacklist_comment)",
        };
    } else {
        $DB->sqlInsert('ipblacklistref', {});
        $data->{-ipblacklistref_id}  = 'LAST_INSERT_ID()';
        $data->{ipblacklist_comment} = $blockReason;
    }

    my $result = $DB->sqlInsert('ipblacklist', $data, $update);

    if ($result) {
        my $action = $listRef ? "updated IP blacklist entry for" : "added $ipToAdd to IP blacklist";
        $APP->securityLog($event, $USER->NODEDATA, $USER->title . " $action: \"$blockReason.\"");
        my $message = $listRef
            ? "Updated IP blacklist entry for $ipToAdd"
            : "The IP \"$ipToAdd\" was successfully added to the blacklist.";
        return {success => 1, message => $message};
    }
    return {success => 0, message => "Error adding $ipToAdd to blacklist"};
}

# Add a single IP OR a CIDR range. Used by the regular (non-mass) tool.
sub add_ip_or_range {
    my ($self, $ipToAdd, $blockReason, $USER, $event) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    my ($isRangeAddr, $rangeMin, $rangeMax) = $self->parse_cidr_range($ipToAdd);
    return $self->add_single_ip($ipToAdd, $blockReason, $USER, $event) unless $isRangeAddr;

    my $addBlacklistRefSQL = q|INSERT INTO ipblacklistref () VALUES ()|;
    my $addBlacklistSQL    = "INSERT INTO ipblacklistrange\n"
        . "    (banner_user_id, min_ip, max_ip, comment, ipblacklistref_id)\n"
        . "    VALUES (" . $USER->node_id . ", $rangeMin, $rangeMax, "
        . $DB->quote($blockReason) . ", LAST_INSERT_ID())";

    my $saveRaise = $DB->{dbh}->{RaiseError};
    $DB->{dbh}->{RaiseError} = 1;
    my $eval_ok = eval {
        $DB->{dbh}->do($addBlacklistRefSQL);
        $DB->{dbh}->do($addBlacklistSQL);
        1;
    };
    $DB->{dbh}->{RaiseError} = $saveRaise;

    if (!$eval_ok) {
        return {success => 0,
            message => "There was an error adding this block to the database: " . $DB->{dbh}->errstr()};
    }

    $APP->securityLog($event, $USER->NODEDATA,
        $USER->title . " added $ipToAdd to the IP blacklist: \"$blockReason.\"");
    return {success => 1, message => "The IP range \"$ipToAdd\" was successfully added to the blacklist."};
}

sub remove_ip {
    my ($self, $idToRemove, $USER, $event) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    $idToRemove = int $idToRemove;

    # Pull the raw parts and format them the same way the list does, so a range reads as
    # dotted CIDR (e.g. 198.51.100.0/24) in the message + audit log rather than the raw
    # integers stored in ipblacklistrange (#4464 follow-up).
    my $row = $DB->{dbh}->selectrow_hashref(qq|
SELECT
    ipblacklist.ipblacklist_ipaddress,
    ipblacklistrange.min_ip,
    ipblacklistrange.max_ip
    FROM ipblacklistref
    LEFT JOIN ipblacklist
        ON ipblacklistref.ipblacklistref_id = ipblacklist.ipblacklistref_id
    LEFT JOIN ipblacklistrange
        ON ipblacklistref.ipblacklistref_id = ipblacklistrange.ipblacklistref_id
    WHERE ipblacklistref.ipblacklistref_id = $idToRemove|);

    my $blAddress = $self->_format_entry_address($row);

    my $removeSQL = qq|
DELETE ipblacklist, ipblacklistref, ipblacklistrange
    FROM ipblacklistref
    LEFT JOIN ipblacklist
        ON ipblacklistref.ipblacklistref_id = ipblacklist.ipblacklistref_id
    LEFT JOIN ipblacklistrange
        ON ipblacklistref.ipblacklistref_id = ipblacklistrange.ipblacklistref_id
    WHERE ipblacklistref.ipblacklistref_id = $idToRemove|;

    my $saveRaise = $DB->{dbh}->{RaiseError};
    $DB->{dbh}->{RaiseError} = 1;
    my $eval_ok = eval { $DB->{dbh}->do($removeSQL); 1 };
    $DB->{dbh}->{RaiseError} = $saveRaise;

    if (!$eval_ok) {
        return {success => 0,
            message => "There was an error removing this block from the database: " . $DB->{dbh}->errstr()};
    }

    $APP->securityLog($event, $USER->NODEDATA, $USER->title . " removed $blAddress from the IP blacklist.");
    return {success => 1, message => "The IP \"$blAddress\" was successfully removed from the blacklist."};
}

# ---- IP/CIDR helpers ------------------------------------------------------

sub parse_cidr_range {
    my ($self, $cidrIP) = @_;

    return () unless $cidrIP =~ m/^(\d{1,3}\.\d{1,3}.\d{1,3}\.\d{1,3})\s*\/(\d{1,2})$/;
    my $addr = $1;
    my $bits = $2;

    my $intAddr = $self->int_from_addr($addr);
    return () unless $intAddr;
    return () unless $bits < 33 && $bits > 7;

    my $maxAddr = $self->int_from_addr('255.255.255.255');
    my $mask    = ($maxAddr << (32 - $bits)) & $maxAddr;

    my $addrMin = $intAddr & $mask;
    my $addrMax = $addrMin + ($maxAddr >> $bits);

    return (1, $addrMin, $addrMax);
}

sub int_from_addr {
    my ($self, $addr) = @_;

    return unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return if $1 > 255 or $2 > 255 or $3 > 255 or $4 > 255;

    return ((int $1) * 256 * 256 * 256 + (int $2) * 256 * 256 + (int $3) * 256 + (int $4));
}

sub addr_from_int {
    my ($self, $intAddr) = @_;

    my ($oc1, $oc2, $oc3, $oc4) = (
        $intAddr & 255,
        ($intAddr >> 8) & 255,
        ($intAddr >> 16) & 255,
        ($intAddr >> 24) & 255,
    );

    return "$oc4.$oc3.$oc2.$oc1";
}

sub range_bits_from_ints {
    my ($self, $minAddr, $maxAddr) = @_;

    my $diff     = abs($maxAddr - $minAddr) + 1;
    my $log2diff = log($diff) / log(2);
    my $epsilon  = 1e-11;

    return if (($log2diff - int($log2diff)) > $epsilon);
    return (32 - $log2diff);
}

1;
