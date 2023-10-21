package Everything::Preference::List;

use Moose;
use namespace::autoclean;
extends 'Everything::Preference';

has 'allowed_values' => (isa => 'ArrayRef', is => 'ro');

sub validate
{
  my ($self, $value) = @_;

  return scalar(grep({$value eq "$_"} @{$self->allowed_values}) == 1);
}

sub should_delete
{
  my ($self, $value) = @_;

  return ($value == $self->default_value);
}

__PACKAGE__->meta->make_immutable;
1;
