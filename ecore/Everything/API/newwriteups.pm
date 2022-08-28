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

  my $writeupslist = $self->DB->stashData("newwriteups2");

  unless(UNIVERSAL::isa($writeupslist, "ARRAY"))
  {
    return [$self->HTTP_UNAVAILABLE];
  }

  my $writeups_out = $self->APP->filtered_newwriteups2($REQUEST->user->is_editor);
  return [$self->HTTP_OK, $writeups_out];
}

1;
