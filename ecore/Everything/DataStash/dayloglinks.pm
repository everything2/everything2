package Everything::DataStash::dayloglinks;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $daylogs = [];
  my @months = qw(January February March April May June July August September October November December);

  my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
  $year+= 1900;

  # Link to monthly ed log/root
  my $mnthdate = $months[$mon].' '.$year;

  my $daydate = "$months[$mon] $mday, $year";
  # Create daylog e2node if it's not already there.

  foreach my $block([$daydate,"Day logs for $daydate"],["Editor Log: $mnthdate","Editor logs for $mnthdate"],["root log: $mnthdate","Coder logs for $mnthdate"])
  {
    $this->DB->insertNode($block->[0], 'e2node', $this->DB->getNode('Cool Man Eddie', 'user')) unless $this->DB->getNode($block->[0], 'e2node');
    push @$daylogs, $block;
  }

  return $this->SUPER::generate($daylogs);
}


__PACKAGE__->meta->make_immutable;
1;
