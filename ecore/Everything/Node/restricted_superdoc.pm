package Everything::Node::restricted_superdoc;
use Moose;
extends 'Everything::Node::document';

__PACKAGE__->meta->make_immutable;
1;
