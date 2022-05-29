package Everything::Node::stylesheet;
use Moose;

extends 'Everything::Node';
with 'Everything::Node::helper::s3';

sub supported
{
  my ($self) = @_;
  return $self->APP->getParameter($self->NODEDATA, "supported_sheet");
}

around 'cdn_link' => sub
{
  my $orig = shift;
  my $self = shift;

  return $self->$orig(@_).".css";
};

__PACKAGE__->meta->make_immutable;
1;
