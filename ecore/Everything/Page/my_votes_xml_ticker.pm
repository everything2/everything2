package Everything::Page::my_votes_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::my_votes_xml_ticker - My Votes XML Ticker

=head1 DESCRIPTION

Returns XML listing the user's vote history, including which writeups
they voted on, their vote weight (up/down), and current reputation.

Supports pagination via the 'p' query parameter (100 votes per page).

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing user's vote history.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $count = 100;
    my $page = int($query->param('p') || 0);

    my $sql = "SELECT node.node_id,node.title,vote.weight,node.reputation,vote.votetime
           FROM vote,node
           WHERE node.node_id=vote.vote_id
            AND vote.voter_user=$$USER{user_id}
           ORDER BY vote.votetime
           LIMIT ".($page*$count).",$count";
    my $ds = $self->DB->{dbh}->prepare($sql);
    $ds->execute() or return $ds->errstr;

    my $votes = '';
    while(my $v = $ds->fetchrow_hashref)
    {
        $votes .= "  " . $XG->vote(
            {votetime => $$v{votetime}},
            "\n    " .
            $XG->e2link({node_id => $$v{node_id}}, $$v{title}) .
            "\n    " .
            $XG->rep({cast => $$v{weight}}, $$v{reputation}) .
            "\n  "
        ) . "\r\n";
    }

    return $self->xml_header() . $XG->votes("\r\n" . $votes);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
