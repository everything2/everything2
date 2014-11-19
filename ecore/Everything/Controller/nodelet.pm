package Everything::Controller::nodelet;

use Moose;
extends 'Everything::Controller';

sub nodelet
{
  my ($this, $request, $node, $properties) = @_;

  my $nodelettitle = $node->{title};
  my $nodeletclass = $nodelettitle;
  $nodeletclass =~ s/\W//g;

  $properties->{nodelettitle} = $nodelettitle;
  $properties->{nodeletclass} = $nodeletclass;

  my $template = $properties->{template};

  return $request->response->make_block($template, $properties);
}

1;

