package Everything::Node::document;

use Moose;
extends 'Everything::Node';

override 'json_display' => sub
{
  my ($self) = @_;

  my $values = super();
  if(defined($self->doctext))
  {
      $values->{doctext} = $self->doctext;
  }

  return $values;
};

sub doctext
{
  my ($self) = @_;
  return $self->NODEDATA->{doctext};
}

__PACKAGE__->meta->make_immutable;
1;
