package Everything::API::weblog;

use Moose;
use namespace::autoclean;
use JSON;
extends 'Everything::API';

=head1 NAME

Everything::API::weblog - Weblog entry management API

=head1 DESCRIPTION

Handles weblog entry operations (remove entries from weblogs).
Used by News for Noders and usergroup weblogs.

=head1 ENDPOINTS

=head2 DELETE /api/weblog/:weblog_id/:to_node

Remove an entry from a weblog (soft delete by setting removedby_user).

=cut

sub routes {
    return {
        '/:weblog_id/:to_node' => 'handle_entry',
    };
}

sub handle_entry {
    my ($self, $REQUEST, $weblog_id, $to_node) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'delete') {
        return $self->remove_entry($REQUEST, $weblog_id, $to_node);
    }

    return [$self->HTTP_OK, {
        success => 0,
        error => 'Method not allowed'
    }];
}

sub remove_entry {
    my ($self, $REQUEST, $weblog_id, $to_node) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Validate IDs
    $weblog_id = int($weblog_id || 0);
    $to_node = int($to_node || 0);

    unless ($weblog_id && $to_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid weblog_id or to_node'
        }];
    }

    # Check if user is logged in
    if ($user->is_guest) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Must be logged in'
        }];
    }

    # Get the weblog node to check ownership
    my $weblog_node = $DB->getNodeById($weblog_id);
    unless ($weblog_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Weblog not found'
        }];
    }

    # Check permissions: admin, usergroup owner, or original linker
    my $is_admin = $APP->isAdmin($user->NODEDATA);
    my $is_owner = 0;

    # Check if user is the usergroup owner (if this is a usergroup weblog)
    if ($weblog_node->{type}{title} eq 'usergroup') {
        my $owner_id = $APP->getParameter($weblog_id, 'usergroup_owner');
        $is_owner = 1 if $owner_id && $user->node_id == $owner_id;
    }

    # Check if user originally linked this entry
    my $is_linker = $DB->sqlSelect(
        'linkedby_user',
        'weblog',
        "weblog_id=" . $DB->quote($weblog_id) .
        " AND to_node=" . $DB->quote($to_node) .
        " AND linkedby_user=" . $DB->quote($user->node_id) .
        " AND removedby_user=0"
    );

    unless ($is_admin || $is_owner || $is_linker) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Permission denied'
        }];
    }

    # Check that the entry exists and isn't already removed
    my $entry_exists = $DB->sqlSelect(
        'to_node',
        'weblog',
        "weblog_id=" . $DB->quote($weblog_id) .
        " AND to_node=" . $DB->quote($to_node) .
        " AND removedby_user=0"
    );

    unless ($entry_exists) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Entry not found or already removed'
        }];
    }

    # Perform the soft delete
    my $sth = $DB->getDatabaseHandle()->prepare(
        'UPDATE weblog SET removedby_user=? WHERE weblog_id=? AND to_node=?'
    );
    $sth->execute($user->node_id, $weblog_id, $to_node);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Entry removed'
    }];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::API>

=cut
