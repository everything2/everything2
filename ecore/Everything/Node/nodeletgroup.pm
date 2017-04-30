package Everything::Node::nodeletgroup;

use Moose;
extends 'Everything::Node::htmlcode';
with 'Everything::Node::helper::group';

__PACKAGE__->meta->make_immutable;
1;
