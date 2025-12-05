package Everything::Page::cool_nodes_xml_ticker_ii;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::cool_nodes_xml_ticker_ii - Cool Nodes XML Ticker II

=head1 DESCRIPTION

Returns XML listing cool writeups with filtering and sorting options.

Supports query parameters:
- writtenby: Filter by author username
- cooledby: Filter by cooler username
- startat: Offset for pagination (default 0)
- limit: Number of results (default 50, max 50)
- sort: Sort order (highestrep, lowestrep, recentcool, oldercool)

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing cool writeups with metadata.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $XG = $self->xml_generator;

    my $writtenby;
    $writtenby = $self->DB->getNode($query->param("writtenby"), "user") if $query->param("writtenby");
    my $cooledby;
    $cooledby = $self->DB->getNode($query->param("cooledby"), "user") if $query->param("cooledby");

    my $startat = $query->param("startat");
    $startat ||= "0";
    $startat =~ s/[^\d]//g;

    my $limit = $query->param("limit");
    $limit ||= "50";
    $limit =~ s/[^\d]//g;
    $limit = 50 if($limit > 50);
    $limit = " LIMIT $startat,$limit";

    my @params;
    push @params, "coolwriteups_id=node_id";
    push @params,"author_user=\"$$writtenby{node_id}\"" if $writtenby;
    push @params,"cooledby_user=\"$$cooledby{node_id}\"" if $cooledby;

    my $wherestr = join " AND ",@params;
    my $orderchoices = {"highestrep" => "reputation DESC", "lowestrep" => "reputation ASC", "recentcool" => "tstamp DESC", "oldercool" => "tstamp ASC"};

    my $order = $$orderchoices{$query->param("sort")};
    $order ||= $$orderchoices{recentcool};
    $order = " ORDER BY $order";

    my $csr = $self->DB->sqlSelectMany("node_id, cooledby_user", "node, coolwriteups", "$wherestr $order $limit");

    my $cools = '';
    while(my $row = $csr->fetchrow_hashref)
    {
        my $n = $self->DB->getNodeById($$row{node_id});
        my $cooler = $self->DB->getNodeById($$row{cooledby_user});
        my $author = $self->DB->getNodeById($$n{author_user});

        $cools .= $XG->cool(
            $XG->writeup(
                $XG->e2link({node_id => $$n{node_id}}, $$n{title})
            ) .
            $XG->author(
                $XG->e2link({node_id => $$author{node_id}}, $$author{title})
            ) .
            $XG->cooledby(
                $XG->e2link({node_id => $$cooler{node_id}}, $$cooler{title})
            )
        ) . "\n";
    }

    return $self->xml_header() . $XG->coolwriteups("\n" . $cools);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
