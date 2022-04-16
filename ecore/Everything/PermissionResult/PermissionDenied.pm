package Everything::PermissionResult::PermissionDenied;

use Moose;
extends 'Everything::PermissionResult';

has allowed => (default => '0', is => 'ro');
has redirect => (default => sub { $_[0]->CONF->permission_denied_location }, is => 'ro');

1;
