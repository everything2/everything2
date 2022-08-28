package Everything::API::hidewriteups;

use Moose;
use namespace::autoclean;
use Everything::DataStash::newwriteups2;
extends 'Everything::API';


sub routes
{ 
  return {
  ":id/action/hide" => "hide_writeup(:id)",
  ":id/action/show" => "show_writeup(:id)"
  }
}

sub toggle_writeup
{
  my ($self, $REQUEST, $writeup_id, $notnew) = @_;

  my $writeup = $self->APP->node_by_id($writeup_id);
  if(defined($writeup) and $writeup->type->title eq "writeup")
  {
    $writeup->update($REQUEST->user, {notnew => $notnew});

    my $datastash = Everything::DataStash::newwriteups2->new(APP => $self->APP, CONF => $self->CONF, DB => $self->DB);
    $datastash->generate();

    return [$self->HTTP_OK, {node_id => $writeup->node_id, notnew => ($notnew)?(\1):(\0)}];
  }else{
    $self->devLog("Can't access toggle_writeup due to '$writeup_id' not being a writeup");
    return [$self->HTTP_UNAUTHORIZED];
  }
}

sub hide_writeup
{
  my ($self, $REQUEST, $writeup_id) = @_;
  return $self->toggle_writeup($REQUEST, $writeup_id, 1);
}

sub show_writeup
{
  my ($self, $REQUEST, $writeup_id) = @_;

  return $self->toggle_writeup($REQUEST, $writeup_id, 0); 
}

around ['hide_writeup','show_writeup'] => \&Everything::API::unauthorized_unless_editor;
__PACKAGE__->meta->make_immutable;
1;
