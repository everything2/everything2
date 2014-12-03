package Everything::DataStash::randomnodes;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $randomnodes = [];

  foreach(1..12)
  {
    my $N = $this->APP->getRandomNode();
    push $randomnodes, {"node_id" => $N->{node_id}, "title" => $N->{title}};
  }

  return $this->SUPER::generate($randomnodes);
}


__PACKAGE__->meta->make_immutable;
1;
