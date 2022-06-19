package Everything::Node::jscript;
use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::s3';
has 'media_extension' => (isa => 'Str', is => 'ro', default => 'js');

__PACKAGE__->meta->make_immutable;
1;
