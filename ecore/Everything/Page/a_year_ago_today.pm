package Everything::Page::a_year_ago_today;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year+=1900;

  my $yearsago = $REQUEST->param('yearsago') || '';
  $yearsago =~ s/[^0-9]//g;
  $yearsago||=1;

  my $startat = $REQUEST->param('startat') || '';
  $startat =~ s/[^0-9]//g;
  $startat ||=0;

  my $previous = $self->APP->previous_years_nodes($yearsago, $startat);

  # int(): yearsago/startat come off the URL as strings, and JSON would ship them that way --
  # React then concatenated ("50" + 50 = "5050") and never matched yearsago === 1 (#4579).
  # The unused `node` field is gone; React never read it, and a blessed node there would 500 too.
  return {
    current_year => int($year),
    count => int($previous->{count} || 0),
    yearsago => int($yearsago),
    nodes => $previous->{nodes},
    startat => int($startat),
  };
}

__PACKAGE__->meta->make_immutable;

1;
