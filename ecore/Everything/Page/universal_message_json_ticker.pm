package Everything::Page::universal_message_json_ticker;

use Moose;
extends 'Everything::Page';

has 'mimetype' => (default => 'application/json', is => 'ro');

=head1 NAME

Everything::Page::universal_message_json_ticker - Universal Message JSON API

=head1 DESCRIPTION

Returns JSON feed of chat messages for rooms and private messages.

Supports query parameters:
- for_node: Node ID or "me" (default: 0 = outside)
- msglimit: Only return messages with ID > this value (default: 0)
- backtime: Time window in minutes - 5 or 10 (default: 5)
- nosort: If 1, don't sort by message_id (default: 0)
- links_noparse: If 1, don't parse [square bracket] links (default: 0)
- do_the_right_thing: If 1, escape angle brackets in room topics (default: 0)

=head1 METHODS

=head2 display($REQUEST, $node)

Returns JSON feed of messages based on query parameters.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;
    my $VARS = $APP->getVars($USER);
    my $query = $REQUEST->cgi;

    # Sanitize msglimit to prevent SQL injection
    my $msglimit = int($query->param("msglimit") || 0);
    if ($msglimit !~ /^[0-9]*$/) {
        $msglimit = 0;
    }

    my $for_node = $query->param("for_node") || 0;
    my $backtime = $query->param("backtime") || 0;
    my $nosort = $query->param("nosort") || 0;
    my $lnp = $query->param("links_noparse") || 0;

    # Handle "me" as for_node
    $for_node = $USER->node_id if ($for_node eq "me");

    # Sanitize parameters
    $nosort ||= 0;
    $for_node ||= 0;
    $msglimit ||= 0;
    $backtime ||= 0;

    my $recip = $for_node ? $DB->getNodeById($for_node) : undef;

    # Default to "outside" room if for_node is 0
    if ($for_node == 0) {
        my $room_type = $DB->getType('room');
        $recip = {
            type_nodetype => $room_type->{node_id},
            node_id => 0,
            title => "outside",
            criteria => "1;"
        };
    }

    my $limits = "";
    my $secs;
    my $messages = {};

    # Handle room messages
    if ($recip->{type_nodetype} == $DB->getType('room')->{node_id}) {
        # Check room access using delegation
        my $roomTitle = $recip->{title} || '';
        $roomTitle =~ s/[\s\-]/_/g;  # Replace spaces and hyphens with underscores
        $roomTitle = lc($roomTitle);

        my $hasAccess = 1;  # Default to allow (public room)

        # Check if room has delegation function for access control
        my $roomDelegation = Everything::Delegation::room->can($roomTitle);
        if ($roomDelegation) {
            $hasAccess = $roomDelegation->($USER->NODEDATA, $VARS, $APP);
        }

        if ($hasAccess
            && (!$APP->isGuest($USER->NODEDATA)
            || $self->is_public_room($recip->{node_id}))
            ) {
            my $room_topics = $APP->node_by_name("room topics", "setting");
            my $room_vars = $APP->getVars($room_topics);
            my $topic = $room_vars->{$recip->{node_id}} || '';

            unless ($lnp == 1) {
                if ($query->param('do_the_right_thing')) {
                    $topic = $APP->escapeAngleBrackets($topic);
                }
                $topic = $self->parseLinks($topic);
            }

            $messages->{room} = {
                room_id => $recip->{node_id},
                content => $recip->{title}
            };

            $messages->{topic} = {content => $topic};

            # Validate backtime (only 5 and 10 are allowed)
            if ($backtime != 5 && $backtime != 10) {
                $backtime = 5;
            }

            $secs = $backtime * 60;

            if ($USER->in_room == $recip->{node_id} || $APP->isGuest($USER->NODEDATA)) {
                # Use interval here to avoid a table scan
                $limits = "message_id > $msglimit AND room='$recip->{node_id}' AND for_user='0'"
                        . " AND tstamp >= date_sub(now(), interval $secs second)";
            } else {
                $limits = "";
            }
        }
    }
    # Handle private messages
    elsif ($recip->{type_nodetype} == $DB->getType('user')->{node_id}) {
        $secs = $backtime * 60;

        if ($USER->node_id == $recip->{node_id}) {
            $limits = "message_id > $msglimit AND for_user='" . $USER->node_id . "' AND room='0'";
            # Avoid a table scan here, too
            $limits.= " AND tstamp >= date_sub(now(), interval $secs second)" if($secs > 0);
        } else {
            $limits = "";
        }
    }

    $limits .=" ORDER BY message_id" unless($nosort == 1 || $limits eq "");
    $limits = " message_id is NULL LIMIT 0" if($limits eq "");
    my $csr = $DB->sqlSelectMany("*", "message use index(foruser_tstamp)", $limits);

    my $username;
    my $msglist = [];

    unless ($APP->isGuest($recip->{node_id})) {
        while (my $row = $csr->fetchrow_hashref()) {
            my $msg = {};
            $msg->{msg_id} = $row->{message_id};
            $msg->{msg_time} = $row->{tstamp};
            $msg->{archive} = 1 if($row->{archive} == 1);

            my $frm = $DB->getNodeById($row->{author_user});
            my $grp = $DB->getNodeById($row->{for_usergroup});
            $username = $frm ? $frm->{title} : '';

            # Properly encode usernames
            utf8::encode($username) if $username;

            if($frm) {
                my $frmdata = [{
                    node_id => $frm->{node_id},
                    content => $username
                }];
                $msg->{from} = $frmdata;
            }

            if($grp) {
                $msg->{grp} = {
                    type    => $grp->{type}{title},
                    e2link  => {
                        node_id => $grp->{node_id},
                        content => $grp->{title}
                    }
                };
            }

            my $txt = $row->{msgtext};
            if($lnp != 1) {
                $txt = $self->parseLinks($txt);
            }

            $msg->{txt} = {content => $txt};
            push @$msglist, $msg;
        }
    }

    $messages->{msglist} = {msg => $msglist};

    # Return data structure - Router will handle JSON encoding
    return [$self->HTTP_OK, {messages => $messages}, {type => $self->mimetype}];
}

=head2 is_public_room($room_id)

Checks if a room is accessible to guest users.

=cut

sub is_public_room {
    my ($self, $room_id) = @_;

    my $public_rooms = $self->APP->node_by_name("public rooms", "setting");
    my $public_vars = $self->APP->getVars($public_rooms);

    return $public_vars->{$room_id} ? 1 : 0;
}

=head2 parseLinks($text)

Parses [square bracket] E2 links into HTML.

=cut

sub parseLinks {
    my ($self, $text) = @_;

    return Everything::HTML::parseLinks($text);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
