package Everything::Node::jscript;
use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::s3';
has 'media_extension' => (isa => 'Str', is => 'ro', default => 'js');
has 'local_pref' => (isa => 'Str', is => 'ro', default => 'use_local_javascript');

__PACKAGE__->meta->make_immutable;
1;
