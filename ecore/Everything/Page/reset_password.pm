package Everything::Page::reset_password;

use Moose;
extends 'Everything::Page';

# Password reset is accessible to everyone (including guests)

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        resetPassword => {
            validForMinutes => 20,
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
