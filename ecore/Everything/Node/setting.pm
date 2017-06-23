package Everything::Node::setting;
use Moose;
extends 'Everything::Node';
with 'Everything::Node::helper::setting';

__PACKAGE__->meta->make_immutable;
1;
