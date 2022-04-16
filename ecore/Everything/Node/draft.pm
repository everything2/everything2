package Everything::Node::draft;
use Moose;
extends 'Everything::Node::writeup';

sub canonical_url
{
  my ($self) = @_;
  return "/user/".$self->author->uri_safe_title."/writeups/".$self->uri_safe_title;
}
__PACKAGE__->meta->make_immutable;
1;
