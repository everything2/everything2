package Everything::Node::helper::s3;

use Moose::Role;

sub cdn_link
{
  my ($self, $decoration) = @_;
  my $link = "https://s3.amazonaws.com/jscss.everything2.com/";
  $link .= join(".",$self->node_id,$self->contentversion,"min");
  $link .= ".$decoration" if $decoration;

  return $link;
}

sub contentversion
{
  my ($self) = @_;

  return $self->NODEDATA->{contentversion};
}

1;
