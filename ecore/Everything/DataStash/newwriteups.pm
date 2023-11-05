package Everything::DataStash::newwriteups;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;
  my $howMany = 100;

  my $cuss = $this->DB->sqlSelectMany('writeup_id','writeup',"publishtime > 0 ORDER BY publishtime DESC LIMIT $howMany");

  my $writeups = [];
  while(my $item = $cuss->fetchrow_hashref)
  {
    my $writeup = $this->APP->node_by_id($item->{writeup_id});
    next unless $writeup;

    push @$writeups, $writeup->new_writeups_reference;
  }

  return $this->SUPER::generate($writeups);
}


__PACKAGE__->meta->make_immutable;
1;
