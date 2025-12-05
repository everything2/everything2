package Everything::Page::new_nodes_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::new_nodes_xml_ticker - New Nodes XML Ticker (DEPRECATED)

=head1 DESCRIPTION

Legacy new nodes XML ticker. Returns recently published writeups in XML format.
Admins see all writeups including those marked notnew=1.

Query parameters:
- None

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of new writeups.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $USER = $REQUEST->user->NODEDATA;

    my $limit = 100;

    my $qry = "SELECT * FROM newwriteup, node where newwriteup.node_id=node.node_id ";

    $qry .= "and notnew=0 " unless $self->APP->isAdmin($USER);
    $qry .= " order by newwriteup_id DESC LIMIT $limit";

    my $csr = $self->DB->{dbh}->prepare($qry);

    $csr->execute or return [$self->HTTP_INTERNAL_SERVER_ERROR, "Database error", {type => 'text/plain'}];
    my $count = 0;

    my $XG = XML::Generator->new();

    my $str = "";
    $str .= $XG->INFO({
        site => $self->CONF->site_url,
        sitename => $self->CONF->site_name,
        servertime => scalar(localtime(time))
    }, "Rendered by the New Nodes XML Ticker") . "\n";

    while (my $N = $csr->fetchrow_hashref) {
        $N = Everything::getNode($N->{node_id});
        my $parent_node = $self->DB->getNodeById($N->{parent_e2node});
        my $wrtype_node = $self->DB->getNodeById($N->{wrtype_writeuptype});
        my $author_node = $self->DB->getNodeById($N->{author_user});

        $str .= $XG->node({
            createtime => $N->{publishtime} || $N->{createtime},
            e2node_id => $N->{parent_e2node},
            writeuptype => $wrtype_node->{title},
            author_user => $self->APP->xml_escape($author_node->{title}),
            node_id => Everything::getId($N)
        }, $self->APP->xml_escape($parent_node->{title}) . "\n");
    }
    $csr->finish;

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $XG->NewNodes($str), {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
