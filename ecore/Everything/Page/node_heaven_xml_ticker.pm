package Everything::Page::node_heaven_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::node_heaven_xml_ticker - Node Heaven XML Ticker

=head1 DESCRIPTION

Returns XML listing the user's writeups in heaven (deleted writeups).
Only available to logged-in users (guests see empty XML).

Supports query parameters:
- visitnode_id: Show details for specific writeup
- nosort: Skip ORDER BY clause
- links_noparse: Skip link parsing in doctext

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing user's writeups in heaven.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $angels = '';
    my $UID = $self->DB->getId($USER) || 0;

    if( !$self->APP->isGuest($USER) ) {
        my $writeup_type = $self->DB->getType('writeup');
        my $wherestr = 'author_user='.$UID.' and type_nodetype='.$self->DB->getId($writeup_type);
        my $visitid = $query->param('visitnode_id');
        $visitid ||= '';
        $visitid =~ s/[^\d]//g;
        $wherestr .= " AND node_id=$visitid" if $visitid;
        $wherestr .= " ORDER BY title" unless($query->param('nosort'));

        my $csr = $self->DB->sqlSelectMany('*', 'heaven', $wherestr);
        while(my $row = $csr->fetchrow_hashref)
        {
            my $content = '';
            if($visitid){
                my $data = $self->APP->safe_deserialize_dumper('my '.$$row{data});
                if ($data) {
                    my $txt = $$data{doctext};
                    $txt = $self->APP->parseLinks($txt) unless($query->param('links_noparse'));
                    $content = $txt;
                }
            }

            $angels .= $XG->nodeangel(
                {
                    node_id => $$row{node_id},
                    title => $$row{title},
                    reputation => $$row{reputation},
                    createtime => $$row{createtime}
                },
                $content
            );
        }
    }

    return qq{<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n} . $XG->nodeheaven("\n" . $angels);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
