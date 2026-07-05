package Everything::API::usergroup_message_archive;

use Moose;
extends 'Everything::API';

use Everything qw(getId getNode setVars);

# POST /api/usergroup_message_archive/copy -- logged-in (#4472, Refs #4298). Mirrors the
# archive form submit: copy the selected group-archive messages into the caller's own
# message box, and persist the `ugma_resettime` preference. Re-verifies membership +
# allow_message_archive server-side, and that each message actually belongs to the named
# group's archive. Replaces the cpgroupmsg_* / ugma_resettime mutation loop in
# Everything::Page::usergroup_message_archive's buildReactData.

sub routes {
    return { 'copy' => 'copy_messages' };
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
