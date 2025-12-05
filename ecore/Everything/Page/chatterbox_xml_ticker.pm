package Everything::Page::chatterbox_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::chatterbox_xml_ticker - Chatterbox XML Ticker (DEPRECATED)

=head1 DESCRIPTION

Legacy chatterbox XML ticker deprecated since 2002. Returns recent room messages
in XML format. Use universal_message_xml_ticker instead.

Query parameters:
- None (uses USER's in_room)

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of recent chatterbox messages.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    my $room = $USER->{in_room};
    $room ||= 0;
    my $RNODE = $self->DB->getNodeById($room);
    my $str = '';
    my $XG = XML::Generator->new();

    my $oldUA = $query->user_agent();
    if (index($oldUA,'JChatter/0.1.12.1beta')!=-1) {
        $oldUA = 1;
    } else {
        $oldUA = 0;
    }

    my $csr = $self->DB->sqlSelectMany('*', 'message', "for_user=0 and room=$room and tstamp > date_sub(now(), interval 500 second)", 'order by tstamp');

    my @msgs = ();
    while (my $MSG = $csr->fetchrow_hashref) {
        push @msgs, $MSG;
    }

    my $V = Everything::getVars($self->DB->getNode('room topics','setting'));
    my $topic = '';
    if (exists $V->{$room}) {
        $topic = $V->{$room};
        $topic = $query->escape($topic);
    }

    $str .= $XG->INFO({
        site => $self->CONF->site_url,
        sitename => $self->CONF->site_name,
        servertime => scalar(localtime(time)),
        room => $RNODE->{title},
        topic => $topic
    }, "Rendered by the Chatterbox XML Ticker, which has been deprecated since 2002. Use the universal message xml ticker instead.");

    my $m = '';
    my $mTime = '';
    foreach my $MSG (@msgs) {
        my $FUSER = $self->DB->getNodeById($MSG->{author_user});
        $m = $MSG->{msgtext};

        $m =~ s/\[([^\]]*?)$/&#91;$1/;

        $m = $self->APP->xml_escape($m);

        $mTime = $MSG->{tstamp};
        if ($oldUA) {
            if ($mTime =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
                $mTime = $1.$2.$3.$4.$5.$6;
            } else {
                $mTime .= ' no';
            }
        }

        $str .= "\n" . $XG->message({
            author => $self->APP->xml_escape($FUSER->{title}),
            time => $mTime,
        }, "\n" . $m);
    }

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $XG->CHATTER($str . "\n"), {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
