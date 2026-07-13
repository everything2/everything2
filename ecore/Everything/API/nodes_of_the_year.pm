package Everything::API::nodes_of_the_year;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::nodes_of_the_year - top writeups for a given year, filtered by type

=head1 DESCRIPTION

Public browse: the year's writeups, optionally filtered by writeup type, ordered by C!/reputation
(or date). Moved out of C<Everything::Page::nodes_of_the_year>'s buildReactData (#4524): the Page is
a pure gate, React (NodesOfTheYear) reads year/wutype/count/orderby off the URL and calls this.

  GET /api/nodes_of_the_year?year=<y>&wutype=<id>&count=<n>&orderby=<key>

C<orderby> is whitelisted against the UI's sort options -- the old Page interpolated it into the SQL
unvalidated, a latent injection this closes.

=cut

# Whitelisted sort expressions (the UI's four options). Anything else falls back to the default,
# so the value can be interpolated into ORDER BY safely.
my %ALLOWED_ORDERBY = map { $_ => 1 } (
    'cooled DESC,reputation DESC',
    'reputation DESC',
    'publishtime DESC',
    'publishtime ASC',
);

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB = $self->DB;

    my $wutype = abs(int($REQUEST->param('wutype') || 0));
    my $count  = abs(int($REQUEST->param('count')  || 50));
    $count = 50 if $count < 1 || $count > 500;   # clamp (bounds the LIMIT)

    my $orderby = $REQUEST->param('orderby') || 'cooled DESC,reputation DESC';
    $orderby = 'cooled DESC,reputation DESC' unless $ALLOWED_ORDERBY{$orderby};

    # Default to last year until ~December (11*30.5*24*3600 = 28987200), matching the old page.
    my $year = $REQUEST->param('year');
    $year = (localtime(time - 28987200))[5] + 1900 unless defined $year && "$year" =~ /^\d+$/;
    $year = abs(int($year));
    my $nextyear = $year + 1;

    # Writeup types for the filter dropdown.
    my $writeuptype_type = $DB->getType('writeuptype');
    my @writeuptypes = $DB->getNodeWhere({ type_nodetype => $writeuptype_type->{node_id} });
    my @types = sort { $a->{title} cmp $b->{title} }
        map { { node_id => int($_->{node_id}), title => $_->{title} } } @writeuptypes;

    # $wutype/$year/$nextyear are ints and $orderby is whitelisted -> injection-safe interpolation.
    my $where = '';
    $where = "wrtype_writeuptype=$wutype AND " if $wutype;
    $where .= "publishtime >= '$year-01-01 00:00:00' AND publishtime < '$nextyear-01-01 00:00:00'";

    my $csr = $DB->sqlSelectMany(
        'writeup_id, parent_e2node, publishtime, node.author_user, type.title AS type_title, cooled, node.reputation',
        'writeup JOIN node ON writeup_id = node.node_id JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where,
        "ORDER BY $orderby LIMIT $count"
    );

    my @writeups;
    while (my $row = $csr->fetchrow_hashref) {
        my $parent = $DB->getNodeById($row->{parent_e2node}, 'light');
        my $author = $DB->getNodeById($row->{author_user}, 'light');
        push @writeups, {
            writeup_id   => int($row->{writeup_id}),
            parent_id    => int($row->{parent_e2node}),
            parent_title => $parent ? $parent->{title} : 'Unknown',
            type_title   => $row->{type_title},
            author_id    => int($row->{author_user}),
            author_title => $author ? $author->{title} : 'Unknown',
            publishtime  => $row->{publishtime},
            cooled       => int($row->{cooled} || 0),
            reputation   => int($row->{reputation} || 0),
        };
    }

    return [$self->HTTP_OK, {
        success       => 1,
        year          => $year,
        wutype        => $wutype,
        count         => $count,
        orderby       => $orderby,
        writeup_types => \@types,
        writeups      => \@writeups,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
