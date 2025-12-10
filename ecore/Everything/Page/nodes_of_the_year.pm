package Everything::Page::nodes_of_the_year;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::nodes_of_the_year - Best writeups by year

=head1 DESCRIPTION

Shows top writeups for a given year with filtering by writeup type, count, and order.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns writeup list and filter options.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $CGI = $REQUEST->cgi;
    my $USER = $REQUEST->user;

    # Get parameters
    my $wutype = abs(int($CGI->param("wutype") || 0));
    my $count = abs(int($CGI->param("count") || 50));
    my $orderby = $CGI->param('orderby') || 'cooled DESC,reputation DESC';

    # Show last year until Decemberish (11*30.5*24*3600 = 28987200)
    my $year = $CGI->param('year') || (localtime(time - 28987200))[5] + 1900;
    $year = int($year);

    my $nextyear = $year + 1;

    # Get writeup types
    my $writeuptype_type = $DB->getType('writeuptype');
    my @writeuptypes = $DB->getNodeWhere({ type_nodetype => $writeuptype_type->{node_id} });

    my @types = ();
    foreach my $wt (@writeuptypes) {
        push @types, {
            node_id => $wt->{node_id},
            title => $wt->{title}
        };
    }

    # Sort types alphabetically
    @types = sort { $a->{title} cmp $b->{title} } @types;

    # Build query
    my $where = '';
    if ($wutype) {
        $where = "wrtype_writeuptype=$wutype AND ";
    }

    $where .= "publishtime >= '$year-01-01 00:00:00' AND publishtime < '$nextyear-01-01 00:00:00'";

    # Get writeups
    my $csr = $DB->sqlSelectMany(
        'writeup_id, parent_e2node, publishtime, node.author_user, type.title AS type_title, cooled, node.reputation',
        'writeup JOIN node ON writeup_id = node.node_id JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where,
        "ORDER BY $orderby LIMIT $count"
    );

    my @writeups = ();
    while (my $row = $csr->fetchrow_hashref) {
        # Get parent e2node title
        my $parent = $DB->getNodeById($row->{parent_e2node}, 'light');
        my $author = $DB->getNodeById($row->{author_user}, 'light');

        push @writeups, {
            writeup_id => $row->{writeup_id},
            parent_id => $row->{parent_e2node},
            parent_title => $parent ? $parent->{title} : 'Unknown',
            type_title => $row->{type_title},
            author_id => $row->{author_user},
            author_title => $author ? $author->{title} : 'Unknown',
            publishtime => $row->{publishtime},
            cooled => $row->{cooled} || 0,
            reputation => $row->{reputation} || 0
        };
    }

    return {
        type => 'nodes_of_the_year',
        year => $year,
        wutype => $wutype,
        count => $count,
        orderby => $orderby,
        writeup_types => \@types,
        writeups => \@writeups
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
