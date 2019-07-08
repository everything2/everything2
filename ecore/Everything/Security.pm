package Everything::Security;

use Moose::Role;

use Everything::PermissionResult::OK;
with 'Everything::HTTP';
with 'Everything::Globals';

sub check_permission
{
  my ($self) = @_;

  $self->devLog("Inside of Everything::Security");
  return Everything::PermissionResult::OK->new;
}

1;
