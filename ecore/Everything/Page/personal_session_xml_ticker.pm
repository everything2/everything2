package Everything::Page::personal_session_xml_ticker;

use Moose;
use POSIX qw(asctime);

extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::personal_session_xml_ticker - Personal Session XML Ticker

=head1 DESCRIPTION

Returns XML with comprehensive user session information including:
- Current user and server time
- Borg status (chat room auto-away)
- Current chat room location
- Personal nodelet items
- Experience changes and level progress
- Cools available, votes left, karma, writeup count
- User lock/forbiddance status

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML with complete session state for the current user.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $self->APP->getVars($USER);
    my $XG = $self->xml_generator;

    my $currenttime = time;
    my $content = $XG->currentuser({user_id => $$USER{user_id}}, $$USER{title}) . "\n" .
                  $XG->servertime({time => $currenttime}, asctime(localtime($currenttime)));

    if ($self->APP->isGuest($USER)) {
        return $self->xml_header() . $XG->e2session("\n" . $content . "\n");
    }

    # Inline borgcheck logic - updates borg status
    if ($$VARS{borged}) {
        my $t = time;
        my $numborged = $$VARS{numborged} || 1;
        $numborged *= 2;

        if ($t - $$VARS{borged} >= 300 + 60 * $numborged) {
            $$VARS{lastborg} = $$VARS{borged};
            delete $$VARS{borged};
            $self->DB->sqlUpdate('room', {borgd => '0'}, 'member_user=' . $self->DB->getId($USER));
        }
    }

    $content .= "\n" . $XG->borgstatus(
        {value => ($$VARS{borged} ? "1" : "0")},
        ($$VARS{borged} ? "borged" : "unborged")
    );

    my $room_content = '';
    if ($$USER{in_room} != 0) {
        my $rm = $self->DB->getNodeById($$USER{in_room});
        $room_content = $XG->e2link({node_id => $$rm{node_id}}, $$rm{title}) if $rm;
    }
    $content .= "\n" . $XG->in_room($room_content);

    # Personal nodes
    my $pnodes = '';
    foreach(split('<br>', $$VARS{personal_nodelet} || '')) {
        next unless $_;
        $pnodes .= $XG->pn($_);
    }
    $content .= "\n" . $XG->personalnodes($pnodes);

    # Inline shownewexp logic for XML output
    unless ($$VARS{oldexp}) {
        $$VARS{oldexp} = $$USER{experience};
    }

    if ($$VARS{oldexp} != $$USER{experience}) {
        my $newexp = $$USER{experience} - $$VARS{oldexp};
        $$VARS{oldexp} = $$USER{experience};

        my $lvl = $self->APP->getLevel($USER) + 1;
        my $level_exp_node = $self->DB->getNode('level experience', 'setting');
        my $level_wrp_node = $self->DB->getNode('level writeups', 'setting');
        my $LVLS = $self->APP->getVars($level_exp_node);
        my $WRPS = $self->APP->getVars($level_wrp_node);

        my $expleft = (exists $$LVLS{$lvl}) ? ($$LVLS{$lvl} - $$USER{experience}) : 0;
        my $numwu = $$VARS{numwriteups} || 0;
        my $wrpleft = (exists $$WRPS{$lvl}) ? ($$WRPS{$lvl} - $numwu) : undef;

        $content .= "\n" . $XG->xpinfo(
            $XG->xpchange({value => $newexp}, $$USER{experience}) .
            "\n" .
            $XG->nextlevel({experience => $expleft, writeups => $wrpleft}, $lvl)
        );
    }

    $content .= "\n" . $XG->cools($$VARS{cools} || 0);
    $content .= "\n" . $XG->votesleft($$USER{votesleft});
    $content .= "\n" . $XG->karma($$USER{karma});
    $content .= "\n" . $XG->experience($$USER{experience});
    $content .= "\n" . $XG->numwriteups($$VARS{numwriteups} || 0);

    my $userlock = $self->DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$USER{user_id}");
    my $forbiddance = '';
    $forbiddance = $$userlock{nodelock_reason} if $userlock;
    $content .= "\n" . $XG->forbiddance($forbiddance);

    return $self->xml_header() . $XG->e2session("\n" . $content . "\n");
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut
