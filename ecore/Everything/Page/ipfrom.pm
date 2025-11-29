package Everything::Page::ipfrom;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Get user's IP address
  my $ip = $REQUEST->get_ip;

  return {
    ip => $ip
  };
}

__PACKAGE__->meta->make_immutable;

1;
