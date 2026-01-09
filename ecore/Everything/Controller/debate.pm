package Everything::Controller::debate;

use Moose;
extends 'Everything::Controller::debatecomment';

# Debate Controller
#
# Handles display of debate nodes (usergroup discussion containers).
# Fully inherits from debatecomment controller since debate extends
# debatecomment in the nodetype hierarchy.

__PACKAGE__->meta->make_immutable;
1;
