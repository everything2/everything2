package Everything::Page::node_backup;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    # Check if in development environment
    my $is_development = $Everything::CONF->environment eq 'development';

    return {
        type          => 'node_backup',
        isAdmin       => $APP->isAdmin($USER->NODEDATA) ? \1 : \0,
        isDevelopment => $is_development ? \1 : \0,
    };
}

__PACKAGE__->meta->make_immutable;

1;
