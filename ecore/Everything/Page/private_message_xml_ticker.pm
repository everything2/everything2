package Everything::Page::private_message_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::private_message_xml_ticker - Private Message XML Ticker

=head1 DESCRIPTION

Returns private messages for the authenticated user in XML format.

Query parameters:
- fromuser: Filter messages by author username
- messageidstart: Return only messages with message_id greater than this value

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of private messages.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n<PRIVATE_MESSAGES></PRIVATE_MESSAGES>}, {type => $self->mimetype}] if $self->APP->isGuest($USER);

    my $str = '';
    my $nl = "\n";
    my $UID = Everything::getId($USER) || 0;
    my $XG = XML::Generator->new();

    my $limits = 'for_user=' . $UID;
    my $filterUser = $query->param('fromuser');
    if ($filterUser) {
        $filterUser = Everything::getNode($filterUser, 'user');
        $filterUser = $filterUser ? $filterUser->{node_id} : 0;
    }
    $limits .= ' AND author_user=' . $filterUser if $filterUser;

    if ((defined $query->param('messageidstart')) && length($query->param('messageidstart'))) {
        my $idMin = $query->param('messageidstart');
        if ($idMin =~ /^(\d+)$/) {
            $idMin = $1;
            $limits .= ' AND message_id > ' . $idMin;
        }
    }

    my $csr = $self->DB->sqlSelectMany('*', 'message', $limits, 'order by tstamp, message_id');

    my $lines = 0;
    my @msgs = ();
    while (my $MSG = $csr->fetchrow_hashref) {
        $lines++;
        push @msgs, $MSG;
    }

    $str .= $XG->INFO({
        site => $self->CONF->site_url,
        sitename => $self->CONF->site_name,
        servertime => scalar(localtime(time))
    }, 'Rendered by the Private Message XML Ticker') . $nl;

    $str .= $XG->info({
        'for_user' => $UID,
        'for_username' => $self->APP->xml_escape($USER->{title}),
        'messagecount' => scalar(@msgs),
    }) . $nl;

    my $UG = undef;

    foreach my $MSG (@msgs) {
        my $FUSER = $self->DB->getNodeById($MSG->{author_user});
        my $forGroupID = $MSG->{for_usergroup} || 0;
        my $msgInfo = {
            time => $MSG->{tstamp},
            message_id => $MSG->{message_id}
        };

        $msgInfo->{'author'} = (defined $FUSER) ? $self->APP->xml_escape($FUSER->{title}) : '!!! user with node_id of ' . $MSG->{author_user} . ' was deleted !!!';

        if ($forGroupID) {
            $msgInfo->{for_usergroup_id} = $forGroupID;
            $UG = $self->DB->getNodeById($forGroupID) || undef;
            $msgInfo->{for_usergroup} = (defined $UG) ? $UG->{title} : '!!! usergroup with node_id of ' . $forGroupID . ' was deleted !!!';
        }

        $str .= $nl . "\t" . $XG->message($msgInfo, $nl . $self->APP->xml_escape($MSG->{msgtext}));
    }

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $XG->PRIVATE_MESSAGES($str . $nl), {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
