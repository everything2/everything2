package Everything::Controller::restricted_superdoc;

use Moose;
extends 'Everything::Controller::superdoc';

# restricted_superdoc inherits from superdoc and uses the same controller
# This enables React page routing for restricted_superdoc nodes
# (e.g., Giant Teddy Bear Suit, Suspension Info)

__PACKAGE__->meta->make_immutable();
1;
