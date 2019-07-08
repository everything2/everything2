package Everything::PermissionResult::RedirectLogin;

use Moose;
extends 'Everything::PermissionResult';

has allowed => (default => '0', is => 'ro');
has redirect => (default => sub { $_[0]->CONF->login_location }, is => 'ro');

1;
