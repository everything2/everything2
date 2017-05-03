package Everything::API::e2nodes;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

__PACKAGE__->meta->make_immutable;
1;
