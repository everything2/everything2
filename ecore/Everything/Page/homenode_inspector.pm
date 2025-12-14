package Everything::Page::homenode_inspector;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::homenode_inspector - Inspect user homenodes for spam

=head1 DESCRIPTION

Admin tool for finding potentially spammy homenodes. Filters by
inactivity period, writeup count, external links, and shows
homenode content for review with quick-smite links.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'homenode_inspector',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    # Get filter parameters
    my $gonetime   = $q->param('gonetime');
    $gonetime = 0 if defined($gonetime) && $gonetime eq '0';
    $gonetime //= 0;

    my $goneunit   = $q->param('goneunit') || 'MONTH';
    my $showlength = $q->param('showlength') || 1000;
    my $maxwus     = $q->param('maxwus') || 0;
    my $extlinks   = $q->param('extlinks') ? 1 : 0;
    my $dotstoo    = $q->param('dotstoo') ? 1 : 0;
    my $page       = $q->param('page') || 1;

    # Validate parameters
    unless ($maxwus =~ /^\d+$/ && $gonetime =~ /^\d+$/ &&
            $showlength =~ /^\d+$/ && $goneunit =~ /^(year|month|week|day)$/i) {
        return {
            type  => 'homenode_inspector',
            error => 'Parameter error'
        };
    }

    $maxwus     = int($maxwus);
    $gonetime   = int($gonetime);
    $showlength = int($showlength);
    $page       = int($page);
    $page = 1 if $page < 1;

    # Get The Old Hooked Pole for smite links
    my $pole = $DB->getNode('The Old Hooked Pole', 'restricted_superdoc');
    my $pole_id = $pole ? int($pole->{node_id}) : undef;

    my $result = {
        type        => 'homenode_inspector',
        node_id     => $node_id,
        filters     => {
            gonetime   => $gonetime,
            goneunit   => $goneunit,
            showlength => $showlength,
            maxwus     => $maxwus,
            extlinks   => $extlinks,
            dotstoo    => $dotstoo
        },
        pole_id     => $pole_id,
        page        => $page
    };

    # Build filter SQL
    my $filter = "doctext != ''";
    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gonetime $goneunit)";
    $filter .= " AND numwriteups <= $maxwus";
    $filter .= " AND doctext LIKE '%[http%'" if $extlinks;
    $filter .= " AND doctext != '...'" unless $dotstoo;

    # Get total count
    my $total = $DB->sqlSelect(
        'COUNT(*)',
        'node JOIN user ON node_id=user_id JOIN document ON node_id=document_id',
        $filter
    ) || 0;

    my $per_page = 10;
    my $offset = ($page - 1) * $per_page;

    # Get results
    my $csr = $DB->sqlSelectMany(
        'title, node_id, user_id AS author_user, doctext',
        'node JOIN user ON node_id=user_id JOIN document ON node_id=document_id',
        $filter,
        "ORDER BY lasttime DESC LIMIT $offset, $per_page"
    );

    my @items = ();
    while (my $row = $csr->fetchrow_hashref) {
        my $doctext = $row->{doctext} || '';
        # Truncate content
        my $truncated = length($doctext) > $showlength
            ? substr($doctext, 0, $showlength) . '...'
            : $doctext;

        push @items, {
            node_id   => int($row->{node_id}),
            title     => $row->{title},
            doctext   => $truncated,
            full_length => length($doctext)
        };
    }
    $csr->finish;

    $result->{items}      = \@items;
    $result->{total}      = int($total);
    $result->{per_page}   = $per_page;
    $result->{total_pages} = int(($total + $per_page - 1) / $per_page);

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
