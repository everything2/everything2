package Everything::Controller::document;

use Moose;
use namespace::autoclean;

extends 'Everything::Controller';

has '+EXTERNAL' => (default => sub { [qw/display/]});

sub display
{
  my ($this, $request) = @_;

  $request->response->template("document");

  return $this->SUPER::display($request);
}

__PACKAGE__->meta->make_immutable;
1;
