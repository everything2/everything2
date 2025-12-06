package Everything::Security::StaffOrDeveloper;

use Moose::Role;

use Everything::PermissionResult::OK;
use Everything::PermissionResult::PermissionDenied;

# Allows access to editors, developers, and admins
# Used for maintenance nodes and other system pages
sub check_permission
{
  my ($self, $REQUEST, $node) = @_;

  my $user = $REQUEST->user;

  # Allow editors (staff) - includes admins via is_editor check
  if($user->is_editor)
  {
    return Everything::PermissionResult::OK->new;
  }

  # Allow developers (edev group)
  if($user->is_developer)
  {
    return Everything::PermissionResult::OK->new;
  }

  # Deny everyone else
  return Everything::PermissionResult::PermissionDenied->new;
}

1;
