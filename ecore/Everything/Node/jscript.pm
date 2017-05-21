package Everything::Node::jscript;
use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::s3';

around 'cdn_link' => sub {
  my $orig = shift;
  my $self = shift;

  return $self->$orig(@_).".js";
};

__PACKAGE__->meta->make_immutable;
1;
