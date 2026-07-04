package Everything::Page::ip_blacklist;

use Moose;
extends 'Everything::Page';

with 'Everything::Roles::IPBlacklist';

=head1 NAME

Everything::Page::ip_blacklist - IP Blacklist management tool

=head1 DESCRIPTION

Admin tool for managing IP addresses that are barred from creating new accounts.
Supports individual IPs and CIDR ranges.

Pure-render: the add/remove mutations moved to POST /api/ip_blacklist/add|remove|list
(Everything::API::ip_blacklist, #4464, Refs #4298), a single unified interface shared with
the mass_ip_blacklister page. Shared read/mutation logic lives in
Everything::Roles::IPBlacklist. This page just gates on admin and hands the React
component the first page of entries; C<source> selects the audit-log event on the API side.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $USER = $REQUEST->user;

    unless ( $self->APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type   => 'ip_blacklist',
            source => 'ip_blacklist',
            error  => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my $page_size = 200;
    my $entries   = $self->get_blacklist_entries( 0, $page_size );

    return {
        type          => 'ip_blacklist',
        source        => 'ip_blacklist',
        entries       => $entries->{items},
        total_count   => $entries->{total},
        offset        => 0,
        page_size     => $page_size,
        guest_user_id => $Everything::CONF->guest_user
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Roles::IPBlacklist>, L<Everything::API::ip_blacklist>

=cut
