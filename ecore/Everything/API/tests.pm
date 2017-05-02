package Everything::API::tests;

use strict;
use Moose;
use namespace::autoclean;

extends 'Everything::API';

has 'MINIMUM_VERSION' => (isa => "Int", default => 2, is => "ro");
has 'CURRENT_VERSION' => (isa => "Int", default => 3, is => "ro");

sub routes
{
  return {
  "/" => "get",
  }
}


sub get
{
  my ($self, $REQUEST) = @_;

  my $version = $REQUEST->get_api_version || $self->CURRENT_VERSION;

  if($version == 2)
  {
    return [$self->HTTP_OK, {"v" => $version }];
  }else{
    return [$self->HTTP_OK, {"version" => $version}];
  }
}

__PACKAGE__->meta->make_immutable;
1;

