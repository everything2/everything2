package Everything::Page::sanctify;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user;

  return {
    contentData => {
      type => 'sanctify',
      sanctity => $USER->sanctity
      # Note: GP and GPOptout available in e2.user (global)
    }
  };
}

__PACKAGE__->meta->make_immutable;

1;
