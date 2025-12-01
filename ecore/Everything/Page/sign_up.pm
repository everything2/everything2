package Everything::Page::sign_up;

use Moose;
use utf8;
extends 'Everything::Page';

=head1 NAME

Everything::Page::sign_up - Sign Up page for new user registration

=head1 DESCRIPTION

This Page class provides initial data for the Sign Up React component.
The actual registration is handled by the /api/signup endpoint.

=cut

sub buildReactData {
  my ($self, $REQUEST) = @_;

  my $CONF = $self->CONF;

  # Determine if we need reCAPTCHA
  my $use_recaptcha = 0;
  if ($CONF->is_production || ($ENV{HTTP_HOST} // '') =~ /^development\.everything2\.com/) {
    $use_recaptcha = 1;
  }

  return {
    type => 'sign_up',
    use_recaptcha => $use_recaptcha,
    recaptcha_v3_public_key => $CONF->recaptcha_v3_public_key // ''
  };
}

__PACKAGE__->meta->make_immutable;

1;
