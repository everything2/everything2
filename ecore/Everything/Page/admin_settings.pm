package Everything::Page::admin_settings;

use Moose;
extends 'Everything::Page::settings';

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)

=head1 NAME

Everything::Page::admin_settings - Admin Settings page for editors

=head1 DESCRIPTION

Extends the Settings page with defaultTab='admin' to show the Admin tab.
Non-editors are redirected to regular Settings (they won't see the Admin tab).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Get the base settings data from parent class
    my $response = $self->SUPER::buildReactData($REQUEST);

    # Non-editors get regular settings (no admin tab available)
    return $response unless $APP->isEditor($user->NODEDATA);

    # Set default tab to admin for editors
    $response->{defaultTab} = 'admin';

    return $response;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::settings>

=cut
