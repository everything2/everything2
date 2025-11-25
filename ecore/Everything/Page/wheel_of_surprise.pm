package Everything::Page::wheel_of_surprise;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user;

  # Get user's GP and opt-out status
  # Note: $USER is a blessed user object, must call methods not hash access
  my $userGP = $USER->GP || 0;
  my $hasGPOptout = $USER->gp_optout ? 1 : 0;

  # Check if it's Halloween
  my $isHalloween = 0;  # TODO: Use $self->APP->isSpecialDate('halloween')

  return {
    contentData => {
      type => 'wheel_of_surprise',
      result => undef,  # No initial result
      isHalloween => $isHalloween,
      userGP => $userGP,
      hasGPOptout => $hasGPOptout
    }
  };
}

__PACKAGE__->meta->make_immutable;

1;
