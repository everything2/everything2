package Everything::API::usergrouppicks;

use Moose;
extends 'Everything::API';

sub routes {
    return {
        'unlink' => 'unlink_node',
    };
}

sub unlink_node {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $data = $REQUEST->JSON_POSTDATA;
    my $weblog_id = $data->{weblog_id};
    my $node_id = $data->{node_id};

    return [$self->HTTP_OK, {success => 0, error => 'Missing weblog_id'}]
        unless $weblog_id && $weblog_id =~ /^\d+$/;

    return [$self->HTTP_OK, {success => 0, error => 'Missing node_id'}]
        unless $node_id && $node_id =~ /^\d+$/;

    my $DB = $self->DB;
    my $USER_DATA = $user->NODEDATA;

    # Update the weblog entry to mark it as removed
    my $result = $DB->sqlUpdate(
        'weblog',
        { removedby_user => $USER_DATA->{user_id} },
        "weblog_id='$weblog_id' AND to_node='$node_id'"
    );

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Node unlinked from group',
    }];
}

__PACKAGE__->meta->make_immutable;

1;
