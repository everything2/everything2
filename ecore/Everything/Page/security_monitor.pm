package Everything::Page::security_monitor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::security_monitor - Security audit log viewer

=head1 DESCRIPTION

Admin tool for viewing security-related actions across the site.
Shows categorized logs for various security events like kills, suspensions,
blessings, account lockings, etc.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;
    # URL params via the transport-agnostic accessor ($REQUEST->param delegates to the Plack
    # query object) so the pagestate API path parses them identically. (routing-epoch sweep T2 -- #4496.)

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'security_monitor',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    # Categories come from the Everything::SecurityLog enum, counted by
    # seclog_event (#4272 phase 4) -- no node lookups, so retiring opcode nodes
    # can never make a category vanish. Show only non-empty ones, by label.
    my @categories =
        sort { $a->{name} cmp $b->{name} }
        grep { $_->{count} > 0 }
        @{ $APP->seclog_event_counts };

    my $result = {
        type       => 'security_monitor',
        node_id    => int($node_id),
        categories => [
            map { {
                id    => $_->{event_id},
                name  => $_->{name},
                group => $_->{group},
                count => $_->{count},
            } } @categories
        ],
    };

    # Drill-in: sectype is now an EVENT id (0..N), not a node id. Entries come
    # back keyed off seclog_event, with the affected node from seclog_subject.
    my $sectype = $REQUEST->param('sectype');
    if (defined $sectype && $sectype =~ /^\d+$/) {
        my $startat = $REQUEST->param('startat') || 0;
        $startat =~ s/[^0-9]//g;
        $startat = int($startat);

        my $page = $APP->seclog_entries($sectype, $startat, 50);

        $result->{viewing_type} = int($sectype);
        $result->{entries}      = $page->{entries};
        $result->{startat}      = $startat;
        $result->{total}        = $page->{total};
        $result->{page_size}    = 50;
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
