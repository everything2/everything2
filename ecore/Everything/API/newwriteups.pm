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

  my $writeups_out = [];
  my $writeupslist = $self->DB->stashData("newwriteups2");

  unless(UNIVERSAL::isa($writeupslist, "ARRAY"))
  {
    return [$self->HTTP_UNAVAILABLE];
  }

  my $limit = 15; 

  if(not $REQUEST->is_guest)
  {
    $limit = $REQUEST->param("limit") || 15;
    $limit = 40 if $limit > 40;
  }

  foreach my $writeup (@$writeupslist)
  {
    if($writeup->{notnew} and not $REQUEST->is_editor)
    {
      next;
    }

    my $writeup_to_add;
    foreach my $param (qw|title node_id is_log writeuptype parent author|)
    {
      $writeup_to_add->{$param} = $writeup->{$param};
    }

    if($REQUEST->is_editor)
    {
      $writeup_to_add->{notnew} = $writeup->{notnew};
    }

    push @$writeups_out, $writeup_to_add;

    if(scalar(@$writeups_out) == $limit)
    {
      last;
    }    
  }

  return [$self->HTTP_OK, $writeups_out];
}

1;
