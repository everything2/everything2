package Everything::Node::stylesheet;
use Moose;

extends 'Everything::Node';
with 'Everything::Node::helper::s3';

has 'media_extension' => (isa => 'Str', is => 'ro', default => 'css');
has 'local_pref' => (isa => 'Str', is => 'ro', default => 'use_local_css');

sub supported
{
  my ($self) = @_;
  return $self->APP->getParameter($self->NODEDATA, "supported_sheet");
}

__PACKAGE__->meta->make_immutable;
1;
