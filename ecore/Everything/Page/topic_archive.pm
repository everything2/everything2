package Everything::Page::topic_archive;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

use Readonly;
Readonly my $PAGE_SIZE => 50;

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $q = $REQUEST->cgi;

    # Get the E2 Gift Shop node ID
    my $gift_shop = $DB->getNode('E2 Gift Shop', 'superdoc');
    return { type => 'topic_archive', error => 'Gift Shop not found' }
        unless $gift_shop;

    my $sectype = $gift_shop->{node_id};

    # Pagination
    my $startat = $q->param('startat') || 0;
    $startat =~ s/[^0-9]//g;
    $startat ||= 0;
    $startat = int($startat);

    # Get total count - only room topic changes
    my ($total_count) = $DB->sqlSelect(
        'count(*)',
        'seclog',
        "seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00' AND seclog_details LIKE '%changed room topic%'"
    );
    $total_count ||= 0;

    # Fetch log entries - only room topic changes
    my $csr = $DB->sqlSelectMany(
        '*',
        'seclog',
        "seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00' AND seclog_details LIKE '%changed room topic%' order by seclog_time DESC limit $startat,$PAGE_SIZE"
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
