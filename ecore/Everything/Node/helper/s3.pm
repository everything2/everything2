package Everything::Node::helper::s3;

use Moose::Role;

sub cdn_link
{
  my ($self, $decoration) = @_;

  if($self->CONF->use_local_assets)
  {
    return "/".$self->media_extension."/".$self->node_id.'.'.$self->media_extension;
  }

  my $link = $self->CONF->assets_location;
  $link .= join(".",$self->node_id,"min");
  $link .= ".$decoration" if $decoration;
  $link .= ".".$self->media_extension;

  return $link;
}

sub contentversion
{
  my ($self) = @_;

  return $self->NODEDATA->{contentversion};
}

1;
