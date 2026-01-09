package Everything::API::collaborations;

use Moose;
extends 'Everything::API';

use POSIX qw(strftime);

# API for managing collaborations
# Collaborations are private group documents with access control and edit locking

use constant LOCK_EXPIRE_SECONDS => 15 * 60;  # 15 minutes

sub routes {
    return {
        '/:id/action/save' => 'save(:id)',
        '/:id/action/unlock' => 'unlock(:id)',
        '/:id/action/addmember' => 'addmember(:id)',
        '/:id/action/removemember' => 'removemember(:id)',
    };
}

# Check if user can access the collaboration
sub _check_access {
    my ($self, $user, $node) = @_;

    my $APP = $self->APP;

    # Admins always have access
    return 1 if $user->is_admin;

    # Content Editors have access
    return 1 if $user->is_editor;

    # crtleads members have access
    my $crtleads = $self->DB->getNode('crtleads', 'usergroup');
    if ($crtleads && Everything::isApproved($user->NODEDATA, $crtleads)) {
        return 1;
    }

    # Check if user is in the collaboration's approved list
    if (Everything::isApproved($user->NODEDATA, $node->NODEDATA)) {
        return 1;
    }

    return 0;
}

# Check if lock has expired
sub _is_lock_expired {
    my ($self, $locktime) = @_;

    return 1 unless $locktime && $locktime ne '0000-00-00 00:00:00';

    my $expire_threshold = strftime('%Y-%m-%d %H:%M:%S', localtime(time() - LOCK_EXPIRE_SECONDS));
    return $locktime lt $expire_threshold;
}

# Get member list with node info
sub _get_members {
    my ($self, $node) = @_;

    my @members;
    my $group = $node->NODEDATA->{group} || [];

    foreach my $member_id (@$group) {
        my $member = $self->APP->node_by_id($member_id);
        next unless $member;

        push @members, {
            node_id => int($member_id),
            title => $member->title,
            type => $member->type->title
        };
    }

    return \@members;
}

sub save {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;

    # Get the collaboration node
    my $node = $self->APP->node_by_id($id);

    unless ($node && $node->type->title eq 'collaboration') {
        return [$self->HTTP_OK, {success => 0, error => 'Collaboration not found'}];
    }

    # Check access
    unless ($self->_check_access($user, $node)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Check lock - user must hold the lock (or be admin/CE) to save
    my $lockedby = $node->NODEDATA->{lockedby_user} || 0;
    my $locktime = $node->NODEDATA->{locktime} || '0000-00-00 00:00:00';

    unless ($lockedby == $user->node_id || $user->is_admin || $user->is_editor) {
        # Check if lock expired
        unless ($self->_is_lock_expired($locktime)) {
            return [$self->HTTP_OK, {success => 0, error => 'Document is locked by another user'}];
        }
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    # Update doctext if provided
    if (exists $data->{doctext}) {
        $node->NODEDATA->{doctext} = $data->{doctext} // '';
    }

    # Update public flag if provided
    if (exists $data->{public}) {
        $node->NODEDATA->{public} = $data->{public} ? 1 : 0;
    }

    # Refresh the lock time
    $node->NODEDATA->{locktime} = strftime('%Y-%m-%d %H:%M:%S', localtime());
    $node->NODEDATA->{lockedby_user} = $user->node_id;

    # Update the node
    $DB->updateNode($node->NODEDATA, $user->node_id);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Collaboration saved'
    }];
}

sub unlock {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;

    # Get the collaboration node
    my $node = $self->APP->node_by_id($id);

    unless ($node && $node->type->title eq 'collaboration') {
        return [$self->HTTP_OK, {success => 0, error => 'Collaboration not found'}];
    }

    # Check access
    unless ($self->_check_access($user, $node)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Check if user can unlock (owner of lock, admin, CE, or lock expired)
    my $lockedby = $node->NODEDATA->{lockedby_user} || 0;
    my $locktime = $node->NODEDATA->{locktime} || '0000-00-00 00:00:00';

    my $can_unlock = ($lockedby == $user->node_id) ||
                     $user->is_admin ||
                     $user->is_editor ||
                     $self->_is_lock_expired($locktime);

    unless ($can_unlock) {
        return [$self->HTTP_OK, {success => 0, error => 'Cannot unlock - document is locked by another user'}];
    }

    # Clear the lock
    $node->NODEDATA->{locktime} = '0000-00-00 00:00:00';
    $node->NODEDATA->{lockedby_user} = 0;

    $DB->updateNode($node->NODEDATA, -1);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Document unlocked'
    }];
}

sub addmember {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;

    # Only admins and CEs can manage members
    unless ($user->is_admin || $user->is_editor) {
        return [$self->HTTP_OK, {success => 0, error => 'Only administrators and editors can manage members'}];
    }

    my $DB = $self->DB;

    # Get the collaboration node
    my $node = $self->APP->node_by_id($id);

    unless ($node && $node->type->title eq 'collaboration') {
        return [$self->HTTP_OK, {success => 0, error => 'Collaboration not found'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH' && $data->{name}) {
        return [$self->HTTP_OK, {success => 0, error => 'Member name required'}];
    }

    my $name = $data->{name};

    # Look up the user or usergroup
    my $member = $DB->getNode($name, 'user') || $DB->getNode($name, 'usergroup');

    unless ($member) {
        return [$self->HTTP_OK, {success => 0, error => "User or group '$name' not found"}];
    }

    # Check if already a member
    my $group = $node->NODEDATA->{group} || [];
    if (grep { $_ == $member->{node_id} } @$group) {
        return [$self->HTTP_OK, {success => 0, error => "'$name' is already a member"}];
    }

    # Add to the group (signature: $NODE, $USER, $insert)
    $DB->insertIntoNodegroup($node->NODEDATA, -1, $member);

    # Refresh and return updated members
    $node->cache_refresh;

    return [$self->HTTP_OK, {
        success => 1,
        message => "Added '$name' to collaboration",
        members => $self->_get_members($node)
    }];
}

sub removemember {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;

    # Only admins and CEs can manage members
    unless ($user->is_admin || $user->is_editor) {
        return [$self->HTTP_OK, {success => 0, error => 'Only administrators and editors can manage members'}];
    }

    my $DB = $self->DB;

    # Get the collaboration node
    my $node = $self->APP->node_by_id($id);

    unless ($node && $node->type->title eq 'collaboration') {
        return [$self->HTTP_OK, {success => 0, error => 'Collaboration not found'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH' && $data->{node_id}) {
        return [$self->HTTP_OK, {success => 0, error => 'Member node_id required'}];
    }

    my $member_id = $data->{node_id};

    # Get the member node
    my $member = $DB->getNodeById($member_id);

    unless ($member) {
        return [$self->HTTP_OK, {success => 0, error => 'Member not found'}];
    }

    # Remove from the group
    $DB->removeFromNodegroup($node->NODEDATA, $member, -1);

    # Refresh and return updated members
    $node->cache_refresh;

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Member removed',
        members => $self->_get_members($node)
    }];
}

around ['save', 'unlock', 'addmember', 'removemember'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
