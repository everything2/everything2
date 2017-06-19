package Everything::Controller::fullpage;

use Moose;
extends 'Everything::Controller';

has 'transate_to_page' => (is => 'ro', default => 1);

__PACKAGE__->meta->make_immutable();
1;
