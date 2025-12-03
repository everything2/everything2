package Everything::Controller::oppressor_superdoc;

use Moose;
extends 'Everything::Controller::superdoc';

# oppressor_superdoc inherits from superdoc and uses the same controller
# This enables React page routing for oppressor_superdoc nodes
# (e.g., Everything2 User Relations: e2contact and chanops)

__PACKAGE__->meta->make_immutable();
1;
