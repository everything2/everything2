package Everything::API::usergroups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

1;

