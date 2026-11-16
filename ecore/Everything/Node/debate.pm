package Everything::Node::debate;
use Moose;
# A debate is the root of a discussion and follows the same access rule as its comments.
extends 'Everything::Node::debatecomment';

__PACKAGE__->meta->make_immutable;
1;
