package Everything::Node;

use strict;
use Everything;
use Moose;

with 'Everything::Globals';

has 'NODEDATA' => (isa => "HashRef", required => 1, is => "rw");

sub get
{
  my ($self) = @_;
}

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift; 
  my $NODEDATA = shift;

  return $class->$orig("NODEDATA" => $NODEDATA);
};

__PACKAGE__->meta->make_immutable;
1;
