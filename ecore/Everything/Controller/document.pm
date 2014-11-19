package Everything::Controller::document;

use Moose;

extends 'Everything::Controller';

has '+EXTERNAL' => (default => sub { [qw/display/]});

sub display
{
  my ($this, $request) = @_;

  $request->response->template("document");

  return $this->SUPER::display($request);
}

1;
