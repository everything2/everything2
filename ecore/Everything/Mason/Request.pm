package Everything::Mason::Request;

use Moose;
extends 'Mason::Request';

around 'comp' => sub {
  my $orig = shift;
  my $self = shift;
  my $component = shift;

  # Syntactic sugar to shorten code up
  unless($self->comp_exists($component))
  {
    $component = "/helpers/$component.mi";
  }
  return $self->$orig($component, @_);
};

__PACKAGE__->meta->make_immutable;

1;
