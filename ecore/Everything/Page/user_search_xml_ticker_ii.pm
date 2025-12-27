package Everything::Page::user_search_xml_ticker_ii;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::user_search_xml_ticker_ii - User Search XML Ticker II

=head1 DESCRIPTION

Returns XML listing a user's writeups with detailed metadata including
reputation, votes, cools, writeup type, and parent e2node.

Supports query parameters:
- searchuser: Username to search (defaults to current user)
- startat: Offset for pagination (default 0)
- count: Number of results (default 50)
- sort: Sort order (rep, title, creation, publication)
- nolimit: Remove LIMIT clause
- nosort: Remove ORDER BY clause

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing user's writeups with metadata.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $searchuser = $query->param("searchuser");
    $searchuser = $self->DB->getNode($searchuser, "user") if defined($searchuser);
    $searchuser ||= $USER;

    my $startat = $query->param("startat") || "0";
    $startat =~ s/[^\d]//g;

    my $limit = $query->param("count") || "50";
    $limit =~ s/[^\d]//g;
    $limit = " LIMIT $startat,$limit ";
    $limit = "" if $query->param("nolimit");

    my $o = " ORDER BY ";
    my $sortchoices = {
        'rep' => "$o reputation DESC",
        'rep_asc' => "$o reputation",
        'title' => "$o title",
        'creation' => "$o publishtime DESC",
        'creation_asc' => "$o publishtime",
        'publication' => "$o publishtime DESC",
        'publication_asc' => "$o publishtime"
    };
    my $sort_param = $query->param("sort") // '';
    my $sort = $sortchoices->{$sort_param} // $sortchoices->{creation};
    $sort = "" if $query->param("nosort");

    my $wuCount = $self->DB->sqlSelect('count(*)','node',
        "author_user=$searchuser->{node_id} AND type_nodetype=117");

    my $nr_node = $self->DB->getNode("node row", "oppressor_superdoc");
    my $nr = $self->DB->getId($nr_node);

    my $csr = $self->DB->sqlSelectMany("node_id", "node JOIN writeup ON node_id=writeup_id",
        "author_user=$searchuser->{node_id} $sort $limit");

    my $writeups = '';

    while(my $row = $csr->fetchrow_hashref)
    {
        my $n = $self->DB->getNodeById($row->{node_id});
        next unless $n;
        my $parent = $self->DB->getNodeById($n->{parent_e2node});

        my %attrs = (createtime => $n->{publishtime});

        my $marked = ($self->DB->sqlSelect('linkedby_user', 'weblog',
            "weblog_id=$nr and to_node=$n->{node_id}") ? 1 : 0);
        $attrs{marked} = $marked if($searchuser->{node_id} == $USER->{node_id});

        my $hidden = $n->{notnew} || 0;
        $attrs{hidden} = $hidden if($searchuser->{node_id} == $USER->{node_id});

        my $c = $self->DB->sqlSelect("count(*)", "coolwriteups",
            "coolwriteups_id=$n->{node_id}") || 0;
        $attrs{cools} = $c;

        my $wrtype = $self->DB->getNodeById($n->{wrtype_writeuptype});
        $attrs{wrtype} = $wrtype->{title};

        my $up = $self->DB->sqlSelect("count(*)", "vote",
            "vote_id=$n->{node_id} AND weight=1");
        my $down = $self->DB->sqlSelect("count(*)", "vote",
            "vote_id=$n->{node_id} AND weight=-1");

        my $wu_content = '';
        if($searchuser->{node_id} == $USER->{node_id}) {
            $wu_content .= $XG->rep({up => $up, down => $down}, $n->{reputation});
        }
        $wu_content .= $XG->e2link({node_id => $n->{node_id}}, $n->{title});
        $wu_content .= $XG->parent(
            $XG->e2link({node_id => $parent->{node_id}}, $parent->{title})
        );

        $writeups .= $XG->wu(\%attrs, $wu_content);
    }

    return $self->xml_header() . $XG->usersearch(
        {user => $searchuser->{title}, writeupCount => $wuCount},
        $writeups
    );
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
