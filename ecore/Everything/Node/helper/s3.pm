package Everything::Node::helper::s3;

use Moose::Role;

sub use_local
{
  my ($self) = @_;

  my $attr = $self->local_pref;
  return $self->CONF->$attr;
}

sub cdn_link
{
  my ($self, $decoration) = @_;

  if($self->use_local)
  {
    return "/".$self->media_extension."/".$self->node_id.'.'.$self->media_extension;
  }

  my $link = "https://s3-us-west-2.amazonaws.com/deployed.everything2.com/".$self->CONF->last_commit."/";
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
