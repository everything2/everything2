package Everything::Node::nodegroup;

use Moose;
extends 'Everything::Node';
with 'Everything::Node::helper::group';

__PACKAGE__->meta->make_immutable;
1;
