package Everything::API::users;

use Moose;
extends 'Everything::API::nodes';

has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

sub field_whitelist
{
  my ($self) = @_;
  return ["doctext"];
}

1;
