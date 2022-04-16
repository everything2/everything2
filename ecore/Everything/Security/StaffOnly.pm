package Everything::Security::StaffOnly;

use Moose::Role;

use Everything::PermissionResult::OK;
use Everything::PermissionResult::PermissionDenied;

sub check_permission
{
  my ($self, $REQUEST, $node) = @_;

  if($REQUEST->user->is_editor)
  {
    return Everything::PermissionResult::OK->new;
  }else{
    return Everything::PermissionResult::PermissionDenied->new;
  }
}

1;
