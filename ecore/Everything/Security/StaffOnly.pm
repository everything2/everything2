package Everything::Security::StaffOnly;

use Moose::Role;

use Everything::PermissionResult::OK;
use Everything::PermissionResult::RedirectLogin;

sub check_permission
{
  my ($self, $REQUEST, $node) = @_;

  if($REQUEST->user->is_editor)
  {
    return Everything::PermissionResult::OK->new;
  }else{
    return Everything::PermissionResult::RedirectLogin->new;
  }
}

1;
