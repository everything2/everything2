package Everything::Security::NoGuest;

use Moose::Role;

use Everything::PermissionResult::OK;
use Everything::PermissionResult::RedirectLogin;

sub check_permission
{
  my ($self, $REQUEST, $node) = @_;

  $self->devLog("Inside of Everything::Security::NoGuest");
  if($REQUEST->user->is_guest)
  {
    return Everything::PermissionResult::RedirectLogin->new;
  }else{
    return Everything::PermissionResult::OK->new;
  }
}

1;
