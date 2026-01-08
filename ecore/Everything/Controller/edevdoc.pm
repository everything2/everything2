package Everything::Controller::edevdoc;

use Moose;
extends 'Everything::Controller::document';

# Edevdoc Controller
#
# Handles display of edevdoc nodes (E2 developer documentation).
# Fully inherits from document controller - same display and edit behavior.

__PACKAGE__->meta->make_immutable;
1;
