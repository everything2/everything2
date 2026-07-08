package Everything::API::notelet;

use Moose;
extends 'Everything::API';

with 'Everything::Roles::Notelet';

# Self-service notelet mutations (#4479, Refs #4298). Replaces the render-time ?makethechange /
# ?YesReallyCastrate writes that Everything::Page::notelet_editor used to perform in
# buildReactData off query params. Both endpoints are logged-in-only (a user edits their own
# notelet); the shared save/castrate/payload logic lives in Everything::Roles::Notelet so the
# page stays pure-render.
#
#   POST /api/notelet/save     { notelet_source, keep_comments } -> save the raw source
#   POST /api/notelet/castrate                                    -> comment out all JS

sub routes {
    return {
        'save'     => 'save',
        'castrate' => 'castrate',
    };
}

sub save {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'You must be logged in to edit your notelet.'}]
        if $user->is_guest;

    my $data = $REQUEST->JSON_POSTDATA;
    $data = {} unless ref $data eq 'HASH';

    my $source        = defined $data->{notelet_source} ? $data->{notelet_source} : '';
    my $keep_comments = $data->{keep_comments} ? 1 : 0;

    my $error = $self->save_notelet($user, $source, $keep_comments);

    return [$self->HTTP_OK, {
        success => 1,
        error   => $error,
        message => $error ? '' : 'Notelet saved successfully!',
        %{ $self->notelet_payload($user) },
    }];
}

sub castrate {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'You must be logged in to edit your notelet.'}]
        if $user->is_guest;

    $self->castrate_notelet($user);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Notelet castrated successfully!',
        %{ $self->notelet_payload($user) },
    }];
}

__PACKAGE__->meta->make_immutable;
1;
