package Everything::API::usergroup_message_archive;

use Moose;
extends 'Everything::API';

use Everything qw(getId getNode getNodeById setVars);

# GET  /api/usergroup_message_archive       -- the read view (list, #4541)
# POST /api/usergroup_message_archive/copy  -- the copy mutation (#4472, Refs #4298)
sub routes {
    return { '/' => 'list', 'copy' => 'copy_messages' };
}

# GET /api/usergroup_message_archive?viewgroup=<name>&max_show=<n>&startnum=<n>
# Moved out of Everything::Page::usergroup_message_archive's buildReactData (#4541): the Page is a
# pure gate, React reads viewgroup/max_show/startnum off the URL and calls this. Logged-in only;
# error C<state>s ('guest'/'no_such_group'/'not_member'/'no_archive') carry the copy in React.
sub list {
    my ($self, $REQUEST) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    my $USER = $user->NODEDATA;

    # Groups that archive messages (the picker).
    my @archive_groups;
    foreach my $ug_id (@{ $APP->getNodesWithParameter('allow_message_archive') || [] }) {
        my $ug = getNodeById($ug_id) or next;
        push @archive_groups, { node_id => int($ug->{node_id}), title => $ug->{title} };
    }

    my $viewgroup = $REQUEST->param('viewgroup');
    return [$self->HTTP_OK, { success => 1, archive_groups => \@archive_groups }]
        unless defined($viewgroup) && $viewgroup ne '';

    my $UG = getNode($viewgroup, 'usergroup');
    return [$self->HTTP_OK, { success => 0, state => 'no_such_group', archive_groups => \@archive_groups }]
        unless $UG;

    my $selected = { node_id => int($UG->{node_id}), title => $UG->{title} };

    return [$self->HTTP_OK, { success => 0, state => 'not_member', archive_groups => \@archive_groups, selected_group => $selected }]
        unless Everything::isApproved($USER, $UG);

    return [$self->HTTP_OK, { success => 0, state => 'no_archive', archive_groups => \@archive_groups, selected_group => $selected }]
        unless $APP->getParameter($UG, 'allow_message_archive');

    my $ugID = getId($UG);
    my $VARS = $APP->getVars($USER);

    my $LIMITS = "for_user=$ugID AND for_usergroup=$ugID";   # $ugID is an int -> injection-safe
    my ($numMsg) = $DB->sqlSelect('COUNT(*)', 'message', $LIMITS);
    $numMsg ||= 0;

    my $max_show_p = $REQUEST->param('max_show');
    my $max_show = (defined $max_show_p && $max_show_p =~ /^\d+$/ && $max_show_p > 0) ? int($max_show_p) : 25;

    my $start_default = $numMsg - $max_show;
    $start_default = 0 if $start_default < 0;

    my $startnum_p = $REQUEST->param('startnum');
    my $show_start = (defined $startnum_p && $startnum_p =~ /^\d+$/) ? int($startnum_p) : $start_default;
    $show_start = $start_default if $show_start > $start_default;
    $show_start = 0 if $show_start < 0;

    my $csr = $DB->sqlSelectMany('*', 'message', $LIMITS, "ORDER BY tstamp,message_id LIMIT $show_start,$max_show");

    my @messages;
    my $msg_count = $show_start;
    while (my $row = $csr->fetchrow_hashref) {
        $msg_count++;
        my $author = $row->{author_user} ? getNodeById($row->{author_user}) : undef;
        (my $author_name = $author ? $author->{title} : '') =~ tr/ /_/;

        my $text = $row->{msgtext} || '';
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/\s+\\n\s+/<br \/>/g;
        $text = $APP->parseLinks($text);
        $text =~ s/\[/&#91;/g;

        push @messages, {
            message_id   => int($row->{message_id}),
            number       => $msg_count,
            author_id    => $author ? int($author->{node_id}) : 0,
            author_title => $APP->encodeHTML($author_name),
            timestamp    => $row->{tstamp},
            text         => $text,
        };
    }
    $csr->finish;

    return [$self->HTTP_OK, {
        success        => 1,
        archive_groups => \@archive_groups,
        selected_group => $selected,
        messages       => \@messages,
        total_messages => int($numMsg),
        show_start     => int($show_start),
        max_show       => int($max_show),
        num_show       => scalar(@messages),
        reset_time     => $VARS->{ugma_resettime} ? \1 : \0,   # JSON boolean (#4108)
    }];
}

sub copy_messages {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'You must login to use this feature.'}]
        if $user->is_guest;

    my $USER = $user->NODEDATA;
    my $data = $REQUEST->JSON_POSTDATA;

    my $UG = getNode($data->{group}, 'usergroup');
    return [$self->HTTP_OK, {success => 0, error => 'There is no such usergroup.'}]
        unless $UG;

    return [$self->HTTP_OK,
        {success => 0, error => "You aren't a member of this group, so you can't view the group's messages."}]
        unless Everything::isApproved($USER, $UG);

    return [$self->HTTP_OK, {success => 0, error => "This group doesn't archive messages."}]
        unless $self->APP->getParameter($UG, 'allow_message_archive');

    my $ugID   = getId($UG);
    my $userid = getId($USER);

    # Persist the reset-time preference (checkbox state travels with the submit).
    my $reset_time = $data->{reset_time} ? 1 : 0;
    my $VARS = $self->APP->getVars($USER);
    $VARS->{ugma_resettime} = $reset_time;
    setVars($USER, $VARS);
    $self->DB->updateNode($USER, -1);

    # Copy each selected message that genuinely belongs to this group's archive.
    my $ids = $data->{message_ids};
    $ids = [] unless ref $ids eq 'ARRAY';

    my $copied = 0;
    foreach my $mid (@$ids) {
        next unless defined $mid && $mid =~ /^\d+$/;
        my $MSG = $self->DB->sqlSelectHashref('*', 'message', 'message_id=' . int($mid));
        next unless $MSG;
        next unless ($MSG->{for_user} == $ugID) && ($MSG->{for_usergroup} == $ugID);

        delete $MSG->{message_id};
        delete $MSG->{tstamp} if $reset_time;
        $MSG->{for_user} = $userid;
        $self->DB->sqlInsert('message', $MSG);
        $copied++;
    }

    return [$self->HTTP_OK, {
        success       => 1,
        copied_count  => $copied,
        reset_time    => $reset_time,
    }];
}

__PACKAGE__->meta->make_immutable;

1;
