package Everything::Controller::oppressor_document;

use Moose;
extends 'Everything::Controller::document';

# Oppressor Document Controller
#
# Handles display of oppressor_document nodes (admin-only documents).
# Fully inherits from document controller - same display and edit behavior.

__PACKAGE__->meta->make_immutable;
1;
