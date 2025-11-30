package Everything::Page::a_year_ago_today;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST, $node) = @_;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year+=1900;

  my $yearsago = $REQUEST->param('yearsago') || '';
  $yearsago =~ s/[^0-9]//g;
  $yearsago||=1;

  my $startat = $REQUEST->param('startat') || '';
  $startat =~ s/[^0-9]//g;
  $startat ||=0;

  my $previous = $self->APP->previous_years_nodes($yearsago, $startat);

  return {
    current_year => $year,
    count => $previous->{count},
    yearsago => $yearsago,
    nodes => $previous->{nodes},
    startat => $startat,
    node => $node
  };
}

__PACKAGE__->meta->make_immutable;

1;
