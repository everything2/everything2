package Everything::Controller::superdocnolinks;

use Moose;
extends 'Everything::Controller::superdoc';

# Superdocnolinks Controller
#
# Inherits from superdoc controller to get React Page class support.
# superdocnolinks nodes are displayed identically to superdocs - the only
# difference is that link parsing is disabled in their content.
#
# Since superdocnolinks inherits from superdoc in the nodetype hierarchy,
# it makes sense that its controller also inherits from the superdoc controller.

__PACKAGE__->meta->make_immutable();
1;
