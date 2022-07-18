package Everything::API::developervars;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{ 
  return {
  "/" => "get_vars",
  }
}

sub get_vars
{
  my ($self, $REQUEST) = @_;

  my $output = {};

  foreach my $key (keys %{$REQUEST->user->VARS})
  {
    $output->{$key} = $REQUEST->user->VARS->{$key};
  }

  return [$self->HTTP_OK, $output];
}

around ['get_vars'] => \&Everything::API::unauthorized_unless_developer;
__PACKAGE__->meta->make_immutable;
1;
