package Everything::Page::mass_ip_blacklister;

use Moose;
extends 'Everything::Page';

with 'Everything::Roles::IPBlacklist';

=head1 NAME

Everything::Page::mass_ip_blacklister - Mass IP Blacklist management tool

=head1 DESCRIPTION

Admin tool for bulk-adding IP addresses that are barred from creating new accounts.

Pure-render: this now renders the SAME unified React component and hits the SAME
POST /api/ip_blacklist/add|remove|list interface as the regular ip_blacklist page (#4464,
Refs #4298) -- a single IP is just a one-line list. It differs only in C<source>, which
selects the SECLOG_IP_BLACKLIST_MASS audit-log event on the API side. Shared logic lives
in Everything::Roles::IPBlacklist.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $USER = $REQUEST->user;

    unless ( $self->APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type   => 'mass_ip_blacklister',
            source => 'mass_ip_blacklister',
            error  => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my $page_size = 200;
    my $entries   = $self->get_blacklist_entries( 0, $page_size );

    return {
        type          => 'mass_ip_blacklister',
        source        => 'mass_ip_blacklister',
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
