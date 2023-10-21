package Everything::Preference::String;

use Moose;
use namespace::autoclean;
extends 'Everything::Preference';

has 'allowed_values' => (isa => 'REGEXP', is => 'ro');

sub validate
{
  my ($self, $value) = @_;

  return scalar($value =~ $self->allowed_values);
}

sub should_delete
{
  my ($self, $value) = @_;

  return ($value eq "" or $value =~ /^\s+$/);
}

__PACKAGE__->meta->make_immutable;
1;
