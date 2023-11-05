package Everything::API::newwriteups;

use Moose;

extends 'Everything::API';

sub routes
{
  return {"/" => "get"}
}

sub get
{
  my ($self, $REQUEST) = @_;

  my $writeups_out = $self->APP->filtered_newwriteups($REQUEST->user->NODEDATA);
  unless(UNIVERSAL::isa($writeups_out, "ARRAY"))
  {
    return [$self->HTTP_UNAVAILABLE];
  }
  return [$self->HTTP_OK, $writeups_out];
}

1;
