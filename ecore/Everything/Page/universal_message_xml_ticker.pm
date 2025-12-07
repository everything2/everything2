package Everything::Page::universal_message_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Simple;
use Everything::HTML;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::universal_message_xml_ticker - Universal Message XML Ticker

=head1 DESCRIPTION

Returns messages for rooms or users in XML format. This is the primary XML ticker
for retrieving chat messages, supporting both room messages and private messages.

Query parameters:
- for_node: Node ID of room or user (or "me" for current user)
- msglimit: Only return messages with message_id greater than this value
- backtime: Minutes to look back (5 or 10, defaults to 5)
- nosort: If 1, don't sort messages by message_id
- links_noparse: If 1, don't parse E2 links in message text

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of messages for the specified room or user.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    my $msglimit_raw = $query->param("msglimit") // '';
    my $msglimit = ($msglimit_raw =~ /^[0-9]+$/) ? int($msglimit_raw) : 0;

    my $for_node = $query->param("for_node") // '';
    my $backtime = $query->param("backtime");
    my $nosort = $query->param("nosort");
    my $lnp = $query->param("links_noparse") // 0;

    $for_node = $USER->{user_id} if ($for_node eq "me");

    $nosort ||= 0;
    $for_node ||= 0;
    $msglimit ||= 0; #not actually necessary due to call's fix above, but better safe than sorry -- tmw
    $backtime ||= 0;
    my $recip = $self->DB->getNodeById($for_node);

    if ($for_node == 0)
    {
        $recip->{type_nodetype} = Everything::getId($self->DB->getType('room'));
        $recip->{node_id} = 0;
        $recip->{title} = "outside";
        $recip->{criteria} = "1;";
    }

    my $limits = "";
    my $secs;
    my $room;
    my $messages = {};

    if ($recip->{type_nodetype} == Everything::getId($self->DB->getType('room')))
    {
        if ($self->APP->canEnterRoom($recip, $USER, Everything::getVars($USER))
            and ((!$self->APP->isGuest($USER))
            or Everything::getVars($self->DB->getNode("public rooms", "setting"))->{$recip->{node_id}})
            )
        {
            $room = Everything::getVars($self->DB->getNode("room topics", "setting"));
            my $topic = $room->{$recip->{node_id}};
            unless ($lnp == 1)
            {
                if ($query->param('do_the_right_thing'))
                {
                    $topic = $self->APP->escapeAngleBrackets($topic);
                }
                $topic = Everything::HTML::parseLinks($topic);
            }

            $messages -> {room} = {room_id => $recip->{node_id},
                                content => $recip->{title}
                                };

            $messages -> {topic} = {content => $topic};

            if ($backtime != 5 && $backtime != 10)
            {
                $backtime = 5;
            }

            $secs = $backtime * 60;

            if ($USER->{in_room} == $recip->{node_id} || $USER->{user_id} == Everything::getId($self->DB->getNode("Guest User", "user")))
            {
                # Use interval here to avoid a table scan -- [call]
                $limits = "message_id > $msglimit AND room='$recip->{node_id}' AND for_user='0'"
                    . " AND tstamp >= date_sub(now(), interval $secs second)";
            }
            else
            {
                $limits = "";
            }
        }
    }
    elsif ($recip->{type_nodetype} == Everything::getId($self->DB->getType('user')))
    {
        $secs = $backtime * 60;

        if ($USER->{user_id} == $recip->{node_id})
        {
            $limits = "message_id > $msglimit AND for_user='$USER->{user_id}' AND room='0'";
            # Avoid a table scan here, too. -- [call]
            $limits.= " AND tstamp >= date_sub(now(), interval $secs second)" if($secs > 0);
        }
        else
        {
            $limits = "";
        }
    }

    $limits .=" ORDER BY message_id" unless($nosort == 1 || $limits eq "");
    $limits = " message_id is NULL LIMIT 0" if($limits eq "");
    my $csr = $self->DB->sqlSelectMany("*", "message use index(foruser_tstamp)", $limits);

    my $gu = $self->DB->getNode("Guest User", "user");
    my $username;
    my $costume;
    my $msglist = [];

    unless ($recip->{node_id} == $gu->{node_id})
    {
        while (my $row = $csr->fetchrow_hashref())
        {
            my $msg = {};
            $msg -> {msg_id} = $row->{message_id};
            $msg -> {msg_time} = $row->{tstamp};
            $msg -> {archive} = 1 if($row->{archive} == 1);

            my $frm = $self->DB->getNodeById($row->{author_user});
            my $grp = $self->DB->getNodeById($row->{for_usergroup});
            $username = $frm->{title};

            if (Everything::HTML::htmlcode('isSpecialDate','halloween') && $room)
            {
                $costume = '';
                $costume = Everything::getVars($frm)->{costume} if (Everything::getVars($frm)->{costume});
                $costume =~ s/\t//g;

                if ($costume gt '')
                {
                    $username = $costume;
                }
            }

            #properly encode usernames
            utf8::encode($username);

            if($frm)
            {
                #This weird way of putting the form data is because we're using
                #<from> tags without any attributes, and XML::Simple will only
                #allow this for grouping tags.
                my $frmdata = [];
                my $md5 = Everything::HTML::htmlcode('getGravatarMD5', $frm);
                push @$frmdata, {node_id => $frm->{node_id},
                            content => $username,
                            md5 => $md5
                            };
                $msg -> {from} = $frmdata;
            }

            if($grp)
            {
                $msg -> {grp} = {type    => $grp->{type}{title},
                            e2link  => {node_id => $grp->{node_id},
                                        content => $grp->{title}
                                        },
                            };
            }

            my $txt = Everything::HTML::encodeHTML($row->{msgtext});
            unless ($lnp == 1)
            {
                $txt = Everything::HTML::parseLinks($txt);
            }

            $msg -> {txt} = {content => $txt};
            push @$msglist,  $msg;
        }
    }

    $messages -> {msglist} = { msg => $msglist };

    # For reason behind options, see
    # http://perldesignpatterns.com/?XmlSimple, as well as the XML::Simple
    # documentation.

    my $xmls = XML::Simple->new(
        RootName => undef,
        KeepRoot => 1,
        ForceArray => 1,
        ForceContent => 1,
        XMLDecl => 1,
        GroupTags => {from => 'e2link'}, #Hack to get <from> tags without attributes
    );
    my $xml = $xmls -> XMLout({"messages" => $messages});
    return [$self->HTTP_OK, $xml, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
