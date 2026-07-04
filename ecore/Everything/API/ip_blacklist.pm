package Everything::API::ip_blacklist;

use Moose;
extends 'Everything::API';

with 'Everything::Roles::IPBlacklist';

use Everything::SecurityLog qw(:events);

# POST /api/ip_blacklist/list | /add | /remove -- admin-only (#4464, Refs #4298). One
# unified interface backing BOTH the ip_blacklist and mass_ip_blacklister Document pages:
# `add` takes a newline-separated block of entries (each a single IP or a CIDR range) and
# processes each line, so a single IP is just a one-line list. The `source` field selects
# the audit-log event (SECLOG_IP_BLACKLIST vs SECLOG_IP_BLACKLIST_MASS) so the
# regular-vs-mass distinction is preserved. Shared logic: Everything::Roles::IPBlacklist.

my $PAGE_SIZE = 200;

my %EVENT_FOR_SOURCE = (
    ip_blacklist        => SECLOG_IP_BLACKLIST,
    mass_ip_blacklister => SECLOG_IP_BLACKLIST_MASS,
);

sub routes {
    return {
        'list'   => 'list_entries',
        'add'    => 'add_entries',
        'remove' => 'remove_entry',
    };
}

sub _event {
    my ($self, $source) = @_;
    return $EVENT_FOR_SOURCE{$source // ''} // SECLOG_IP_BLACKLIST;
}

# Standard admin denial (200 + success=0 -- never a 4xx from an API controller).
sub _denied {
    my ($self) = @_;
    return [$self->HTTP_OK,
        {success => 0, error => 'Access denied. This tool is restricted to administrators.'}];
}

# The refreshed list page at $offset -- folded into every response so the React updates in
# one round-trip.
sub _list_payload {
    my ($self, $offset) = @_;
    $offset = 0 unless (defined $offset && $offset =~ /^\d+$/);
    my $entries = $self->get_blacklist_entries($offset, $PAGE_SIZE);
    return {
        entries     => $entries->{items},
        total_count => $entries->{total},
        offset      => int($offset),
        page_size   => $PAGE_SIZE,
    };
}

sub list_entries {
    my ($self, $REQUEST) = @_;
    return $self->_denied unless $REQUEST->user->is_admin;

    my $data = $REQUEST->JSON_POSTDATA;
    return [$self->HTTP_OK, {success => 1, %{$self->_list_payload($data->{offset})}}];
}

sub add_entries {
    my ($self, $REQUEST) = @_;
    return $self->_denied unless $REQUEST->user->is_admin;

    my $data   = $REQUEST->JSON_POSTDATA;
    my $reason = $data->{reason};
    $reason =~ s/^\s+|\s+$//g if defined $reason;

    my @ips = grep { /\S/ } split /\r?\n/, ($data->{ips} // '');
    @ips = map { s/^\s+|\s+$//gr } @ips;

    return [$self->HTTP_OK, {success => 0, error => 'You must list at least one IP to block.',
        %{$self->_list_payload($data->{offset})}}]
        unless @ips;
    return [$self->HTTP_OK, {success => 0, error => 'You must give a reason to block.',
        %{$self->_list_payload($data->{offset})}}]
        unless (defined $reason && length $reason);

    my $event = $self->_event($data->{source});
    my $user  = $REQUEST->user;

    my @results;
    foreach my $ip (@ips) {
        my $r = $self->add_ip_or_range($ip, $reason, $user, $event);
        push @results, {ip => $ip, success => ($r->{success} ? 1 : 0), message => $r->{message}};
    }

    return [$self->HTTP_OK,
        {success => 1, results => \@results, %{$self->_list_payload($data->{offset})}}];
}

sub remove_entry {
    my ($self, $REQUEST) = @_;
    return $self->_denied unless $REQUEST->user->is_admin;

    my $data = $REQUEST->JSON_POSTDATA;
    my $id   = $data->{id};
    return [$self->HTTP_OK, {success => 0, error => 'A blacklist entry id is required.',
        %{$self->_list_payload($data->{offset})}}]
        unless (defined $id && $id =~ /^\d+$/);

    my $r = $self->remove_ip($id, $REQUEST->user, $self->_event($data->{source}));
    return [$self->HTTP_OK, {
        success => ($r->{success} ? 1 : 0),
        message => $r->{message},
        %{$self->_list_payload($data->{offset})},
    }];
}

__PACKAGE__->meta->make_immutable;

1;
