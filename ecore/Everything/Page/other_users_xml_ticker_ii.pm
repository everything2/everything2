package Everything::Page::other_users_xml_ticker_ii;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::other_users_xml_ticker_ii - Other Users XML Ticker II

=head1 DESCRIPTION

Returns XML listing users currently in chat rooms with detailed metadata
including staff symbols (gods, editors, developers), experience, borg status,
and Gravatar MD5 hashes.

Supports query parameters:
- in_room: Filter by room ID
- nosort: Skip ORDER BY clause

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing users in rooms with metadata.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $sortstr = '';
    $sortstr = 'ORDER BY experience DESC' unless $query->param('nosort');
    my $wherestr;

    #TODO: do not do visible filter if infravision
    $wherestr = 'visible = 0';

    my $roomfor = $query->param('in_room');
    if ($roomfor) {
        $roomfor =~ s/[^\d]//g;
        $wherestr .= " AND room_id = $roomfor" if $roomfor;
    }

    my $csr = $self->DB->sqlSelectMany('*', 'room', $wherestr, $sortstr);

    my $users = '';
    while (my $row = $csr->fetchrow_hashref) {
        my $member = $$row{member_user};
        my $u = $self->DB->getNodeById($$row{member_user});

        my $e2god = ( $self->APP->isAdmin($member)
                && !$self->APP->getParameter($member,"hide_chatterbox_staff_symbol") )?(1):(0);

        my $committer = $self->APP->inUsergroup($member, '%%', 'nogods');
        my $chanop = $self->APP->isChanop($member, 'nogods');

        my $ce = ($self->APP->isEditor($member,"nogods") && !$self->APP->isAdmin($USER) && !$self->APP->getParameter($member,"hide_chatterbox_staff_symbol") )?(1):(0);

        my $edev = ($self->APP->isDeveloper($member,"nogods")?(1):(0));
        my $xp = $$u{experience};

        my $borged = $$row{borgd};
        $borged ||=0;

        my $md5 = Everything::HTML::htmlcode('getGravatarMD5', $member);

        my $room_xml = '';
        my $r = $self->DB->getNodeById($$row{room_id});
        if ($r) {
            $room_xml = $XG->room({node_id => $$r{node_id}}, $$r{title});
        }

        $users .= $XG->user(
            {
                e2god => $e2god,
                committer => $committer,
                chanop => $chanop,
                ce => $ce,
                edev => $edev,
                xp => $xp,
                borged => $borged
            },
            "\n" .
            $XG->e2link({node_id => $$u{node_id}, md5 => $md5}, $$u{title}) .
            "\n" . $room_xml
        ) . "\n";
    }

    return $self->xml_header() . $XG->otherusers("\n" . $users);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
