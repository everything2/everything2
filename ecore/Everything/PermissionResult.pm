package Everything::PermissionResult;

use Moose;

with 'Everything::Globals';
with 'Everything::HTTP';

has allowed => (default => '1', is => 'ro');
has redirect => (default => '', is => 'ro');

__PACKAGE__->meta->make_immutable();
1;
