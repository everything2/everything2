package Everything::Controller::collaboration;

use Moose;
extends 'Everything::Controller';

use POSIX qw(strftime);
use Readonly;

# Controller for collaboration nodes
# Collaborations are private group documents with:
# - Access control (admins, CEs, crtleads, and approved users/groups)
# - Edit locking (15-minute auto-expire)
# - Public/private toggle
# - Member management (who can access)

Readonly my $LOCK_EXPIRE_SECONDS => 15 * 60;  # 15 minutes

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

    # Parse locktime and compare to expiry threshold
    my $expire_threshold = strftime('%Y-%m-%d %H:%M:%S', localtime(time() - $LOCK_EXPIRE_SECONDS));

    # String comparison works for datetime format
    return $locktime lt $expire_threshold;
}

# Clear the lock on a node
sub _clear_lock {
    my ($self, $node) = @_;

    $node->NODEDATA->{locktime} = '0000-00-00 00:00:00';
    $node->NODEDATA->{lockedby_user} = 0;
    $self->DB->updateNode($node->NODEDATA, -1);
    return;
}

# Set lock on a node
sub _set_lock {
    my ($self, $node, $user_id) = @_;

    $node->NODEDATA->{locktime} = strftime('%Y-%m-%d %H:%M:%S', localtime());
    $node->NODEDATA->{lockedby_user} = $user_id;
    $self->DB->updateNode($node->NODEDATA, -1);
    return;
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

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;
    my $cgi = $REQUEST->cgi;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    # Get collaboration data
    my $lockedby_user = $node->NODEDATA->{lockedby_user} || 0;
    my $locktime = $node->NODEDATA->{locktime} || '0000-00-00 00:00:00';
    my $is_public = $node->NODEDATA->{public} ? 1 : 0;

    # Handle unlock action
    my $unlock_msg;
    if ($cgi->param('unlock') && $cgi->param('unlock') eq 'true') {
        if ($can_access) {
            my $can_unlock = $user->is_admin || $user->is_editor ||
                            $lockedby_user == $user_id ||
                            $self->_is_lock_expired($locktime);
            if ($can_unlock) {
                $self->_clear_lock($node);
                $lockedby_user = 0;
                $locktime = '0000-00-00 00:00:00';
                $unlock_msg = 'Document unlocked.';
            }
        }
    }

    # Auto-expire stale locks
    if ($lockedby_user && $self->_is_lock_expired($locktime)) {
        $self->_clear_lock($node);
        $lockedby_user = 0;
        $locktime = '0000-00-00 00:00:00';
    }

    # Determine lock state
    my $is_locked = $lockedby_user ? 1 : 0;
    my $is_locked_by_me = ($lockedby_user == $user_id) ? 1 : 0;
    my $lockedby_other = ($is_locked && !$is_locked_by_me) ? 1 : 0;

    # Can edit if: has access AND (admin/CE OR not locked by someone else)
    my $can_edit = $can_access && ($user->is_admin || $user->is_editor || !$lockedby_other);

    # Get locker info
    my $lockedby_data;
    if ($lockedby_user) {
        my $locker = $self->APP->node_by_id($lockedby_user);
        if ($locker) {
            $lockedby_data = {
                node_id => int($lockedby_user),
                title => $locker->title
            };
        }
    }

    # Get members
    my $members = $self->_get_members($node);

    # Get author
    my $author_data;
    if ($node->NODEDATA->{author_user}) {
        my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});
        if ($author) {
            $author_data = {
                node_id => int($node->NODEDATA->{author_user}),
                title => $author->title
            };
        }
    }

    # Build content data
    my $content_data = {
        type => 'collaboration',
        collaboration => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            public => $is_public,
            locktime => $locktime,
            lockedby_user => int($lockedby_user),
            author => $author_data,
            createtime => $node->NODEDATA->{createtime}
        },
        members => $members,
        lockedby => $lockedby_data,
        can_access => $can_access ? 1 : 0,
        can_edit => $can_edit ? 1 : 0,
        is_locked => $is_locked,
        is_locked_by_me => $is_locked_by_me,
        is_public => $is_public,
        unlock_msg => $unlock_msg,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0,
            is_editor => $user->is_editor ? 1 : 0
        }
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

sub useredit {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;

    # Check access
    my $can_access = $self->_check_access($user, $node);

    unless ($can_access) {
        # Return display with permission denied
        return $self->display($REQUEST, $node);
    }

    # Get current lock state
    my $lockedby_user = $node->NODEDATA->{lockedby_user} || 0;
    my $locktime = $node->NODEDATA->{locktime} || '0000-00-00 00:00:00';

    # Auto-expire stale locks
    if ($lockedby_user && $self->_is_lock_expired($locktime)) {
        $lockedby_user = 0;
        $locktime = '0000-00-00 00:00:00';
    }

    my $is_locked_by_other = ($lockedby_user && $lockedby_user != $user_id) ? 1 : 0;

    # Can we acquire the lock?
    my $can_lock = $user->is_admin || $user->is_editor || !$is_locked_by_other;

    unless ($can_lock) {
        # Return display with lock info
        return $self->display($REQUEST, $node);
    }

    # Acquire the lock
    $self->_set_lock($node, $user_id);

    # Refresh lock state
    $lockedby_user = $user_id;
    $locktime = $node->NODEDATA->{locktime};

    # Get locker info (it's now us)
    my $lockedby_data = {
        node_id => $user_id,
        title => $user->title
    };

    # Get members
    my $members = $self->_get_members($node);

    # Build content data for edit mode
    my $content_data = {
        type => 'collaborationEdit',
        collaboration => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node->NODEDATA->{doctext} || '',
            public => $node->NODEDATA->{public} ? 1 : 0,
            locktime => $locktime,
            lockedby_user => int($lockedby_user)
        },
        members => $members,
        lockedby => $lockedby_data,
        can_access => 1,
        can_edit => 1,
        can_manage_members => ($user->is_admin || $user->is_editor) ? 1 : 0,
        is_locked => 1,
        is_locked_by_me => 1,
        user => {
            node_id => $user_id,
            title => $user->title,
            is_guest => $user->is_guest ? 1 : 0,
            is_admin => $user->is_admin ? 1 : 0,
            is_editor => $user->is_editor ? 1 : 0
        }
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $user->NODEDATA,
        $user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    my $html = $self->layout('/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable();
1;
