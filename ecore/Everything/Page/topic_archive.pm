package Everything::Page::topic_archive;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

use Readonly;
use Everything::SecurityLog qw(:events);
Readonly my $PAGE_SIZE => 50;

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    # URL params via the transport-agnostic accessor ($REQUEST->param delegates to the Plack
    # query object) so the pagestate API path parses them identically. (routing-epoch sweep T2 -- #4496.)

    # Room-topic-change events (decoupled from the old E2 Gift Shop seclog_node).
    my $event = SECLOG_GIFTSHOP_TOPIC;

    # Pagination
    my $startat = $REQUEST->param('startat') || 0;
    $startat =~ s/[^0-9]//g;
    $startat ||= 0;
    $startat = int($startat);

    # Get total count - only room topic changes
    my ($total_count) = $DB->sqlSelect(
        'count(*)',
        'seclog',
        "seclog_event=$event AND seclog_time>'2011-01-22 00:00:00' AND seclog_details LIKE '%changed room topic%'"
    );
    $total_count ||= 0;

    # Fetch log entries - only room topic changes
    my $csr = $DB->sqlSelectMany(
        '*',
        'seclog',
        "seclog_event=$event AND seclog_time>'2011-01-22 00:00:00' AND seclog_details LIKE '%changed room topic%' order by seclog_time DESC limit $startat,$PAGE_SIZE"
    );

    my @entries = ();
    while (my $row = $csr->fetchrow_hashref) {
        push @entries, {
            time    => $row->{seclog_time},
            details => $row->{seclog_details},
        };
    }
    $csr->finish;

    return {
        type       => 'topic_archive',
        entries    => \@entries,
        startat    => $startat,
        pageSize   => $PAGE_SIZE,
        totalCount => int($total_count),
        hasNext    => ($startat + $PAGE_SIZE) < $total_count ? \1 : \0,
        hasPrev    => $startat > 0 ? \1 : \0,
    };
}

__PACKAGE__->meta->make_immutable;

1;
