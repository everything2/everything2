package Everything::Page::caja_de_arena;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::caja_de_arena - Sandbox spam detection tool

=head1 DESCRIPTION

Admin tool for finding potentially spammy homenodes from users who
have never published any writeups. Similar to homenode_inspector
but focused on users with zero writeups.

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
            type  => 'caja_de_arena',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    # Get filter parameters
    my $gonesince  = $q->param('gonesince') || '1 YEAR';
    my $showlength = $q->param('showlength') || 1000;
    my $published  = $q->param('published') ? 1 : 0;
    my $extlinks   = $q->param('extlinks') ? 1 : 0;
    my $page       = $q->param('page') || 1;

    # Validate gonesince format (number + unit)
    unless ($gonesince =~ /^\d+\s+(YEAR|MONTH|WEEK|DAY)$/i) {
        $gonesince = '1 YEAR';
    }

    $showlength = int($showlength);
    $showlength = 1000 if $showlength < 100 || $showlength > 5000;
    $page = int($page);
    $page = 1 if $page < 1;

    # Get The Old Hooked Pole for smite links
    my $pole = $DB->getNode('The Old Hooked Pole', 'restricted_superdoc');
    my $pole_id = $pole ? int($pole->{node_id}) : undef;

    my $result = {
        type        => 'caja_de_arena',
        node_id     => $node_id,
        filters     => {
            gonesince  => $gonesince,
            showlength => $showlength,
            published  => $published,
            extlinks   => $extlinks
        },
        pole_id     => $pole_id,
        page        => $page
    };

    # Build filter SQL
    my $filter = "doctext != ''";
    $filter .= " AND lasttime < DATE_SUB(NOW(), INTERVAL $gonesince)";
    $filter .= " AND numwriteups = 0" unless $published;
    $filter .= " AND doctext LIKE '%[http%'" if $extlinks;

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
            node_id     => int($row->{node_id}),
            title       => $row->{title},
            doctext     => $truncated,
            full_length => length($doctext)
        };
    }
    $csr->finish;

    $result->{items}       = \@items;
    $result->{total}       = int($total);
    $result->{per_page}    = $per_page;
    $result->{total_pages} = int(($total + $per_page - 1) / $per_page);

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
