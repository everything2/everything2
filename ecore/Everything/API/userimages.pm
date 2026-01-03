package Everything::API::userimages;

use Moose;
extends 'Everything::API';

sub routes {
    return {
        'approve' => 'approve',
        'delete'  => 'remove_image',
    };
}

sub approve {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}]
        unless $user->is_editor;

    my $data = $REQUEST->JSON_POSTDATA;
    my $user_id = $data->{userId};

    return [$self->HTTP_OK, {success => 0, error => 'User ID required'}]
        unless $user_id && $user_id =~ /^\d+$/;

    # Remove from pending queue (image is already set on user node)
    $self->DB->getDatabaseHandle()->do(
        "DELETE FROM newuserimage WHERE newuserimage_id = ?",
        undef,
        int($user_id)
    );

    $self->APP->securityLog(
        $user->NODEDATA,
        $self->APP->node_by_id($user_id)->NODEDATA,
        'Approved user image'
    );

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Image approved',
    }];
}

sub remove_image {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}]
        unless $user->is_editor;

    my $data = $REQUEST->JSON_POSTDATA;
    my $user_id = $data->{userId};

    return [$self->HTTP_OK, {success => 0, error => 'User ID required'}]
        unless $user_id && $user_id =~ /^\d+$/;

    # Get the user node and clear their image
    my $target_user = $self->APP->node_by_id($user_id);
    return [$self->HTTP_OK, {success => 0, error => 'User not found'}]
        unless $target_user;

    # Clear the image
    $target_user->NODEDATA->{imgsrc} = '';
    $self->DB->updateNode($target_user->NODEDATA, -1);

    # Remove from pending queue
    $self->DB->getDatabaseHandle()->do(
        "DELETE FROM newuserimage WHERE newuserimage_id = ?",
        undef,
        int($user_id)
    );

    $self->APP->securityLog(
        $user->NODEDATA,
        $target_user->NODEDATA,
        'Removed user image'
    );

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Image removed',
    }];
}

__PACKAGE__->meta->make_immutable;

1;
