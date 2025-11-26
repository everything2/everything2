package Everything::Page::silver_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    # Determine which user's trinkets to show
    my $target_user = $REQUEST->user;    # Default to requesting user

    # Admins can look up other users
    if ( $REQUEST->user->is_admin ) {
        my $form_result = $self->validate_username($REQUEST);
        if ( $form_result->{result} ) {
            $target_user = $form_result->{result};
        }
    }

    # Type is automatically added by Application.pm
    return { sanctity => $target_user->sanctity };
}

__PACKAGE__->meta->make_immutable;

1;
