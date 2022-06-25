package Everything::Node::helper::s3;

use Moose::Role;

sub cdn_link
{
  my ($self) = @_;
  return $self->APP->asset_uri($self->node_id.".".$self->media_extension);
}

sub contentversion
{
  my ($self) = @_;

  return $self->NODEDATA->{contentversion};
}

1;
